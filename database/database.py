"""
Database configuration, session management, and initialization.
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Generator

from dotenv import load_dotenv
from sqlalchemy import create_engine, event, select
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from database.models import Base, Tag

# Load environment variables from .env file if present
load_dotenv()

# Project Root and Data Directory
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"

# SQLite / Database URL
DEFAULT_DB_PATH = DATA_DIR / "expense_tracker.db"
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DEFAULT_DB_PATH.as_posix()}")

# Ensure sqlite foreign key constraints are enforced
@event.listens_for(Engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    if DATABASE_URL.startswith("sqlite"):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON;")
        cursor.close()

# SQLAlchemy Engine and Session factory
# Note: check_same_thread=False is needed for multi-threaded frameworks like Streamlit
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    echo=False,  # Set to True if SQL query debugging is desired
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
    expire_on_commit=False,
)


@contextmanager
def get_db_session() -> Generator[Session, None, None]:
    """
    Context manager for database sessions.
    Automatically commits on success, rolls back on error, and closes the session.
    """
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


# Default tags for initial seeding (editable by the user)
DEFAULT_TAGS = [
    {"name": "Food", "description": "Meals, groceries, dining out, and snacks"},
    {"name": "Transport", "description": "Fuel, public transit, rideshare, and parking"},
    {"name": "Education", "description": "Courses, books, materials, and tuition"},
    {"name": "Entertainment", "description": "Movies, concerts, gaming, and leisure"},
    {"name": "Shopping", "description": "Clothing, electronics, and general merchandise"},
    {"name": "Bills", "description": "Utilities, phone recharge, internet, and subscriptions"},
    {"name": "Rent", "description": "Housing and rental payments"},
    {"name": "Health", "description": "Medical, pharmacy, fitness, and health care"},
    {"name": "Travel", "description": "Flights, lodging, vacations, and excursions"},
    {"name": "Misc", "description": "Miscellaneous and uncategorized expenses"},
]


def init_db(seed_defaults: bool = True) -> None:
    """
    Initialize the database:
    1. Ensures data directory exists.
    2. Creates all tables defined in Base metadata.
    3. Seeds initial editable tags if the tags table is empty.
    """
    # Ensure data directory exists if using SQLite local file
    if DATABASE_URL.startswith("sqlite"):
        DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Create all tables
    Base.metadata.create_all(bind=engine)

    if seed_defaults:
        with get_db_session() as session:
            existing_count = session.scalar(select(Tag).limit(1))
            if existing_count is None:
                for tag_data in DEFAULT_TAGS:
                    tag = Tag(name=tag_data["name"], description=tag_data["description"])
                    session.add(tag)
                print(f"[Database] Seeded {len(DEFAULT_TAGS)} default tags.")
            else:
                print("[Database] Tags already exist, skipping default seeding.")

    print(f"[Database] Initialized database at: {DATABASE_URL}")


if __name__ == "__main__":
    init_db()
