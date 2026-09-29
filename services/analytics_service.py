"""
Analytics service for computing comprehensive spending patterns,
time-series trends, breakdowns by category/store/payment method, and month-over-month comparisons.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Optional
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from database.database import get_db_session
from database.models import Expense, Store, Tag


def get_analytics_data(
    time_period: str = "Monthly",
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    tag_ids: Optional[List[int]] = None,
    session: Optional[Session] = None,
) -> Dict:
    """
    Compute comprehensive financial analytics based on the selected period and optional category filters.
    Periods supported:
    - 'Daily' (last 14 days)
    - 'Weekly' (last 8 weeks)
    - 'Monthly' (last 6 months)
    - 'Custom' (user defined start_date and end_date)
    """
    today = date.today()

    # Determine date range if not Custom
    if time_period == "Daily":
        start_d = today - timedelta(days=13)
        end_d = today
    elif time_period == "Weekly":
        start_d = today - timedelta(weeks=8)
        end_d = today
    elif time_period == "Monthly":
        # First day of 6 months ago
        start_d = (today.replace(day=1) - timedelta(days=150)).replace(day=1)
        end_d = today
    else:  # Custom
        start_d = start_date or (today - timedelta(days=30))
        end_d = end_date or today

    num_days = max(1, (end_d - start_d).days + 1)

    def _calc(s: Session) -> Dict:
        # Base query conditions
        conditions = [Expense.date >= start_d, Expense.date <= end_d]
        if tag_ids:
            conditions.append(Expense.tag_id.in_(tag_ids))

        # 1. High-level aggregates
        agg_stmt = select(
            func.count(Expense.id).label("count"),
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("total"),
        ).where(*conditions)
        agg_res = s.execute(agg_stmt).one()

        tx_count = agg_res.count or 0
        total_spent = Decimal(str(agg_res.total or "0.00"))
        avg_daily = (total_spent / num_days).quantize(Decimal("0.01"))
        avg_tx = (total_spent / tx_count).quantize(Decimal("0.01")) if tx_count > 0 else Decimal("0.00")

        # 2. Peak Spending Day
        peak_day_stmt = (
            select(
                Expense.date,
                func.sum(Expense.amount).label("day_total"),
            )
            .where(*conditions)
            .group_by(Expense.date)
            .order_by(func.sum(Expense.amount).desc())
            .limit(1)
        )
        peak_day_row = s.execute(peak_day_stmt).first()
        peak_day = {
            "date": peak_day_row[0].strftime("%d %b %Y") if peak_day_row else "—",
            "amount": Decimal(str(peak_day_row[1] or "0.00")) if peak_day_row else Decimal("0.00"),
        }

        # 3. Peak Category
        peak_cat_stmt = (
            select(
                func.coalesce(Tag.name, "Uncategorized").label("tag_name"),
                func.sum(Expense.amount).label("cat_total"),
            )
            .outerjoin(Tag, Expense.tag_id == Tag.id)
            .where(*conditions)
            .group_by(Tag.name)
            .order_by(func.sum(Expense.amount).desc())
            .limit(1)
        )
        peak_cat_row = s.execute(peak_cat_stmt).first()
        peak_category = {
            "name": peak_cat_row[0] if peak_cat_row else "—",
            "amount": Decimal(str(peak_cat_row[1] or "0.00")) if peak_cat_row else Decimal("0.00"),
        }

        # 4. Peak Store
        peak_store_stmt = (
            select(
                func.coalesce(Store.name, "Unspecified Merchant").label("store_name"),
                func.sum(Expense.amount).label("store_total"),
            )
            .outerjoin(Store, Expense.store_id == Store.id)
            .where(*conditions)
            .group_by(Store.name)
            .order_by(func.sum(Expense.amount).desc())
            .limit(1)
        )
        peak_store_row = s.execute(peak_store_stmt).first()
        peak_store = {
            "name": peak_store_row[0] if peak_store_row else "—",
            "amount": Decimal(str(peak_store_row[1] or "0.00")) if peak_store_row else Decimal("0.00"),
        }

        # 5. Spending Over Time (Interactive Trend Series)
        time_series = _generate_time_series(s, conditions, start_d, end_d, time_period)

        # 6. Spending by Category (Tag)
        cat_stmt = (
            select(
                func.coalesce(Tag.name, "Uncategorized").label("name"),
                func.sum(Expense.amount).label("amount"),
            )
            .outerjoin(Tag, Expense.tag_id == Tag.id)
            .where(*conditions)
            .group_by(Tag.name)
            .order_by(func.sum(Expense.amount).desc())
        )
        cat_rows = s.execute(cat_stmt).all()
        spending_by_tag = [
            {
                "category": r.name,
                "amount": float(r.amount),
                "percentage": round((float(r.amount) / float(total_spent) * 100), 1) if total_spent > 0 else 0.0,
            }
            for r in cat_rows
        ]

        # 7. Spending by Store (Merchant)
        store_stmt = (
            select(
                func.coalesce(Store.name, "Unspecified Merchant").label("name"),
                func.sum(Expense.amount).label("amount"),
                func.count(Expense.id).label("count"),
            )
            .outerjoin(Store, Expense.store_id == Store.id)
            .where(*conditions)
            .group_by(Store.name)
            .order_by(func.sum(Expense.amount).desc())
            .limit(8)
        )
        store_rows = s.execute(store_stmt).all()
        spending_by_store = [
            {
                "store": r.name,
                "amount": float(r.amount),
                "count": r.count,
                "percentage": round((float(r.amount) / float(total_spent) * 100), 1) if total_spent > 0 else 0.0,
            }
            for r in store_rows
        ]

        # 8. Payment Method Breakdown
        pm_stmt = (
            select(
                Expense.payment_method,
                func.sum(Expense.amount).label("amount"),
                func.count(Expense.id).label("count"),
            )
            .where(*conditions)
            .group_by(Expense.payment_method)
            .order_by(func.sum(Expense.amount).desc())
        )
        pm_rows = s.execute(pm_stmt).all()
        spending_by_pm = [
            {
                "method": r.payment_method,
                "amount": float(r.amount),
                "count": r.count,
                "percentage": round((float(r.amount) / float(total_spent) * 100), 1) if total_spent > 0 else 0.0,
            }
            for r in pm_rows
        ]

        # 9. Month-over-Month Comparison
        cur_month_start = today.replace(day=1)
        prev_month_end = cur_month_start - timedelta(days=1)
        prev_month_start = prev_month_end.replace(day=1)

        cur_month_tot = s.scalar(
            select(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).where(
                Expense.date >= cur_month_start, Expense.date <= today
            )
        ) or Decimal("0.00")

        prev_month_tot = s.scalar(
            select(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).where(
                Expense.date >= prev_month_start, Expense.date <= prev_month_end
            )
        ) or Decimal("0.00")

        mom_delta = cur_month_tot - prev_month_tot
        mom_pct = (
            round(float(mom_delta / prev_month_tot) * 100, 1)
            if prev_month_tot > Decimal("0.00")
            else 0.0
        )

        return {
            "start_date": start_d,
            "end_date": end_d,
            "days_analyzed": num_days,
            "total_spent": total_spent,
            "avg_daily_spent": avg_daily,
            "avg_transaction_amt": avg_tx,
            "transaction_count": tx_count,
            "peak_day": peak_day,
            "peak_category": peak_category,
            "peak_store": peak_store,
            "time_series": time_series,
            "spending_by_tag": spending_by_tag,
            "spending_by_store": spending_by_store,
            "spending_by_pm": spending_by_pm,
            "mom": {
                "cur_month_total": cur_month_tot,
                "prev_month_total": prev_month_tot,
                "delta": mom_delta,
                "pct": mom_pct,
            },
        }

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)


def _generate_time_series(
    session: Session,
    base_conditions: list,
    start_d: date,
    end_d: date,
    period: str,
) -> List[Dict]:
    """Generate aggregated timeline buckets (daily, weekly, or monthly)."""
    # Fetch all records in range
    rows = session.execute(
        select(Expense.date, func.sum(Expense.amount).label("amt"))
        .where(*base_conditions)
        .group_by(Expense.date)
    ).all()
    date_map = {r[0]: float(r[1]) for r in rows}

    result = []
    if period in ["Daily", "Custom"]:
        # Day-by-day continuous sequence
        cur = start_d
        while cur <= end_d:
            result.append({
                "label": cur.strftime("%d %b"),
                "date": cur.strftime("%Y-%m-%d"),
                "amount": date_map.get(cur, 0.0),
            })
            cur += timedelta(days=1)
    elif period == "Weekly":
        # Group into 7-day buckets
        cur = start_d
        while cur <= end_d:
            bucket_end = min(end_d, cur + timedelta(days=6))
            bucket_amt = sum((date_map.get(cur + timedelta(days=d), 0.0) for d in range((bucket_end - cur).days + 1)))
            label = f"{cur.strftime('%d %b')} - {bucket_end.strftime('%d %b')}"
            result.append({"label": label, "date": cur.strftime("%Y-%m-%d"), "amount": bucket_amt})
            cur += timedelta(days=7)
    else:  # Monthly
        # Group by calendar month
        cur = start_d.replace(day=1)
        while cur <= end_d:
            next_m = (cur.replace(day=28) + timedelta(days=4)).replace(day=1)
            month_end = next_m - timedelta(days=1)
            bucket_amt = sum(
                (v for d, v in date_map.items() if cur <= d <= month_end)
            )
            result.append({
                "label": cur.strftime("%b %Y"),
                "date": cur.strftime("%Y-%m-%d"),
                "amount": bucket_amt,
            })
            cur = next_m

    return result
