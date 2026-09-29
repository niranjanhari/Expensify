"""
Unit tests for Expense Prediction Service (Phase 14).
"""

from datetime import date, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Budget, Expense, RecurringExpense, Store, Tag
from services.prediction_service import (
    predict_monthly_run_rate,
    predict_upcoming_expenses,
)


class TestPredictionService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed tags and store
        self.tag_food = Tag(name="Food")
        self.store_canteen = Store(name="College Canteen", normalized_name="college canteen")
        self.session.add_all([self.tag_food, self.store_canteen])
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(self.engine)

    def test_predict_upcoming_recurring(self):
        today = date.today()
        rec = RecurringExpense(
            description="Daily Canteen Lunch",
            amount=Decimal("80.00"),
            store_id=self.store_canteen.id,
            tag_id=self.tag_food.id,
            frequency="Daily",
            next_due_date=today + timedelta(days=1),
            active=True,
            payment_method="GPay",
        )
        self.session.add(rec)
        self.session.commit()

        predictions = predict_upcoming_expenses(days_ahead=3, reference_date=today, session=self.session)
        self.assertGreaterEqual(len(predictions), 1)
        first_pred = predictions[0]
        self.assertEqual(first_pred["source"], "Scheduled Recurring")
        self.assertEqual(first_pred["predicted_amount"], Decimal("80.00"))
        self.assertIn("Expected tomorrow", first_pred["expected_timing"])

    def test_predict_upcoming_cadence(self):
        # 3 purchases spaced every 2 days: Day -6, Day -4, Day -2
        today = date.today()
        exp1 = Expense(amount=Decimal("50.00"), date=today - timedelta(days=6), store_id=self.store_canteen.id, tag_id=self.tag_food.id)
        exp2 = Expense(amount=Decimal("60.00"), date=today - timedelta(days=4), store_id=self.store_canteen.id, tag_id=self.tag_food.id)
        exp3 = Expense(amount=Decimal("70.00"), date=today - timedelta(days=2), store_id=self.store_canteen.id, tag_id=self.tag_food.id)
        self.session.add_all([exp1, exp2, exp3])
        self.session.commit()

        predictions = predict_upcoming_expenses(days_ahead=4, reference_date=today, session=self.session)
        cadence_preds = [p for p in predictions if p["source"] == "Habit & Cadence"]
        self.assertEqual(len(cadence_preds), 1)
        self.assertEqual(cadence_preds[0]["store_name"], "College Canteen")
        self.assertEqual(cadence_preds[0]["predicted_amount"], Decimal("60.00"))
        self.assertEqual(cadence_preds[0]["expected_date"], today)

    def test_predict_monthly_run_rate(self):
        today = date.today()
        # Add an expense this month
        exp = Expense(amount=Decimal("1500.00"), date=today, tag_id=self.tag_food.id)
        budget = Budget(amount=Decimal("5000.00"))
        self.session.add_all([exp, budget])
        self.session.commit()

        forecast = predict_monthly_run_rate(reference_date=today, session=self.session)
        self.assertGreater(forecast["projected_month_end"], Decimal("0.00"))
        self.assertEqual(forecast["budget_target"], Decimal("5000.00"))
        self.assertIn("pacing_status", forecast)


if __name__ == "__main__":
    unittest.main()
