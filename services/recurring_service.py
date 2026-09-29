"""
Recurring Expenses service for scheduled templates, automated due-date calculation,
and safe confirmation-driven transaction generation.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import List, Optional, Union
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Expense, RecurringExpense, Store, Tag
from services.expense_service import create_expense


def _advance_due_date(current_date: date, frequency: str) -> date:
    """Calculate next due date based on schedule frequency."""
    freq = frequency.strip().capitalize()
    if freq == "Daily":
        return current_date + timedelta(days=1)
    elif freq == "Weekly":
        return current_date + timedelta(weeks=1)
    elif freq == "Monthly":
        # Advance approximately 1 month
        month = current_date.month % 12 + 1
        year = current_date.year + (current_date.month // 12)
        try:
            return current_date.replace(year=year, month=month)
        except ValueError:
            # Handle month-end day overflow (e.g. Jan 31 -> Feb 28)
            return (current_date.replace(day=28, year=year, month=month) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
    else:
        return current_date + timedelta(days=30)


def create_recurring_expense(
    description: str,
    amount: Union[Decimal, float, str],
    store_id: Optional[int] = None,
    tag_id: Optional[int] = None,
    frequency: str = "Monthly",
    next_due_date: Optional[date] = None,
    payment_method: str = "Cash",
    session: Optional[Session] = None,
) -> RecurringExpense:
    """Create a new recurring expense schedule."""
    clean_desc = description.strip()
    if not clean_desc:
        raise ValueError("Description cannot be empty.")

    dec_amount = Decimal(str(amount)).quantize(Decimal("0.01"))
    if dec_amount <= Decimal("0.00"):
        raise ValueError("Amount must be greater than zero.")

    due = next_due_date or date.today()

    def _execute(s: Session) -> RecurringExpense:
        rec = RecurringExpense(
            description=clean_desc,
            amount=dec_amount,
            store_id=store_id,
            tag_id=tag_id,
            frequency=frequency.strip().capitalize(),
            next_due_date=due,
            payment_method=payment_method.strip() if payment_method else "Cash",
            active=True,
        )
        s.add(rec)
        s.flush()
        return rec

    if session:
        return _execute(session)
    with get_db_session() as s:
        rec = _execute(s)
        s.expunge(rec)
        return rec


def get_all_recurring_expenses(active_only: bool = True, session: Optional[Session] = None) -> List[RecurringExpense]:
    """Retrieve recurring expense templates with eager-loaded stores and tags."""
    stmt = (
        select(RecurringExpense)
        .options(joinedload(RecurringExpense.store), joinedload(RecurringExpense.tag))
        .order_by(RecurringExpense.next_due_date.asc())
    )
    if active_only:
        stmt = stmt.where(RecurringExpense.active == True)

    if session:
        return list(session.scalars(stmt).unique().all())
    with get_db_session() as s:
        return list(s.scalars(stmt).unique().all())


def get_due_recurring_expenses(session: Optional[Session] = None) -> List[RecurringExpense]:
    """Retrieve active recurring expenses that are due today or overdue."""
    today = date.today()
    stmt = (
        select(RecurringExpense)
        .options(joinedload(RecurringExpense.store), joinedload(RecurringExpense.tag))
        .where(RecurringExpense.active == True, RecurringExpense.next_due_date <= today)
        .order_by(RecurringExpense.next_due_date.asc())
    )
    if session:
        return list(session.scalars(stmt).unique().all())
    with get_db_session() as s:
        return list(s.scalars(stmt).unique().all())


def confirm_and_log_recurring(recurring_id: int, session: Optional[Session] = None) -> Optional[Expense]:
    """
    Log an approved recurring expense into the transaction database and advance its next due date.
    Never blindly generates transactions without this confirmation step.
    """
    today = date.today()
    now_time = datetime.now().time()

    def _execute(s: Session) -> Optional[Expense]:
        rec = s.get(RecurringExpense, recurring_id)
        if not rec or not rec.active:
            return None

        # Create the confirmed expense
        new_exp = Expense(
            amount=rec.amount,
            date=today,
            time=now_time,
            description=f"[Recurring] {rec.description}",
            store_id=rec.store_id,
            tag_id=rec.tag_id,
            payment_method=rec.payment_method,
            is_recurring=True,
            recurring_expense_id=rec.id,
        )
        s.add(new_exp)

        # Advance next due date
        rec.next_due_date = _advance_due_date(rec.next_due_date, rec.frequency)
        s.flush()
        return new_exp

    if session:
        return _execute(session)
    with get_db_session() as s:
        exp = _execute(s)
        if exp:
            s.expunge(exp)
        return exp


def skip_recurring(recurring_id: int, session: Optional[Session] = None) -> bool:
    """Skip the current due instance and advance to the next due date without logging an expense."""
    def _execute(s: Session) -> bool:
        rec = s.get(RecurringExpense, recurring_id)
        if not rec:
            return False
        rec.next_due_date = _advance_due_date(rec.next_due_date, rec.frequency)
        s.flush()
        return True

    if session:
        return _execute(session)
    with get_db_session() as s:
        return _execute(s)


def delete_recurring_expense(recurring_id: int, session: Optional[Session] = None) -> bool:
    """Delete a recurring expense template."""
    def _execute(s: Session) -> bool:
        rec = s.get(RecurringExpense, recurring_id)
        if not rec:
            return False
        s.delete(rec)
        s.flush()
        return True

    if session:
        return _execute(session)
    with get_db_session() as s:
        return _execute(s)
