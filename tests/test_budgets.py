"""
Unit tests for Budget System (overall and category limits, progress calculations).
"""

from datetime import date
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base
from services.budget_service import (
    delete_budget,
    get_all_budgets,
    get_budget_progress,
    set_budget,
)
from services.expense_service import create_expense
from services.tag_service import get_or_create_tag


class TestBudgetService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        self.tag_food = get_or_create_tag("Food", session=self.session)
        self.tag_transport = get_or_create_tag("Transport", session=self.session)
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_set_and_update_budget(self):
        # Set overall budget
        b_overall = set_budget(amount="10000.00", tag_id=None, session=self.session)
        self.session.commit()
        self.assertEqual(b_overall.amount, Decimal("10000.00"))

        # Update overall budget
        b_updated = set_budget(amount="12000.00", tag_id=None, session=self.session)
        self.session.commit()
        self.assertEqual(b_updated.amount, Decimal("12000.00"))

        # Set category budget for Food
        b_food = set_budget(amount="4000.00", tag_id=self.tag_food.id, session=self.session)
        self.session.commit()
        self.assertEqual(b_food.amount, Decimal("4000.00"))

        all_b = get_all_budgets(session=self.session)
        self.assertEqual(len(all_b), 2)

    def test_budget_progress_calculations(self):
        # Overall 10,000, Food 4,000
        set_budget(amount="10000.00", tag_id=None, session=self.session)
        set_budget(amount="4000.00", tag_id=self.tag_food.id, session=self.session)
        self.session.commit()

        # Spend 2,500 on Food
        today = date.today()
        create_expense(amount="2500.00", date=today, tag_id=self.tag_food.id, session=self.session)
        self.session.commit()

        progress = get_budget_progress(session=self.session)
        self.assertTrue(progress["has_budgets"])

        # Check overall
        overall = progress["overall"]
        self.assertEqual(overall["budget_amount"], Decimal("10000.00"))
        self.assertEqual(overall["spent_amount"], Decimal("2500.00"))
        self.assertEqual(overall["remaining_amount"], Decimal("7500.00"))
        self.assertEqual(overall["percentage_used"], 25.0)

        # Check Food category
        food_p = progress["categories"][0]
        self.assertEqual(food_p["category"], "Food")
        self.assertEqual(food_p["spent_amount"], Decimal("2500.00"))
        self.assertEqual(food_p["percentage_used"], 62.5)

    def test_delete_budget(self):
        b = set_budget(amount="1000.00", tag_id=self.tag_transport.id, session=self.session)
        self.session.commit()

        del_res = delete_budget(b.id, session=self.session)
        self.session.commit()
        self.assertTrue(del_res)

        all_b = get_all_budgets(session=self.session)
        self.assertEqual(len(all_b), 0)


if __name__ == "__main__":
    unittest.main()
