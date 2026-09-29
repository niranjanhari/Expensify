"""
Budget service for managing overall monthly and category-specific financial goals.
Provides neutral, non-judgmental progress tracking and headroom calculations.
"""

from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Dict, List, Optional, Union
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Budget, Expense, Tag


def set_budget(
    amount: Union[Decimal, float, str],
    tag_id: Optional[int] = None,
    period: str = "monthly",
    session: Optional[Session] = None,
) -> Budget:
    """
    Set or update a budget goal.
    If tag_id is None, sets the overall monthly budget.
    If tag_id is provided, sets a category-specific budget.
    """
    dec_amount = Decimal(str(amount)).quantize(Decimal("0.01"))
    if dec_amount <= Decimal("0.00"):
        raise ValueError("Budget amount must be greater than zero.")

    def _execute(s: Session) -> Budget:
        # Check if budget already exists for this tag/overall
        stmt = select(Budget).where(Budget.tag_id == tag_id, Budget.period == period)
        existing = s.scalar(stmt)
        if existing:
            existing.amount = dec_amount
            s.flush()
            return existing

        new_budget = Budget(
            amount=dec_amount,
            tag_id=tag_id,
            period=period,
        )
        s.add(new_budget)
        s.flush()
        return new_budget

    if session:
        return _execute(session)
    with get_db_session() as s:
        b = _execute(s)
        s.expunge(b)
        return b


def delete_budget(budget_id: int, session: Optional[Session] = None) -> bool:
    """Delete a budget goal."""
    def _execute(s: Session) -> bool:
        budget = s.get(Budget, budget_id)
        if not budget:
            return False
        s.delete(budget)
        s.flush()
        return True

    if session:
        return _execute(session)
    with get_db_session() as s:
        return _execute(s)


def get_all_budgets(session: Optional[Session] = None) -> List[Budget]:
    """Retrieve all active budget targets with eager-loaded tags."""
    stmt = select(Budget).options(joinedload(Budget.tag)).order_by(Budget.tag_id.asc().nullsfirst())
    if session:
        return list(session.scalars(stmt).all())
    with get_db_session() as s:
        return list(s.scalars(stmt).all())


def get_budget_progress(session: Optional[Session] = None) -> Dict:
    """
    Compute progress, remaining amounts, and neutral feedback for all active budgets.
    Uses month-to-date spending for calculations.
    """
    today = date.today()
    month_start = today.replace(day=1)

    def _calc(s: Session) -> Dict:
        budgets = list(s.scalars(select(Budget).options(joinedload(Budget.tag))).all())
        
        # 1. Overall month spending
        overall_spent = s.scalar(
            select(func.coalesce(func.sum(Expense.amount), Decimal("0.00")))
            .where(Expense.date >= month_start, Expense.date <= today)
        ) or Decimal("0.00")

        # 2. Tag-specific spending
        tag_spent_rows = s.execute(
            select(Expense.tag_id, func.sum(Expense.amount))
            .where(Expense.date >= month_start, Expense.date <= today, Expense.tag_id != None)
            .group_by(Expense.tag_id)
        ).all()
        tag_spent_map = {row[0]: Decimal(str(row[1])) for row in tag_spent_rows}

        overall_budget_info = None
        category_budgets_info = []

        for b in budgets:
            if b.tag_id is None:
                # Overall Budget
                b_amt = b.amount
                spent = overall_spent
                rem = max(Decimal("0.00"), b_amt - spent)
                over = max(Decimal("0.00"), spent - b_amt)
                pct = round(float(spent / b_amt * 100), 1) if b_amt > 0 else 0.0

                if spent <= b_amt:
                    status_text = f"Overall spending is currently {pct}% of your monthly budget."
                else:
                    status_text = f"Overall spending has exceeded your monthly target by {pct - 100:.1f}%."

                overall_budget_info = {
                    "id": b.id,
                    "budget_amount": b_amt,
                    "spent_amount": spent,
                    "remaining_amount": rem,
                    "overspent_amount": over,
                    "percentage_used": pct,
                    "status_message": status_text,
                }
            else:
                # Category Budget
                b_amt = b.amount
                tag_name = b.tag.name if b.tag else "Uncategorized"
                spent = tag_spent_map.get(b.tag_id, Decimal("0.00"))
                rem = max(Decimal("0.00"), b_amt - spent)
                over = max(Decimal("0.00"), spent - b_amt)
                pct = round(float(spent / b_amt * 100), 1) if b_amt > 0 else 0.0

                if spent <= b_amt:
                    status_text = f"{tag_name} spending is currently {pct}% of your monthly {tag_name} budget."
                else:
                    status_text = f"{tag_name} spending has reached {pct}% of your planned limit."

                category_budgets_info.append({
                    "id": b.id,
                    "tag_id": b.tag_id,
                    "category": tag_name,
                    "budget_amount": b_amt,
                    "spent_amount": spent,
                    "remaining_amount": rem,
                    "overspent_amount": over,
                    "percentage_used": pct,
                    "status_message": status_text,
                })

        return {
            "has_budgets": len(budgets) > 0,
            "overall": overall_budget_info,
            "categories": category_budgets_info,
            "month_name": today.strftime("%B %Y"),
        }

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)
