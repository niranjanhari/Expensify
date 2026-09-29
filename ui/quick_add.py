"""
Quick Add UI component (Redesigned - Editorial & Minimal).
Provides rapid shortcut logging for frequent and pinned routines.
"""

from decimal import Decimal
from typing import Dict, List
import streamlit as st

from services.quick_add_service import (
    execute_quick_add,
    get_quick_add_suggestions,
    hide_quick_add_item,
    pin_quick_add_item,
)
from services.store_service import get_all_stores
from services.tag_service import get_all_tags
from utils.constants import PAYMENT_METHODS


def render_quick_add_page(currency_symbol: str = "₹") -> None:
    """Render the dedicated Quick Add spending page."""
    st.markdown('<div class="section-label">Shortcuts</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Quick Add</h1>', unsafe_allow_html=True)
    st.markdown(
        '<p class="page-subtitle">Ranked by frequency and recency. Log frequent purchases with a single click.</p>',
        unsafe_allow_html=True,
    )

    # Top Bar: Add custom Pin Popover
    col_hdr, col_pin = st.columns([3, 1])
    with col_hdr:
        st.caption("Common repeated items are identified automatically. You can also pin custom shortcuts below.")
    with col_pin:
        with st.popover("Pin new shortcut", use_container_width=True):
            st.markdown("**New shortcut template**")
            all_stores = get_all_stores()
            all_tags = get_all_tags()
            store_map = {s.name: s.id for s in all_stores}
            tag_map = {t.name: t.id for t in all_tags}

            pin_amt = st.number_input(
                f"Amount ({currency_symbol}) *",
                min_value=0.01,
                value=50.00,
                step=10.0,
                format="%.2f",
                key="new_pin_amt",
            )
            pin_store = st.selectbox("Store / Merchant", options=["None"] + list(store_map.keys()), key="new_pin_st")
            pin_tag = st.selectbox("Category", options=["None"] + list(tag_map.keys()), key="new_pin_tg")
            pin_desc = st.text_input("Description", placeholder="e.g. Daily Coffee, Metro", key="new_pin_desc")
            pin_pm = st.selectbox("Payment method", options=PAYMENT_METHODS, key="new_pin_pm")

            if st.button("Save shortcut", type="primary", use_container_width=True):
                st_id = store_map.get(pin_store) if pin_store != "None" else None
                tg_id = tag_map.get(pin_tag) if pin_tag != "None" else None
                pin_quick_add_item(
                    amount=Decimal(str(pin_amt)),
                    store_id=st_id,
                    tag_id=tg_id,
                    description=pin_desc,
                    payment_method=pin_pm,
                )
                st.success("Shortcut pinned.")
                st.rerun()

    suggestions = get_quick_add_suggestions(limit=10)

    if not suggestions:
        st.info("No repeated spending patterns detected yet. Log a few expenses or pin a shortcut above.")
        return

    st.markdown("<hr>", unsafe_allow_html=True)

    # Render clean 2-column shortcut rows
    cols = st.columns(2)
    for idx, item in enumerate(suggestions):
        col = cols[idx % 2]
        title = item["description"] or item["store_name"] or item["tag_name"] or "Expense"
        sub_info = f"{item['store_name']} • {item['tag_name']}" if item["store_name"] != "Unspecified" else item["tag_name"]

        with col:
            with st.container():
                st.markdown(
                    f"""
                    <div class="quick-add-item">
                        <div>
                            <div class="quick-add-name">{title}</div>
                            <div class="quick-add-meta">{sub_info}</div>
                        </div>
                        <div class="quick-add-amount">{currency_symbol}{item['amount']:,.2f}</div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
                b_c1, b_c2 = st.columns([3, 1])
                with b_c1:
                    if st.button("Log today", key=f"qa_btn_{idx}", use_container_width=True, type="primary"):
                        execute_quick_add(item)
                        st.success(f"Recorded {currency_symbol}{item['amount']:,.2f} for {title}.")
                        st.rerun()
                with b_c2:
                    if st.button("Hide", key=f"qa_hide_{idx}", use_container_width=True):
                        hide_quick_add_item(
                            amount=item["amount"],
                            store_id=item["store_id"],
                            tag_id=item["tag_id"],
                            description=item["description"],
                        )
                        st.rerun()


def render_quick_add_bar(currency_symbol: str = "₹", limit: int = 3) -> None:
    """Render a subtle inline strip of top Quick Add shortcuts."""
    items = get_quick_add_suggestions(limit=limit)
    if not items:
        return

    st.markdown('<div class="section-label">Frequent shortcuts</div>', unsafe_allow_html=True)
    cols = st.columns(len(items))

    for idx, item in enumerate(items):
        with cols[idx]:
            title = item["description"] or item["store_name"] or item["tag_name"] or "Expense"
            label = f"{title} · {currency_symbol}{item['amount']:,.2f}"
            if st.button(label, key=f"bar_qa_{idx}", use_container_width=True):
                execute_quick_add(item)
                st.success(f"Logged {currency_symbol}{item['amount']:,.2f} for {title}.")
                st.rerun()
    st.markdown("<br>", unsafe_allow_html=True)
