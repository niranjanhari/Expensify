"""
Dashboard UI component (Mobile-First & Editorial).
Hierarchy:
1. Current Bank Balance (prominently displayed, persistent, real-time)
2. Compact Spending Summary (Today & This Month)
3. Touch-friendly Quick Actions (fully working navigation)
4. Recent Transactions (touch-optimized list + link to ledger)
5. Category Breakdown & Spending Visualizations
"""

from __future__ import annotations

from datetime import date
from decimal import Decimal
import plotly.graph_objects as go
import streamlit as st

from services.balance_service import get_balance_details, update_account_balance
from services.budget_service import get_budget_progress
from services.dashboard_service import (
    get_category_breakdown,
    get_daily_spending_trend,
    get_dashboard_summary,
)
from services.expense_service import get_recent_expenses
from services.prediction_service import predict_upcoming_expenses
from services.recurring_service import get_due_recurring_expenses
from utils.navigation import navigate_to

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
    """Render the mobile-first, editorial spending dashboard."""
    today = date.today()
    month_name = today.strftime("%B %Y")

    # Header: Month and Editorial Title
    st.markdown(f'<div class="section-label">{month_name}</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Spending Overview</h1>', unsafe_allow_html=True)

    summary = get_dashboard_summary()

    # ---------------- 1. CURRENT BANK BALANCE ----------------
    bal_info = get_balance_details()

    if bal_info["is_configured"]:
        curr_bal = bal_info["current_balance"]
        base_amt = bal_info["baseline_amount"]
        spent_since = bal_info["expenses_since_baseline"]
        subtext_str = (
            f"Baseline: <b>{currency_symbol}{base_amt:,.2f}</b> • "
            f"<b>{currency_symbol}{spent_since:,.2f}</b> logged since baseline"
        )
        bal_display = f"{currency_symbol}{curr_bal:,.2f}"
    else:
        bal_display = "Not Set"
        subtext_str = "Establish your bank balance to track live funds and deductions."

    st.markdown(
        f"""
        <div class="balance-hero-card">
            <div class="balance-hero-label">Current Balance</div>
            <div class="balance-hero-amount">{bal_display}</div>
            <div class="balance-hero-subtext">{subtext_str}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    # Quick balance adjust popover right on the card line
    popover_label = "Update balance" if bal_info["is_configured"] else "Set initial balance"
    with st.popover(popover_label, use_container_width=True):
        st.markdown("**Update Bank Account Balance**")
        st.caption(
            "Enter your actual bank balance. New expenses will automatically deduct from this baseline."
        )
        init_val = float(bal_info["current_balance"]) if bal_info["is_configured"] else 10000.0
        new_bal_input = st.number_input(
            f"Current Balance ({currency_symbol})",
            min_value=0.0,
            max_value=100000000.0,
            value=init_val,
            step=500.0,
            format="%.2f",
            key="dash_quick_bal_input",
        )
        note_input = st.text_input(
            "Note (optional)",
            value=bal_info["notes"] or "",
            placeholder="e.g. Primary Bank Account",
            key="dash_quick_bal_note",
        )
        if st.button("Save Balance", type="primary", use_container_width=True, key="dash_save_bal_btn"):
            update_account_balance(Decimal(str(new_bal_input)), notes=note_input)
            st.success("Balance updated successfully.")
            st.rerun()

    # ---------------- 2. COMPACT SPENDING SUMMARY ----------------
    col_today, col_month = st.columns(2)
    with col_today:
        st.markdown(
            f"""
            <div class="compact-stat-card">
                <div class="compact-stat-label">Today</div>
                <div class="compact-stat-value">{currency_symbol}{summary['today_total']:,.2f}</div>
                <div class="compact-stat-subtext">{summary['today_count']} transaction{'s' if summary['today_count'] != 1 else ''}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    with col_month:
        st.markdown(
            f"""
            <div class="compact-stat-card">
                <div class="compact-stat-label">This Month</div>
                <div class="compact-stat-value">{currency_symbol}{summary['this_month_total']:,.2f}</div>
                <div class="compact-stat-subtext">{summary['this_month_count']} tx • {currency_symbol}{summary['daily_avg']:,.2f}/day</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    # Active Monthly Budget Target Progress if configured
    b_progress = get_budget_progress()
    overall_b = b_progress.get("overall")
    if overall_b:
        b_pct = overall_b["percentage_used"]
        bar_color = "#3E6B56" if b_pct <= 80 else ("#A87A42" if b_pct <= 100 else "#A34D43")
        st.markdown(
            f"""
            <div style="background: #141713; border: 1px solid #22261F; border-radius: 8px; padding: 0.85rem 1.1rem; margin-top: 0.6rem;">
                <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 5px;">
                    <span style="font-size: 0.82rem; color: #C5C4BA; font-weight: 500;">Monthly target: {currency_symbol}{overall_b['budget_amount']:,.2f}</span>
                    <span style="font-family: 'IBM Plex Mono', monospace; font-size: 0.85rem; font-weight: 600; color: #EDEDE8;">{b_pct:.1f}% used</span>
                </div>
                <div style="background: #1F221E; border-radius: 4px; height: 5px; overflow: hidden; margin-bottom: 5px;">
                    <div style="background: {bar_color}; width: {min(100.0, b_pct)}%; height: 100%;"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 0.75rem; color: #85847B;">
                    <span>{overall_b['status_message']}</span>
                    <span>Remaining: {currency_symbol}{overall_b['remaining_amount']:,.2f}</span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    # Recurring Expenses Alert Notice if any are due today
    due_recurring = get_due_recurring_expenses()
    if due_recurring:
        rec_count = len(due_recurring)
        r_col1, r_col2 = st.columns([3, 1])
        with r_col1:
            st.markdown(
                f"""
                <div class="notice-block" style="margin-top: 0.75rem; margin-bottom: 0;">
                    <b>{rec_count} recurring schedule{'s' if rec_count > 1 else ''} due today.</b>
                </div>
                """,
                unsafe_allow_html=True,
            )
        with r_col2:
            if st.button("Review", use_container_width=True, key="dash_view_rec"):
                navigate_to("Recurring")

    # ---------------- 3. QUICK ACTIONS (MOBILE-FIRST) ----------------
    st.markdown('<div class="section-title">Quick Actions</div>', unsafe_allow_html=True)

    # Primary prominent button
    if st.button("+ Add Expense", type="primary", use_container_width=True, key="qa_btn_add_expense"):
        navigate_to("Add Expense")

    # Secondary action grid
    col_qa1, col_qa2 = st.columns(2)
    with col_qa1:
        if st.button("Quick Add", use_container_width=True, key="qa_btn_quick_add"):
            navigate_to("Quick Add")
        if st.button("Analytics", use_container_width=True, key="qa_btn_analytics"):
            navigate_to("Analytics")

    with col_qa2:
        if st.button("Transactions", use_container_width=True, key="qa_btn_transactions"):
            navigate_to("Transactions")
        if st.button("Budgets", use_container_width=True, key="qa_btn_budgets"):
            navigate_to("Budgets")

    # ---------------- 4. RECENT TRANSACTIONS ----------------
    st.markdown('<div class="section-title">Recent Transactions</div>', unsafe_allow_html=True)
    recent = get_recent_expenses(limit=5)
    if not recent:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No transactions recorded yet</div>
                <div class="empty-state-desc">Use Quick Actions above to record your first expense.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
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

        if st.button("View all transactions →", use_container_width=True, key="dash_view_all_tx"):
            navigate_to("Transactions")

    # ---------------- 5. SPENDING BY CATEGORY & VISUALIZATIONS ----------------
    st.markdown("<hr>", unsafe_allow_html=True)
    st.markdown('<div class="section-title">Spending Breakdown</div>', unsafe_allow_html=True)

    category_data = get_category_breakdown(days=30)
    trend_data = get_daily_spending_trend(days=30)

    # Anticipated outflow note if available
    upcoming_preds = predict_upcoming_expenses(days_ahead=3)
    if upcoming_preds:
        first_up = upcoming_preds[0]
        st.markdown(
            f"""
            <div style="background: #141713; border: 1px solid #232720; border-radius: 6px; padding: 0.85rem 1rem; margin-bottom: 1rem;">
                <div style="font-size: 0.70rem; text-transform: uppercase; letter-spacing: 0.06em; color: #7A7970; font-weight: 600;">Anticipated Outflow</div>
                <div style="font-size: 0.92rem; font-weight: 500; color: #EDEDE8; margin-top: 2px;">
                    {first_up['title']} <span style="font-family: 'IBM Plex Mono', monospace; color: #A3C9B3;">(~{currency_symbol}{first_up['predicted_amount']:,.2f})</span>
                </div>
                <div style="font-size: 0.75rem; color: #85847B; margin-top: 2px;">
                    {first_up['expected_timing']}
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    # Category breakdown horizontal bar chart
    if not category_data:
        st.caption("No categorized expenses recorded in the last 30 days.")
    else:
        cat_names = [c["category"] for c in reversed(category_data[:6])]
        cat_values = [c["amount"] for c in reversed(category_data[:6])]

        fig_bar = go.Figure(
            go.Bar(
                x=cat_values,
                y=cat_names,
                orientation="h",
                marker=dict(
                    color="#315843",
                    line=dict(color="#3E6B56", width=1),
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
            height=220,
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

    # Spending trend line chart
    if any(d["amount"] > 0 for d in trend_data):
        st.markdown('<div class="section-label" style="margin-top: 1rem;">Daily Spending Trend</div>', unsafe_allow_html=True)
        dates = [d["display_date"] for d in trend_data]
        amounts = [d["amount"] for d in trend_data]

        fig_trend = go.Figure()
        fig_trend.add_trace(
            go.Scatter(
                x=dates,
                y=amounts,
                mode="lines",
                line=dict(color="#4A7A60", width=2),
                fill="tozeroy",
                fillcolor="rgba(49, 88, 67, 0.12)",
                hovertemplate="<b>%{x}</b><br>Spent: " + currency_symbol + "%{y:,.2f}<extra></extra>",
            )
        )
        fig_trend.update_layout(
            template="plotly_dark",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(family="Inter", color="#85847B", size=11),
            margin=dict(l=10, r=10, t=10, b=10),
            height=220,
            xaxis=dict(
                showgrid=False,
                tickangle=-45,
                tickfont=dict(size=9, family="IBM Plex Mono"),
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
