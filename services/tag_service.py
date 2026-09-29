"""
Tag service for managing expense categories.
"""

from __future__ import annotations

from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.orm import Session

from database.database import get_db_session
from database.models import Tag


def get_all_tags(session: Optional[Session] = None) -> List[Tag]:
    """Retrieve all tags sorted alphabetically by name."""
    if session:
        return list(session.scalars(select(Tag).order_by(Tag.name.asc())).all())
    with get_db_session() as s:
        return list(s.scalars(select(Tag).order_by(Tag.name.asc())).all())


def get_tag_by_name(name: str, session: Optional[Session] = None) -> Optional[Tag]:
    """Find a tag by exact name (case-insensitive)."""
    clean_name = name.strip()
    if session:
        return session.scalar(
            select(Tag).where(Tag.name.ilike(clean_name))
        )
    with get_db_session() as s:
        return s.scalar(
            select(Tag).where(Tag.name.ilike(clean_name))
        )


def get_or_create_tag(
    name: str,
    description: Optional[str] = None,
    session: Optional[Session] = None,
) -> Tag:
    """Find an existing tag or create a new one."""
    clean_name = name.strip()
    if not clean_name:
        raise ValueError("Tag name cannot be empty.")

    if session:
        existing = session.scalar(
            select(Tag).where(Tag.name.ilike(clean_name))
        )
        if existing:
            return existing
        new_tag = Tag(name=clean_name, description=description)
        session.add(new_tag)
        session.flush()
        return new_tag

    with get_db_session() as s:
        existing = s.scalar(
            select(Tag).where(Tag.name.ilike(clean_name))
        )
        if existing:
            return existing
        new_tag = Tag(name=clean_name, description=description)
        s.add(new_tag)
        s.flush()
        s.expunge(new_tag)
        return new_tag
