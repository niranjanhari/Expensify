"""
Unit tests for Transaction Import & Staging Service (Phase 16).
"""

from datetime import date
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Expense, ImportedTransaction, Store, Tag
from services.import_service import (
    approve_imported_transaction,
    batch_approve_all_pending,
    get_pending_imported_transactions,
    parse_and_stage_csv,
    parse_and_stage_sms_batch,
    parse_sms_text,
    reject_imported_transaction,
)


class TestImportService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed tags
        self.tag_food = Tag(name="Food")
        self.session.add(self.tag_food)
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(self.engine)

    def test_parse_sms_text(self):
        sms = "Paid ₹250 to ABC Restaurant using UPI."
        res = parse_sms_text(sms)
        self.assertEqual(res["detected_amount"], Decimal("250.00"))
        self.assertEqual(res["detected_merchant"], "ABC Restaurant")
        self.assertEqual(res["detected_payment_method"], "UPI")
        self.assertGreaterEqual(res["confidence"], 0.70)

    def test_parse_and_stage_sms_batch(self):
        sms_lines = [
            "Paid ₹250 to ABC Restaurant using UPI.",
            "Debited Rs. 450.00 at Uber by GPay on 29-09-2026",
        ]
        staged = parse_and_stage_sms_batch(sms_lines, session=self.session)
        self.assertEqual(len(staged), 2)

        pending = get_pending_imported_transactions(session=self.session)
        self.assertEqual(len(pending), 2)

    def test_approve_and_reject_imported_transaction(self):
        sms_lines = ["Paid ₹80 to Canteen using GPay."]
        staged = parse_and_stage_sms_batch(sms_lines, session=self.session)
        item = staged[0]

        # Approve item
        exp = approve_imported_transaction(item.id, session=self.session)
        self.assertIsNotNone(exp)
        self.assertEqual(exp.amount, Decimal("80.00"))
        self.assertEqual(item.status, "imported")
        self.assertEqual(item.expense_id, exp.id)

        # Stage another and reject
        staged2 = parse_and_stage_sms_batch(["Spent Rs 100 on test"], session=self.session)
        item2 = staged2[0]
        reject_success = reject_imported_transaction(item2.id, session=self.session)
        self.assertTrue(reject_success)
        self.assertEqual(item2.status, "rejected")

    def test_parse_csv_statement(self):
        csv_data = """Date,Particulars,Debit,Credit
2026-09-25,Starbucks Coffee,180.00,0.00
2026-09-26,Salary Credit,0.00,50000.00
2026-09-27,Uber Ride,320.50,0.00
"""
        staged = parse_and_stage_csv(csv_data, session=self.session)
        self.assertEqual(len(staged), 2) # Only debit amounts > 0
        self.assertEqual(staged[0].detected_amount, Decimal("180.00"))
        self.assertEqual(staged[1].detected_amount, Decimal("320.50"))


if __name__ == "__main__":
    unittest.main()
