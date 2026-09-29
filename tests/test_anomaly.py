"""
Unit tests for Anomaly Detection Service (Phase 15).
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Expense, Store, Tag
from services.anomaly_service import (
    check_single_expense_anomaly,
    detect_all_anomalies,
)


class TestAnomalyService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed tags
        self.tag_food = Tag(name="Food")
        self.store = Store(name="College Canteen", normalized_name="college canteen")
        self.session.add_all([self.tag_food, self.store])
        self.session.commit()

        # Insert 5 normal Food expenses (₹40, ₹50, ₹60, ₹70, ₹80)
        today = date.today()
        for idx, amt in enumerate([40, 50, 60, 70, 80]):
            self.session.add(
                Expense(
                    amount=Decimal(str(amt)),
                    date=today - timedelta(days=idx),
                    tag_id=self.tag_food.id,
                    store_id=self.store.id,
                )
            )
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(self.engine)

    def test_detect_category_outlier(self):
        # Insert a ₹1,200 food expense
        today = date.today()
        huge_exp = Expense(
            amount=Decimal("1200.00"),
            date=today,
            tag_id=self.tag_food.id,
            store_id=self.store.id,
            description="Massive treat",
        )
        self.session.add(huge_exp)
        self.session.commit()

        anomalies = detect_all_anomalies(days=30, session=self.session)
        self.assertGreaterEqual(len(anomalies), 1)
        first_a = anomalies[0]
        self.assertEqual(first_a["expense_id"], huge_exp.id)
        self.assertEqual(first_a["anomaly_type"], "Category Outlier")
        self.assertEqual(first_a["tag_name"], "Food")
        self.assertIn("1,200", first_a["message"])

    def test_check_single_expense_anomaly(self):
        res_normal = check_single_expense_anomaly(
            amount=Decimal("65.00"),
            tag_id=self.tag_food.id,
            session=self.session,
        )
        self.assertIsNone(res_normal)

        res_anomaly = check_single_expense_anomaly(
            amount=Decimal("1500.00"),
            tag_id=self.tag_food.id,
            session=self.session,
        )
        self.assertIsNotNone(res_anomaly)
        self.assertTrue(res_anomaly["is_anomaly"])


if __name__ == "__main__":
    unittest.main()
