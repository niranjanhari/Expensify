"""
Service for managing user-configured bank account balance and real-time tracking.

Follows principles:
1. Manual user entry (no fake transactions, no automatic bank retrieval).
2. Never treated as income.
3. Persistent in database (survives refreshes, reruns, redeployments).
4. Pure read-calculation for current balance:
   current_balance = baseline_amount - sum(expenses logged since baseline)
   This guarantees no accidental double-subtractions on Streamlit reruns.
5. Fully compatible with SQLite and Supabase PostgreSQL.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Dict, Optional, Union
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from database.database import get_db_session
from database.models import AccountBalance, Expense, utc_now


def get_balance_details(session: Optional[Session] = None) -> Dict:
    """
    Retrieve the current account balance details.
    
    Returns a dictionary with:
    - is_configured: bool
    - baseline_amount: Decimal
    - current_balance: Decimal (baseline_amount - expenses_since_baseline)
    - expenses_since_baseline: Decimal
    - set_at: Optional[datetime]
    - last_expense_id: Optional[int]
    - notes: Optional[str]
    """
    def _fetch(s: Session) -> Dict:
        stmt = (
            select(AccountBalance)
            .order_by(AccountBalance.id.desc())
            .limit(1)
        )
        balance = s.scalar(stmt)

        if not balance:
            return {
                "is_configured": False,
                "baseline_amount": Decimal("0.00"),
                "current_balance": Decimal("0.00"),
                "expenses_since_baseline": Decimal("0.00"),
                "set_at": None,
                "last_expense_id": None,
                "notes": None,
            }

        # Calculate sum of expenses logged after this baseline was established
        if balance.last_expense_id is not None:
            exp_stmt = select(
                func.coalesce(func.sum(Expense.amount), Decimal("0.00"))
            ).where(Expense.id > balance.last_expense_id)
        else:
            exp_stmt = select(
                func.coalesce(func.sum(Expense.amount), Decimal("0.00"))
            ).where(Expense.created_at >= balance.set_at)

        expenses_sum = s.execute(exp_stmt).scalar() or Decimal("0.00")
        current_bal = balance.baseline_amount - Decimal(str(expenses_sum))

        return {
            "is_configured": True,
            "baseline_amount": balance.baseline_amount,
            "current_balance": current_bal,
            "expenses_since_baseline": Decimal(str(expenses_sum)),
            "set_at": balance.set_at,
            "last_expense_id": balance.last_expense_id,
            "notes": balance.notes,
        }

    if session:
        return _fetch(session)
    with get_db_session() as s:
        return _fetch(s)


def update_account_balance(
    new_balance: Union[Decimal, float, str],
    notes: Optional[str] = None,
    session: Optional[Session] = None,
) -> Dict:
    """
    Save or update the user's current bank balance baseline.
    
    Establishes a new baseline at this moment in time and records
    the current max expense ID so subsequent expenses deduct from this baseline.
    """
    dec_balance = Decimal(str(new_balance)).quantize(Decimal("0.01"))
    clean_notes = notes.strip() if notes else None

    def _execute(s: Session) -> Dict:
        # Determine highest expense id currently logged
        max_id_stmt = select(func.max(Expense.id))
        max_id = s.execute(max_id_stmt).scalar()

        new_record = AccountBalance(
            baseline_amount=dec_balance,
            last_expense_id=max_id,
            set_at=utc_now(),
            notes=clean_notes,
        )
        s.add(new_record)
        s.flush()

        return {
            "is_configured": True,
            "baseline_amount": dec_balance,
            "current_balance": dec_balance,
            "expenses_since_baseline": Decimal("0.00"),
            "set_at": new_record.set_at,
            "last_expense_id": max_id,
            "notes": clean_notes,
        }

    if session:
        return _execute(session)
    with get_db_session() as s:
        return _execute(s)
