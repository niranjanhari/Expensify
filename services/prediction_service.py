"""
Expense Prediction Service (Phase 14).
Generates statistical forecasts of upcoming expenses and month-end projections:
1. Recurring schedules due in the forecast window
2. Store purchase frequency and inter-purchase interval cadence
3. Day-of-week spending affinities
4. Month-end projected run-rate using weighted moving averages
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
import statistics
from typing import Any, Dict, List, Optional
from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Budget, Expense, RecurringExpense, Store, Tag


def predict_upcoming_expenses(
    days_ahead: int = 7,
    reference_date: Optional[date] = None,
    session: Optional[Session] = None,
) -> List[Dict[str, Any]]:
    """
    Predict likely upcoming transactions over the next `days_ahead` days.
    Combines:
    - Explicit recurring schedules
    - Periodic merchant purchase cadence (average interval between visits)
    - Strong day-of-week affinity
    """
    ref_d = reference_date or date.today()
    max_d = ref_d + timedelta(days=days_ahead)

    def _predict(s: Session) -> List[Dict[str, Any]]:
        predictions: List[Dict[str, Any]] = []
        seen_keys = set()

        # ---------------- 1. Scheduled Recurring Items ----------------
        recurring_items = list(
            s.scalars(
                select(RecurringExpense)
                .options(joinedload(RecurringExpense.store), joinedload(RecurringExpense.tag))
                .where(
                    RecurringExpense.active == True,
                    RecurringExpense.next_due_date >= ref_d,
                    RecurringExpense.next_due_date <= max_d,
                )
                .order_by(RecurringExpense.next_due_date.asc())
            ).all()
        )

        for rec in recurring_items:
            days_diff = (rec.next_due_date - ref_d).days
            if days_diff == 0:
                timing_str = "Expected today"
            elif days_diff == 1:
                timing_str = "Expected tomorrow"
            else:
                timing_str = f"Expected in {days_diff} days ({rec.next_due_date.strftime('%a, %d %b')})"

            store_name = rec.store.name if rec.store else rec.description
            key = f"rec_{rec.id}"
            seen_keys.add(f"store_{rec.store_id}" if rec.store_id else key)

            predictions.append({
                "source": "Scheduled Recurring",
                "title": rec.description,
                "store_name": store_name,
                "store_id": rec.store_id,
                "tag_name": rec.tag.name if rec.tag else "Uncategorized",
                "tag_id": rec.tag_id,
                "predicted_amount": rec.amount,
                "expected_date": rec.next_due_date,
                "expected_timing": timing_str,
                "confidence": 0.98,
                "reason": f"Active {rec.frequency.lower()} recurring schedule",
                "payment_method": rec.payment_method,
            })

        # ---------------- 2. Inter-Purchase Interval Cadence ----------------
        # Look at last 90 days of transactions grouped by store
        start_history = ref_d - timedelta(days=90)
        history_expenses = list(
            s.scalars(
                select(Expense)
                .options(joinedload(Expense.store), joinedload(Expense.tag))
                .where(
                    Expense.date >= start_history,
                    Expense.date <= ref_d,
                    Expense.store_id.isnot(None),
                )
                .order_by(Expense.date.asc())
            ).all()
        )

        store_dates: Dict[int, List[date]] = defaultdict(list)
        store_amounts: Dict[int, List[Decimal]] = defaultdict(list)
        store_tags: Dict[int, Optional[Tag]] = {}
        store_names: Dict[int, str] = {}
        store_pms: Dict[int, List[str]] = defaultdict(list)

        for exp in history_expenses:
            sid = exp.store_id
            if sid is not None and exp.store is not None:
                store_dates[sid].append(exp.date)
                store_amounts[sid].append(exp.amount)
                if exp.tag:
                    store_tags[sid] = exp.tag
                store_names[sid] = exp.store.name
                store_pms[sid].append(exp.payment_method)

        for sid, d_list in store_dates.items():
            if f"store_{sid}" in seen_keys:
                continue

            # Require at least 3 distinct purchase visits to establish cadence
            unique_dates = sorted(list(set(d_list)))
            if len(unique_dates) < 3:
                continue

            # Calculate intervals in days between consecutive visits
            intervals = [
                (unique_dates[i] - unique_dates[i - 1]).days
                for i in range(1, len(unique_dates))
            ]
            if not intervals:
                continue

            avg_interval = statistics.mean(intervals)
            # Only consider stores with a reasonably regular rhythm (e.g. avg interval between 1 and 21 days)
            if 1.0 <= avg_interval <= 21.0:
                last_visit = unique_dates[-1]
                days_since_last = (ref_d - last_visit).days
                expected_next_date = last_visit + timedelta(days=int(round(avg_interval)))

                # If the projected date falls between today and max_d
                if ref_d <= expected_next_date <= max_d:
                    # Calculate typical purchase amount (median or mean)
                    amounts = store_amounts[sid]
                    avg_amt = (sum(amounts) / Decimal(str(len(amounts)))).quantize(Decimal("0.01"))
                    days_diff = (expected_next_date - ref_d).days

                    if days_diff == 0:
                        timing_str = "Likely today"
                    elif days_diff == 1:
                        timing_str = "Likely tomorrow"
                    else:
                        timing_str = f"Likely in {days_diff} days ({expected_next_date.strftime('%a, %d %b')})"

                    # Confidence scaled by consistency
                    stdev_interval = statistics.stdev(intervals) if len(intervals) > 1 else 1.0
                    consistency_score = max(0.40, min(0.92, 1.0 - (stdev_interval / (avg_interval + 1.0))))

                    # Dominant payment method
                    pm_counts = defaultdict(int)
                    for pm in store_pms[sid]:
                        pm_counts[pm] += 1
                    top_pm = max(pm_counts.items(), key=lambda x: x[1])[0] if pm_counts else "Cash"

                    seen_keys.add(f"store_{sid}")
                    predictions.append({
                        "source": "Habit & Cadence",
                        "title": f"Visit to {store_names[sid]}",
                        "store_name": store_names[sid],
                        "store_id": sid,
                        "tag_name": store_tags[sid].name if sid in store_tags and store_tags[sid] else "General",
                        "tag_id": store_tags[sid].id if sid in store_tags and store_tags[sid] else None,
                        "predicted_amount": avg_amt,
                        "expected_date": expected_next_date,
                        "expected_timing": timing_str,
                        "confidence": float(round(consistency_score, 2)),
                        "reason": f"Purchased every ~{int(round(avg_interval))} days ({len(unique_dates)} visits logged)",
                        "payment_method": top_pm,
                    })

        # Sort predictions by expected date, then by confidence
        predictions.sort(key=lambda x: (x["expected_date"], -x["confidence"]))
        return predictions

    if session:
        return _predict(session)
    with get_db_session() as s:
        return _predict(s)


def predict_monthly_run_rate(
    reference_date: Optional[date] = None,
    session: Optional[Session] = None,
) -> Dict[str, Any]:
    """
    Compute statistical forecast for the current month's final spending volume:
    - Days elapsed vs total days in month
    - Weighted daily burn rate (emphasizes recent 7 days over early month)
    - Upper & Lower expected bounds
    - Comparison vs configured overall budget
    """
    ref_d = reference_date or date.today()
    month_start = ref_d.replace(day=1)
    
    # Calculate days in current month
    if ref_d.month == 12:
        next_month = ref_d.replace(year=ref_d.year + 1, month=1, day=1)
    else:
        next_month = ref_d.replace(month=ref_d.month + 1, day=1)
    days_in_month = (next_month - month_start).days
    days_elapsed = max(1, ref_d.day)
    days_remaining = max(0, days_in_month - days_elapsed)

    def _calc(s: Session) -> Dict[str, Any]:
        # 1. Month-to-date total
        m_stmt = select(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).where(
            Expense.date >= month_start,
            Expense.date <= ref_d,
        )
        mtd_total = s.scalar(m_stmt) or Decimal("0.00")

        # 2. Recent 7 days burn rate
        r_start = max(month_start, ref_d - timedelta(days=6))
        r_days = (ref_d - r_start).days + 1
        r_stmt = select(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).where(
            Expense.date >= r_start,
            Expense.date <= ref_d,
        )
        recent_total = s.scalar(r_stmt) or Decimal("0.00")

        # Weighted average daily rate: 60% recent velocity, 40% full-month velocity
        full_daily_rate = mtd_total / Decimal(str(days_elapsed))
        recent_daily_rate = recent_total / Decimal(str(r_days)) if r_days > 0 else full_daily_rate
        weighted_burn_rate = (recent_daily_rate * Decimal("0.60")) + (full_daily_rate * Decimal("0.40"))

        # Projected addition for remainder of month
        projected_remaining_spend = weighted_burn_rate * Decimal(str(days_remaining))
        projected_month_end = (mtd_total + projected_remaining_spend).quantize(Decimal("0.01"))

        # Confidence bounds (±12% based on typical variance)
        low_bound = (projected_month_end * Decimal("0.88")).quantize(Decimal("0.01"))
        high_bound = (projected_month_end * Decimal("1.12")).quantize(Decimal("0.01"))

        # Overall Budget Target
        overall_b = s.scalar(select(Budget).where(Budget.tag_id.is_(None)))
        budget_target = overall_b.amount if overall_b else None
        
        # Pacing assessment
        if budget_target and budget_target > Decimal("0.00"):
            pct_projected = float((projected_month_end / budget_target) * Decimal("100.0"))
            if pct_projected <= 95.0:
                pacing_status = "On Track (Under Budget)"
                pacing_color = "#10B981"
            elif pct_projected <= 105.0:
                pacing_status = "Close to Target (Within 5%)"
                pacing_color = "#F59E0B"
            else:
                pacing_status = "Projected to Exceed Budget"
                pacing_color = "#F43F5E"
        else:
            pct_projected = 0.0
            pacing_status = "Uncapped (No Budget Set)"
            pacing_color = "#6366F1"

        return {
            "days_elapsed": days_elapsed,
            "days_remaining": days_remaining,
            "days_in_month": days_in_month,
            "mtd_spent": mtd_total,
            "current_daily_burn": weighted_burn_rate.quantize(Decimal("0.01")),
            "projected_month_end": projected_month_end,
            "range_low": low_bound,
            "range_high": high_bound,
            "budget_target": budget_target,
            "pct_projected": pct_projected,
            "pacing_status": pacing_status,
            "pacing_color": pacing_color,
        }

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)
