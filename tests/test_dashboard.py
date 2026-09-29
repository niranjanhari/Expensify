"""
Unit tests for dashboard metrics, spending trends, and category distribution calculations.
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base
from services.dashboard_service import (
    get_category_breakdown,
    get_daily_spending_trend,
    get_dashboard_summary,
)
from services.expense_service import create_expense
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


class TestDashboardService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed categories & stores
        self.tag_food = get_or_create_tag("Food", session=self.session)
        self.tag_bills = get_or_create_tag("Bills", session=self.session)
        self.store = get_or_create_store("Metro Cafe", session=self.session)
        self.session.commit()

        # Seed transactions
        today = date.today()
        yesterday = today - timedelta(days=1)

        create_expense(amount="100.00", date=today, tag_id=self.tag_food.id, store_id=self.store.id, session=self.session)
        create_expense(amount="50.00", date=today, tag_id=self.tag_food.id, store_id=self.store.id, session=self.session)
        create_expense(amount="200.00", date=yesterday, tag_id=self.tag_bills.id, store_id=self.store.id, session=self.session)
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_dashboard_summary(self):
        summary = get_dashboard_summary(session=self.session)
        self.assertEqual(summary["today_total"], Decimal("150.00"))
        self.assertEqual(summary["today_count"], 2)
        self.assertEqual(summary["all_time_total"], Decimal("350.00"))
        self.assertEqual(summary["all_time_count"], 3)
        self.assertGreaterEqual(summary["this_month_total"], Decimal("150.00"))

    def test_daily_spending_trend(self):
        trend = get_daily_spending_trend(days=7, session=self.session)
        self.assertEqual(len(trend), 7)
        # Today's item should be 150.0
        self.assertEqual(trend[-1]["amount"], 150.0)
        # Yesterday's item should be 200.0
        self.assertEqual(trend[-2]["amount"], 200.0)

    def test_category_breakdown(self):
        breakdown = get_category_breakdown(days=7, session=self.session)
        self.assertEqual(len(breakdown), 2)
        # Bills (200.0) and Food (150.0)
        categories = {b["category"]: b["amount"] for b in breakdown}
        self.assertEqual(categories["Bills"], 200.0)
        self.assertEqual(categories["Food"], 150.0)


if __name__ == "__main__":
    unittest.main()
