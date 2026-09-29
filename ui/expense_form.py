"""
Add Expense UI component (Redesigned - Editorial & Minimal).
Provides focused, fast expense entry where amount visually dominates,
followed by merchant, category, and transaction details.
"""

from datetime import date, datetime
from decimal import Decimal
import streamlit as st

from services.anomaly_service import check_single_expense_anomaly
from services.categorization_service import predict_tag_for_expense
from services.expense_service import create_expense, get_recent_expenses
from services.nlp_expense_service import parse_natural_language_expense
from services.store_service import (
    get_all_stores,
    get_or_create_store,
    get_store_metrics,
)
from services.tag_service import get_all_tags, get_or_create_tag
from utils.constants import PAYMENT_METHODS


def render_expense_form(currency_symbol: str = "₹") -> None:
    """Render the fast, focused Add Expense view."""
    st.markdown('<h1 class="page-title">Add Expense</h1>', unsafe_allow_html=True)
    st.markdown(
        '<p class="page-subtitle">Record a purchase manually or enter a plain sentence.</p>',
        unsafe_allow_html=True,
    )

    tab_manual, tab_sentence = st.tabs(["Manual Entry", "Sentence Entry"])

    with tab_manual:
        _render_centered_manual_form(currency_symbol)

    with tab_sentence:
        _render_sentence_entry_tab(currency_symbol)

    # Recent entries section
    st.markdown("<hr>", unsafe_allow_html=True)
    st.markdown('<div class="section-title">Recent entries</div>', unsafe_allow_html=True)
    recent_entries = get_recent_expenses(limit=5)
    if not recent_entries:
        st.caption("No transactions recorded yet.")
    else:
        for exp in recent_entries:
            store_title = exp.store.name if exp.store else "Unspecified"
            tag_title = exp.tag.name if exp.tag else "Uncategorized"
            date_str = exp.date.strftime("%d %b %Y")

            st.markdown(
                f"""
                <div class="data-row">
                    <div>
                        <div class="data-row-store">{store_title}</div>
                        <div class="data-row-category">{tag_title} • {exp.description or exp.payment_method}</div>
                    </div>
                    <div>
                        <div class="data-row-amount">{currency_symbol}{exp.amount:,.2f}</div>
                        <div class="data-row-date">{date_str}</div>
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )


def _render_centered_manual_form(currency_symbol: str = "₹") -> None:
    """Render centered, fast manual expense entry form."""
    tags = get_all_tags()
    stores = get_all_stores()

    tag_names = [t.name for t in tags]
    tag_options = tag_names + ["+ Add new category..."]

    store_names = [s.name for s in stores]
    store_options = store_names + ["+ Add new store..."]

    col_l, col_center, col_r = st.columns([1, 6, 1])

    with col_center:
        # 1. Store selector outside form to allow live category prediction
        selected_store_name = st.selectbox(
            "Store / Merchant",
            options=store_options,
            index=0 if store_names else len(store_options) - 1,
            label_visibility="visible",
        )

        new_store_input = ""
        default_tag_index = 0

        if selected_store_name == "+ Add new store...":
            new_store_input = st.text_input(
                "New store name",
                placeholder="e.g. Starbucks, College Canteen, Amazon",
            )
        elif selected_store_name:
            matched_store = next((s for s in stores if s.name == selected_store_name), None)
            if matched_store:
                metrics = get_store_metrics(matched_store.id)
                if metrics["purchase_count"] > 0:
                    freq_tag = metrics.get("frequent_tag_name")
                    tag_suffix = f"• Usually {freq_tag}" if freq_tag else ""
                    st.caption(
                        f"History: {metrics['purchase_count']} visits • Average {currency_symbol}{metrics['avg_spent']:,.2f} {tag_suffix}"
                    )
                    if metrics["frequent_tag_name"] in tag_names:
                        default_tag_index = tag_names.index(metrics["frequent_tag_name"])
                elif matched_store.default_tag and matched_store.default_tag.name in tag_names:
                    default_tag_index = tag_names.index(matched_store.default_tag.name)
                else:
                    pred = predict_tag_for_expense(store_name=matched_store.name)
                    if pred["confidence"] >= 0.8 and pred["tag_name"] in tag_names:
                        default_tag_index = tag_names.index(pred["tag_name"])

        # 2. Main Entry Form
        with st.form("add_expense_form", clear_on_submit=True):
            amount = st.number_input(
                f"Amount ({currency_symbol}) *",
                min_value=0.01,
                max_value=10000000.0,
                value=None,
                step=10.0,
                format="%.2f",
                placeholder="0.00",
            )

            selected_tag = st.selectbox(
                "Category",
                options=tag_options,
                index=default_tag_index if tag_names else len(tag_options) - 1,
            )

            new_tag_input = ""
            if selected_tag == "+ Add new category...":
                new_tag_input = st.text_input(
                    "New category name",
                    placeholder="e.g. Subscriptions, Groceries, Gym",
                )

            description = st.text_input(
                "Description (optional)",
                placeholder="e.g. Lunch thali, Cold coffee, Metro ticket",
            )

            row2_c1, row2_c2 = st.columns(2)
            with row2_c1:
                expense_date = st.date_input("Date", value=date.today())
                expense_time = st.time_input("Time", value=datetime.now().time())
            with row2_c2:
                payment_method = st.selectbox("Payment method", options=PAYMENT_METHODS, index=0)

            submit_btn = st.form_submit_button("Save expense", type="primary", use_container_width=True)

        if submit_btn:
            if amount is None or amount <= 0:
                st.error("Please enter a valid amount.")
                return

            # Resolve Store
            store_id = None
            store_display = ""
            if selected_store_name == "+ Add new store...":
                if not new_store_input.strip():
                    st.error("Please enter a store name.")
                    return
                store = get_or_create_store(new_store_input.strip())
                store_id = store.id
                store_display = store.name
            elif selected_store_name:
                store = next((s for s in stores if s.name == selected_store_name), None)
                if store:
                    store_id = store.id
                    store_display = store.name

            # Resolve Tag
            tag_id = None
            tag_display = ""
            if selected_tag == "+ Add new category...":
                if not new_tag_input.strip():
                    st.error("Please enter a category name.")
                    return
                tag = get_or_create_tag(new_tag_input.strip())
                tag_id = tag.id
                tag_display = tag.name
            elif selected_tag:
                tag = next((t for t in tags if t.name == selected_tag), None)
                if tag:
                    tag_id = tag.id
                    tag_display = tag.name

            try:
                create_expense(
                    amount=amount,
                    date=expense_date,
                    time=expense_time,
                    description=description,
                    store_id=store_id,
                    tag_id=tag_id,
                    payment_method=payment_method,
                )

                # Check statistical anomaly for awareness
                anomaly = check_single_expense_anomaly(
                    amount=Decimal(str(amount)),
                    tag_id=tag_id,
                    store_id=store_id,
                )
                if anomaly:
                    st.markdown(
                        f"""
                        <div class="notice-block-warn">
                            <b>Unusual amount:</b> {anomaly['message']}
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )

                st.markdown(
                    f"""
                    <div class="notice-block">
                        Recorded {currency_symbol}{Decimal(str(amount)):,.2f} at {store_display or 'merchant'} [{tag_display or 'Uncategorized'}].
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
                st.rerun()
            except Exception as e:
                st.error(f"Failed to record expense: {e}")


def _render_sentence_entry_tab(currency_symbol: str = "₹") -> None:
    """Render plain natural language entry tab."""
    st.markdown('<div class="section-title">Enter spending in plain text</div>', unsafe_allow_html=True)
    st.caption("Example: 'Spent 80 at college canteen for lunch using gpay' or 'Paid 450 for Uber'")

    col_nl1, col_nl2 = st.columns([4, 1])
    with col_nl1:
        nl_text = st.text_input(
            "Expense sentence",
            placeholder="e.g. Paid 150 for coffee at Starbucks with GPay",
            label_visibility="collapsed",
            key="nl_prompt_input",
        )
    with col_nl2:
        parse_clicked = st.button("Parse sentence", type="primary", use_container_width=True)

    if parse_clicked and nl_text.strip():
        try:
            candidate = parse_natural_language_expense(nl_text.strip())
            st.session_state.nlp_candidate = candidate
        except Exception as e:
            st.error(f"Parsing failed: {e}")

    if "nlp_candidate" in st.session_state and st.session_state.nlp_candidate:
        cand = st.session_state.nlp_candidate
        st.markdown(
            f"""
            <div class="editorial-card" style="margin-top: 1rem;">
                <div style="font-size: 0.76rem; text-transform: uppercase; letter-spacing: 0.06em; color: #85847B; font-weight: 600;">Detected Details</div>
                <div style="font-size: 0.86rem; color: #C5C4BA; margin-top: 4px;">
                    Review the extracted fields before saving to transactions.
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

        with st.form("confirm_ai_expense_form"):
            rf_col1, rf_col2 = st.columns(2)
            with rf_col1:
                conf_amount = st.number_input(
                    f"Amount ({currency_symbol}) *",
                    min_value=0.01,
                    value=float(cand["amount"]) if cand["amount"] > 0 else 50.0,
                    step=10.0,
                    format="%.2f",
                )
                conf_store = st.text_input("Merchant / Store", value=cand["store"])
                conf_tag = st.text_input("Category", value=cand["tag"])
            with rf_col2:
                conf_desc = st.text_input("Description", value=cand["description"])
                cur_pm_idx = PAYMENT_METHODS.index(cand["payment_method"]) if cand["payment_method"] in PAYMENT_METHODS else 0
                conf_pm = st.selectbox("Payment method", options=PAYMENT_METHODS, index=cur_pm_idx)
                conf_date = st.date_input("Date", value=date.today())

            if st.form_submit_button("Confirm transaction", type="primary", use_container_width=True):
                try:
                    st_obj = get_or_create_store(conf_store.strip()) if conf_store.strip() else None
                    tg_obj = get_or_create_tag(conf_tag.strip()) if conf_tag.strip() else None
                    create_expense(
                        amount=conf_amount,
                        date=conf_date,
                        description=conf_desc,
                        store_id=st_obj.id if st_obj else None,
                        tag_id=tg_obj.id if tg_obj else None,
                        payment_method=conf_pm,
                    )
                    st.session_state.nlp_candidate = None
                    st.success(f"Recorded {currency_symbol}{conf_amount:,.2f} at {conf_store} [{conf_tag}].")
                    st.rerun()
                except Exception as ex:
                    st.error(f"Error saving expense: {ex}")
