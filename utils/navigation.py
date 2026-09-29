"""
Navigation helper for Expensify.
Ensures seamless programmatic navigation across Streamlit reruns.
"""

from __future__ import annotations

import streamlit as st

NAV_OPTIONS = [
    "Dashboard",
    "Add Expense",
    "Transactions",
    "Quick Add",
    "Analytics",
    "Budgets",
    "Recurring",
    "Forecast & Predictions",
    "Anomalies",
    "Import / Staging",
    "Stores & Merchants",
    "AI Advisor",
    "Settings",
]

PRIMARY_NAV_PAGES = [
    "Dashboard",
    "Add Expense",
    "Transactions",
    "Analytics",
    "Budgets",
    "Recurring",
    "AI Advisor",
    "Settings",
]


def navigate_to(page_name: str) -> None:
    """
    Programmatically switch to a page and rerun.
    Updates app_nav in session state and triggers immediate rerun.
    """
    if page_name in NAV_OPTIONS:
        st.session_state["app_nav"] = page_name
        st.rerun()
