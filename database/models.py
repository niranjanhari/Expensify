"""
SQLAlchemy ORM models for Personal Expense Intelligence System.

This module defines the core database models:
- Tag: Categories for expenses (user-editable, non-hardcoded)
- Store: Merchants/vendors with normalization and usage tracking
- Expense: Financial transactions with exact decimal amounts
"""

from __future__ import annotations

from datetime import date as datetime_date, datetime, time as datetime_time, timezone
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, Numeric, String, Text, Time, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def utc_now() -> datetime:
    """Return current timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models."""
    pass


class Tag(Base):
    """
    Represents an expense category/tag.
    
    Tags are completely user-editable and not hardcoded into business logic.
    Expenses retain foreign keys with SET NULL on deletion to preserve history.
    """
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    # Relationships
    expenses: Mapped[List["Expense"]] = relationship(
        "Expense",
        back_populates="tag",
        passive_deletes=True,
    )

    def __repr__(self) -> str:
        return f"<Tag(id={self.id}, name='{self.name}')>"


class Store(Base):
    """
    Represents a merchant or vendor.
    
    Includes normalized_name (lowercase trimmed) to prevent case-variation duplicates
    (e.g., 'Starbucks', 'starbucks', 'STARBUCKS' map to the same store).
    Tracks usage_count to inform autocomplete and Quick Add recommendations.
    """
    __tablename__ = "stores"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    default_tag_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("tags.id", ondelete="SET NULL"),
        nullable=True
    )
    usage_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=utc_now,
        onupdate=utc_now,
        nullable=False
    )

    # Relationships
    default_tag: Mapped[Optional["Tag"]] = relationship("Tag")
    expenses: Mapped[List["Expense"]] = relationship(
        "Expense",
        back_populates="store",
        passive_deletes=True,
    )

    @staticmethod
    def normalize_store_name(raw_name: str) -> str:
        """Utility to produce a uniform key for duplicate prevention."""
        return " ".join(raw_name.strip().lower().split())

    def __repr__(self) -> str:
        return f"<Store(id={self.id}, name='{self.name}', usage_count={self.usage_count})>"


class Expense(Base):
    """
    Represents an individual financial transaction.
    
    Amount is stored as Numeric(10, 2) and mapped to Python Decimal to guarantee
    exact decimal representation and eliminate floating-point rounding errors.
    Foreign keys to Store and Tag use ondelete='SET NULL' so deleting a store or tag
    never deletes historical records.
    """
    __tablename__ = "expenses"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    date: Mapped[datetime_date] = mapped_column(Date, nullable=False, index=True)
    time: Mapped[Optional[datetime_time]] = mapped_column(Time, nullable=True)
    description: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    store_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("stores.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    tag_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("tags.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    
    payment_method: Mapped[str] = mapped_column(String(50), default="Cash", nullable=False)
    is_recurring: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    recurring_expense_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=utc_now,
        onupdate=utc_now,
        nullable=False
    )

    # Relationships
    store: Mapped[Optional["Store"]] = relationship("Store", back_populates="expenses")
    tag: Mapped[Optional["Tag"]] = relationship("Tag", back_populates="expenses")

    def __repr__(self) -> str:
        return (
            f"<Expense(id={self.id}, amount={self.amount}, "
            f"date={self.date}, description='{self.description}')>"
        )


class QuickAddPin(Base):
    """
    User-pinned or hidden Quick Add presets.
    Pinned items appear at the top of Quick Add suggestions.
    Hidden items are excluded from automated ranking.
    """
    __tablename__ = "quick_add_pins"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    store_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("stores.id", ondelete="SET NULL"),
        nullable=True,
    )
    tag_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("tags.id", ondelete="SET NULL"),
        nullable=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    payment_method: Mapped[str] = mapped_column(String(50), default="Cash", nullable=False)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    # Relationships
    store: Mapped[Optional["Store"]] = relationship("Store")
    tag: Mapped[Optional["Tag"]] = relationship("Tag")

    def __repr__(self) -> str:
        return f"<QuickAddPin(id={self.id}, amount={self.amount}, pinned={self.is_pinned})>"


class Budget(Base):
    """
    Budget model supporting overall monthly budgets (tag_id is None)
    and category-specific budgets.
    """
    __tablename__ = "budgets"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    tag_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("tags.id", ondelete="SET NULL"),
        nullable=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    period: Mapped[str] = mapped_column(String(20), default="monthly", nullable=False)
    start_date: Mapped[Optional[datetime_date]] = mapped_column(Date, nullable=True)
    end_date: Mapped[Optional[datetime_date]] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    # Relationships
    tag: Mapped[Optional["Tag"]] = relationship("Tag")

    def __repr__(self) -> str:
        cat = self.tag.name if self.tag else "Overall"
        return f"<Budget(id={self.id}, category='{cat}', amount={self.amount})>"


class RecurringExpense(Base):
    """
    Recurring expenses template (subscriptions, daily canteen, rent, phone recharge).
    Generates suggestions when due without silent unprompted insertions.
    """
    __tablename__ = "recurring_expenses"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    description: Mapped[str] = mapped_column(String(255), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    store_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("stores.id", ondelete="SET NULL"),
        nullable=True,
    )
    tag_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("tags.id", ondelete="SET NULL"),
        nullable=True,
    )
    frequency: Mapped[str] = mapped_column(String(50), default="Monthly", nullable=False)
    next_due_date: Mapped[datetime_date] = mapped_column(Date, nullable=False, index=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    payment_method: Mapped[str] = mapped_column(String(50), default="Cash", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    # Relationships
    store: Mapped[Optional["Store"]] = relationship("Store")
    tag: Mapped[Optional["Tag"]] = relationship("Tag")

    def __repr__(self) -> str:
        return f"<RecurringExpense(id={self.id}, desc='{self.description}', amount={self.amount}, next_due={self.next_due_date})>"


class ImportedTransaction(Base):
    """
    Auditable staging table for parsed SMS alerts, UPI notifications,
    and CSV bank statement imports.
    Transactions remain pending until explicitly confirmed or rejected by the user.
    """
    __tablename__ = "imported_transactions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    raw_text: Mapped[str] = mapped_column(Text, nullable=False)
    source_type: Mapped[str] = mapped_column(String(50), default="SMS", nullable=False)
    detected_amount: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 2), nullable=True)
    detected_merchant: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    detected_date: Mapped[Optional[datetime_date]] = mapped_column(Date, nullable=True)
    detected_payment_method: Mapped[str] = mapped_column(String(50), default="UPI", nullable=False)
    predicted_tag_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    confidence: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False, index=True)
    expense_id: Mapped[Optional[int]] = mapped_column(ForeignKey("expenses.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    # Relationships
    expense: Mapped[Optional["Expense"]] = relationship("Expense")

    def __repr__(self) -> str:
        return f"<ImportedTransaction(id={self.id}, status='{self.status}', amount={self.detected_amount}, merchant='{self.detected_merchant}')>"
