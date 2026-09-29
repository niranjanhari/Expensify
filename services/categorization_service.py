"""
Smart Categorization & Auto-Tagging Service (Phase 12).
Classifies expenses into tags using a three-tier intelligence hierarchy:
1. Store historical dominance (user-specific memory)
2. Keyword & semantic heuristics (offline rule-based engine)
3. Gemini AI inference (semantic context)
"""

from __future__ import annotations

import os
import re
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Expense, Store, Tag
from services.store_service import get_store_by_name
from services.tag_service import get_all_tags, get_or_create_tag

load_dotenv()

# Built-in semantic keyword dictionary mapping keywords to standard tag categories
KEYWORD_TAG_RULES: Dict[str, List[str]] = {
    "Food": [
        "canteen", "lunch", "dinner", "breakfast", "cafe", "coffee", "starbucks",
        "burger", "pizza", "restaurant", "food", "tea", "chai", "snack", "bakery",
        "swiggy", "zomato", "mcdonalds", "subway", "dominos", "biryani", "juice",
        "thali", "dosa", "ice cream", "meal", "groceries", "supermarket", "mart"
    ],
    "Transport": [
        "uber", "ola", "metro", "bus", "train", "flight", "petrol", "diesel",
        "fuel", "auto", "rickshaw", "rapido", "cab", "parking", "toll", "fastag",
        "ticket", "commute", "fare"
    ],
    "Entertainment": [
        "movie", "cinema", "pvr", "inox", "netflix", "spotify", "prime",
        "concert", "game", "gaming", "steam", "playstation", "theatre", "show"
    ],
    "Shopping": [
        "amazon", "flipkart", "myntra", "clothes", "shirt", "pants", "shoes",
        "electronics", "mall", "zara", "h&m", "purchase", "shopping", "gift"
    ],
    "Utilities": [
        "wifi", "internet", "electricity", "water", "gas", "recharge", "phone",
        "airtel", "jio", "broadband", "cylinder", "bill"
    ],
    "Health": [
        "pharmacy", "medicine", "doctor", "hospital", "clinic", "gym",
        "fitness", "consultation", "chemist", "apollo", "meds"
    ],
    "Education": [
        "book", "course", "udemy", "coursera", "college", "tuition", "exam",
        "stationery", "pen", "notebook", "library", "school"
    ],
}


def predict_tag_for_expense(
    description: str = "",
    store_name: Optional[str] = None,
    session: Optional[Session] = None,
) -> Dict[str, Any]:
    """
    Predict the most appropriate category tag for a transaction.
    Returns:
    {
        "tag_id": Optional[int],
        "tag_name": str,
        "confidence": float,  # 0.0 to 1.0
        "reason": str,
        "is_new_suggested_tag": bool
    }
    """
    desc_clean = (description or "").strip().lower()
    store_clean = (store_name or "").strip()

    def _predict(s: Session) -> Dict[str, Any]:
        all_tags = list(s.scalars(select(Tag)).all())
        tag_by_name = {t.name.lower(): t for t in all_tags}

        # ---------------- Tier 1: Store Historical Memory ----------------
        if store_clean:
            matched_store = s.scalar(select(Store).where(func.lower(Store.name) == store_clean.lower()))
            if matched_store:
                # Check store's explicit default tag
                if matched_store.default_tag_id and matched_store.default_tag:
                    return {
                        "tag_id": matched_store.default_tag.id,
                        "tag_name": matched_store.default_tag.name,
                        "confidence": 0.95,
                        "reason": f"Default category for '{matched_store.name}'",
                        "is_new_suggested_tag": False,
                    }

                # Check store's historical purchase tag dominance
                top_tag_row = s.execute(
                    select(Expense.tag_id, func.count(Expense.id).label("count"))
                    .where(Expense.store_id == matched_store.id, Expense.tag_id.isnot(None))
                    .group_by(Expense.tag_id)
                    .order_by(desc("count"))
                    .limit(1)
                ).first()

                if top_tag_row and top_tag_row[0]:
                    dominant_tag = s.get(Tag, top_tag_row[0])
                    if dominant_tag:
                        return {
                            "tag_id": dominant_tag.id,
                            "tag_name": dominant_tag.name,
                            "confidence": 0.90,
                            "reason": f"Most frequent category at '{matched_store.name}'",
                            "is_new_suggested_tag": False,
                        }

        # ---------------- Tier 2: Keyword & Semantic Rules ----------------
        combined_text = f"{store_clean} {desc_clean}".lower()
        for cat_name, keywords in KEYWORD_TAG_RULES.items():
            for kw in keywords:
                # Whole-word regex match
                if re.search(r"\b" + re.escape(kw) + r"\b", combined_text):
                    existing_tag = tag_by_name.get(cat_name.lower())
                    return {
                        "tag_id": existing_tag.id if existing_tag else None,
                        "tag_name": existing_tag.name if existing_tag else cat_name,
                        "confidence": 0.85,
                        "reason": f"Matched keyword '{kw}'",
                        "is_new_suggested_tag": existing_tag is None,
                    }

        # ---------------- Tier 3: Gemini AI Semantic Classifier ----------------
        api_key = os.getenv("GEMINI_API_KEY")
        if api_key and api_key.strip() and (combined_text.strip()):
            try:
                ai_pred = _classify_with_gemini(combined_text, [t.name for t in all_tags], api_key.strip())
                if ai_pred:
                    existing_tag = tag_by_name.get(ai_pred.lower())
                    return {
                        "tag_id": existing_tag.id if existing_tag else None,
                        "tag_name": existing_tag.name if existing_tag else ai_pred,
                        "confidence": 0.80,
                        "reason": "Gemini AI semantic inference",
                        "is_new_suggested_tag": existing_tag is None,
                    }
            except Exception:
                pass

        # Fallback default
        misc_tag = tag_by_name.get("misc")
        return {
            "tag_id": misc_tag.id if misc_tag else None,
            "tag_name": misc_tag.name if misc_tag else "Misc",
            "confidence": 0.30,
            "reason": "Default fallback",
            "is_new_suggested_tag": misc_tag is None,
        }

    if session:
        return _predict(session)
    with get_db_session() as s:
        return _predict(s)


def _classify_with_gemini(text: str, existing_tags: List[str], api_key: str) -> Optional[str]:
    """Classify expense text into existing or concise single-word tag."""
    try:
        from google import genai
        client = genai.Client(api_key=api_key)
        prompt = (
            f"Classify this expense text: '{text}'. "
            f"Choose the best category from this list: {existing_tags}. "
            f"If none fit, reply with a single concise title-cased word. Reply with ONLY the category name."
        )
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        cat = response.text.strip().replace('"', '').replace("'", "")
        return cat if cat else None
    except Exception:
        return None


def get_uncategorized_expenses(limit: int = 50, session: Optional[Session] = None) -> List[Expense]:
    """Retrieve expenses that currently have no assigned category tag."""
    stmt = (
        select(Expense)
        .options(joinedload(Expense.store))
        .where(Expense.tag_id.is_(None))
        .order_by(Expense.date.desc())
        .limit(limit)
    )
    if session:
        return list(session.scalars(stmt).all())
    with get_db_session() as s:
        return list(s.scalars(stmt).all())


def suggest_tags_for_uncategorized(limit: int = 50, session: Optional[Session] = None) -> List[Dict[str, Any]]:
    """
    Produce auto-tag predictions for all currently uncategorized transactions.
    """
    def _suggest(s: Session) -> List[Dict[str, Any]]:
        expenses = get_uncategorized_expenses(limit=limit, session=s)
        suggestions = []
        for exp in expenses:
            store_name = exp.store.name if exp.store else None
            pred = predict_tag_for_expense(description=exp.description or "", store_name=store_name, session=s)
            suggestions.append({
                "expense_id": exp.id,
                "date": exp.date,
                "amount": exp.amount,
                "description": exp.description or "",
                "store_name": store_name or "—",
                "suggested_tag_id": pred["tag_id"],
                "suggested_tag_name": pred["tag_name"],
                "confidence": pred["confidence"],
                "reason": pred["reason"],
            })
        return suggestions

    if session:
        return _suggest(session)
    with get_db_session() as s:
        return _suggest(s)


def apply_suggested_tag(expense_id: int, tag_name: str, session: Optional[Session] = None) -> bool:
    """Apply a predicted or selected tag to an expense."""
    def _apply(s: Session) -> bool:
        exp = s.get(Expense, expense_id)
        if not exp:
            return False
        tag = get_or_create_tag(tag_name, session=s)
        exp.tag_id = tag.id
        s.flush()
        return True

    if session:
        return _apply(session)
    with get_db_session() as s:
        return _apply(s)


def batch_apply_tags(assignments: List[Dict[str, Any]], session: Optional[Session] = None) -> int:
    """
    Apply multiple tag assignments in a single transaction.
    assignments: [{"expense_id": int, "tag_name": str}, ...]
    """
    def _batch(s: Session) -> int:
        count = 0
        tag_cache: Dict[str, Tag] = {}
        for item in assignments:
            exp_id = item.get("expense_id")
            tag_name = item.get("tag_name", "").strip()
            if not exp_id or not tag_name:
                continue
            exp = s.get(Expense, exp_id)
            if not exp:
                continue

            if tag_name.lower() not in tag_cache:
                tag_cache[tag_name.lower()] = get_or_create_tag(tag_name, session=s)
            exp.tag_id = tag_cache[tag_name.lower()].id
            count += 1
        s.flush()
        return count

    if session:
        return _batch(session)
    with get_db_session() as s:
        return _batch(s)
