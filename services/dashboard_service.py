"""
Dashboard service for computing top KPI metrics, spending trends, and category distribution.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Optional
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from database.database import get_db_session
from database.models import Expense, Store, Tag


def get_dashboard_summary(session: Optional[Session] = None) -> Dict:
    """
    Compute core high-level metrics for the user:
    - This Month's spending
    - Today's spending
    - Average daily spending for the current month
    - Number of transactions this month and today
    - All-time total spending
    """
    today = date.today()
    month_start = today.replace(day=1)

    def _calc(s: Session) -> Dict:
        # Month metrics
        month_stmt = select(
            func.count(Expense.id).label("count"),
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("total"),
        ).where(Expense.date >= month_start, Expense.date <= today)
        month_res = s.execute(month_stmt).one()
        month_count = month_res.count or 0
        month_total = Decimal(str(month_res.total or "0.00"))

        # Today metrics
        today_stmt = select(
            func.count(Expense.id).label("count"),
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("total"),
        ).where(Expense.date == today)
        today_res = s.execute(today_stmt).one()
        today_count = today_res.count or 0
        today_total = Decimal(str(today_res.total or "0.00"))

        # Daily Average for current month (days elapsed so far)
        days_elapsed = max(1, today.day)
        daily_avg = (month_total / days_elapsed).quantize(Decimal("0.01"))

        # All-time total
        all_time_stmt = select(
            func.count(Expense.id).label("count"),
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("total"),
        )
        all_time_res = s.execute(all_time_stmt).one()
        all_time_total = Decimal(str(all_time_res.total or "0.00"))
        all_time_count = all_time_res.count or 0

        return {
            "this_month_total": month_total,
            "this_month_count": month_count,
            "today_total": today_total,
            "today_count": today_count,
            "daily_avg": daily_avg,
            "days_elapsed": days_elapsed,
            "all_time_total": all_time_total,
            "all_time_count": all_time_count,
        }

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)


def get_daily_spending_trend(days: int = 30, session: Optional[Session] = None) -> List[Dict]:
    """
    Retrieve daily aggregated spending for the last N days.
    Fills in zeros for days without expenses to guarantee continuous charts.
    """
    today = date.today()
    start_date = today - timedelta(days=days - 1)

    def _calc(s: Session) -> List[Dict]:
        stmt = (
            select(
                Expense.date.label("expense_date"),
                func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("daily_total"),
            )
            .where(Expense.date >= start_date, Expense.date <= today)
            .group_by(Expense.date)
        )
        rows = s.execute(stmt).all()
        date_map = {row.expense_date: float(row.daily_total) for row in rows}

        trend = []
        cur_date = start_date
        while cur_date <= today:
            trend.append({
                "date": cur_date.strftime("%Y-%m-%d"),
                "display_date": cur_date.strftime("%d %b"),
                "amount": date_map.get(cur_date, 0.0),
            })
            cur_date += timedelta(days=1)

        return trend

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)


def get_category_breakdown(days: int = 30, session: Optional[Session] = None) -> List[Dict]:
    """
    Retrieve category (tag) spending totals and percentage shares for the last N days.
    """
    today = date.today()
    start_date = today - timedelta(days=days - 1)

    def _calc(s: Session) -> List[Dict]:
        stmt = (
            select(
                func.coalesce(Tag.name, "Uncategorized").label("tag_name"),
                func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("tag_total"),
            )
            .outerjoin(Tag, Expense.tag_id == Tag.id)
            .where(Expense.date >= start_date, Expense.date <= today)
            .group_by(Tag.name)
            .order_by(func.sum(Expense.amount).desc())
        )
        rows = s.execute(stmt).all()
        total_sum = sum((float(r.tag_total) for r in rows), 0.0)

        breakdown = []
        for r in rows:
            amt = float(r.tag_total)
            pct = round((amt / total_sum * 100), 1) if total_sum > 0 else 0.0
            breakdown.append({
                "category": r.tag_name,
                "amount": amt,
                "percentage": pct,
            })

        return breakdown

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)
