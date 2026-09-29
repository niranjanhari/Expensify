"""
Expensify - Personal Expense Intelligence System.
Main Streamlit application entry point.
"""

from __future__ import annotations

import os
import streamlit as st
from dotenv import load_dotenv

from database.database import init_db
from ui.advisor import render_advisor_view
from ui.analytics import render_analytics_view
from ui.anomalies import render_anomalies_view
from ui.budgets import render_budgets_view
from ui.dashboard import render_dashboard
from ui.expense_form import render_expense_form
from ui.import_view import render_import_view
from ui.predictions import render_predictions_view
from ui.quick_add import render_quick_add_page
from ui.recurring import render_recurring_view
from ui.settings_view import render_settings_view
from ui.stores import render_stores_view
from ui.styles import CUSTOM_CSS
from ui.transactions import render_transactions_view

# Load environment configuration
load_dotenv()
DEFAULT_CURRENCY = os.getenv("DEFAULT_CURRENCY", "₹")

# Configure Streamlit page
st.set_page_config(
    page_title="Expensify — Personal Spending Journal",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Apply Central Design System
st.markdown(CUSTOM_CSS, unsafe_allow_html=True)

# Initialize database schema and defaults once per app run
@st.cache_resource
def setup_database():
    init_db(seed_defaults=True)
    return True

setup_database()

# Navigation options with Dashboard as default
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

if "app_nav" not in st.session_state:
    st.session_state.app_nav = "Dashboard"

# Sidebar Navigation
with st.sidebar:
    st.markdown(
        """
        <div class="sidebar-header">
            <div class="sidebar-app-name">Expensify</div>
            <div class="sidebar-app-desc">Personal Spending Journal</div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    current_idx = NAV_OPTIONS.index(st.session_state.app_nav) if st.session_state.app_nav in NAV_OPTIONS else 0
    selected_nav = st.radio(
        "Navigation",
        options=NAV_OPTIONS,
        index=current_idx,
        label_visibility="collapsed",
        key="main_nav_radio",
    )
    if selected_nav != st.session_state.app_nav:
        st.session_state.app_nav = selected_nav

    st.markdown("<hr>", unsafe_allow_html=True)
    active_currency = st.session_state.get("app_currency", DEFAULT_CURRENCY)
    st.caption("Database: Local SQLite")
    st.caption(f"Currency: {active_currency}")

# Route to corresponding section
active_currency = st.session_state.get("app_currency", DEFAULT_CURRENCY)

if st.session_state.app_nav == "Dashboard":
    render_dashboard(currency_symbol=active_currency)
elif st.session_state.app_nav == "Quick Add":
    render_quick_add_page(currency_symbol=active_currency)
elif st.session_state.app_nav == "Add Expense":
    render_expense_form(currency_symbol=active_currency)
elif st.session_state.app_nav == "Transactions":
    render_transactions_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Analytics":
    render_analytics_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Budgets":
    render_budgets_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Recurring":
    render_recurring_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Forecast & Predictions":
    render_predictions_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Anomalies":
    render_anomalies_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Import / Staging":
    render_import_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "AI Advisor":
    render_advisor_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Stores & Merchants":
    render_stores_view(currency_symbol=active_currency)
elif st.session_state.app_nav == "Settings":
    render_settings_view(currency_symbol=active_currency)
else:
    st.markdown(f"### {st.session_state.app_nav}")
    st.info(f"Welcome to **{st.session_state.app_nav}**.")
