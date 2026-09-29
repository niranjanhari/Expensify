"""
Natural Language Expense Parsing Service (Phase 11).
Extracts structured financial transactions from free-form text:
- Primary: Google Gemini API (if GEMINI_API_KEY is configured in .env)
- Graceful Fallback: Rule-based heuristic & regex parser (100% offline & private)

Never inserts blindly into the database; returns structured candidates for user confirmation.
"""

from __future__ import annotations

import json
import os
import re
from decimal import Decimal
from typing import Dict, List, Optional
from dotenv import load_dotenv

from services.store_service import get_all_stores
from services.tag_service import get_all_tags

load_dotenv()


def parse_natural_language_expense(text: str) -> Dict:
    """
    Parse an informal natural language sentence into a structured transaction candidate.
    Example: 'Spent 80 at college canteen for lunch using gpay'
    Returns:
    {
        "amount": Decimal("80.00"),
        "store": "College Canteen",
        "tag": "Food",
        "description": "Lunch",
        "payment_method": "GPay",
        "confidence": 0.92,
        "source": "Gemini AI" | "Rule-based Engine",
        "raw_text": text,
    }
    """
    clean_text = text.strip()
    if not clean_text:
        raise ValueError("Please provide an expense description to parse.")

    api_key = os.getenv("GEMINI_API_KEY")

    # If Gemini API key is available, attempt AI parsing
    if api_key and api_key.strip():
        try:
            return _parse_with_gemini(clean_text, api_key.strip())
        except Exception as e:
            # Gracefully fall back to rule-based engine on any AI error
            fallback_res = _parse_with_rules(clean_text)
            fallback_res["ai_error"] = str(e)
            return fallback_res

    # Default offline rule-based parser
    return _parse_with_rules(clean_text)


def _parse_with_gemini(text: str, api_key: str) -> Dict:
    """Invoke Google Gemini API with strict structured JSON schema."""
    try:
        from google import genai
        client = genai.Client(api_key=api_key)
        
        all_tags = [t.name for t in get_all_tags()]
        all_stores = [s.name for s in get_all_stores()]

        prompt = f"""
        Extract financial transaction data from this natural language text:
        "{text}"

        Available Categories: {all_tags}
        Known Merchants: {all_stores}

        Return ONLY a raw JSON object with these exact keys:
        - "amount": number (positive float/integer)
        - "store": string (merchant or vendor name, or null)
        - "tag": string (best matching category from Available Categories, or "Misc")
        - "description": string (short description of purchase)
        - "payment_method": string ("GPay", "Cash", "Card", "UPI", "Bank Transfer", or "Other")
        - "confidence": number between 0.0 and 1.0
        """

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        
        # Clean potential markdown fences ```json ... ```
        raw_output = response.text.strip()
        if raw_output.startswith("```"):
            raw_output = re.sub(r"^```(?:json)?", "", raw_output)
            raw_output = re.sub(r"```$", "", raw_output).strip()

        data = json.loads(raw_output)
        amt = Decimal(str(data.get("amount", "0.00"))).quantize(Decimal("0.01"))
        if amt <= Decimal("0.00"):
            raise ValueError("Amount extracted was zero or negative.")

        return {
            "amount": amt,
            "store": data.get("store") or "Unspecified Merchant",
            "tag": data.get("tag") or "Misc",
            "description": data.get("description") or text,
            "payment_method": data.get("payment_method") or "Cash",
            "confidence": float(data.get("confidence", 0.90)),
            "source": "Gemini AI",
            "raw_text": text,
        }
    except Exception as e:
        # Re-raise to trigger fallback
        raise RuntimeError(f"Gemini API parsing failed: {e}")


def _parse_with_rules(text: str) -> Dict:
    """
    Offline heuristic & regex rule engine.
    Extracts amounts, merchants, categories, and payment methods with high precision.
    """
    lower = text.lower()

    # 1. Extract Amount (matches '80', '₹150', 'rs 250', '299.50', etc.)
    amt_match = re.search(r"(?:₹|rs\.?|inr)?\s*(\d+(?:\.\d{1,2})?)(?:\s*(?:rs|rupees|bucks))?", lower)
    if amt_match:
        extracted_amt = Decimal(amt_match.group(1)).quantize(Decimal("0.01"))
    else:
        # Fallback to any number in text
        num_match = re.search(r"\b(\d+)\b", lower)
        extracted_amt = Decimal(num_match.group(1)) if num_match else Decimal("0.00")

    # 2. Extract Payment Method
    detected_pm = "Cash"
    if any(k in lower for k in ["gpay", "google pay", "googlepay"]):
        detected_pm = "GPay"
    elif any(k in lower for k in ["upi", "phonepe", "paytm"]):
        detected_pm = "UPI"
    elif any(k in lower for k in ["card", "credit", "debit", "visa", "mastercard"]):
        detected_pm = "Card"
    elif any(k in lower for k in ["net banking", "transfer", "neft", "imps"]):
        detected_pm = "Bank Transfer"
    elif "cash" in lower:
        detected_pm = "Cash"

    # 3. Known Store Matching from Database
    known_stores = get_all_stores()
    detected_store = None
    for s in known_stores:
        if s.name.lower() in lower or s.normalized_name in lower:
            detected_store = s.name
            break

    # If no existing store matched, check common prepositions 'at <store>' or 'in <store>'
    if not detected_store:
        prep_match = re.search(r"\b(?:at|from|to)\s+([a-zA-Z0-9\s&'-]+?)(?:\s+(?:for|using|with|via|on|in|rs|₹|\d|$))", text, re.IGNORECASE)
        if prep_match:
            candidate = prep_match.group(1).strip()
            if candidate and len(candidate.split()) <= 4:
                detected_store = candidate.title()

    # 4. Category Prediction based on keywords
    detected_tag = "Misc"
    if any(k in lower for k in ["canteen", "lunch", "dinner", "breakfast", "coffee", "latte", "food", "swiggy", "zomato", "restaurant", "tea", "snack", "pizza", "burger"]):
        detected_tag = "Food"
    elif any(k in lower for k in ["uber", "ola", "bus", "metro", "auto", "train", "fuel", "petrol", "cab", "transport"]):
        detected_tag = "Transport"
    elif any(k in lower for k in ["recharge", "phone", "bill", "electricity", "water", "wifi", "internet"]):
        detected_tag = "Bills"
    elif any(k in lower for k in ["amazon", "flipkart", "shopping", "clothes", "shoes", "mall"]):
        detected_tag = "Shopping"
    elif any(k in lower for k in ["movie", "cinema", "netflix", "spotify", "game", "entertainment"]):
        detected_tag = "Entertainment"
    elif any(k in lower for k in ["medicine", "doctor", "health", "pharmacy", "clinic"]):
        detected_tag = "Health"
    elif any(k in lower for k in ["course", "book", "tuition", "education", "college"]):
        detected_tag = "Education"
    elif any(k in lower for k in ["rent", "housing", "flat"]):
        detected_tag = "Rent"

    # 5. Description Extraction: look for 'for <desc>'
    desc_match = re.search(r"\bfor\s+([a-zA-Z0-9\s&'-]+?)(?:\s+(?:at|using|with|via|on|in|rs|₹|\d|$))", text, re.IGNORECASE)
    if desc_match:
        detected_desc = desc_match.group(1).strip().capitalize()
    else:
        detected_desc = text.strip()

    return {
        "amount": extracted_amt,
        "store": detected_store or "Unspecified Merchant",
        "tag": detected_tag,
        "description": detected_desc,
        "payment_method": detected_pm,
        "confidence": 0.88 if extracted_amt > 0 else 0.50,
        "source": "Rule-based Engine (Offline)",
        "raw_text": text,
    }
