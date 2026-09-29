"""
Transaction Import UI component (Phase 16 - Redesigned Editorial).
Provides an auditable staging interface for SMS debit notifications,
UPI alerts, and CSV bank statements with 1-click review and approval.
"""

from datetime import date
from decimal import Decimal
import streamlit as st

from services.import_service import (
    approve_imported_transaction,
    batch_approve_all_pending,
    get_pending_imported_transactions,
    parse_and_stage_csv,
    parse_and_stage_sms_batch,
    reject_imported_transaction,
)
from services.tag_service import get_all_tags
from utils.constants import PAYMENT_METHODS


def render_import_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Transaction Importer and Staging Queue view."""
    st.markdown('<div class="section-label">Intake</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Transaction Importer</h1>', unsafe_allow_html=True)

    pending_items = get_pending_imported_transactions()
    pending_count = len(pending_items)

    tab_sms, tab_csv, tab_queue = st.tabs([
        "SMS & UPI Parser",
        "Bank CSV Import",
        f"Staging Queue ({pending_count})",
    ])

    # ---------------- TAB 1: SMS & UPI ALERT PARSER ----------------
    with tab_sms:
        st.markdown('<div class="section-label">Input</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Banking or UPI Notifications</div>', unsafe_allow_html=True)
        st.caption("Paste single or multiple SMS/UPI transaction alerts (one per line).")

        default_sample = (
            "Paid ₹250 to ABC Restaurant using UPI.\n"
            "Debited Rs. 450.00 at Uber by GPay on 29-09-2026 Ref 98765\n"
            "Rs 180.00 spent on your card at Starbucks on 28-09-2026"
        )

        col_sample1, col_sample2 = st.columns([4, 1])
        with col_sample2:
            if st.button("Load Examples", use_container_width=True):
                st.session_state.sms_input_area = default_sample

        sms_text = st.text_area(
            "Transaction Text",
            value=st.session_state.get("sms_input_area", ""),
            height=130,
            placeholder="Paste text like: 'Paid ₹250 to ABC Restaurant using UPI.'",
            key="sms_text_area",
        )

        if st.button("Parse & Stage to Queue", type="primary", use_container_width=True, key="btn_stage_sms"):
            if sms_text.strip():
                lines = [l for l in sms_text.strip().splitlines() if l.strip()]
                staged = parse_and_stage_sms_batch(lines)
                st.success(f"Parsed and staged {len(staged)} candidate item(s).")
                st.rerun()
            else:
                st.warning("Please paste at least one transaction message.")

    # ---------------- TAB 2: BANK CSV IMPORT ----------------
    with tab_csv:
        st.markdown('<div class="section-label">File Upload</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Bank Statement CSV</div>', unsafe_allow_html=True)
        st.caption("Upload a standard CSV bank statement or paste CSV text below.")

        sample_csv = "Date,Particulars,Debit,Credit\n2026-09-26,College Canteen,80.00,0.00\n2026-09-27,Metro Rail Recharge,200.00,0.00"

        uploaded_file = st.file_uploader("Upload CSV Statement", type=["csv"])
        csv_text_input = st.text_area("Or Paste CSV Text Directly", height=100, placeholder=sample_csv)

        if st.button("Parse & Stage CSV", type="primary", use_container_width=True, key="btn_stage_csv"):
            content = ""
            if uploaded_file is not None:
                content = uploaded_file.read().decode("utf-8", errors="ignore")
            elif csv_text_input.strip():
                content = csv_text_input.strip()

            if content:
                staged = parse_and_stage_csv(content)
                if staged:
                    st.success(f"Parsed and staged {len(staged)} transactions from CSV.")
                    st.rerun()
                else:
                    st.error("No valid debit transactions could be parsed from the provided CSV content.")
            else:
                st.warning("Please upload a CSV file or paste CSV text.")

    # ---------------- TAB 3: STAGING REVIEW QUEUE ----------------
    with tab_queue:
        st.markdown('<div class="section-label">Review</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Staged Candidates</div>', unsafe_allow_html=True)
        st.caption("Review extracted amounts, detected merchants, and category suggestions before confirmation.")

        if not pending_items:
            st.markdown(
                """
                <div class="empty-state">
                    <div class="empty-state-title">Staging queue is empty</div>
                    <div class="empty-state-desc">Use the SMS parser or CSV import tabs above to stage incoming transactions.</div>
                </div>
                """,
                unsafe_allow_html=True,
            )
            return

        col_q1, col_q2 = st.columns([3, 1])
        with col_q1:
            st.markdown(f"<div style='font-size: 0.85rem; color: #8C8B82; padding-top: 8px;'><b>{pending_count} item(s)</b> awaiting confirmation</div>", unsafe_allow_html=True)
        with col_q2:
            if st.button("Approve High Confidence (≥85%)", type="primary", use_container_width=True, key="btn_batch_approve"):
                count = batch_approve_all_pending(min_confidence=0.85)
                st.success(f"Approved {count} high-confidence transaction(s).")
                st.rerun()

        all_tags = get_all_tags()
        tag_names = [t.name for t in all_tags]

        for item in pending_items:
            amt_display = f"{currency_symbol}{item.detected_amount:,.2f}" if item.detected_amount else "Unspecified"
            merchant_display = item.detected_merchant or "Unspecified Merchant"
            conf_pct = int(item.confidence * 100)
            tag_display = item.predicted_tag_name or "Misc"

            with st.container():
                st.markdown(
                    f"""
                    <div class="editorial-card" style="margin-bottom: 6px; padding: 1rem 1.25rem;">
                        <div style="display: flex; justify-content: space-between; align-items: baseline;">
                            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">
                                    {merchant_display}
                                </span>
                                <span class="subtle-tag">{tag_display}</span>
                                <span class="subtle-tag" style="color: #8C8B82;">{item.source_type}</span>
                            </div>
                            <div style="text-align: right;">
                                <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.15rem; font-weight: 600; color: #EDEDE8;">
                                    {amt_display}
                                </div>
                                <div style="font-size: 0.72rem; color: #8C8B82;">
                                    {conf_pct}% confidence
                                </div>
                            </div>
                        </div>
                        <div style="font-size: 0.78rem; color: #8C8B82; margin-top: 6px; font-family: 'IBM Plex Mono', monospace;">
                            "{item.raw_text}"
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )

                b_col1, b_col2, b_col3 = st.columns([2, 1, 1])
                with b_col1:
                    with st.popover("Edit details", use_container_width=True):
                        st.markdown("**Adjust Extracted Fields**")
                        edit_amt = st.number_input(
                            f"Amount ({currency_symbol})",
                            min_value=0.01,
                            value=float(item.detected_amount) if item.detected_amount else 100.0,
                            key=f"edit_amt_{item.id}",
                        )
                        edit_merch = st.text_input("Merchant", value=merchant_display, key=f"edit_merch_{item.id}")
                        t_idx = tag_names.index(tag_display) if tag_display in tag_names else 0
                        edit_tag = st.selectbox("Category", options=tag_names, index=t_idx, key=f"edit_tag_{item.id}")
                        edit_pm = st.selectbox("Payment Method", options=PAYMENT_METHODS, key=f"edit_pm_{item.id}")

                        if st.button("Confirm Edited Entry", type="primary", use_container_width=True, key=f"btn_save_edit_{item.id}"):
                            approve_imported_transaction(
                                item.id,
                                overrides={
                                    "amount": Decimal(str(edit_amt)),
                                    "store_name": edit_merch.strip(),
                                    "tag_name": edit_tag,
                                    "payment_method": edit_pm,
                                },
                            )
                            st.rerun()

                with b_col2:
                    if st.button("Import", key=f"btn_appr_{item.id}", use_container_width=True, type="primary"):
                        approve_imported_transaction(item.id)
                        st.rerun()

                with b_col3:
                    if st.button("Reject", key=f"btn_rej_{item.id}", use_container_width=True):
                        reject_imported_transaction(item.id)
                        st.rerun()

                st.markdown("<div style='margin-bottom: 6px;'></div>", unsafe_allow_html=True)
