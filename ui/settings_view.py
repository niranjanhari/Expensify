"""
Settings, Data Export & Management UI component (Phases 17 & 18 - Redesigned Editorial).
Provides:
- 1-Click CSV, JSON, and SQLite database downloads
- JSON backup restoration
- Currency formatting & default preferences
- AI privacy controls (100% offline mode toggle)
- Category and merchant management
"""

import os
from decimal import Decimal
import streamlit as st

from services.balance_service import get_balance_details, update_account_balance
from services.export_service import (
    create_sqlite_snapshot_bytes,
    export_expenses_to_csv,
    export_full_backup_json,
    restore_backup_from_json,
)
from services.store_service import get_all_stores, get_or_create_store
from services.tag_service import get_all_tags, get_or_create_tag
from utils.constants import PAYMENT_METHODS


def render_settings_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Settings and Data Management view."""
    st.markdown('<div class="section-label">System</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Settings & Data</h1>', unsafe_allow_html=True)

    tab_balance, tab_prefs, tab_entities, tab_backup = st.tabs([
        "Current Balance",
        "Preferences & Privacy",
        "Categories & Merchants",
        "Backup & Export",
    ])

    # ---------------- TAB 1: CURRENT BANK BALANCE ----------------
    with tab_balance:
        st.markdown('<div class="section-label">Bank Account</div>', unsafe_allow_html=True)
        st.markdown(
            '<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.25rem;">'
            'Manage Current Balance</div>',
            unsafe_allow_html=True,
        )
        st.caption(
            "Configure your actual bank balance. When you record expenses, your balance will "
            "automatically update in real-time."
        )

        bal_info = get_balance_details()

        # Balance overview card
        if bal_info["is_configured"]:
            set_at_text = (
                bal_info["set_at"].strftime("%d %b %Y, %I:%M %p")
                if bal_info["set_at"]
                else "Unknown"
            )
            note_display = f" • {bal_info['notes']}" if bal_info["notes"] else ""
            st.markdown(
                f"""
                <div class="balance-hero-card" style="margin-top: 0.75rem; margin-bottom: 1.25rem;">
                    <div class="balance-hero-label">Calculated Live Balance</div>
                    <div class="balance-hero-amount">{currency_symbol}{bal_info['current_balance']:,.2f}</div>
                    <div class="balance-hero-subtext">
                        Saved baseline: <b>{currency_symbol}{bal_info['baseline_amount']:,.2f}</b><br>
                        Logged expenses since baseline: <b>{currency_symbol}{bal_info['expenses_since_baseline']:,.2f}</b><br>
                        Baseline established: <b>{set_at_text}</b>{note_display}
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )
        else:
            st.markdown(
                f"""
                <div class="balance-hero-card" style="margin-top: 0.75rem; margin-bottom: 1.25rem;">
                    <div class="balance-hero-label">Status</div>
                    <div class="balance-hero-amount" style="font-size: 1.6rem; color: #9C9B91;">Not Configured</div>
                    <div class="balance-hero-subtext">
                        Establish your bank balance baseline below to start tracking live funds.
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        # Form to set/update balance
        st.markdown(
            '<div style="font-weight: 600; font-size: 0.95rem; color: #EDEDE8; margin-bottom: 0.5rem;">'
            'Update Balance Baseline</div>',
            unsafe_allow_html=True,
        )
        with st.form("set_balance_form"):
            init_val = float(bal_info["current_balance"]) if bal_info["is_configured"] else 10000.0
            new_balance_val = st.number_input(
                f"Current Bank Account Balance ({currency_symbol}) *",
                min_value=0.0,
                max_value=100000000.0,
                value=init_val,
                step=100.0,
                format="%.2f",
                help="Enter your actual bank account balance right now.",
            )
            balance_note = st.text_input(
                "Account Description / Note (optional)",
                value=bal_info["notes"] or "",
                placeholder="e.g. Primary Checking Account, Salary Account",
            )
            submit_bal = st.form_submit_button("Save Current Balance", type="primary", use_container_width=True)

        if submit_bal:
            update_account_balance(
                Decimal(str(new_balance_val)),
                notes=balance_note,
            )
            st.success(
                f"Bank balance updated to {currency_symbol}{new_balance_val:,.2f}. "
                "New baseline established successfully."
            )
            st.rerun()

    # ---------------- TAB 2: PREFERENCES & PRIVACY ----------------
    with tab_backup:
        st.markdown('<div class="section-label">Data Portability</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Export Your Records</div>', unsafe_allow_html=True)
        st.caption("Your financial data belongs to you. Export raw records anytime.")

        c1, c2, c3 = st.columns(3)

        with c1:
            st.markdown(
                """
                <div class="editorial-card" style="padding: 1.15rem; margin-bottom: 0.5rem;">
                    <div style="font-weight: 600; color: #EDEDE8; margin-bottom: 4px;">CSV Spreadsheet</div>
                    <div style="font-size: 0.8rem; color: #8C8B82;">
                        Compatible with Excel, Google Sheets, and Numbers.
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )
            csv_data = export_expenses_to_csv()
            st.download_button(
                "Download CSV",
                data=csv_data,
                file_name="expensify_transactions.csv",
                mime="text/csv",
                use_container_width=True,
                key="btn_dl_csv",
            )

        with c2:
            st.markdown(
                """
                <div class="editorial-card" style="padding: 1.15rem; margin-bottom: 0.5rem;">
                    <div style="font-weight: 600; color: #EDEDE8; margin-bottom: 4px;">Full JSON Backup</div>
                    <div style="font-size: 0.8rem; color: #8C8B82;">
                        Complete structured backup of expenses, stores, tags, and targets.
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )
            json_data = export_full_backup_json()
            st.download_button(
                "Download JSON",
                data=json_data,
                file_name="expensify_full_backup.json",
                mime="application/json",
                use_container_width=True,
                key="btn_dl_json",
            )

        with c3:
            st.markdown(
                """
                <div class="editorial-card" style="padding: 1.15rem; margin-bottom: 0.5rem;">
                    <div style="font-weight: 600; color: #EDEDE8; margin-bottom: 4px;">SQLite Database</div>
                    <div style="font-size: 0.8rem; color: #8C8B82;">
                        Binary snapshot of local database file (expense_tracker.db).
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )
            try:
                db_bytes = create_sqlite_snapshot_bytes()
                st.download_button(
                    "Download SQLite (.db)",
                    data=db_bytes,
                    file_name="expense_tracker.db",
                    mime="application/x-sqlite3",
                    use_container_width=True,
                    key="btn_dl_db",
                )
            except Exception as e:
                st.caption(f"Snapshot unavailable: {e}")

        st.markdown("<div style='margin-top: 2rem; border-top: 1px solid #232521; padding-top: 1.5rem;'></div>", unsafe_allow_html=True)

        st.markdown('<div class="section-label">Restoration</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Restore from Backup</div>', unsafe_allow_html=True)
        st.caption("Upload a previously exported JSON backup file to merge your entries.")

        uploaded_backup = st.file_uploader("Upload JSON Backup File", type=["json"], key="backup_json_upload")
        if uploaded_backup is not None:
            if st.button("Restore Backup", type="primary", use_container_width=True):
                try:
                    content = uploaded_backup.read().decode("utf-8")
                    stats = restore_backup_from_json(content)
                    st.success(
                        f"Restoration complete: added {stats['expenses_added']} expense(s), "
                        f"{stats['tags_added']} tag(s), and {stats['stores_added']} merchant(s)."
                    )
                    st.rerun()
                except Exception as ex:
                    st.error(f"Failed to restore backup: {ex}")

    # ---------------- TAB 2: PREFERENCES & PRIVACY ----------------
    with tab_prefs:
        st.markdown('<div class="section-label">Localization</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Display & Formatting</div>', unsafe_allow_html=True)

        pref_col1, pref_col2 = st.columns(2)
        with pref_col1:
            st.markdown("<div class='stat-label'>Currency Symbol</div>", unsafe_allow_html=True)
            cur_choices = ["₹", "$", "€", "£", "¥", "C$", "A$"]
            cur_idx = cur_choices.index(currency_symbol) if currency_symbol in cur_choices else 0
            sel_currency = st.selectbox("Display Currency", options=cur_choices, index=cur_idx, key="sel_pref_cur", label_visibility="collapsed")
            if sel_currency != currency_symbol:
                st.session_state.app_currency = sel_currency
                st.rerun()

        with pref_col2:
            st.markdown("<div class='stat-label'>Default Payment Method</div>", unsafe_allow_html=True)
            st.selectbox("Default Payment", options=PAYMENT_METHODS, index=0, key="sel_pref_pm", label_visibility="collapsed")

        st.markdown("<div style='margin-top: 2rem;'></div>", unsafe_allow_html=True)
        st.markdown('<div class="section-label">Architecture</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Privacy & Intelligence Controls</div>', unsafe_allow_html=True)

        gemini_key = os.getenv("GEMINI_API_KEY")
        has_key = bool(gemini_key and gemini_key.strip())

        ai_status_badge = "Configured (Gemini API)" if has_key else "Offline Mode (Local Heuristics)"
        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1.3rem;">
                <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px;">
                    <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">Engine Status</span>
                    <span class="subtle-tag">{ai_status_badge}</span>
                </div>
                <p style="font-size: 0.85rem; color: #8C8B82; line-height: 1.5; margin-bottom: 12px;">
                    Expensify operates on a <b>Privacy-First Local Foundation</b>. 
                    All transactions, merchants, and budgets reside exclusively on your local machine in SQLite.
                    When using Natural Language Entry or the AI Advisor, data is sanitized and anonymized before processing.
                </p>
                <div class="notice-block" style="margin-bottom: 0;">
                    <b>Local Execution Guarantee:</b> If no API key is set, Expensify functions entirely offline with zero network calls.
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    # ---------------- TAB 3: MANAGE TAGS & STORES ----------------
    with tab_entities:
        ent_col1, ent_col2 = st.columns(2)

        with ent_col1:
            st.markdown('<div class="section-label">Taxonomy</div>', unsafe_allow_html=True)
            st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Category Tags</div>', unsafe_allow_html=True)
            with st.form("new_tag_form", clear_on_submit=True):
                new_t_name = st.text_input("New Category Tag", placeholder="e.g. Subscriptions, Utilities, Hobbies", label_visibility="collapsed")
                if st.form_submit_button("Add Category", type="primary", use_container_width=True):
                    if new_t_name.strip():
                        get_or_create_tag(new_t_name.strip())
                        st.success(f"Category '{new_t_name.strip()}' created.")
                        st.rerun()

            all_tags = get_all_tags()
            st.caption(f"Currently managing {len(all_tags)} categories:")
            for t in all_tags:
                st.markdown(
                    f"""
                    <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 10px; background: #161815; border: 1px solid #232521; border-radius: 6px; margin-bottom: 4px; font-size: 0.85rem;">
                        <span style="font-weight: 500; color: #EDEDE8;">{t.name}</span>
                        <span class="subtle-tag">Active</span>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )

        with ent_col2:
            st.markdown('<div class="section-label">Counterparties</div>', unsafe_allow_html=True)
            st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Merchants & Vendors</div>', unsafe_allow_html=True)
            with st.form("new_store_form", clear_on_submit=True):
                new_s_name = st.text_input("New Merchant", placeholder="e.g. Amazon, Metro Rail, Swiggy", label_visibility="collapsed")
                if st.form_submit_button("Add Merchant", type="primary", use_container_width=True):
                    if new_s_name.strip():
                        get_or_create_store(new_s_name.strip())
                        st.success(f"Merchant '{new_s_name.strip()}' added.")
                        st.rerun()

            all_stores = get_all_stores()
            st.caption(f"Currently remembering {len(all_stores)} merchants:")
            for s in all_stores[:15]:
                st.markdown(
                    f"""
                    <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 10px; background: #161815; border: 1px solid #232521; border-radius: 6px; margin-bottom: 4px; font-size: 0.85rem;">
                        <span style="font-weight: 500; color: #EDEDE8;">{s.name}</span>
                        <span style="font-family: 'IBM Plex Mono', monospace; color: #8C8B82; font-size: 0.78rem;">{s.usage_count} logged</span>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
