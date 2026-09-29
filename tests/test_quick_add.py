"""
Unit tests for the Quick Add system (pattern recognition, recency weighting, 1-click execution, pin & hide).
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Expense
from services.expense_service import create_expense, get_recent_expenses
from services.quick_add_service import (
    execute_quick_add,
    get_quick_add_suggestions,
    hide_quick_add_item,
    pin_quick_add_item,
)
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


class TestQuickAdd(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed categories & stores
        self.tag_food = get_or_create_tag("Food", session=self.session)
        self.tag_transport = get_or_create_tag("Transport", session=self.session)
        self.canteen = get_or_create_store("College Canteen", session=self.session)
        self.metro = get_or_create_store("Metro Rail", session=self.session)
        self.session.commit()

        # Seed repeated transactions
        # Canteen Lunch (50.00) logged 3 times recently
        today = date.today()
        for i in range(3):
            create_expense(
                amount="50.00",
                date=today - timedelta(days=i),
                description="Lunch Thali",
                store_id=self.canteen.id,
                tag_id=self.tag_food.id,
                payment_method="GPay",
                session=self.session,
            )

        # Metro Ticket (30.00) logged 1 time recently
        create_expense(
            amount="30.00",
            date=today,
            description="Metro pass",
            store_id=self.metro.id,
            tag_id=self.tag_transport.id,
            payment_method="UPI",
            session=self.session,
        )
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_quick_add_pattern_recognition(self):
        suggestions = get_quick_add_suggestions(limit=5, session=self.session)
        self.assertGreaterEqual(len(suggestions), 2)

        # The canteen purchase should rank first due to higher frequency (3 vs 1)
        top = suggestions[0]
        self.assertEqual(top["store_name"], "College Canteen")
        self.assertEqual(top["amount"], Decimal("50.00"))
        self.assertEqual(top["frequency"], 3)
        self.assertEqual(top["icon"], "🍛")

    def test_execute_quick_add(self):
        suggestions = get_quick_add_suggestions(limit=1, session=self.session)
        top = suggestions[0]

        # Execute 1-click Quick Add
        new_exp = execute_quick_add(top, session=self.session)
        self.session.commit()

        self.assertIsNotNone(new_exp.id)
        self.assertEqual(new_exp.date, date.today())
        self.assertEqual(new_exp.amount, Decimal("50.00"))
        self.assertEqual(new_exp.store.name, "College Canteen")

        # Verify historical count is now 4 for this pattern
        updated_suggestions = get_quick_add_suggestions(limit=1, session=self.session)
        self.assertEqual(updated_suggestions[0]["frequency"], 4)

    def test_pin_and_hide(self):
        # Manually pin a custom item
        pin = pin_quick_add_item(
            amount=Decimal("150.00"),
            store_id=self.canteen.id,
            tag_id=self.tag_food.id,
            description="Special Buffet",
            payment_method="Card",
            session=self.session,
        )
        self.session.commit()

        suggestions = get_quick_add_suggestions(limit=5, session=self.session)
        # Pinned item must be first
        self.assertTrue(suggestions[0]["is_pinned"])
        self.assertEqual(suggestions[0]["amount"], Decimal("150.00"))

        # Hide the Metro item
        hide_quick_add_item(
            amount=Decimal("30.00"),
            store_id=self.metro.id,
            tag_id=self.tag_transport.id,
            description="Metro pass",
            session=self.session,
        )
        self.session.commit()

        # Metro item should no longer appear in suggestions
        refreshed = get_quick_add_suggestions(limit=5, session=self.session)
        metro_items = [s for s in refreshed if s["store_name"] == "Metro Rail"]
        self.assertEqual(len(metro_items), 0)


if __name__ == "__main__":
    unittest.main()
