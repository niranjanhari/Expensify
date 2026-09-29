"""
Unit tests for AI Spending Advisor & Weekly Digest Service (Phase 13).
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Budget, Expense, RecurringExpense, Store, Tag
from services.advisor_service import (
    ask_advisor_ai,
    get_spending_observations,
    get_weekly_digest,
)


class TestAdvisorService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed test data
        self.tag_food = Tag(name="Food")
        self.store_cafe = Store(name="Daily Cafe", normalized_name="daily cafe")
        self.session.add_all([self.tag_food, self.store_cafe])
        self.session.commit()

        # Add expenses across 2 weeks
        today = date.today()
        # This week
        exp1 = Expense(amount=Decimal("200.00"), date=today, description="Lunch", tag_id=self.tag_food.id, store_id=self.store_cafe.id)
        exp2 = Expense(amount=Decimal("100.00"), date=today - timedelta(days=2), description="Coffee", tag_id=self.tag_food.id, store_id=self.store_cafe.id)
        # Last week
        exp3 = Expense(amount=Decimal("150.00"), date=today - timedelta(days=8), description="Past meal", tag_id=self.tag_food.id, store_id=self.store_cafe.id)
        self.session.add_all([exp1, exp2, exp3])
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(self.engine)

    def test_get_weekly_digest(self):
        digest = get_weekly_digest(session=self.session)
        self.assertEqual(digest["current_total"], Decimal("300.00"))
        self.assertEqual(digest["prev_total"], Decimal("150.00"))
        self.assertEqual(digest["delta_amount"], Decimal("150.00"))
        self.assertEqual(digest["delta_percentage"], 100.0)
        self.assertEqual(digest["top_category"], "Food")
        self.assertEqual(digest["top_merchant"], "Daily Cafe")

    def test_get_spending_observations(self):
        # Set budget to check observations
        budget = Budget(amount=Decimal("1000.00"))
        self.session.add(budget)
        self.session.commit()

        obs = get_spending_observations(session=self.session)
        self.assertIsInstance(obs, list)
        self.assertGreaterEqual(len(obs), 1)

    def test_ask_advisor_ai_offline_fallback(self):
        answer_food = ask_advisor_ai("How do I control food expenses?", session=self.session)
        self.assertIn("Food", answer_food)

        answer_budget = ask_advisor_ai("Am I within my budget limit?", session=self.session)
        self.assertIn("Budget", answer_budget)


if __name__ == "__main__":
    unittest.main()
