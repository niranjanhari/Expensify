"""
Stores & Merchants UI component (Phase 4 - Redesigned Editorial).
Displays merchant memory, autocomplete search, frequency analytics, and default tags.
"""

from decimal import Decimal
import streamlit as st

from services.store_service import (
    get_all_stores_with_metrics,
    get_or_create_store,
    search_stores,
)
from services.tag_service import get_all_tags


def render_stores_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Stores & Merchants directory."""
    st.markdown('<div class="section-label">Directory</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Stores & Merchants</h1>', unsafe_allow_html=True)

    # Top Action / Search Bar
    col_search, col_add = st.columns([3, 1])
    with col_search:
        search_query = st.text_input(
            "Search remembered stores...",
            placeholder="Search merchants (e.g. Starbucks, Amazon, Canteen)...",
            label_visibility="collapsed",
        )
    with col_add:
        with st.popover("Add Merchant", use_container_width=True):
            tags = get_all_tags()
            tag_map = {t.name: t.id for t in tags}
            new_name = st.text_input("Merchant Name", placeholder="e.g. Blue Tokai")
            selected_def_tag = st.selectbox(
                "Default Category (Optional)",
                options=["None"] + list(tag_map.keys()),
            )
            if st.button("Save Merchant", type="primary", use_container_width=True):
                if new_name.strip():
                    tag_id = tag_map.get(selected_def_tag) if selected_def_tag != "None" else None
                    created = get_or_create_store(new_name.strip(), default_tag_id=tag_id)
                    st.success(f"Saved: {created.name}")
                    st.rerun()
                else:
                    st.error("Please enter a valid store name.")

    # Fetch store metrics
    stores_data = get_all_stores_with_metrics()

    if search_query.strip():
        q_norm = search_query.strip().lower()
        stores_data = [s for s in stores_data if q_norm in s["name"].lower()]

    if not stores_data:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No merchants found</div>
                <div class="empty-state-desc">Add a new expense or use 'Add Merchant' above to record vendors.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
        return

    # Summary Metrics Row
    total_stores = len(stores_data)
    total_spent_all = sum((s["total_spent"] for s in stores_data), Decimal("0.00"))
    total_purchases_all = sum((s["purchase_count"] for s in stores_data), 0)

    m1, m2, m3 = st.columns(3)
    with m1:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Remembered Stores</div>
                <div class="stat-number">{total_stores}</div>
                <div class="stat-subtext">Active merchants in database</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with m2:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Total Outflow Tracked</div>
                <div class="stat-number">{currency_symbol}{total_spent_all:,.2f}</div>
                <div class="stat-subtext">Cumulative merchant spend</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with m3:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Total Transactions</div>
                <div class="stat-number">{total_purchases_all}</div>
                <div class="stat-subtext">Logged purchase events</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)
    st.markdown('<div class="section-label">Registry</div>', unsafe_allow_html=True)
    st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.75rem;">Merchant Directory</div>', unsafe_allow_html=True)

    # Display stores grid
    cols_per_row = 2
    for i in range(0, len(stores_data), cols_per_row):
        row_stores = stores_data[i:i + cols_per_row]
        cols = st.columns(cols_per_row)
        for col, s in zip(cols, row_stores):
            with col:
                frequent_tag = s["frequent_tag_name"] or "Uncategorized"
                last_active = s["last_date"].strftime("%d %b %Y") if s["last_date"] else "Never"

                st.markdown(
                    f"""
                    <div class="editorial-card" style="padding: 1.1rem 1.25rem;">
                        <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px;">
                            <span style="font-weight: 600; color: #EDEDE8; font-size: 1rem;">{s['name']}</span>
                            <span class="subtle-tag">{frequent_tag}</span>
                        </div>
                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; font-size: 0.8rem; color: #8C8B82;">
                            <div>
                                <span class="stat-label">Purchases</span>
                                <div style="font-family: 'IBM Plex Mono', monospace; font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{s['purchase_count']} times</div>
                            </div>
                            <div>
                                <span class="stat-label">Total Volume</span>
                                <div style="font-family: 'IBM Plex Mono', monospace; font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{currency_symbol}{s['total_spent']:,.2f}</div>
                            </div>
                            <div>
                                <span class="stat-label">Average Ticket</span>
                                <div style="font-family: 'IBM Plex Mono', monospace; font-weight: 500; color: #EDEDE8; font-size: 0.9rem;">{currency_symbol}{s['avg_spent']:,.2f}</div>
                            </div>
                            <div>
                                <span class="stat-label">Last Active</span>
                                <div style="font-size: 0.85rem; color: #8C8B82;">{last_active}</div>
                            </div>
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
