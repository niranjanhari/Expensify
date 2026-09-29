"""
Expense Predictions & Run-Rate Forecast UI component (Phase 14 - Redesigned Editorial).
Provides statistical visibility into upcoming transactions, merchant cadences,
and weighted month-end projections without ever inserting data unprompted.
"""

from datetime import date
from decimal import Decimal
import streamlit as st

from services.expense_service import create_expense
from services.prediction_service import (
    predict_monthly_run_rate,
    predict_upcoming_expenses,
)


def render_predictions_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Predictions and Run-Rate Forecast view."""
    st.markdown('<div class="section-label">Projections</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Forecast & Run-Rate</h1>', unsafe_allow_html=True)

    st.markdown(
        """
        <div class="notice-block">
            <b>Statistical Planning Model:</b> Projections are hypotheses derived from recurring schedules 
            and merchant rhythms. Transactions are never logged automatically without your explicit confirmation.
        </div>
        """,
        unsafe_allow_html=True,
    )

    tab_upcoming, tab_runrate = st.tabs([
        "Expected Outflows",
        "Month-End Projection",
    ])

    # ---------------- TAB 1: UPCOMING EXPECTED OUTFLOWS ----------------
    with tab_upcoming:
        col_ctrl1, col_ctrl2 = st.columns([3, 1])
        with col_ctrl1:
            st.markdown('<div class="section-label">Anticipated</div>', unsafe_allow_html=True)
            st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Upcoming Expected Expenses</div>', unsafe_allow_html=True)
            st.caption("Transactions expected based on recurring subscriptions and cadence intervals.")
        with col_ctrl2:
            window_days = st.selectbox(
                "Horizon",
                options=[3, 7, 14],
                index=1,
                format_func=lambda x: f"Next {x} Days",
                key="pred_window_select",
            )

        predictions = predict_upcoming_expenses(days_ahead=window_days)

        if not predictions:
            st.markdown(
                f"""
                <div class="empty-state">
                    <div class="empty-state-title">No upcoming outflows detected</div>
                    <div class="empty-state-desc">No predicted transactions within the next {window_days} days based on your historical rhythms.</div>
                </div>
                """,
                unsafe_allow_html=True,
            )
        else:
            cols = st.columns(2)
            for idx, p in enumerate(predictions):
                col = cols[idx % 2]
                conf_pct = int(p["confidence"] * 100)

                with col:
                    st.markdown(
                        f"""
                        <div class="editorial-card" style="padding: 1.15rem 1.3rem;">
                            <div style="display: flex; justify-content: space-between; align-items: baseline;">
                                <div>
                                    <div style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">
                                        {p['title']}
                                    </div>
                                    <div style="margin-top: 4px; display: flex; gap: 6px; flex-wrap: wrap;">
                                        <span class="subtle-tag">{p['source']}</span>
                                        <span class="subtle-tag">{p['tag_name']}</span>
                                    </div>
                                </div>
                                <div style="text-align: right;">
                                    <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.15rem; font-weight: 600; color: #EDEDE8;">
                                        ~{currency_symbol}{p['predicted_amount']:,.2f}
                                    </div>
                                    <div style="font-size: 0.72rem; color: #8C8B82;">
                                        {conf_pct}% confidence
                                    </div>
                                </div>
                            </div>
                            <div style="margin: 10px 0 6px 0; font-size: 0.8rem; color: #8C8B82;">
                                Timing: <b style="color: #EDEDE8;">{p['expected_timing']}</b>
                            </div>
                            <div style="font-size: 0.78rem; color: #8C8B82; border-top: 1px solid #232521; padding-top: 6px;">
                                {p['reason']}
                            </div>
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )

                    btn_key = f"log_pred_{idx}_{p['store_id']}_{p['predicted_amount']}"
                    if st.button(
                        f"Log this ({currency_symbol}{p['predicted_amount']:,.2f})",
                        key=btn_key,
                        use_container_width=True,
                    ):
                        create_expense(
                            amount=p["predicted_amount"],
                            date=date.today(),
                            description=f"Auto-logged from forecast: {p['title']}",
                            store_id=p["store_id"],
                            tag_id=p["tag_id"],
                            payment_method=p["payment_method"],
                        )
                        st.rerun()

    # ---------------- TAB 2: MONTH-END RUN-RATE PROJECTION ----------------
    with tab_runrate:
        st.markdown('<div class="section-label">Burn-Rate Model</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.5rem;">Month-End Run-Rate Trajectory</div>', unsafe_allow_html=True)
        st.caption("Calculated using a weighted moving average of recent spending velocity.")

        forecast = predict_monthly_run_rate()

        m1, m2, m3, m4 = st.columns(4)
        with m1:
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Month-to-Date Spend</div>
                    <div class="stat-number">{currency_symbol}{forecast['mtd_spent']:,.2f}</div>
                    <div class="stat-subtext">{forecast['days_elapsed']} of {forecast['days_in_month']} days elapsed</div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with m2:
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Weighted Burn Rate</div>
                    <div class="stat-number">{currency_symbol}{forecast['current_daily_burn']:,.2f}</div>
                    <div class="stat-subtext">Per day run-rate</div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with m3:
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Projected Month-End</div>
                    <div class="stat-number">{currency_symbol}{forecast['projected_month_end']:,.2f}</div>
                    <div class="stat-subtext">Range: {currency_symbol}{forecast['range_low']:,.0f} – {currency_symbol}{forecast['range_high']:,.0f}</div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with m4:
            tgt_text = (
                f"{currency_symbol}{forecast['budget_target']:,.2f}"
                if forecast['budget_target']
                else "No target set"
            )
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Monthly Target</div>
                    <div class="stat-number" style="font-size: 1.25rem;">{tgt_text}</div>
                    <div class="stat-subtext" style="color: #3E6B56; font-weight: 500;">
                        {forecast['pacing_status']}
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)

        # Visual Trajectory Breakdown Card
        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1.3rem 1.5rem;">
                <div style="font-weight: 600; color: #EDEDE8; font-size: 1rem; margin-bottom: 6px;">
                    Pacing Assessment
                </div>
                <p style="font-size: 0.88rem; color: #8C8B82; line-height: 1.6; margin-bottom: 12px;">
                    With <b>{forecast['days_remaining']} days remaining</b> in this month, maintaining your current daily burn rate of 
                    <span style="font-family: 'IBM Plex Mono', monospace; color: #EDEDE8;">{currency_symbol}{forecast['current_daily_burn']:,.2f}/day</span> will conclude the month around 
                    <span style="font-family: 'IBM Plex Mono', monospace; font-weight: 600; color: #EDEDE8;">{currency_symbol}{forecast['projected_month_end']:,.2f}</span>.
                </p>
                <div style="background: rgba(255, 255, 255, 0.05); border-radius: 4px; height: 6px; overflow: hidden; margin-bottom: 10px;">
                    <div style="background: #3E6B56; width: {min(100.0, float(forecast['days_elapsed'] / forecast['days_in_month'] * 100.0))}%; height: 100%; border-radius: 4px;"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 0.78rem; color: #8C8B82;">
                    <span>Month Elapsed: {forecast['days_elapsed']} days</span>
                    <span>Status: <b style="color: #EDEDE8;">{forecast['pacing_status']}</b></span>
                    <span>Remaining: {forecast['days_remaining']} days</span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )
