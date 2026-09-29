"""
Expense service for recording and retrieving financial transactions.
"""

from __future__ import annotations

from datetime import date as datetime_date, time as datetime_time
from decimal import Decimal
from typing import List, Optional, Union
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Expense, Store, Tag
from services.store_service import increment_store_usage


def create_expense(
    amount: Union[Decimal, float, str],
    date: datetime_date,
    time: Optional[datetime_time] = None,
    description: Optional[str] = None,
    store_id: Optional[int] = None,
    tag_id: Optional[int] = None,
    payment_method: str = "Cash",
    is_recurring: bool = False,
    session: Optional[Session] = None,
) -> Expense:
    """
    Validate and save a new expense to the database.
    Increments merchant usage frequency when store_id is provided.
    """
    dec_amount = Decimal(str(amount)).quantize(Decimal("0.01"))
    if dec_amount <= Decimal("0.00"):
        raise ValueError("Expense amount must be greater than zero.")

    clean_desc = description.strip() if description else None
    clean_payment = payment_method.strip() if payment_method else "Cash"

    def _execute(s: Session) -> Expense:
        new_expense = Expense(
            amount=dec_amount,
            date=date,
            time=time,
            description=clean_desc,
            store_id=store_id,
            tag_id=tag_id,
            payment_method=clean_payment,
            is_recurring=is_recurring,
        )
        s.add(new_expense)
        s.flush()

        if store_id:
            increment_store_usage(store_id, session=s)

        return new_expense

    if session:
        return _execute(session)
    with get_db_session() as s:
        expense = _execute(s)
        s.expunge(expense)
        return expense


def get_recent_expenses(limit: int = 10, session: Optional[Session] = None) -> List[Expense]:
    """Retrieve the most recent transactions with eager-loaded store and tag."""
    stmt = (
        select(Expense)
        .options(joinedload(Expense.store), joinedload(Expense.tag))
        .order_by(Expense.date.desc(), Expense.id.desc())
        .limit(limit)
    )
    if session:
        return list(session.scalars(stmt).unique().all())
    with get_db_session() as s:
        return list(s.scalars(stmt).unique().all())


def get_expense_by_id(expense_id: int, session: Optional[Session] = None) -> Optional[Expense]:
    """Retrieve an expense by its ID with eager-loaded store and tag."""
    stmt = (
        select(Expense)
        .options(joinedload(Expense.store), joinedload(Expense.tag))
        .where(Expense.id == expense_id)
    )
    if session:
        return session.scalar(stmt)
    with get_db_session() as s:
        return s.scalar(stmt)


def get_filtered_expenses(
    search_query: Optional[str] = None,
    start_date: Optional[datetime_date] = None,
    end_date: Optional[datetime_date] = None,
    tag_ids: Optional[List[int]] = None,
    store_ids: Optional[List[int]] = None,
    payment_methods: Optional[List[str]] = None,
    min_amount: Optional[Union[Decimal, float]] = None,
    max_amount: Optional[Union[Decimal, float]] = None,
    sort_order: str = "desc",
    page: int = 1,
    page_size: int = 15,
    session: Optional[Session] = None,
) -> dict:
    """
    Query expenses with comprehensive filtering and pagination.
    Returns:
    {
        "items": List[Expense],
        "total_count": int,
        "total_amount": Decimal,
        "page": int,
        "page_size": int,
        "total_pages": int,
    }
    """
    from sqlalchemy import and_, func, or_

    def _execute(s: Session) -> dict:
        conditions = []

        if search_query and search_query.strip():
            term = f"%{search_query.strip()}%"
            conditions.append(
                or_(
                    Expense.description.ilike(term),
                    Expense.store.has(Store.name.ilike(term)),
                    Expense.tag.has(Tag.name.ilike(term)),
                    Expense.payment_method.ilike(term),
                )
            )

        if start_date:
            conditions.append(Expense.date >= start_date)
        if end_date:
            conditions.append(Expense.date <= end_date)

        if tag_ids:
            conditions.append(Expense.tag_id.in_(tag_ids))
        if store_ids:
            conditions.append(Expense.store_id.in_(store_ids))
        if payment_methods:
            conditions.append(Expense.payment_method.in_(payment_methods))

        if min_amount is not None:
            conditions.append(Expense.amount >= Decimal(str(min_amount)))
        if max_amount is not None:
            conditions.append(Expense.amount <= Decimal(str(max_amount)))

        where_clause = and_(*conditions) if conditions else True

        # Aggregate total count and total amount for the filtered set
        stats_stmt = select(
            func.count(Expense.id).label("count"),
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("total"),
        ).where(where_clause)
        stats = s.execute(stats_stmt).one()

        total_count = stats.count or 0
        total_amount = Decimal(str(stats.total or "0.00"))
        total_pages = max(1, (total_count + page_size - 1) // page_size) if total_count > 0 else 1

        # Items query with ordering and pagination
        items_stmt = (
            select(Expense)
            .options(joinedload(Expense.store), joinedload(Expense.tag))
            .where(where_clause)
        )

        if sort_order == "asc":
            items_stmt = items_stmt.order_by(Expense.date.asc(), Expense.id.asc())
        else:
            items_stmt = items_stmt.order_by(Expense.date.desc(), Expense.id.desc())

        offset = max(0, (page - 1) * page_size)
        items_stmt = items_stmt.offset(offset).limit(page_size)

        items = list(s.scalars(items_stmt).unique().all())

        return {
            "items": items,
            "total_count": total_count,
            "total_amount": total_amount,
            "page": page,
            "page_size": page_size,
            "total_pages": total_pages,
        }

    if session:
        return _execute(session)
    with get_db_session() as s:
        return _execute(s)


def update_expense(
    expense_id: int,
    amount: Union[Decimal, float, str],
    date: datetime_date,
    time: Optional[datetime_time] = None,
    description: Optional[str] = None,
    store_id: Optional[int] = None,
    tag_id: Optional[int] = None,
    payment_method: str = "Cash",
    session: Optional[Session] = None,
) -> Optional[Expense]:
    """Update an existing expense transaction."""
    dec_amount = Decimal(str(amount)).quantize(Decimal("0.01"))
    if dec_amount <= Decimal("0.00"):
        raise ValueError("Expense amount must be greater than zero.")

    def _execute(s: Session) -> Optional[Expense]:
        expense = s.get(Expense, expense_id)
        if not expense:
            return None

        expense.amount = dec_amount
        expense.date = date
        expense.time = time
        expense.description = description.strip() if description else None
        expense.store_id = store_id
        expense.tag_id = tag_id
        expense.payment_method = payment_method.strip() if payment_method else "Cash"
        s.flush()
        return expense

    if session:
        return _execute(session)
    with get_db_session() as s:
        exp = _execute(s)
        if exp:
            s.expunge(exp)
        return exp


def delete_expense(expense_id: int, session: Optional[Session] = None) -> bool:
    """Delete an expense record by its ID."""
    def _execute(s: Session) -> bool:
        expense = s.get(Expense, expense_id)
        if not expense:
            return False
        s.delete(expense)
        s.flush()
        return True

    if session:
        return _execute(session)
    with get_db_session() as s:
        return _execute(s)
