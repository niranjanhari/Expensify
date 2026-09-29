"""
AI Spending Advisor & Weekly Digest UI component (Phase 13 - Redesigned Editorial).
Presents calm, non-judgmental financial analysis, week-over-week trends,
and structured analytical inquiries without chatbot gimmicks.
"""

from decimal import Decimal
import streamlit as st

from services.advisor_service import (
    ask_advisor_ai,
    get_spending_observations,
    get_weekly_digest,
)


def render_advisor_view(currency_symbol: str = "₹") -> None:
    """Render the calm, editorial Financial Analysis & Advisor report."""
    st.markdown('<div class="section-label">Intelligence</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Spending Notes & Advisor</h1>', unsafe_allow_html=True)

    tab_digest, tab_observations, tab_inquiries = st.tabs([
        "Spending Notes",
        "Weekly Cadence",
        "Financial Inquiries",
    ])

    # ---------------- TAB 1: SPENDING NOTES (SMART OBSERVATIONS) ----------------
    with tab_digest:
        st.markdown('<div class="section-label">Observed Patterns</div>', unsafe_allow_html=True)
        st.caption("Heuristic and contextual observations derived from your recent transaction history.")

        observations = get_spending_observations()
        if not observations:
            st.markdown(
                """
                <div class="empty-state">
                    <div class="empty-state-title">No spending notes available</div>
                    <div class="empty-state-desc">Log a few more transactions across this month to generate analytical patterns.</div>
                </div>
                """,
                unsafe_allow_html=True,
            )
        else:
            for obs in observations:
                st.markdown(
                    f"""
                    <div class="editorial-card" style="margin-bottom: 0.75rem; padding: 1.1rem 1.3rem;">
                        <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 6px;">
                            <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{obs['title']}</span>
                            <span class="subtle-tag">{obs['badge']}</span>
                        </div>
                        <p style="font-size: 0.88rem; color: #CBD5E1; margin: 4px 0 10px 0; line-height: 1.55;">
                            {obs['message']}
                        </p>
                        <div style="font-size: 0.8rem; color: #8C8B82; border-top: 1px solid #232521; padding-top: 6px;">
                            <span style="font-weight: 500; color: #EDEDE8;">Recommendation:</span> {obs['action_tip']}
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )

    # ---------------- TAB 2: WEEKLY CADENCE (WEEKLY DIGEST) ----------------
    with tab_observations:
        digest = get_weekly_digest()

        # 4 Stat Blocks
        c1, c2, c3, c4 = st.columns(4)

        delta_pct = digest["delta_percentage"]
        delta_sign = "+" if digest["delta_amount"] > 0 else ""
        delta_color = "#C25D53" if digest["delta_amount"] > 0 else "#3E6B56"

        with c1:
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Last 7 Days</div>
                    <div class="stat-number">{currency_symbol}{digest['current_total']:,.2f}</div>
                    <div class="stat-subtext" style="color: {delta_color}; font-weight: 500;">
                        {delta_sign}{digest['delta_percentage']:.1f}% vs prior week
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with c2:
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Prior 7 Days</div>
                    <div class="stat-number">{currency_symbol}{digest['prev_total']:,.2f}</div>
                    <div class="stat-subtext">{digest['prev_count']} transactions</div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with c3:
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Daily Average (7D)</div>
                    <div class="stat-number">{currency_symbol}{digest['daily_average']:,.2f}</div>
                    <div class="stat-subtext">Across past week</div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with c4:
            top_cat = digest["top_category"]
            cat_spend = digest["top_category_spend"]
            st.markdown(
                f"""
                <div class="stat-block">
                    <div class="stat-label">Leading Category</div>
                    <div class="stat-number" style="font-size: 1.25rem;">{top_cat}</div>
                    <div class="stat-subtext">{currency_symbol}{cat_spend:,.2f} logged</div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)

        # Weekly Highlights Cards
        h_col1, h_col2 = st.columns(2)

        with h_col1:
            st.markdown('<div class="section-label">Summary</div>', unsafe_allow_html=True)
            st.markdown('<div style="font-weight: 600; font-size: 1rem; color: #EDEDE8; margin-bottom: 0.75rem;">Week Highlights</div>', unsafe_allow_html=True)
            high_exp = digest.get("highest_expense")
            high_desc = (
                f"{high_exp['description'] or high_exp['tag']} ({currency_symbol}{high_exp['amount']:,.2f})"
                if high_exp and high_exp["amount"] > 0
                else "None recorded"
            )
            top_merchant = digest["top_merchant"]
            top_visits = digest["top_merchant_visits"]

            st.markdown(
                f"""
                <div class="editorial-card" style="padding: 1.2rem;">
                    <div style="margin-bottom: 12px;">
                        <div class="stat-label">Highest Single Outflow</div>
                        <div style="font-size: 1.05rem; font-weight: 600; color: #EDEDE8; margin-top: 2px;">{high_desc}</div>
                    </div>
                    <div style="margin-bottom: 12px;">
                        <div class="stat-label">Most Frequented Merchant</div>
                        <div style="font-size: 1.05rem; font-weight: 600; color: #EDEDE8; margin-top: 2px;">
                            {top_merchant} <span style="font-size: 0.8rem; color: #8C8B82; font-weight: 400;">({top_visits} visits)</span>
                        </div>
                    </div>
                    <div>
                        <div class="stat-label">Observation Window</div>
                        <div style="font-size: 0.88rem; color: #8C8B82; margin-top: 2px;">
                            {digest['current_start'].strftime('%d %b')} – {digest['current_end'].strftime('%d %b %Y')}
                        </div>
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with h_col2:
            st.markdown('<div class="section-label">Assessment</div>', unsafe_allow_html=True)
            st.markdown('<div style="font-weight: 600; font-size: 1rem; color: #EDEDE8; margin-bottom: 0.75rem;">Cadence Analysis</div>', unsafe_allow_html=True)
            if digest["delta_amount"] > Decimal("0.00"):
                takeaway_title = "Pacing Slightly Elevated"
                takeaway_body = (
                    f"Outflow expanded by {currency_symbol}{digest['delta_amount']:,.2f} ({delta_pct:.1f}%) "
                    f"relative to the prior week. This is common during bill cycles or scheduled recurring commitments."
                )
            elif digest["delta_amount"] < Decimal("0.00"):
                takeaway_title = "Pacing Moderated"
                takeaway_body = (
                    f"Spending decreased by {currency_symbol}{abs(digest['delta_amount']):,.2f} compared to the previous week. "
                    f"Daily burn rate slowed down cleanly across primary categories."
                )
            else:
                takeaway_title = "Consistent Financial Flow"
                takeaway_body = "Spending remained consistent with minimal variance week-over-week."

            st.markdown(
                f"""
                <div class="editorial-card" style="padding: 1.2rem;">
                    <div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 6px;">
                        {takeaway_title}
                    </div>
                    <div style="font-size: 0.88rem; color: #8C8B82; line-height: 1.6;">
                        {takeaway_body}
                    </div>
                    <div style="margin-top: 14px; font-size: 0.8rem; color: #3E6B56; font-weight: 500;">
                        Consistent weekly tracking yields cleaner predictability than monthly retrospectives.
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

    # ---------------- TAB 3: FINANCIAL INQUIRIES ----------------
    with tab_inquiries:
        st.markdown('<div class="section-label">Consultation</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1rem; color: #EDEDE8; margin-bottom: 0.5rem;">Analytical Inquiries</div>', unsafe_allow_html=True)
        st.caption("Submit queries regarding spending velocity, category breakdowns, or monthly pacing.")

        # Quick Prompt Chips (clean editorial buttons)
        st.markdown("<div style='font-size: 0.8rem; color: #8C8B82; margin-bottom: 4px;'>Suggested Topics:</div>", unsafe_allow_html=True)
        p_c1, p_c2 = st.columns(2)
        with p_c1:
            if st.button("How can I optimize food spending?", use_container_width=True, key="q_food"):
                st.session_state.advisor_prompt = "How can I optimize my food spending?"
            if st.button("Am I on track with monthly budget pacing?", use_container_width=True, key="q_budget"):
                st.session_state.advisor_prompt = "Am I on track with my monthly budget pacing?"
        with p_c2:
            if st.button("Identify 3 potential savings opportunities", use_container_width=True, key="q_savings"):
                st.session_state.advisor_prompt = "Give me 3 gentle savings opportunities based on my habits"
            if st.button("Summarize overall spending pattern", use_container_width=True, key="q_summary"):
                st.session_state.advisor_prompt = "Summarize my overall spending pattern"

        initial_val = st.session_state.get("advisor_prompt", "")
        user_query = st.text_input(
            "Question",
            value=initial_val,
            placeholder="e.g. Which merchant has the highest cumulative spend? How do my recurring expenses look?",
            label_visibility="collapsed",
            key="advisor_query_input",
        )

        if st.button("Generate Analysis", type="primary", use_container_width=True, key="btn_ask_ai"):
            if user_query.strip():
                with st.spinner("Analyzing data..."):
                    reply = ask_advisor_ai(user_query.strip())
                    st.session_state.advisor_reply = reply
                    st.session_state.advisor_last_query = user_query.strip()
            else:
                st.warning("Enter a question or select a suggested topic.")

        if "advisor_reply" in st.session_state and st.session_state.advisor_reply:
            st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)
            st.markdown(
                f"""
                <div class="editorial-card" style="padding: 1.3rem;">
                    <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 12px; border-bottom: 1px solid #232521; padding-bottom: 8px;">
                        <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">
                            Advisor Assessment
                        </span>
                        <span class="subtle-tag">
                            {st.session_state.get('advisor_last_query', 'Query')}
                        </span>
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )
            st.markdown(st.session_state.advisor_reply)
