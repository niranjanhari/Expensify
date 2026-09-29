"""
Quick Add service: Pattern recognition, frequency x recency ranking,
and 1-click expense execution.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Optional
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Expense, QuickAddPin, Store, Tag
from services.expense_service import create_expense


def _detect_icon(description: Optional[str], store_name: Optional[str], tag_name: Optional[str]) -> str:
    """Helper to pick an icon code for quick add items (preserved for service test contract)."""
    text = f"{description or ''} {store_name or ''} {tag_name or ''}".lower()
    if any(k in text for k in ["coffee", "latte", "tea", "starbucks", "cafe", "espresso", "chai"]):
        return "☕"
    if any(k in text for k in ["lunch", "dinner", "food", "canteen", "burger", "pizza", "swiggy", "zomato", "meal"]):
        return "🍛"
    if any(k in text for k in ["bus", "metro", "train", "uber", "ola", "transport", "auto", "fuel", "petrol"]):
        return "🚌"
    if any(k in text for k in ["recharge", "phone", "wifi", "internet", "bill", "electricity"]):
        return "📱"
    if any(k in text for k in ["movie", "cinema", "game", "entertainment", "netflix", "spotify"]):
        return "🍿"
    if any(k in text for k in ["amazon", "shopping", "clothes", "flipkart", "market"]):
        return "🛍️"
    if any(k in text for k in ["medicine", "doctor", "health", "pharmacy", "hospital"]):
        return "💊"
    if any(k in text for k in ["book", "course", "education", "tuition", "school", "college"]):
        return "📚"
    return "⚡"




def get_quick_add_suggestions(
    limit: int = 6,
    days_lookback: int = 90,
    session: Optional[Session] = None,
) -> List[Dict]:
    """
    Generate ranked Quick Add suggestions combining user pins and historical patterns.
    Pattern recognition groups by: (store_id, tag_id, amount, description).
    Ranking Formula:
        Score = Frequency * (1.0 / (1.0 + 0.05 * DaysSinceLastUsed))
    """
    today = date.today()
    since_date = today - timedelta(days=days_lookback)

    def _calc(s: Session) -> List[Dict]:
        results: List[Dict] = []
        seen_keys = set()

        # 1. Fetch user-pinned items first
        pins_stmt = (
            select(QuickAddPin)
            .options(joinedload(QuickAddPin.store), joinedload(QuickAddPin.tag))
            .where(QuickAddPin.is_pinned == True, QuickAddPin.is_hidden == False)
            .order_by(QuickAddPin.id.desc())
        )
        pinned_records = list(s.scalars(pins_stmt).all())

        for p in pinned_records:
            key = (p.store_id, p.tag_id, p.amount, (p.description or "").strip().lower())
            seen_keys.add(key)
            store_name = p.store.name if p.store else "Unspecified"
            tag_name = p.tag.name if p.tag else "Uncategorized"
            icon = _detect_icon(p.description, store_name, tag_name)

            results.append({
                "pin_id": p.id,
                "is_pinned": True,
                "amount": p.amount,
                "store_id": p.store_id,
                "store_name": store_name,
                "tag_id": p.tag_id,
                "tag_name": tag_name,
                "description": p.description or "",
                "payment_method": p.payment_method or "Cash",
                "frequency": 1,
                "last_date": today,
                "days_ago": 0,
                "score": 999.0,  # Pinned items get maximum score
                "icon": icon,
            })

        # 2. Fetch hidden combinations to exclude
        hidden_stmt = select(QuickAddPin).where(QuickAddPin.is_hidden == True)
        hidden_records = list(s.scalars(hidden_stmt).all())
        hidden_keys = {
            (h.store_id, h.tag_id, h.amount, (h.description or "").strip().lower())
            for h in hidden_records
        }

        # 3. Query historical expenses grouped by pattern tuple
        stmt = (
            select(
                Expense.store_id,
                Expense.tag_id,
                Expense.amount,
                Expense.description,
                Expense.payment_method,
                func.count(Expense.id).label("freq"),
                func.max(Expense.date).label("last_used"),
            )
            .where(Expense.date >= since_date)
            .group_by(
                Expense.store_id,
                Expense.tag_id,
                Expense.amount,
                Expense.description,
                Expense.payment_method,
            )
        )
        grouped_rows = s.execute(stmt).all()

        auto_suggestions = []
        for row in grouped_rows:
            key = (row.store_id, row.tag_id, row.amount, (row.description or "").strip().lower())
            if key in seen_keys or key in hidden_keys:
                continue

            last_used = row.last_used or today
            days_ago = max(0, (today - last_used).days)
            # Recency weight decays gracefully
            recency_factor = 1.0 / (1.0 + 0.05 * days_ago)
            score = float(row.freq) * recency_factor

            # Resolve Store and Tag display names
            st_obj = s.get(Store, row.store_id) if row.store_id else None
            tg_obj = s.get(Tag, row.tag_id) if row.tag_id else None

            store_name = st_obj.name if st_obj else "Unspecified"
            tag_name = tg_obj.name if tg_obj else "Uncategorized"
            icon = _detect_icon(row.description, store_name, tag_name)

            auto_suggestions.append({
                "pin_id": None,
                "is_pinned": False,
                "amount": row.amount,
                "store_id": row.store_id,
                "store_name": store_name,
                "tag_id": row.tag_id,
                "tag_name": tag_name,
                "description": row.description or "",
                "payment_method": row.payment_method or "Cash",
                "frequency": row.freq,
                "last_date": last_used,
                "days_ago": days_ago,
                "score": score,
                "icon": icon,
            })

        # Sort automatic suggestions by score descending
        auto_suggestions.sort(key=lambda x: x["score"], reverse=True)

        # Merge pinned items with top automatic items up to limit
        total_remaining = max(0, limit - len(results))
        results.extend(auto_suggestions[:total_remaining])
        return results

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)


def execute_quick_add(
    item: Optional[Dict] = None,
    amount: Optional[Decimal] = None,
    store_id: Optional[int] = None,
    tag_id: Optional[int] = None,
    description: Optional[str] = None,
    payment_method: str = "Cash",
    session: Optional[Session] = None,
) -> Expense:
    """
    1-Click Expense Execution:
    Instantly logs a new expense with today's date and current time using the Quick Add pattern.
    Supports either passing a suggestion dictionary item or individual keyword arguments.
    """
    if isinstance(item, dict):
        amt = item["amount"]
        desc = item.get("description")
        st_id = item.get("store_id")
        tg_id = item.get("tag_id")
        pm = item.get("payment_method", "Cash")
    else:
        amt = amount
        desc = description
        st_id = store_id
        tg_id = tag_id
        pm = payment_method

    now_time = datetime.now().time()
    return create_expense(
        amount=amt,
        date=date.today(),
        time=now_time,
        description=desc,
        store_id=st_id,
        tag_id=tg_id,
        payment_method=pm,
        session=session,
    )


def pin_quick_add_item(
    amount: Decimal,
    store_id: Optional[int],
    tag_id: Optional[int],
    description: Optional[str] = None,
    payment_method: str = "Cash",
    session: Optional[Session] = None,
) -> QuickAddPin:
    """Manually pin a Quick Add item preset."""
    clean_desc = description.strip() if description else None

    def _execute(s: Session) -> QuickAddPin:
        pin = QuickAddPin(
            amount=amount,
            store_id=store_id,
            tag_id=tag_id,
            description=clean_desc,
            payment_method=payment_method,
            is_pinned=True,
            is_hidden=False,
        )
        s.add(pin)
        s.flush()
        return pin

    if session:
        return _execute(session)
    with get_db_session() as s:
        p = _execute(s)
        s.expunge(p)
        return p


def hide_quick_add_item(
    amount: Decimal,
    store_id: Optional[int],
    tag_id: Optional[int],
    description: Optional[str] = None,
    session: Optional[Session] = None,
) -> None:
    """Hide/dismiss an automatically ranked Quick Add combination from appearing."""
    clean_desc = description.strip() if description else None

    def _execute(s: Session) -> None:
        pin = QuickAddPin(
            amount=amount,
            store_id=store_id,
            tag_id=tag_id,
            description=clean_desc,
            is_pinned=False,
            is_hidden=True,
        )
        s.add(pin)
        s.flush()

    if session:
        _execute(session)
    else:
        with get_db_session() as s:
            _execute(s)
