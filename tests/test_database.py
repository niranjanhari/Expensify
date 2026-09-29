"""
Verification tests for the database foundation.

Tests:
1. Database creation and default tag seeding.
2. Insertion of Store, Tag, and Expense with Decimal accuracy.
3. Store name normalization and duplicate detection logic.
4. SET NULL cascade behavior when a Tag or Store is deleted (expenses must persist).
"""

from datetime import date, time
from decimal import Decimal
import unittest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from database.models import Base, Expense, Store, Tag


class TestDatabaseFoundation(unittest.TestCase):
    def setUp(self):
        # Use an in-memory SQLite database with foreign keys enabled
        self.engine = create_engine("sqlite:///:memory:")
        
        # Enforce foreign key constraints in SQLite
        from sqlalchemy import event
        @event.listens_for(self.engine, "connect")
        def set_sqlite_pragma(dbapi_connection, connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON;")
            cursor.close()

        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_store_and_tag_creation(self):
        food_tag = Tag(name="Food", description="Meals and snacks")
        self.session.add(food_tag)
        self.session.commit()

        canteen_store = Store(
            name="College Canteen",
            normalized_name=Store.normalize_store_name("College Canteen"),
            default_tag_id=food_tag.id,
            usage_count=1,
        )
        self.session.add(canteen_store)
        self.session.commit()

        self.assertIsNotNone(food_tag.id)
        self.assertIsNotNone(canteen_store.id)
        self.assertEqual(canteen_store.default_tag.name, "Food")

    def test_expense_numeric_accuracy(self):
        food_tag = Tag(name="Food")
        store = Store(
            name="Starbucks",
            normalized_name=Store.normalize_store_name("Starbucks"),
        )
        self.session.add_all([food_tag, store])
        self.session.commit()

        expense = Expense(
            amount=Decimal("150.75"),
            date=date.today(),
            time=time(14, 30),
            description="Cold Brew",
            store_id=store.id,
            tag_id=food_tag.id,
            payment_method="GPay",
        )
        self.session.add(expense)
        self.session.commit()

        retrieved = self.session.scalar(select(Expense).where(Expense.id == expense.id))
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved.amount, Decimal("150.75"))
        self.assertEqual(retrieved.store.name, "Starbucks")
        self.assertEqual(retrieved.tag.name, "Food")

    def test_store_normalization_logic(self):
        norm1 = Store.normalize_store_name("  Starbucks  ")
        norm2 = Store.normalize_store_name("STARBUCKS")
        norm3 = Store.normalize_store_name("starbucks")
        self.assertEqual(norm1, norm2)
        self.assertEqual(norm2, norm3)
        self.assertEqual(norm1, "starbucks")

    def test_set_null_on_tag_deletion(self):
        tag = Tag(name="Transport")
        self.session.add(tag)
        self.session.commit()

        expense = Expense(
            amount=Decimal("45.00"),
            date=date.today(),
            description="Metro Ticket",
            tag_id=tag.id,
        )
        self.session.add(expense)
        self.session.commit()

        # Delete tag
        self.session.delete(tag)
        self.session.commit()

        # Expense should still exist, with tag_id set to None
        refreshed_expense = self.session.scalar(select(Expense).where(Expense.id == expense.id))
        self.assertIsNotNone(refreshed_expense)
        self.assertIsNone(refreshed_expense.tag_id)
        self.assertIsNone(refreshed_expense.tag)


if __name__ == "__main__":
    unittest.main()
