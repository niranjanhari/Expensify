"""
Transaction History UI component (Phase 5 - Redesigned Editorial).
Provides clean searching, multi-criteria filtering, pagination, editing, and deletion.
"""

from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Optional
import streamlit as st

from services.categorization_service import (
    batch_apply_tags,
    suggest_tags_for_uncategorized,
)
from services.expense_service import (
    delete_expense,
    get_filtered_expenses,
    update_expense,
)
from services.store_service import get_all_stores
from services.tag_service import get_all_tags
from utils.constants import PAYMENT_METHODS


PAGE_SIZE = 12


def render_transactions_view(currency_symbol: str = "₹") -> None:
    """Render the clean, editorial Transaction History view."""
    st.markdown('<div class="section-label">Ledger</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Transactions</h1>', unsafe_allow_html=True)

    # Initialize session state for filters and pagination if not present
    if "tx_page" not in st.session_state:
        st.session_state.tx_page = 1
    if "tx_search" not in st.session_state:
        st.session_state.tx_search = ""

    # Load master tags and stores for filter dropdowns
    all_tags = get_all_tags()
    all_stores = get_all_stores()
    tag_options = {t.name: t.id for t in all_tags}
    store_options = {s.name: s.id for s in all_stores}

    # Top Search, Sort & Auto-Tag Bar (proportional weighting for breathing room)
    col_search, col_sort, col_autotag = st.columns([5, 2, 2])
    with col_search:
        search_query = st.text_input(
            "Search",
            value=st.session_state.tx_search,
            placeholder="Search by merchant, note, category, or payment method...",
            label_visibility="collapsed",
            key="tx_search_input",
        )
        if search_query != st.session_state.tx_search:
            st.session_state.tx_search = search_query
            st.session_state.tx_page = 1

    with col_sort:
        sort_choice = st.selectbox(
            "Sort",
            options=["Newest First", "Oldest First"],
            index=0,
            label_visibility="collapsed",
        )
        sort_order = "desc" if sort_choice == "Newest First" else "asc"

    with col_autotag:
        with st.popover("Auto-tag", use_container_width=True):
            st.markdown("**Smart Category Tagging**")
            st.caption("Inspect uncategorized purchases and apply suggested tags.")
            uncat_suggestions = suggest_tags_for_uncategorized(limit=30)
            if not uncat_suggestions:
                st.info("All transactions have assigned categories.")
            else:
                st.caption(f"Found {len(uncat_suggestions)} uncategorized item{'s' if len(uncat_suggestions) > 1 else ''}.")
                table_preview = []
                for s in uncat_suggestions:
                    table_preview.append({
                        "Date": s["date"].strftime("%d %b"),
                        "Merchant": s["store_name"],
                        "Amount": f"{currency_symbol}{s['amount']:,.2f}",
                        "Suggested": s["suggested_tag_name"],
                        "Confidence": f"{int(s['confidence'] * 100)}%",
                    })
                st.dataframe(table_preview, use_container_width=True, hide_index=True)

                if st.button("Apply Suggested Tags", type="primary", use_container_width=True, key="btn_apply_all_tags"):
                    batch_payload = [
                        {"expense_id": s["expense_id"], "tag_name": s["suggested_tag_name"]}
                        for s in uncat_suggestions
                    ]
                    applied = batch_apply_tags(batch_payload)
                    st.success(f"Categorized {applied} transactions.")
                    st.rerun()

    # Expandable Advanced Filters
    with st.expander("Filter transactions", expanded=False):
        f_col1, f_col2, f_col3 = st.columns(3)

        with f_col1:
            date_filter_mode = st.selectbox(
                "Date Range",
                options=["All Time", "This Month", "Last 30 Days", "Custom Range"],
                index=0,
            )
            start_date: Optional[date] = None
            end_date: Optional[date] = None

            today = date.today()
            if date_filter_mode == "This Month":
                start_date = today.replace(day=1)
                end_date = today
            elif date_filter_mode == "Last 30 Days":
                start_date = today - timedelta(days=30)
                end_date = today
            elif date_filter_mode == "Custom Range":
                c1, c2 = st.columns(2)
                with c1:
                    start_date = st.date_input("From", value=today - timedelta(days=7))
                with c2:
                    end_date = st.date_input("To", value=today)

        with f_col2:
            selected_tag_names = st.multiselect(
                "Category",
                options=list(tag_options.keys()),
                default=[],
            )
            selected_tag_ids = [tag_options[name] for name in selected_tag_names] if selected_tag_names else None

            selected_payments = st.multiselect(
                "Payment Method",
                options=PAYMENT_METHODS,
                default=[],
            )

        with f_col3:
            selected_store_names = st.multiselect(
                "Merchant",
                options=list(store_options.keys()),
                default=[],
            )
            selected_store_ids = [store_options[name] for name in selected_store_names] if selected_store_names else None

            amt_c1, amt_c2 = st.columns(2)
            with amt_c1:
                min_amt = st.number_input("Min", min_value=0.0, value=None, step=50.0, format="%.2f")
            with amt_c2:
                max_amt = st.number_input("Max", min_value=0.0, value=None, step=50.0, format="%.2f")

        if st.button("Reset Filters", use_container_width=True):
            st.session_state.tx_search = ""
            st.session_state.tx_page = 1
            st.rerun()

    # Query Data
    query_result = get_filtered_expenses(
        search_query=st.session_state.tx_search,
        start_date=start_date,
        end_date=end_date,
        tag_ids=selected_tag_ids,
        store_ids=selected_store_ids,
        payment_methods=selected_payments if selected_payments else None,
        min_amount=min_amt,
        max_amount=max_amt,
        sort_order=sort_order,
        page=st.session_state.tx_page,
        page_size=PAGE_SIZE,
    )

    items = query_result["items"]
    total_count = query_result["total_count"]
    total_amount = query_result["total_amount"]
    total_pages = query_result["total_pages"]

    # Top Aggregation Metrics Row
    m1, m2, m3 = st.columns(3)
    avg_amt = (total_amount / total_count).quantize(Decimal("0.01")) if total_count > 0 else Decimal("0.00")

    with m1:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Filtered Spend</div>
                <div class="stat-number">{currency_symbol}{total_amount:,.2f}</div>
                <div class="stat-subtext">Sum of current view</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with m2:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Transactions</div>
                <div class="stat-number">{total_count}</div>
                <div class="stat-subtext">Matching criteria</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with m3:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Average Ticket</div>
                <div class="stat-number">{currency_symbol}{avg_amt:,.2f}</div>
                <div class="stat-subtext">Per transaction</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)

    if not items:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No transactions found</div>
                <div class="empty-state-desc">Try clearing the search query or adjusting your filter criteria.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
        return

    # Transactions List with Edit & Delete actions
    for exp in items:
        store_title = exp.store.name if exp.store else "Unspecified Merchant"
        tag_title = exp.tag.name if exp.tag else "Uncategorized"
        time_text = exp.time.strftime("%I:%M %p") if exp.time else ""
        date_text = f"{exp.date.strftime('%d %b %Y')} {time_text}".strip()

        with st.container():
            card_col, action_col = st.columns([4.2, 1.4])

            with card_col:
                desc_text = exp.description if exp.description else "No description"
                st.markdown(
                    f"""
                    <div class="editorial-card" style="margin-bottom: 0px; padding: 0.9rem 1.1rem;">
                        <div style="display: flex; justify-content: space-between; align-items: baseline;">
                            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{store_title}</span>
                                <span class="subtle-tag">{tag_title}</span>
                                <span style="font-size: 0.78rem; color: #8C8B82;">{exp.payment_method}</span>
                            </div>
                            <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.05rem; font-weight: 600; color: #EDEDE8;">
                                {currency_symbol}{exp.amount:,.2f}
                            </div>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 6px; font-size: 0.8rem; color: #8C8B82;">
                            <span>{desc_text}</span>
                            <span>{date_text}</span>
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )

            with action_col:
                btn_col1, btn_col2 = st.columns(2)

                # Edit Popover
                with btn_col1:
                    with st.popover("Edit", help=f"Edit transaction #{exp.id}", use_container_width=True):
                        st.markdown(f"**Edit Transaction #{exp.id}**")
                        edit_amount = st.number_input(
                            f"Amount ({currency_symbol})",
                            min_value=0.01,
                            value=float(exp.amount),
                            step=10.0,
                            format="%.2f",
                            key=f"edit_amt_{exp.id}",
                        )
                        edit_date = st.date_input("Date", value=exp.date, key=f"edit_dt_{exp.id}")
                        edit_time = st.time_input("Time", value=exp.time or datetime.now().time(), key=f"edit_tm_{exp.id}")

                        # Store selection
                        store_list = ["None"] + list(store_options.keys())
                        cur_store_idx = store_list.index(exp.store.name) if exp.store and exp.store.name in store_list else 0
                        chosen_store = st.selectbox("Merchant", options=store_list, index=cur_store_idx, key=f"edit_st_{exp.id}")
                        new_store_id = store_options.get(chosen_store) if chosen_store != "None" else None

                        # Tag selection
                        tag_list = ["None"] + list(tag_options.keys())
                        cur_tag_idx = tag_list.index(exp.tag.name) if exp.tag and exp.tag.name in tag_list else 0
                        chosen_tag = st.selectbox("Category", options=tag_list, index=cur_tag_idx, key=f"edit_tg_{exp.id}")
                        new_tag_id = tag_options.get(chosen_tag) if chosen_tag != "None" else None

                        # Payment Method
                        cur_pm_idx = PAYMENT_METHODS.index(exp.payment_method) if exp.payment_method in PAYMENT_METHODS else 0
                        edit_pm = st.selectbox("Payment Method", options=PAYMENT_METHODS, index=cur_pm_idx, key=f"edit_pm_{exp.id}")

                        edit_desc = st.text_input("Description", value=exp.description or "", key=f"edit_desc_{exp.id}")

                        if st.button("Save", type="primary", key=f"save_btn_{exp.id}", use_container_width=True):
                            try:
                                update_expense(
                                    expense_id=exp.id,
                                    amount=edit_amount,
                                    date=edit_date,
                                    time=edit_time,
                                    description=edit_desc,
                                    store_id=new_store_id,
                                    tag_id=new_tag_id,
                                    payment_method=edit_pm,
                                )
                                st.success("Updated.")
                                st.rerun()
                            except Exception as e:
                                st.error(f"Error updating transaction: {e}")

                # Delete Popover
                with btn_col2:
                    with st.popover("Del", help=f"Delete transaction #{exp.id}", use_container_width=True):
                        st.markdown(f"**Delete transaction #{exp.id}?**")
                        st.caption(f"Permanently remove {currency_symbol}{exp.amount:,.2f} at {store_title}.")
                        if st.button("Delete", type="primary", key=f"del_btn_{exp.id}", use_container_width=True):
                            delete_expense(exp.id)
                            st.rerun()

            st.markdown("<div style='margin-bottom: 6px;'></div>", unsafe_allow_html=True)

    # Pagination Controls
    st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)
    p_col1, p_col2, p_col3 = st.columns([1, 2, 1])

    with p_col1:
        if st.session_state.tx_page > 1:
            if st.button("Previous", use_container_width=True):
                st.session_state.tx_page -= 1
                st.rerun()

    with p_col2:
        st.markdown(
            f"<div style='text-align: center; color: #8C8B82; font-size: 0.85rem; padding-top: 8px;'>"
            f"Page {st.session_state.tx_page} of {max(1, total_pages)} &nbsp;·&nbsp; {total_count} records"
            f"</div>",
            unsafe_allow_html=True,
        )

    with p_col3:
        if st.session_state.tx_page < total_pages:
            if st.button("Next", use_container_width=True):
                st.session_state.tx_page += 1
                st.rerun()
