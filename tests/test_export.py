"""
Unit tests for Export, Backup & Restoration Service (Phase 17).
"""

from datetime import date
from decimal import Decimal
import json
import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.models import Base, Expense, Store, Tag
from services.export_service import (
    export_expenses_to_csv,
    export_full_backup_json,
    restore_backup_from_json,
)


class TestExportService(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()

        # Seed data
        self.tag_food = Tag(name="Food")
        self.store_cafe = Store(name="Daily Cafe", normalized_name="daily cafe")
        self.session.add_all([self.tag_food, self.store_cafe])
        self.session.commit()

        self.exp = Expense(
            amount=Decimal("120.50"),
            date=date.today(),
            description="Cold coffee",
            tag_id=self.tag_food.id,
            store_id=self.store_cafe.id,
            payment_method="GPay",
        )
        self.session.add(self.exp)
        self.session.commit()

    def tearDown(self):
        self.session.close()
        Base.metadata.drop_all(self.engine)

    def test_export_expenses_to_csv(self):
        csv_str = export_expenses_to_csv(session=self.session)
        self.assertIn("120.50", csv_str)
        self.assertIn("Daily Cafe", csv_str)
        self.assertIn("Food", csv_str)
        self.assertIn("GPay", csv_str)

    def test_export_full_backup_json(self):
        json_str = export_full_backup_json(session=self.session)
        data = json.loads(json_str)
        self.assertEqual(data["version"], "1.0")
        self.assertEqual(len(data["expenses"]), 1)
        self.assertEqual(data["expenses"][0]["amount"], "120.50")

    def test_restore_backup_from_json(self):
        json_str = export_full_backup_json(session=self.session)
        
        # Create a second clean database
        engine2 = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine2)
        Session2 = sessionmaker(bind=engine2)
        session2 = Session2()

        stats = restore_backup_from_json(json_str, session=session2)
        self.assertEqual(stats["expenses_added"], 1)
        self.assertEqual(stats["tags_added"], 1)
        self.assertEqual(stats["stores_added"], 1)

        # Verify restored records
        from sqlalchemy import select
        restored_exp = session2.scalar(select(Expense))
        self.assertIsNotNone(restored_exp)
        self.assertEqual(restored_exp.amount, Decimal("120.50"))
        self.assertEqual(restored_exp.store.name, "Daily Cafe")
        self.assertEqual(restored_exp.tag.name, "Food")

        session2.close()
        Base.metadata.drop_all(engine2)


if __name__ == "__main__":
    unittest.main()
