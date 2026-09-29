"""
Unit tests for analytics calculations, aggregations, time-series grouping, and peak detections.
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base
from services.analytics_service import get_analytics_data
from services.expense_service import create_expense
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


class TestAnalyticsService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed categories & stores
        self.tag_food = get_or_create_tag("Food", session=self.session)
        self.tag_bills = get_or_create_tag("Bills", session=self.session)
        self.store1 = get_or_create_store("Supermarket", session=self.session)
        self.store2 = get_or_create_store("Coffee Shop", session=self.session)
        self.session.commit()

        # Seed test expenses
        today = date.today()
        # High spend on Food at Supermarket
        create_expense(amount="500.00", date=today, tag_id=self.tag_food.id, store_id=self.store1.id, payment_method="Card", session=self.session)
        create_expense(amount="150.00", date=today, tag_id=self.tag_food.id, store_id=self.store2.id, payment_method="UPI", session=self.session)
        create_expense(amount="200.00", date=today - timedelta(days=2), tag_id=self.tag_bills.id, store_id=self.store1.id, payment_method="GPay", session=self.session)
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_analytics_kpi_and_peaks(self):
        data = get_analytics_data(time_period="Daily", session=self.session)

        self.assertEqual(data["total_spent"], Decimal("850.00"))
        self.assertEqual(data["transaction_count"], 3)
        self.assertEqual(data["avg_transaction_amt"], Decimal("283.33"))

        # Peak day should be today with 650.00
        self.assertEqual(data["peak_day"]["amount"], Decimal("650.00"))

        # Peak category should be Food with 650.00
        self.assertEqual(data["peak_category"]["name"], "Food")
        self.assertEqual(data["peak_category"]["amount"], Decimal("650.00"))

        # Peak store should be Supermarket with 700.00
        self.assertEqual(data["peak_store"]["name"], "Supermarket")
        self.assertEqual(data["peak_store"]["amount"], Decimal("700.00"))

    def test_time_series_grouping(self):
        # Daily
        daily_res = get_analytics_data(time_period="Daily", session=self.session)
        self.assertEqual(len(daily_res["time_series"]), 14)

        # Weekly
        weekly_res = get_analytics_data(time_period="Weekly", session=self.session)
        self.assertGreaterEqual(len(weekly_res["time_series"]), 8)

    def test_category_and_payment_breakdown(self):
        data = get_analytics_data(time_period="Daily", session=self.session)
        cats = {c["category"]: c["amount"] for c in data["spending_by_tag"]}
        self.assertEqual(cats["Food"], 650.0)
        self.assertEqual(cats["Bills"], 200.0)

        pms = {p["method"]: p["amount"] for p in data["spending_by_pm"]}
        self.assertEqual(pms["Card"], 500.0)
        self.assertEqual(pms["GPay"], 200.0)
        self.assertEqual(pms["UPI"], 150.0)


if __name__ == "__main__":
    unittest.main()
