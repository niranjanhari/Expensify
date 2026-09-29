"""
Recurring Expenses UI component (Phase 10 - Redesigned Editorial).
Displays recurring expense schedules, due-date notices, and safe 1-click confirmation logging.
"""

from datetime import date
from decimal import Decimal
import streamlit as st

from services.recurring_service import (
    confirm_and_log_recurring,
    create_recurring_expense,
    delete_recurring_expense,
    get_all_recurring_expenses,
    get_due_recurring_expenses,
    skip_recurring,
)
from services.store_service import get_all_stores
from services.tag_service import get_all_tags
from utils.constants import PAYMENT_METHODS


def render_recurring_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Recurring Expenses view."""
    st.markdown('<div class="section-label">Commitments</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Recurring Expenses</h1>', unsafe_allow_html=True)

    all_stores = get_all_stores()
    all_tags = get_all_tags()
    store_map = {s.name: s.id for s in all_stores}
    tag_map = {t.name: t.id for t in all_tags}

    # Top Add Recurring Action
    with st.popover("Add Recurring Template", use_container_width=True):
        st.markdown("**New Recurring Template**")
        desc = st.text_input("Description *", placeholder="e.g. Daily Canteen Lunch, Phone Recharge, Rent")
        amt = st.number_input(f"Amount ({currency_symbol}) *", min_value=0.01, value=100.0, step=10.0, format="%.2f")
        freq = st.selectbox("Frequency", options=["Daily", "Weekly", "Monthly"])
        due_d = st.date_input("First / Next Due Date", value=date.today())
        st_choice = st.selectbox("Merchant", options=["None"] + list(store_map.keys()))
        tg_choice = st.selectbox("Category", options=["None"] + list(tag_map.keys()))
        pm_choice = st.selectbox("Default Payment Method", options=PAYMENT_METHODS)

        if st.button("Save Schedule", type="primary", use_container_width=True):
            if desc.strip():
                st_id = store_map.get(st_choice) if st_choice != "None" else None
                tg_id = tag_map.get(tg_choice) if tg_choice != "None" else None
                create_recurring_expense(
                    description=desc.strip(),
                    amount=Decimal(str(amt)),
                    store_id=st_id,
                    tag_id=tg_id,
                    frequency=freq,
                    next_due_date=due_d,
                    payment_method=pm_choice,
                )
                st.success("Recurring schedule created.")
                st.rerun()
            else:
                st.error("Please enter a description.")

    # 1. Due Today / Pending Confirmation Section
    due_items = get_due_recurring_expenses()
    if due_items:
        st.markdown('<div class="section-label">Pending Action</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.1rem; color: #EDEDE8; margin-bottom: 0.5rem;">Due for Confirmation</div>', unsafe_allow_html=True)
        st.caption("These items have reached their scheduled date. Confirm to record today's transaction.")

        for rec in due_items:
            store_title = rec.store.name if rec.store else "Unspecified Merchant"
            tag_title = rec.tag.name if rec.tag else "Uncategorized"

            with st.container():
                col_info, col_act = st.columns([4, 2])
                with col_info:
                    st.markdown(
                        f"""
                        <div class="editorial-card" style="margin-bottom: 0px; padding: 0.9rem 1.1rem;">
                            <div style="display: flex; justify-content: space-between; align-items: baseline;">
                                <div style="display: flex; align-items: center; gap: 8px;">
                                    <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{rec.description}</span>
                                    <span class="subtle-tag">{tag_title}</span>
                                </div>
                                <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.1rem; font-weight: 600; color: #EDEDE8;">
                                    {currency_symbol}{rec.amount:,.2f}
                                </div>
                            </div>
                            <div style="font-size: 0.8rem; color: #8C8B82; margin-top: 4px;">
                                Merchant: {store_title} · Cadence: <b>{rec.frequency}</b> · Due: <b>{rec.next_due_date.strftime('%d %b %Y')}</b>
                            </div>
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )
                with col_act:
                    c_btn1, c_btn2 = st.columns(2)
                    with c_btn1:
                        if st.button("Confirm", key=f"conf_rec_{rec.id}", use_container_width=True, type="primary"):
                            confirm_and_log_recurring(rec.id)
                            st.rerun()
                    with c_btn2:
                        if st.button("Skip", key=f"skip_rec_{rec.id}", use_container_width=True):
                            skip_recurring(rec.id)
                            st.rerun()
                st.markdown("<div style='margin-bottom: 6px;'></div>", unsafe_allow_html=True)

    st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)

    # 2. All Recurring Schedules
    st.markdown('<div class="section-label">Active List</div>', unsafe_allow_html=True)
    st.markdown('<div style="font-weight: 600; font-size: 1.1rem; color: #EDEDE8; margin-bottom: 0.75rem;">Configured Schedules</div>', unsafe_allow_html=True)
    all_recurring = get_all_recurring_expenses(active_only=True)

    if not all_recurring:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No active recurring schedules</div>
                <div class="empty-state-desc">Use 'Add Recurring Template' above to set up routines, subscriptions, or fixed bills.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
        return

    cols = st.columns(2)
    for idx, rec in enumerate(all_recurring):
        col = cols[idx % 2]
        store_title = rec.store.name if rec.store else "Unspecified"
        tag_title = rec.tag.name if rec.tag else "Uncategorized"

        with col:
            st.markdown(
                f"""
                <div class="editorial-card" style="padding: 1.1rem 1.25rem;">
                    <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 6px;">
                        <div>
                            <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{rec.description}</span>
                            <span class="subtle-tag" style="margin-left: 6px;">{tag_title}</span>
                        </div>
                        <span style="font-family: 'IBM Plex Mono', monospace; font-size: 1.05rem; font-weight: 600; color: #EDEDE8;">
                            {currency_symbol}{rec.amount:,.2f}
                        </span>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 0.78rem; color: #8C8B82; margin-top: 8px;">
                        <div>Merchant: <span style="color: #EDEDE8;">{store_title}</span></div>
                        <div>Frequency: <span style="color: #EDEDE8;">{rec.frequency}</span></div>
                        <div>Next Due: <span style="color: #EDEDE8;">{rec.next_due_date.strftime('%d %b %Y')}</span></div>
                        <div>Payment: <span style="color: #EDEDE8;">{rec.payment_method}</span></div>
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )
            if st.button("Remove Schedule", key=f"del_rec_{rec.id}", use_container_width=True):
                delete_recurring_expense(rec.id)
                st.rerun()
