"""
Unit tests for Smart Categorization & Auto-Tagging Service (Phase 12).
"""

from datetime import date
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Expense, Store, Tag
from services.categorization_service import (
    batch_apply_tags,
    predict_tag_for_expense,
    suggest_tags_for_uncategorized,
)


class TestCategorizationService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed tags
        self.tag_food = Tag(name="Food")
        self.tag_transport = Tag(name="Transport")
        self.tag_ent = Tag(name="Entertainment")
        self.session.add_all([self.tag_food, self.tag_transport, self.tag_ent])
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(self.engine)

    def test_predict_tag_by_keyword(self):
        pred = predict_tag_for_expense(description="Had cold coffee and a burger", session=self.session)
        self.assertEqual(pred["tag_name"], "Food")
        self.assertGreaterEqual(pred["confidence"], 0.8)

    def test_predict_tag_transport_keyword(self):
        pred = predict_tag_for_expense(description="Metro card recharge", session=self.session)
        self.assertEqual(pred["tag_name"], "Transport")

    def test_predict_tag_store_history(self):
        # Create store with default tag
        store = Store(name="College Canteen", normalized_name="college canteen", default_tag_id=self.tag_food.id)
        self.session.add(store)
        self.session.commit()

        pred = predict_tag_for_expense(description="Snacks", store_name="College Canteen", session=self.session)
        self.assertEqual(pred["tag_name"], "Food")
        self.assertGreaterEqual(pred["confidence"], 0.9)

    def test_suggest_tags_for_uncategorized_and_batch_apply(self):
        # Insert uncategorized expenses
        exp1 = Expense(amount=Decimal("150.00"), date=date.today(), description="Uber to office", tag_id=None)
        exp2 = Expense(amount=Decimal("80.00"), date=date.today(), description="Subway sandwich", tag_id=None)
        self.session.add_all([exp1, exp2])
        self.session.commit()

        suggestions = suggest_tags_for_uncategorized(session=self.session)
        self.assertEqual(len(suggestions), 2)
        sug_map = {s["expense_id"]: s["suggested_tag_name"] for s in suggestions}
        self.assertEqual(sug_map[exp1.id], "Transport")
        self.assertEqual(sug_map[exp2.id], "Food")

        # Batch apply
        batch_items = [
            {"expense_id": exp1.id, "tag_name": sug_map[exp1.id]},
            {"expense_id": exp2.id, "tag_name": sug_map[exp2.id]},
        ]
        applied_count = batch_apply_tags(batch_items, session=self.session)
        self.assertEqual(applied_count, 2)

        # Verify applied tags
        self.session.refresh(exp1)
        self.session.refresh(exp2)
        self.assertEqual(exp1.tag.name, "Transport")
        self.assertEqual(exp2.tag.name, "Food")


if __name__ == "__main__":
    unittest.main()
