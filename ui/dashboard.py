"""
Dashboard UI component (Redesigned - Editorial & Minimal).
Provides a clean, thoughtful financial overview:
- Current month financial summary
- 3 key statistic blocks
- Minimalist spending over time line chart
- Horizontal category breakdown
- Clean recent transactions list
"""

from datetime import date
from decimal import Decimal
import streamlit as st
import plotly.graph_objects as go

from services.budget_service import get_budget_progress
from services.dashboard_service import (
    get_category_breakdown,
    get_daily_spending_trend,
    get_dashboard_summary,
)
from services.expense_service import get_recent_expenses
from services.prediction_service import predict_upcoming_expenses
from services.recurring_service import get_due_recurring_expenses


# Restrained, editorial palette for charts
MUTED_PALETTE = [
    "#3E6B56",  # Forest sage
    "#557564",  # Muted olive
    "#6F8A79",  # Soft eucalyptus
    "#859C8D",  # Pale sage
    "#4B5C52",  # Deep charcoal green
    "#73857B",  # Slate sage
    "#34473C",  # Dark pine
    "#97A89F",  # Chalk sage
]
CATEGORY_PALETTE = MUTED_PALETTE



def render_dashboard(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial spending dashboard."""
    today = date.today()
    month_name = today.strftime("%B %Y")

    # Header: Month and Editorial Title
    st.markdown(f'<div class="section-label">{month_name}</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Spending Overview</h1>', unsafe_allow_html=True)

    summary = get_dashboard_summary()

    # Recurring Expenses Alert (understated notice block, no emojis)
    due_recurring = get_due_recurring_expenses()
    if due_recurring:
        rec_count = len(due_recurring)
        r_col1, r_col2 = st.columns([4, 1])
        with r_col1:
            st.markdown(
                f"""
                <div class="notice-block">
                    <b>{rec_count} recurring schedule{'s' if rec_count > 1 else ''} due today.</b> 
                    Review details before recording into transactions.
                </div>
                """,
                unsafe_allow_html=True,
            )
        with r_col2:
            if st.button("Review due", use_container_width=True, key="dash_view_rec"):
                st.session_state.app_nav = "Recurring"
                st.rerun()

    # 3 Clean Statistic Blocks
    c1, c2, c3 = st.columns(3)
    with c1:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">This month</div>
                <div class="stat-value">{currency_symbol}{summary['this_month_total']:,.2f}</div>
                <div class="stat-subtext">{summary['this_month_count']} transactions</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    with c2:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Daily average</div>
                <div class="stat-value">{currency_symbol}{summary['daily_avg']:,.2f}</div>
                <div class="stat-subtext">Over {summary['days_elapsed']} days elapsed</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    with c3:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Today's spend</div>
                <div class="stat-value">{currency_symbol}{summary['today_total']:,.2f}</div>
                <div class="stat-subtext">{summary['today_count']} purchases today</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    # Active Monthly Budget Progress if configured
    b_progress = get_budget_progress()
    overall_b = b_progress.get("overall")
    if overall_b:
        b_pct = overall_b["percentage_used"]
        bar_color = "#3E6B56" if b_pct <= 80 else ("#A87A42" if b_pct <= 100 else "#A34D43")
        st.markdown(
            f"""
            <div style="background: #141613; border: 1px solid #232521; border-radius: 8px; padding: 1rem 1.25rem; margin-top: 1rem;">
                <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 6px;">
                    <span style="font-size: 0.84rem; color: #C5C4BA; font-weight: 500;">Monthly target: {currency_symbol}{overall_b['budget_amount']:,.2f}</span>
                    <span style="font-family: 'IBM Plex Mono', monospace; font-size: 0.88rem; font-weight: 600; color: #EDEDE8;">{b_pct:.1f}% used</span>
                </div>
                <div style="background: #1F221E; border-radius: 4px; height: 6px; overflow: hidden; margin-bottom: 6px;">
                    <div style="background: {bar_color}; width: {min(100.0, b_pct)}%; height: 100%;"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 0.76rem; color: #85847B;">
                    <span>{overall_b['status_message']}</span>
                    <span>Remaining: {currency_symbol}{overall_b['remaining_amount']:,.2f}</span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<hr>", unsafe_allow_html=True)

    # Visualizations Grid: Spending Trend + Category Breakdown
    trend_data = get_daily_spending_trend(days=30)
    category_data = get_category_breakdown(days=30)

    col_trend, col_cat = st.columns([3, 2])

    with col_trend:
        st.markdown('<div class="section-title">Spending over time</div>', unsafe_allow_html=True)
        dates = [d["display_date"] for d in trend_data]
        amounts = [d["amount"] for d in trend_data]

        fig_trend = go.Figure()
        # Clean line with subtle filled area
        fig_trend.add_trace(
            go.Scatter(
                x=dates,
                y=amounts,
                mode="lines",
                line=dict(color="#4A7A60", width=2),
                fill="tozeroy",
                fillcolor="rgba(62, 107, 86, 0.08)",
                hovertemplate="<b>%{x}</b><br>Spent: " + currency_symbol + "%{y:,.2f}<extra></extra>",
            )
        )

        fig_trend.update_layout(
            template="plotly_dark",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(family="Inter", color="#85847B", size=11),
            margin=dict(l=10, r=10, t=10, b=10),
            height=280,
            xaxis=dict(
                showgrid=False,
                tickangle=-45,
                tickfont=dict(size=10, family="IBM Plex Mono"),
                linecolor="#232521",
            ),
            yaxis=dict(
                showgrid=True,
                gridcolor="#1D201A",
                tickprefix=currency_symbol,
                tickfont=dict(size=10, family="IBM Plex Mono"),
                linecolor="#232521",
            ),
            showlegend=False,
        )
        st.plotly_chart(fig_trend, use_container_width=True)

    with col_cat:
        st.markdown('<div class="section-title">By category</div>', unsafe_allow_html=True)
        if not category_data:
            st.caption("No categorized expenses recorded yet.")
        else:
            cat_names = [c["category"] for c in reversed(category_data[:6])]
            cat_values = [c["amount"] for c in reversed(category_data[:6])]

            # Clean horizontal bar chart
            fig_bar = go.Figure(
                go.Bar(
                    x=cat_values,
                    y=cat_names,
                    orientation="h",
                    marker=dict(
                        color="#3E6B56",
                        line=dict(color="#4A7A60", width=1),
                    ),
                    hovertemplate="<b>%{y}</b><br>Total: " + currency_symbol + "%{x:,.2f}<extra></extra>",
                )
            )

            fig_bar.update_layout(
                template="plotly_dark",
                paper_bgcolor="rgba(0,0,0,0)",
                plot_bgcolor="rgba(0,0,0,0)",
                font=dict(family="Inter", color="#85847B", size=11),
                margin=dict(l=10, r=10, t=10, b=10),
                height=280,
                xaxis=dict(
                    showgrid=True,
                    gridcolor="#1D201A",
                    tickprefix=currency_symbol,
                    tickfont=dict(size=10, family="IBM Plex Mono"),
                ),
                yaxis=dict(
                    showgrid=False,
                    tickfont=dict(size=11),
                ),
                showlegend=False,
            )
            st.plotly_chart(fig_bar, use_container_width=True)

    st.markdown("<hr>", unsafe_allow_html=True)

    # Bottom Section: Recent Transactions Table & Quick Actions
    col_recent, col_action = st.columns([3, 2])

    with col_recent:
        st.markdown('<div class="section-title">Recent transactions</div>', unsafe_allow_html=True)
        recent = get_recent_expenses(limit=6)
        if not recent:
            st.caption("No transactions logged yet.")
        else:
            for exp in recent:
                store_title = exp.store.name if exp.store else "Unspecified"
                tag_title = exp.tag.name if exp.tag else "Uncategorized"
                date_text = exp.date.strftime("%d %b")

                st.markdown(
                    f"""
                    <div class="data-row">
                        <div>
                            <div class="data-row-store">{store_title}</div>
                            <div class="data-row-category">{tag_title} • {exp.description or exp.payment_method}</div>
                        </div>
                        <div>
                            <div class="data-row-amount">{currency_symbol}{exp.amount:,.2f}</div>
                            <div class="data-row-date">{date_text}</div>
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )

    with col_action:
        st.markdown('<div class="section-title">Actions & Outlook</div>', unsafe_allow_html=True)

        # Subtle anticipated outflow note if available
        upcoming_preds = predict_upcoming_expenses(days_ahead=3)
        if upcoming_preds:
            first_up = upcoming_preds[0]
            st.markdown(
                f"""
                <div style="background: #141613; border: 1px solid #232521; border-radius: 6px; padding: 0.85rem 1rem; margin-bottom: 1rem;">
                    <div style="font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.06em; color: #7A7970; font-weight: 600;">Anticipated Outflow</div>
                    <div style="font-size: 0.95rem; font-weight: 500; color: #EDEDE8; margin-top: 2px;">
                        {first_up['title']} <span style="font-family: 'IBM Plex Mono', monospace; color: #A3C9B3;">(~{currency_symbol}{first_up['predicted_amount']:,.2f})</span>
                    </div>
                    <div style="font-size: 0.76rem; color: #85847B; margin-top: 2px;">
                        {first_up['expected_timing']}
                    </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

        btn_c1, btn_c2 = st.columns(2)
        with btn_c1:
            if st.button("Add expense", use_container_width=True, type="primary"):
                st.session_state.app_nav = "Add Expense"
                st.rerun()
        with btn_c2:
            if st.button("All transactions", use_container_width=True):
                st.session_state.app_nav = "Transactions"
                st.rerun()

        st.markdown("<div style='margin-bottom: 0.5rem;'></div>", unsafe_allow_html=True)
        btn_c3, btn_c4 = st.columns(2)
        with btn_c3:
            if st.button("Budgets", use_container_width=True):
                st.session_state.app_nav = "Budgets"
                st.rerun()
        with btn_c4:
            if st.button("Forecast", use_container_width=True):
                st.session_state.app_nav = "Forecast & Predictions"
                st.rerun()
