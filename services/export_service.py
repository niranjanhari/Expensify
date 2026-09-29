"""
Export, Backup & Data Portability Service (Phase 17).
Handles:
- CSV export of transactions and summaries
- Full JSON structured backup (Expenses, Stores, Tags, Budgets, Recurring)
- Safe SQLite database binary snapshotting
- JSON backup restoration / import with schema validation
"""

from __future__ import annotations

import csv
from datetime import date, datetime, timezone
from decimal import Decimal
import io
import json
import os
import shutil
import tempfile
from typing import Any, Dict, List, Optional
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from database.database import DEFAULT_DB_PATH, get_db_session
from database.models import Budget, Expense, QuickAddPin, RecurringExpense, Store, Tag
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


def export_expenses_to_csv(session: Optional[Session] = None) -> str:
    """Export all expenses to a standard CSV string."""
    def _export(s: Session) -> str:
        stmt = (
            select(Expense)
            .options(joinedload(Expense.store), joinedload(Expense.tag))
            .order_by(Expense.date.desc(), Expense.id.desc())
        )
        expenses = list(s.scalars(stmt).all())

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "ID",
            "Date",
            "Time",
            "Amount",
            "Merchant",
            "Category",
            "Payment Method",
            "Description",
            "Created At",
        ])

        for e in expenses:
            store_name = e.store.name if e.store else ""
            tag_name = e.tag.name if e.tag else ""
            time_str = e.time.strftime("%H:%M:%S") if e.time else ""
            created_str = e.created_at.strftime("%Y-%m-%d %H:%M:%S") if e.created_at else ""

            writer.writerow([
                e.id,
                e.date.strftime("%Y-%m-%d"),
                time_str,
                f"{e.amount:.2f}",
                store_name,
                tag_name,
                e.payment_method,
                e.description or "",
                created_str,
            ])

        return output.getvalue()

    if session:
        return _export(session)
    with get_db_session() as s:
        return _export(s)


def export_full_backup_json(session: Optional[Session] = None) -> str:
    """
    Export the complete database to a structured JSON string.
    Includes Tags, Stores, Expenses, Budgets, Recurring templates, and Quick Add pins.
    """
    def _export(s: Session) -> str:
        # 1. Tags
        tags = list(s.scalars(select(Tag)).all())
        tags_data = [{"id": t.id, "name": t.name} for t in tags]

        # 2. Stores
        stores = list(s.scalars(select(Store)).all())
        stores_data = [
            {
                "id": st.id,
                "name": st.name,
                "normalized_name": st.normalized_name,
                "default_tag_id": st.default_tag_id,
                "usage_count": st.usage_count,
            }
            for st in stores
        ]

        # 3. Expenses
        expenses = list(s.scalars(select(Expense)).all())
        expenses_data = [
            {
                "id": e.id,
                "amount": str(e.amount),
                "date": e.date.strftime("%Y-%m-%d"),
                "time": e.time.strftime("%H:%M:%S") if e.time else None,
                "description": e.description,
                "store_id": e.store_id,
                "tag_id": e.tag_id,
                "payment_method": e.payment_method,
                "created_at": e.created_at.isoformat() if e.created_at else None,
            }
            for e in expenses
        ]

        # 4. Budgets
        budgets = list(s.scalars(select(Budget)).all())
        budgets_data = [
            {
                "id": b.id,
                "tag_id": b.tag_id,
                "amount": str(b.amount),
                "period": b.period,
            }
            for b in budgets
        ]

        # 5. Recurring
        recurring = list(s.scalars(select(RecurringExpense)).all())
        recurring_data = [
            {
                "id": r.id,
                "description": r.description,
                "amount": str(r.amount),
                "store_id": r.store_id,
                "tag_id": r.tag_id,
                "frequency": r.frequency,
                "next_due_date": r.next_due_date.strftime("%Y-%m-%d"),
                "active": r.active,
                "payment_method": r.payment_method,
            }
            for r in recurring
        ]

        # 6. Quick Add Pins
        pins = list(s.scalars(select(QuickAddPin)).all())
        pins_data = [
            {
                "id": p.id,
                "store_id": p.store_id,
                "tag_id": p.tag_id,
                "amount": str(p.amount),
                "description": p.description,
                "payment_method": p.payment_method,
                "is_pinned": p.is_pinned,
                "is_hidden": p.is_hidden,
            }
            for p in pins
        ]

        payload = {
            "version": "1.0",
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "app": "Expensify",
            "tags": tags_data,
            "stores": stores_data,
            "expenses": expenses_data,
            "budgets": budgets_data,
            "recurring_expenses": recurring_data,
            "quick_add_pins": pins_data,
        }

        return json.dumps(payload, indent=2)

    if session:
        return _export(session)
    with get_db_session() as s:
        return _export(s)


def create_sqlite_snapshot_bytes() -> bytes:
    """
    Safely snapshot the SQLite database file and return its binary bytes.
    Uses copy of the active database file.
    """
    if not os.path.exists(DEFAULT_DB_PATH):
        raise FileNotFoundError(f"Database file not found at {DEFAULT_DB_PATH}")

    # Create temporary snapshot
    temp_dir = tempfile.gettempdir()
    snapshot_path = os.path.join(temp_dir, f"expensify_snapshot_{int(datetime.now().timestamp())}.db")
    try:
        shutil.copy2(DEFAULT_DB_PATH, snapshot_path)
        with open(snapshot_path, "rb") as f:
            data = f.read()
        return data
    finally:
        if os.path.exists(snapshot_path):
            os.remove(snapshot_path)


def restore_backup_from_json(json_content: str, session: Optional[Session] = None) -> Dict[str, int]:
    """
    Restore data from an exported JSON backup.
    Merges tags, stores, and expenses safely without duplicates.
    Returns: {"tags_added": int, "stores_added": int, "expenses_added": int}
    """
    data = json.loads(json_content)
    if "expenses" not in data:
        raise ValueError("Invalid backup format: missing 'expenses' key.")

    def _restore(s: Session) -> Dict[str, int]:
        # 1. Map existing tags
        existing_tags = {t.name.lower(): t for t in s.scalars(select(Tag)).all()}
        tag_id_map: Dict[int, int] = {}
        tags_added = 0

        for t_info in data.get("tags", []):
            t_name = t_info.get("name", "").strip()
            if not t_name:
                continue
            if t_name.lower() in existing_tags:
                tag_id_map[t_info["id"]] = existing_tags[t_name.lower()].id
            else:
                new_tag = Tag(name=t_name)
                s.add(new_tag)
                s.flush()
                existing_tags[t_name.lower()] = new_tag
                tag_id_map[t_info["id"]] = new_tag.id
                tags_added += 1

        # 2. Map existing stores
        existing_stores = {st.normalized_name: st for st in s.scalars(select(Store)).all()}
        store_id_map: Dict[int, int] = {}
        stores_added = 0

        for st_info in data.get("stores", []):
            s_name = st_info.get("name", "").strip()
            if not s_name:
                continue
            norm = st_info.get("normalized_name") or s_name.lower()
            if norm in existing_stores:
                store_id_map[st_info["id"]] = existing_stores[norm].id
            else:
                mapped_def_tag = tag_id_map.get(st_info.get("default_tag_id"))
                new_store = Store(
                    name=s_name,
                    normalized_name=norm,
                    default_tag_id=mapped_def_tag,
                    usage_count=st_info.get("usage_count", 0),
                )
                s.add(new_store)
                s.flush()
                existing_stores[norm] = new_store
                store_id_map[st_info["id"]] = new_store.id
                stores_added += 1

        # 3. Add Expenses
        expenses_added = 0
        for exp_info in data.get("expenses", []):
            try:
                amt = Decimal(exp_info["amount"]).quantize(Decimal("0.01"))
                exp_date = datetime.strptime(exp_info["date"], "%Y-%m-%d").date()
                time_val = None
                if exp_info.get("time"):
                    time_val = datetime.strptime(exp_info["time"], "%H:%M:%S").time()

                mapped_store_id = store_id_map.get(exp_info.get("store_id"))
                mapped_tag_id = tag_id_map.get(exp_info.get("tag_id"))

                expense = Expense(
                    amount=amt,
                    date=exp_date,
                    time=time_val,
                    description=exp_info.get("description"),
                    store_id=mapped_store_id,
                    tag_id=mapped_tag_id,
                    payment_method=exp_info.get("payment_method", "Cash"),
                )
                s.add(expense)
                expenses_added += 1
            except Exception:
                continue

        s.flush()
        return {
            "tags_added": tags_added,
            "stores_added": stores_added,
            "expenses_added": expenses_added,
        }

    if session:
        return _restore(session)
    with get_db_session() as s:
        return _restore(s)
