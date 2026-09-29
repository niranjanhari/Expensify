"""
Unit tests for the Service layer (Expense, Store, Tag services).
"""

from datetime import date, time
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base
from services.expense_service import create_expense, get_recent_expenses
from services.store_service import get_all_stores, get_or_create_store
from services.tag_service import get_all_tags, get_or_create_tag


class TestServices(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_tag_service_get_or_create(self):
        t1 = get_or_create_tag("Groceries", description="Daily food supplies", session=self.session)
        self.session.commit()
        self.assertIsNotNone(t1.id)

        # Re-fetching with same name (different case) should return existing tag
        t2 = get_or_create_tag("groceries", session=self.session)
        self.assertEqual(t1.id, t2.id)

        tags = get_all_tags(session=self.session)
        self.assertEqual(len(tags), 1)

    def test_store_service_normalization_and_usage(self):
        s1 = get_or_create_store("  Blue Tokai Coffee  ", session=self.session)
        self.session.commit()
        self.assertEqual(s1.normalized_name, "blue tokai coffee")

        # Duplicate check with different casing
        s2 = get_or_create_store("BLUE TOKAI COFFEE", session=self.session)
        self.assertEqual(s1.id, s2.id)

        stores = get_all_stores(session=self.session)
        self.assertEqual(len(stores), 1)
        self.assertEqual(stores[0].usage_count, 0)

    def test_expense_service_create_and_recent(self):
        tag = get_or_create_tag("Food", session=self.session)
        store = get_or_create_store("College Canteen", session=self.session)
        self.session.commit()

        exp = create_expense(
            amount="75.50",
            date=date.today(),
            time=time(12, 15),
            description="Lunch thali",
            store_id=store.id,
            tag_id=tag.id,
            payment_method="GPay",
            session=self.session,
        )
        self.session.commit()

        self.assertEqual(exp.amount, Decimal("75.50"))
        
        # Verify store usage incremented
        stores = get_all_stores(session=self.session)
        self.assertEqual(stores[0].usage_count, 1)

        # Retrieve recent
        recent = get_recent_expenses(limit=5, session=self.session)
        self.assertEqual(len(recent), 1)
        self.assertEqual(recent[0].store.name, "College Canteen")
        self.assertEqual(recent[0].tag.name, "Food")

    def test_expense_zero_or_negative_validation(self):
        with self.assertRaises(ValueError):
            create_expense(
                amount="0.00",
                date=date.today(),
                session=self.session,
            )

        with self.assertRaises(ValueError):
            create_expense(
                amount="-10.00",
                date=date.today(),
                session=self.session,
            )

    def test_store_search_and_metrics(self):
        from services.store_service import get_store_metrics, search_stores
        
        tag = get_or_create_tag("Coffee", session=self.session)
        s1 = get_or_create_store("Starbucks", default_tag_id=tag.id, session=self.session)
        s2 = get_or_create_store("Subway", session=self.session)
        self.session.commit()

        # Add transactions for Starbucks
        create_expense(amount="150.00", date=date.today(), store_id=s1.id, tag_id=tag.id, session=self.session)
        create_expense(amount="250.00", date=date.today(), store_id=s1.id, tag_id=tag.id, session=self.session)
        self.session.commit()

        # Test search
        results = search_stores("star", session=self.session)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].name, "Starbucks")

        # Test metrics
        metrics = get_store_metrics(s1.id, session=self.session)
        self.assertEqual(metrics["purchase_count"], 2)
        self.assertEqual(metrics["total_spent"], Decimal("400.00"))
        self.assertEqual(metrics["avg_spent"], Decimal("200.00"))
        self.assertEqual(metrics["frequent_tag_name"], "Coffee")


if __name__ == "__main__":
    unittest.main()
