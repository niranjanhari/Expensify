"""
Store service for managing merchants and vendors with normalization and usage tracking.
"""

from __future__ import annotations

from decimal import Decimal
from typing import List, Optional

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Expense, Store, Tag


def get_all_stores(session: Optional[Session] = None) -> List[Store]:
    """Retrieve all stores with their default tags loaded."""
    stmt = (
        select(Store)
        .options(joinedload(Store.default_tag))
        .order_by(Store.usage_count.desc(), Store.name.asc())
    )

    if session:
        return list(session.scalars(stmt).all())

    with get_db_session() as s:
        stores = list(s.scalars(stmt).all())
        for store in stores:
            if store.default_tag:
                store.default_tag.name

        return stores


def search_stores(
    query: str,
    limit: int = 10,
    session: Optional[Session] = None,
) -> List[Store]:
    """
    Search stores by prefix or substring for autocomplete suggestions.
    Ranks by usage_count desc then name.
    """
    clean_q = query.strip().lower()

    if not clean_q:
        return get_all_stores(session=session)[:limit]

    stmt = (
        select(Store)
        .options(joinedload(Store.default_tag))
        .where(Store.normalized_name.like(f"%{clean_q}%"))
        .order_by(Store.usage_count.desc(), Store.name.asc())
        .limit(limit)
    )

    if session:
        return list(session.scalars(stmt).all())

    with get_db_session() as s:
        return list(s.scalars(stmt).all())


def get_store_by_name(
    name: str,
    session: Optional[Session] = None,
) -> Optional[Store]:
    """Find a store using normalized name matching."""
    normalized = Store.normalize_store_name(name)

    stmt = (
        select(Store)
        .options(joinedload(Store.default_tag))
        .where(Store.normalized_name == normalized)
    )

    if session:
        return session.scalar(stmt)

    with get_db_session() as s:
        store = s.scalar(stmt)

        if store and store.default_tag:
            store.default_tag.name

        return store


def get_store_metrics(
    store_id: int,
    session: Optional[Session] = None,
) -> dict:
    """
    Compute comprehensive metrics for a given store:
    - total purchases
    - total amount spent
    - average ticket size
    - most recent transaction date
    - most frequent tag
    """

    def _calc(s: Session) -> dict:
        store = s.scalar(
            select(Store)
            .options(joinedload(Store.default_tag))
            .where(Store.id == store_id)
        )

        if not store:
            return {
                "exists": False,
                "purchase_count": 0,
                "total_spent": Decimal("0.00"),
                "avg_spent": Decimal("0.00"),
                "last_date": None,
                "frequent_tag_id": None,
                "frequent_tag_name": None,
            }

        stats = s.execute(
            select(
                func.count(Expense.id).label("count"),
                func.coalesce(
                    func.sum(Expense.amount),
                    Decimal("0.00"),
                ).label("total"),
                func.max(Expense.date).label("last_date"),
            ).where(Expense.store_id == store_id)
        ).one()

        count = stats.count or 0
        total = Decimal(str(stats.total or "0.00"))
        avg = (
            (total / count).quantize(Decimal("0.01"))
            if count > 0
            else Decimal("0.00")
        )

        frequent_tag_stmt = (
            select(
                Expense.tag_id,
                Tag.name,
                func.count(Expense.id).label("tag_count"),
            )
            .join(Tag, Expense.tag_id == Tag.id)
            .where(Expense.store_id == store_id)
            .group_by(Expense.tag_id, Tag.name)
            .order_by(func.count(Expense.id).desc())
            .limit(1)
        )

        tag_row = s.execute(frequent_tag_stmt).first()

        if tag_row:
            frequent_tag_id = tag_row[0]
            frequent_tag_name = tag_row[1]
        else:
            frequent_tag_id = store.default_tag_id
            frequent_tag_name = (
                store.default_tag.name
                if store.default_tag
                else None
            )

        return {
            "exists": True,
            "store_id": store.id,
            "name": store.name,
            "purchase_count": count,
            "total_spent": total,
            "avg_spent": avg,
            "last_date": stats.last_date,
            "frequent_tag_id": frequent_tag_id,
            "frequent_tag_name": frequent_tag_name,
        }

    if session:
        return _calc(session)

    with get_db_session() as s:
        return _calc(s)


def get_all_stores_with_metrics(
    session: Optional[Session] = None,
) -> List[dict]:
    """Retrieve all stores with aggregated financial intelligence metrics."""
    stores = get_all_stores(session=session)

    return [
        get_store_metrics(store.id, session=session)
        for store in stores
    ]


def get_or_create_store(
    name: str,
    default_tag_id: Optional[int] = None,
    session: Optional[Session] = None,
) -> Store:
    """
    Find an existing store by normalized name or create a new store.
    Normalizes input to prevent case/spacing duplicates.
    """

    clean_name = name.strip()

    if not clean_name:
        raise ValueError("Store name cannot be empty.")

    normalized = Store.normalize_store_name(clean_name)

    def _execute(s: Session) -> Store:
        existing = s.scalar(
            select(Store)
            .options(joinedload(Store.default_tag))
            .where(Store.normalized_name == normalized)
        )

        if existing:
            if default_tag_id and not existing.default_tag_id:
                existing.default_tag_id = default_tag_id

            return existing

        new_store = Store(
            name=clean_name,
            normalized_name=normalized,
            default_tag_id=default_tag_id,
            usage_count=0,
        )

        s.add(new_store)
        s.flush()

        return new_store

    if session:
        return _execute(session)

    with get_db_session() as s:
        store = _execute(s)

        if store.default_tag:
            store.default_tag.name

        s.expunge(store)

        return store


def increment_store_usage(
    store_id: int,
    session: Optional[Session] = None,
) -> None:
    """Increment the usage counter for a store when an expense is added."""

    stmt = (
        update(Store)
        .where(Store.id == store_id)
        .values(usage_count=Store.usage_count + 1)
    )

    if session:
        session.execute(stmt)
    else:
        with get_db_session() as s:
            s.execute(stmt)