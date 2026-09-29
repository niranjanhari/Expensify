"""
Unit tests for transaction querying, filtering, pagination, updating, and deletion.
"""

from datetime import date, time, timedelta
from decimal import Decimal
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base
from services.expense_service import (
    create_expense,
    delete_expense,
    get_expense_by_id,
    get_filtered_expenses,
    update_expense,
)
from services.store_service import get_or_create_store
from services.tag_service import get_or_create_tag


class TestTransactions(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed test tags and stores
        self.tag_food = get_or_create_tag("Food", session=self.session)
        self.tag_tech = get_or_create_tag("Tech", session=self.session)
        self.store_starbucks = get_or_create_store("Starbucks", session=self.session)
        self.store_amazon = get_or_create_store("Amazon", session=self.session)
        self.session.commit()

        # Seed sample expenses
        today = date.today()
        yesterday = today - timedelta(days=1)
        two_days_ago = today - timedelta(days=2)

        create_expense(
            amount="120.00",
            date=today,
            description="Morning Latte",
            store_id=self.store_starbucks.id,
            tag_id=self.tag_food.id,
            payment_method="GPay",
            session=self.session,
        )
        create_expense(
            amount="850.00",
            date=yesterday,
            description="USB-C Hub",
            store_id=self.store_amazon.id,
            tag_id=self.tag_tech.id,
            payment_method="Card",
            session=self.session,
        )
        create_expense(
            amount="45.00",
            date=two_days_ago,
            description="Croissant",
            store_id=self.store_starbucks.id,
            tag_id=self.tag_food.id,
            payment_method="Cash",
            session=self.session,
        )
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def test_filter_by_search_query(self):
        # Search by description
        res = get_filtered_expenses(search_query="Latte", session=self.session)
        self.assertEqual(res["total_count"], 1)
        self.assertEqual(res["items"][0].description, "Morning Latte")

        # Search by store name
        res_store = get_filtered_expenses(search_query="Amazon", session=self.session)
        self.assertEqual(res_store["total_count"], 1)
        self.assertEqual(res_store["items"][0].amount, Decimal("850.00"))

    def test_filter_by_date_range(self):
        today = date.today()
        yesterday = today - timedelta(days=1)

        res = get_filtered_expenses(start_date=yesterday, end_date=today, session=self.session)
        self.assertEqual(res["total_count"], 2)
        self.assertEqual(res["total_amount"], Decimal("970.00"))

    def test_filter_by_tag_and_store(self):
        res = get_filtered_expenses(
            tag_ids=[self.tag_food.id],
            store_ids=[self.store_starbucks.id],
            session=self.session,
        )
        self.assertEqual(res["total_count"], 2)
        self.assertEqual(res["total_amount"], Decimal("165.00"))

    def test_filter_by_amount_range(self):
        res = get_filtered_expenses(min_amount="100.00", max_amount="500.00", session=self.session)
        self.assertEqual(res["total_count"], 1)
        self.assertEqual(res["items"][0].amount, Decimal("120.00"))

    def test_pagination_and_sorting(self):
        res = get_filtered_expenses(page=1, page_size=2, sort_order="desc", session=self.session)
        self.assertEqual(len(res["items"]), 2)
        self.assertEqual(res["total_count"], 3)
        self.assertEqual(res["total_pages"], 2)

        # Page 2
        res_p2 = get_filtered_expenses(page=2, page_size=2, sort_order="desc", session=self.session)
        self.assertEqual(len(res_p2["items"]), 1)

    def test_update_expense(self):
        expenses = get_filtered_expenses(session=self.session)["items"]
        target = expenses[0]

        updated = update_expense(
            expense_id=target.id,
            amount="199.99",
            date=date.today(),
            description="Updated Latte",
            store_id=self.store_starbucks.id,
            tag_id=self.tag_food.id,
            payment_method="UPI",
            session=self.session,
        )
        self.session.commit()

        self.assertIsNotNone(updated)
        self.assertEqual(updated.amount, Decimal("199.99"))
        self.assertEqual(updated.description, "Updated Latte")
        self.assertEqual(updated.payment_method, "UPI")

    def test_delete_expense(self):
        expenses = get_filtered_expenses(session=self.session)["items"]
        target = expenses[0]

        deleted = delete_expense(target.id, session=self.session)
        self.session.commit()
        self.assertTrue(deleted)

        refetched = get_expense_by_id(target.id, session=self.session)
        self.assertIsNone(refetched)

        all_now = get_filtered_expenses(session=self.session)
        self.assertEqual(all_now["total_count"], 2)


if __name__ == "__main__":
    unittest.main()
