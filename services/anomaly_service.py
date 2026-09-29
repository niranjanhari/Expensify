"""
Anomaly Detection Service (Phase 15).
Identifies statistically unusual or outlier expenses using:
1. Interquartile Range (IQR) & Z-score by category
2. Store-specific historical spending deviation
3. Global transaction magnitude checks

Never automatically deletes or modifies transactions.
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
from database.models import Expense, Store, Tag


def detect_all_anomalies(
    days: int = 90,
    threshold_iqr: float = 1.5,
    threshold_z: float = 2.5,
    session: Optional[Session] = None,
) -> List[Dict[str, Any]]:
    """
    Scan transactions in the last `days` days and detect statistical anomalies.
    Returns:
    [
        {
            "expense_id": int,
            "amount": Decimal,
            "date": date,
            "description": str,
            "store_name": str,
            "tag_name": str,
            "anomaly_type": "Category Outlier" | "Merchant Spike" | "Global Outlier",
            "severity": "High" | "Medium",
            "message": str,
            "typical_range": str,
            "z_score": float,
        },
        ...
    ]
    """
    cutoff = date.today() - timedelta(days=days)

    def _detect(s: Session) -> List[Dict[str, Any]]:
        # Fetch expenses with eager loaded relations
        stmt = (
            select(Expense)
            .options(joinedload(Expense.store), joinedload(Expense.tag))
            .where(Expense.date >= cutoff)
            .order_by(Expense.date.desc())
        )
        expenses = list(s.scalars(stmt).all())
        if not expenses:
            return []

        # 1. Group amounts by category (Tag) and by Store
        cat_amounts: Dict[int, List[Decimal]] = defaultdict(list)
        store_amounts: Dict[int, List[Decimal]] = defaultdict(list)
        all_amounts: List[Decimal] = [e.amount for e in expenses]

        for e in expenses:
            if e.tag_id is not None:
                cat_amounts[e.tag_id].append(e.amount)
            if e.store_id is not None:
                store_amounts[e.store_id].append(e.amount)

        # 2. Compute Category Baselines
        cat_stats: Dict[int, Dict[str, Any]] = {}
        for tid, amounts in cat_amounts.items():
            if len(amounts) >= 3:
                float_vals = sorted([float(a) for a in amounts])
                n = len(float_vals)
                q1 = float_vals[int(0.25 * n)]
                q3 = float_vals[int(0.75 * n)]
                iqr = max(1.0, q3 - q1)
                mean_val = statistics.mean(float_vals)
                stdev_val = statistics.stdev(float_vals) if n > 1 else 1.0

                cat_stats[tid] = {
                    "q1": q1,
                    "q3": q3,
                    "iqr": iqr,
                    "upper_bound": q3 + (threshold_iqr * iqr),
                    "mean": mean_val,
                    "stdev": stdev_val,
                }

        # 3. Compute Store Baselines
        store_stats: Dict[int, Dict[str, Any]] = {}
        for sid, amounts in store_amounts.items():
            if len(amounts) >= 3:
                float_vals = [float(a) for a in amounts]
                store_stats[sid] = {
                    "mean": statistics.mean(float_vals),
                    "max": max(float_vals),
                }

        # 4. Global statistics
        global_floats = sorted([float(a) for a in all_amounts])
        global_median = statistics.median(global_floats) if global_floats else 100.0

        # 5. Evaluate each expense
        anomalies: List[Dict[str, Any]] = []

        for e in expenses:
            f_amt = float(e.amount)
            flagged = False
            anomaly_type = ""
            severity = "Medium"
            message = ""
            typical_str = ""
            z_score_val = 0.0

            # Check Category IQR & Z-score
            if e.tag_id in cat_stats:
                c_st = cat_stats[e.tag_id]
                z_score_val = (f_amt - c_st["mean"]) / c_st["stdev"] if c_st["stdev"] > 0 else 0.0

                if f_amt > c_st["upper_bound"] or z_score_val > threshold_z:
                    flagged = True
                    anomaly_type = "Category Outlier"
                    severity = "High" if z_score_val >= 3.0 or f_amt > (c_st["upper_bound"] * 1.5) else "Medium"
                    tag_name = e.tag.name if e.tag else "Uncategorized"
                    typical_str = f"₹{c_st['q1']:,.2f} – ₹{c_st['q3']:,.2f}"
                    message = (
                        f"₹{f_amt:,.2f} is significantly above your typical {tag_name} expenses "
                        f"(typical range: {typical_str})."
                    )

            # Check Store Deviation if not already high category outlier
            if not flagged and e.store_id in store_stats:
                s_st = store_stats[e.store_id]
                if f_amt > (s_st["mean"] * 2.5) and f_amt > 200.0:
                    flagged = True
                    anomaly_type = "Merchant Outlier"
                    severity = "Medium"
                    store_name = e.store.name if e.store else "this merchant"
                    typical_str = f"Avg ~₹{s_st['mean']:,.2f}"
                    message = f"Noticeably higher than your historical average of {typical_str} at {store_name}."

            # Check Global Outlier (single transaction >= 4x global median)
            if not flagged and f_amt >= (global_median * 4.0) and f_amt >= 1000.0:
                flagged = True
                anomaly_type = "Volume Spike"
                severity = "Medium"
                typical_str = f"Median ~₹{global_median:,.2f}"
                message = f"Single transaction is 4x your overall median purchase size ({typical_str})."

            if flagged:
                anomalies.append({
                    "expense_id": e.id,
                    "amount": e.amount,
                    "date": e.date,
                    "description": e.description or "—",
                    "store_name": e.store.name if e.store else "Unspecified Merchant",
                    "tag_name": e.tag.name if e.tag else "Uncategorized",
                    "anomaly_type": anomaly_type,
                    "severity": severity,
                    "message": message,
                    "typical_range": typical_str,
                    "z_score": float(round(z_score_val, 2)),
                })

        return anomalies

    if session:
        return _detect(session)
    with get_db_session() as s:
        return _detect(s)


def check_single_expense_anomaly(
    amount: Decimal,
    tag_id: Optional[int] = None,
    store_id: Optional[int] = None,
    session: Optional[Session] = None,
) -> Optional[Dict[str, Any]]:
    """
    Lightweight check for whether a newly entered expense is a statistical outlier.
    Returns anomaly details if flagged, or None if normal.
    """
    f_amt = float(amount)

    def _check(s: Session) -> Optional[Dict[str, Any]]:
        if tag_id:
            # Look at past 50 transactions in this category
            amounts = list(
                s.scalars(
                    select(Expense.amount)
                    .where(Expense.tag_id == tag_id)
                    .order_by(Expense.date.desc())
                    .limit(50)
                ).all()
            )
            if len(amounts) >= 3:
                float_vals = sorted([float(a) for a in amounts])
                n = len(float_vals)
                q1 = float_vals[int(0.25 * n)]
                q3 = float_vals[int(0.75 * n)]
                iqr = max(1.0, q3 - q1)
                upper = q3 + (1.5 * iqr)

                if f_amt > upper:
                    tag_obj = s.get(Tag, tag_id)
                    t_name = tag_obj.name if tag_obj else "Category"
                    return {
                        "is_anomaly": True,
                        "anomaly_type": "Category Outlier",
                        "message": f"This amount (₹{f_amt:,.2f}) is noticeably higher than your typical {t_name} spending (₹{q1:,.0f} – ₹{q3:,.0f}).",
                    }

        return None

    if session:
        return _check(session)
    with get_db_session() as s:
        return _check(s)
