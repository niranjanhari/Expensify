"""
Unit tests for Natural Language Expense parsing.
"""

from decimal import Decimal
import unittest

from services.nlp_expense_service import parse_natural_language_expense


class TestNLPExpenseService(unittest.TestCase):
    def test_rule_based_parsing(self):
        text = "Spent 80 at college canteen for lunch using gpay"
        parsed = parse_natural_language_expense(text)

        self.assertEqual(parsed["amount"], Decimal("80.00"))
        self.assertEqual(parsed["payment_method"], "GPay")
        self.assertEqual(parsed["tag"], "Food")
        self.assertIn("canteen", parsed["store"].lower())
        self.assertGreaterEqual(parsed["confidence"], 0.8)

    def test_rule_based_uber_transport(self):
        text = "Paid 250 for uber cab to airport via upi"
        parsed = parse_natural_language_expense(text)

        self.assertEqual(parsed["amount"], Decimal("250.00"))
        self.assertEqual(parsed["payment_method"], "UPI")
        self.assertEqual(parsed["tag"], "Transport")

    def test_empty_string_error(self):
        with self.assertRaises(ValueError):
            parse_natural_language_expense("   ")


if __name__ == "__main__":
    unittest.main()
