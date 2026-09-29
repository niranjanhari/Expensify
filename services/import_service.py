"""
Transaction Import Service (Phase 16).
Provides an auditable staging foundation for importing transactions from:
- SMS transaction alerts & UPI debit messages
- CSV bank / credit card statements
- Free-form text blocks

Transactions remain in an auditable staging queue until explicitly approved or rejected.
"""

from __future__ import annotations

import csv
from datetime import date, datetime
from decimal import Decimal
import io
import re
from typing import Any, Dict, List, Optional
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from database.database import get_db_session
from database.models import Expense, ImportedTransaction, Store, Tag
from services.categorization_service import predict_tag_for_expense
from services.expense_service import create_expense
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


# Common Indian banking & UPI SMS alert patterns
SMS_PATTERNS = [
    # Pattern 1: "Paid ₹250 to ABC Restaurant using UPI." or "Paid Rs 450 to Starbucks"
    re.compile(
        r"(?:paid|sent)\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+([A-Za-z0-9\s\.\&\'\-]+?)(?:\s+using|\s+on|\s+via|\.|$)",
        re.IGNORECASE,
    ),
    # Pattern 2: "Debited Rs. 450.00 at Uber by GPay" or "Debited by INR 120 at Canteen"
    re.compile(
        r"debited\s+(?:by\s+)?(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:at|for|to)\s+([A-Za-z0-9\s\.\&\'\-]+?)(?:\s+by|\s+on|\s+via|\.|$)",
        re.IGNORECASE,
    ),
    # Pattern 3: "Rs 150.00 spent on your card at Starbucks"
    re.compile(
        r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s+spent\s+on\s+.*?\s+at\s+([A-Za-z0-9\s\.\&\'\-]+?)(?:\s+on|\.|$)",
        re.IGNORECASE,
    ),
]


def parse_sms_text(raw_text: str) -> Dict[str, Any]:
    """
    Parse a single SMS or UPI notification into candidate fields.
    """
    clean_text = raw_text.strip()
    detected_amt: Optional[Decimal] = None
    detected_merchant: Optional[str] = None
    detected_pm = "UPI"

    # Detect payment method
    lower_text = clean_text.lower()
    if "gpay" in lower_text or "google pay" in lower_text:
        detected_pm = "GPay"
    elif "card" in lower_text or "credit card" in lower_text or "debit card" in lower_text:
        detected_pm = "Card"
    elif "netbanking" in lower_text or "bank transfer" in lower_text or "neft" in lower_text or "imps" in lower_text:
        detected_pm = "Bank Transfer"
    elif "upi" in lower_text or "vpa" in lower_text:
        detected_pm = "UPI"
    elif "cash" in lower_text:
        detected_pm = "Cash"

    # Match regex patterns
    for pat in SMS_PATTERNS:
        match = pat.search(clean_text)
        if match:
            amt_str = match.group(1).replace(",", "")
            try:
                detected_amt = Decimal(amt_str).quantize(Decimal("0.01"))
            except Exception:
                continue

            detected_merchant = match.group(2).strip()
            # Clean trailing words like "on", "using", "ref"
            detected_merchant = re.sub(r"\s+(?:on|via|using|ref|txn|for|by).*$", "", detected_merchant, flags=re.IGNORECASE).strip()
            break

    # If regex failed, search for standalone currency numbers
    if detected_amt is None:
        amt_match = re.search(r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)", clean_text, re.IGNORECASE)
        if amt_match:
            try:
                detected_amt = Decimal(amt_match.group(1).replace(",", "")).quantize(Decimal("0.01"))
            except Exception:
                pass

    if detected_merchant is None:
        # Fallback merchant extraction
        m_match = re.search(r"(?:to|at|for)\s+([A-Za-z0-9\s]{3,30})", clean_text, re.IGNORECASE)
        if m_match:
            detected_merchant = m_match.group(1).strip()

    # Pass merchant to smart categorizer
    pred = predict_tag_for_expense(description=clean_text, store_name=detected_merchant)

    confidence = 0.85 if (detected_amt and detected_merchant) else 0.50
    if pred["confidence"] >= 0.80:
        confidence = max(confidence, pred["confidence"])

    return {
        "raw_text": clean_text,
        "source_type": "SMS",
        "detected_amount": detected_amt,
        "detected_merchant": detected_merchant or "Unspecified Merchant",
        "detected_date": date.today(),
        "detected_payment_method": detected_pm,
        "predicted_tag_name": pred["tag_name"],
        "confidence": confidence,
    }


def parse_and_stage_sms_batch(lines: List[str], session: Optional[Session] = None) -> List[ImportedTransaction]:
    """
    Parse a list of SMS messages and save them as pending items in the staging queue.
    """
    def _stage(s: Session) -> List[ImportedTransaction]:
        staged: List[ImportedTransaction] = []
        for line in lines:
            line_str = line.strip()
            if not line_str:
                continue
            parsed = parse_sms_text(line_str)
            item = ImportedTransaction(
                raw_text=parsed["raw_text"],
                source_type=parsed["source_type"],
                detected_amount=parsed["detected_amount"],
                detected_merchant=parsed["detected_merchant"],
                detected_date=parsed["detected_date"],
                detected_payment_method=parsed["detected_payment_method"],
                predicted_tag_name=parsed["predicted_tag_name"],
                confidence=parsed["confidence"],
                status="pending",
            )
            s.add(item)
            staged.append(item)
        s.flush()
        return staged

    if session:
        return _stage(session)
    with get_db_session() as s:
        return _stage(s)


def parse_and_stage_csv(csv_content: str, session: Optional[Session] = None) -> List[ImportedTransaction]:
    """
    Parse CSV bank statement content and stage valid debit rows.
    Automatically detects column headers (Date, Description/Details, Debit/Amount).
    """
    reader = csv.DictReader(io.StringIO(csv_content))
    if not reader.fieldnames:
        return []

    # Map column headers case-insensitively
    headers_lower = {h.strip().lower(): h for h in reader.fieldnames}

    date_col = next((headers_lower[h] for h in headers_lower if any(k in h for k in ["date", "txn date", "value date"])), None)
    desc_col = next((headers_lower[h] for h in headers_lower if any(k in h for k in ["narration", "description", "details", "particulars", "merchant", "remarks"])), None)
    amt_col = next((headers_lower[h] for h in headers_lower if any(k in h for k in ["debit", "withdrawal", "amount", "expense"])), None)

    if not amt_col:
        return []

    def _stage(s: Session) -> List[ImportedTransaction]:
        staged: List[ImportedTransaction] = []
        for row in reader:
            raw_line = ", ".join([f"{k}:{v}" for k, v in row.items() if v])
            amt_raw = row.get(amt_col, "").replace(",", "").replace("₹", "").replace("Rs", "").strip()
            if not amt_raw:
                continue

            try:
                amt = Decimal(amt_raw).quantize(Decimal("0.01"))
                if amt <= Decimal("0.00"):
                    continue
            except Exception:
                continue

            desc_raw = row.get(desc_col, "").strip() if desc_col else "Bank Debit"
            txn_date = date.today()
            if date_col and row.get(date_col):
                d_str = row[date_col].strip()
                for fmt in ["%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%m/%d/%Y", "%d %b %Y"]:
                    try:
                        txn_date = datetime.strptime(d_str, fmt).date()
                        break
                    except ValueError:
                        pass

            pred = predict_tag_for_expense(description=desc_raw, store_name=desc_raw)

            item = ImportedTransaction(
                raw_text=raw_line,
                source_type="CSV Statement",
                detected_amount=amt,
                detected_merchant=desc_raw[:100],
                detected_date=txn_date,
                detected_payment_method="Bank Transfer",
                predicted_tag_name=pred["tag_name"],
                confidence=pred["confidence"],
                status="pending",
            )
            s.add(item)
            staged.append(item)
        s.flush()
        return staged

    if session:
        return _stage(session)
    with get_db_session() as s:
        return _stage(s)


def get_pending_imported_transactions(session: Optional[Session] = None) -> List[ImportedTransaction]:
    """Retrieve all pending staged transactions awaiting review."""
    stmt = (
        select(ImportedTransaction)
        .where(ImportedTransaction.status == "pending")
        .order_by(ImportedTransaction.created_at.desc())
    )
    if session:
        return list(session.scalars(stmt).all())
    with get_db_session() as s:
        return list(s.scalars(stmt).all())


def approve_imported_transaction(
    imported_id: int,
    overrides: Optional[Dict[str, Any]] = None,
    session: Optional[Session] = None,
) -> Optional[Expense]:
    """
    Confirm and promote a staged transaction into an official Expense.
    """
    def _approve(s: Session) -> Optional[Expense]:
        item = s.get(ImportedTransaction, imported_id)
        if not item or item.status != "pending":
            return None

        ov = overrides or {}
        amt = ov.get("amount", item.detected_amount) or Decimal("10.00")
        exp_date = ov.get("date", item.detected_date) or date.today()
        store_str = ov.get("store_name", item.detected_merchant) or ""
        tag_str = ov.get("tag_name", item.predicted_tag_name) or "Misc"
        pm_str = ov.get("payment_method", item.detected_payment_method) or "UPI"
        desc_str = ov.get("description", item.raw_text[:120])

        store = get_or_create_store(store_str, session=s) if store_str.strip() else None
        tag = get_or_create_tag(tag_str, session=s) if tag_str.strip() else None

        new_expense = create_expense(
            amount=amt,
            date=exp_date,
            description=desc_str,
            store_id=store.id if store else None,
            tag_id=tag.id if tag else None,
            payment_method=pm_str,
            session=s,
        )

        item.status = "imported"
        item.expense_id = new_expense.id
        s.flush()
        return new_expense

    if session:
        return _approve(session)
    with get_db_session() as s:
        return _approve(s)


def reject_imported_transaction(imported_id: int, session: Optional[Session] = None) -> bool:
    """Mark a staged transaction as rejected without deleting audit history."""
    def _reject(s: Session) -> bool:
        item = s.get(ImportedTransaction, imported_id)
        if not item:
            return False
        item.status = "rejected"
        s.flush()
        return True

    if session:
        return _reject(session)
    with get_db_session() as s:
        return _reject(s)


def batch_approve_all_pending(min_confidence: float = 0.85, session: Optional[Session] = None) -> int:
    """
    Approve all pending staged transactions meeting the minimum confidence threshold.
    """
    def _batch(s: Session) -> int:
        items = list(
            s.scalars(
                select(ImportedTransaction)
                .where(
                    ImportedTransaction.status == "pending",
                    ImportedTransaction.confidence >= min_confidence,
                    ImportedTransaction.detected_amount.isnot(None),
                )
            ).all()
        )
        approved_count = 0
        for it in items:
            approve_imported_transaction(it.id, session=s)
            approved_count += 1
        return approved_count

    if session:
        return _batch(session)
    with get_db_session() as s:
        return _batch(s)
