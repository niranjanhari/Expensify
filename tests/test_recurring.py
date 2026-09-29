"""
Unit tests for Recurring Expenses (templates, due date checks, confirmation logging).
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base
from services.expense_service import get_recent_expenses
from services.recurring_service import (
    confirm_and_log_recurring,
    create_recurring_expense,
    delete_recurring_expense,
    get_all_recurring_expenses,
    get_due_recurring_expenses,
    skip_recurring,
)
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


class TestRecurringService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        self.tag_food = get_or_create_tag("Food", session=self.session)
        self.canteen = get_or_create_store("College Canteen", session=self.session)
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_create_and_fetch_due(self):
        today = date.today()
        # Due today
        rec1 = create_recurring_expense(
            description="Daily Canteen Lunch",
            amount="50.00",
            store_id=self.canteen.id,
            tag_id=self.tag_food.id,
            frequency="Daily",
            next_due_date=today,
            session=self.session,
        )
        # Due in future
        rec2 = create_recurring_expense(
            description="Phone Recharge",
            amount="299.00",
            frequency="Monthly",
            next_due_date=today + timedelta(days=10),
            session=self.session,
        )
        self.session.commit()

        due = get_due_recurring_expenses(session=self.session)
        self.assertEqual(len(due), 1)
        self.assertEqual(due[0].description, "Daily Canteen Lunch")

    def test_confirm_and_log_advances_date(self):
        today = date.today()
        rec = create_recurring_expense(
            description="Gym Membership",
            amount="1200.00",
            frequency="Monthly",
            next_due_date=today,
            session=self.session,
        )
        self.session.commit()

        # Confirm and log
        logged_exp = confirm_and_log_recurring(rec.id, session=self.session)
        self.session.commit()

        self.assertIsNotNone(logged_exp)
        self.assertEqual(logged_exp.amount, Decimal("1200.00"))
        self.assertTrue(logged_exp.is_recurring)

        # Check that next due date advanced past today
        due_now = get_due_recurring_expenses(session=self.session)
        self.assertEqual(len(due_now), 0)

    def test_skip_recurring(self):
        today = date.today()
        rec = create_recurring_expense(
            description="Coffee Subscription",
            amount="300.00",
            frequency="Weekly",
            next_due_date=today,
            session=self.session,
        )
        self.session.commit()

        skipped = skip_recurring(rec.id, session=self.session)
        self.session.commit()
        self.assertTrue(skipped)

        # Due date should have advanced by 7 days
        self.assertEqual(rec.next_due_date, today + timedelta(days=7))


if __name__ == "__main__":
    unittest.main()
