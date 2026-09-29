"""
Analytics UI component (Phase 8 - Redesigned Editorial).
Provides deep spending pattern analytics, time-series trends,
category and merchant breakdowns, payment distributions, and month-over-month comparisons.
"""

from datetime import date, timedelta
from decimal import Decimal
import streamlit as st
import plotly.graph_objects as go

from services.analytics_service import get_analytics_data
from services.tag_service import get_all_tags
from ui.dashboard import MUTED_PALETTE


def render_analytics_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Analytics dashboard."""
    st.markdown('<div class="section-label">Analysis</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Spending Analytics</h1>', unsafe_allow_html=True)

    # Filter Controls
    all_tags = get_all_tags()
    tag_options = {t.name: t.id for t in all_tags}

    c_filter1, c_filter2 = st.columns([1, 2])
    with c_filter1:
        time_period = st.selectbox(
            "Time Interval",
            options=["Monthly", "Weekly", "Daily", "Custom Date Range"],
            index=0,
        )

    with c_filter2:
        selected_tag_names = st.multiselect(
            "Filter by Categories",
            options=list(tag_options.keys()),
            default=[],
            placeholder="All Categories (click to filter)",
        )
        selected_tag_ids = [tag_options[n] for n in selected_tag_names] if selected_tag_names else None

    start_custom = None
    end_custom = None
    if time_period == "Custom Date Range":
        c_d1, c_d2 = st.columns(2)
        today = date.today()
        with c_d1:
            start_custom = st.date_input("From Date", value=today - timedelta(days=30))
        with c_d2:
            end_custom = st.date_input("To Date", value=today)

    # Fetch Computed Analytics Data
    data = get_analytics_data(
        time_period="Custom" if time_period == "Custom Date Range" else time_period,
        start_date=start_custom,
        end_date=end_custom,
        tag_ids=selected_tag_ids,
    )

    # 1. Top KPI Summary (Stat blocks)
    kpi1, kpi2, kpi3, kpi4 = st.columns(4)
    with kpi1:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Total Outflow</div>
                <div class="stat-number">{currency_symbol}{data['total_spent']:,.2f}</div>
                <div class="stat-subtext">{data['days_analyzed']} days observed</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with kpi2:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Daily Average</div>
                <div class="stat-number">{currency_symbol}{data['avg_daily_spent']:,.2f}</div>
                <div class="stat-subtext">Run-rate per day</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with kpi3:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Average Ticket</div>
                <div class="stat-number">{currency_symbol}{data['avg_transaction_amt']:,.2f}</div>
                <div class="stat-subtext">Across {data['transaction_count']} txs</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with kpi4:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Transactions</div>
                <div class="stat-number">{data['transaction_count']}</div>
                <div class="stat-subtext">Recorded entries</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<div style='margin-top: 1rem;'></div>", unsafe_allow_html=True)

    # Peak Insights Row
    peak1, peak2, peak3 = st.columns(3)
    with peak1:
        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1rem 1.2rem;">
                <div class="stat-label">Highest Spending Day</div>
                <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.2rem; font-weight: 600; color: #EDEDE8; margin: 4px 0;">
                    {currency_symbol}{data['peak_day']['amount']:,.2f}
                </div>
                <div style="font-size: 0.8rem; color: #8C8B82;">{data['peak_day']['date']}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with peak2:
        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1rem 1.2rem;">
                <div class="stat-label">Leading Category</div>
                <div style="font-size: 1.15rem; font-weight: 600; color: #EDEDE8; margin: 4px 0;">
                    {data['peak_category']['name']}
                </div>
                <div style="font-family: 'IBM Plex Mono', monospace; font-size: 0.8rem; color: #8C8B82;">
                    {currency_symbol}{data['peak_category']['amount']:,.2f} total
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with peak3:
        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1rem 1.2rem;">
                <div class="stat-label">Primary Merchant</div>
                <div style="font-size: 1.15rem; font-weight: 600; color: #EDEDE8; margin: 4px 0;">
                    {data['peak_store']['name']}
                </div>
                <div style="font-family: 'IBM Plex Mono', monospace; font-size: 0.8rem; color: #8C8B82;">
                    {currency_symbol}{data['peak_store']['amount']:,.2f} total
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    if data["transaction_count"] == 0:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No transaction data</div>
                <div class="empty-state-desc">No records exist for the selected timeframe and category filter.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
        return

    st.markdown("<div style='margin-top: 2rem;'></div>", unsafe_allow_html=True)

    # Chart 1: Spending Over Time (Clean Line Chart)
    st.markdown(f'<div class="section-label">Trajectory</div>', unsafe_allow_html=True)
    st.markdown(f'<div style="font-weight: 600; font-size: 1.1rem; color: #EDEDE8; margin-bottom: 0.75rem;">Spending Trend ({time_period})</div>', unsafe_allow_html=True)
    ts = data["time_series"]
    labels = [t["label"] for t in ts]
    amounts = [t["amount"] for t in ts]

    fig_time = go.Figure()
    fig_time.add_trace(
        go.Scatter(
            x=labels,
            y=amounts,
            mode="lines+markers",
            line=dict(color="#3E6B56", width=2),
            marker=dict(size=5, color="#3E6B56"),
            fill="tozeroy",
            fillcolor="rgba(62, 107, 86, 0.08)",
            hovertemplate="<b>%{x}</b><br>Spent: " + currency_symbol + "%{y:,.2f}<extra></extra>",
        )
    )
    fig_time.update_layout(
        template="plotly_dark",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(family="Inter, sans-serif", color="#8C8B82", size=11),
        margin=dict(l=10, r=10, t=10, b=10),
        height=280,
        xaxis=dict(showgrid=False, tickfont=dict(size=10, color="#8C8B82")),
        yaxis=dict(showgrid=True, gridcolor="rgba(255, 255, 255, 0.05)", tickprefix=currency_symbol, tickfont=dict(size=10, color="#8C8B82")),
        showlegend=False,
    )
    st.plotly_chart(fig_time, use_container_width=True)

    st.markdown("<div style='margin-top: 2rem;'></div>", unsafe_allow_html=True)

    # Row 2: Category Breakdown (Horizontal Bar) + Merchant Ranking (Horizontal Bar)
    row2_col1, row2_col2 = st.columns(2)

    with row2_col1:
        st.markdown('<div class="section-label">Distribution</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.75rem;">Spending by Category</div>', unsafe_allow_html=True)
        cats = data["spending_by_tag"]
        if cats:
            c_names = [c["category"] for c in reversed(cats)]
            c_amts = [c["amount"] for c in reversed(cats)]
            fig_cat = go.Figure(
                go.Bar(
                    x=c_amts,
                    y=c_names,
                    orientation="h",
                    marker=dict(
                        color="#3E6B56",
                        line=dict(color="#4D7C66", width=1),
                    ),
                    hovertemplate="<b>%{y}</b><br>" + currency_symbol + "%{x:,.2f}<extra></extra>",
                )
            )
            fig_cat.update_layout(
                template="plotly_dark",
                paper_bgcolor="rgba(0,0,0,0)",
                plot_bgcolor="rgba(0,0,0,0)",
                font=dict(family="Inter, sans-serif", color="#8C8B82", size=11),
                margin=dict(l=10, r=10, t=10, b=10),
                height=280,
                xaxis=dict(showgrid=True, gridcolor="rgba(255, 255, 255, 0.05)", tickprefix=currency_symbol, tickfont=dict(size=10, color="#8C8B82")),
                yaxis=dict(showgrid=False, tickfont=dict(size=11, color="#EDEDE8")),
                showlegend=False,
            )
            st.plotly_chart(fig_cat, use_container_width=True)

    with row2_col2:
        st.markdown('<div class="section-label">Merchants</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.75rem;">Top Merchants by Spend</div>', unsafe_allow_html=True)
        stores = data["spending_by_store"]
        if stores:
            st_names = [s["store"] for s in reversed(stores)]
            st_amts = [s["amount"] for s in reversed(stores)]

            fig_store = go.Figure(
                go.Bar(
                    x=st_amts,
                    y=st_names,
                    orientation="h",
                    marker=dict(
                        color="#557564",
                        line=dict(color="#6F8A79", width=1),
                    ),
                    hovertemplate="<b>%{y}</b><br>" + currency_symbol + "%{x:,.2f}<extra></extra>",
                )
            )
            fig_store.update_layout(
                template="plotly_dark",
                paper_bgcolor="rgba(0,0,0,0)",
                plot_bgcolor="rgba(0,0,0,0)",
                font=dict(family="Inter, sans-serif", color="#8C8B82", size=11),
                margin=dict(l=10, r=10, t=10, b=10),
                height=280,
                xaxis=dict(showgrid=True, gridcolor="rgba(255, 255, 255, 0.05)", tickprefix=currency_symbol, tickfont=dict(size=10, color="#8C8B82")),
                yaxis=dict(showgrid=False, tickfont=dict(size=11, color="#EDEDE8")),
                showlegend=False,
            )
            st.plotly_chart(fig_store, use_container_width=True)

    st.markdown("<div style='margin-top: 2rem;'></div>", unsafe_allow_html=True)

    # Row 3: Payment Method Breakdown + Month-over-Month Comparison
    row3_col1, row3_col2 = st.columns(2)

    with row3_col1:
        st.markdown('<div class="section-label">Payment Flow</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.75rem;">Payment Methods</div>', unsafe_allow_html=True)
        pms = data["spending_by_pm"]
        if pms:
            fig_pm = go.Figure(
                data=[
                    go.Pie(
                        labels=[p["method"] for p in pms],
                        values=[p["amount"] for p in pms],
                        hole=0.6,
                        marker=dict(colors=MUTED_PALETTE[:len(pms)]),
                        textinfo="percent+label",
                        textfont=dict(family="Inter, sans-serif", size=10, color="#EDEDE8"),
                        hovertemplate="<b>%{label}</b><br>Amount: " + currency_symbol + "%{value:,.2f}<extra></extra>",
                    )
                ]
            )
            fig_pm.update_layout(
                template="plotly_dark",
                paper_bgcolor="rgba(0,0,0,0)",
                plot_bgcolor="rgba(0,0,0,0)",
                font=dict(family="Inter, sans-serif", color="#8C8B82"),
                margin=dict(l=10, r=10, t=10, b=10),
                height=260,
                showlegend=False,
            )
            st.plotly_chart(fig_pm, use_container_width=True)

    with row3_col2:
        st.markdown('<div class="section-label">Cadence</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.75rem;">Month-over-Month Comparison</div>', unsafe_allow_html=True)
        mom = data["mom"]
        delta_pct_str = f"{mom['pct']:+,.1f}%"
        delta_color = "#C25D53" if mom["delta"] > 0 else "#3E6B56"
        delta_direction = "higher" if mom["delta"] > 0 else "lower"

        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1.25rem 1.4rem;">
                <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 1rem;">
                    <div>
                        <div class="stat-label">Current Month</div>
                        <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.4rem; font-weight: 600; color: #EDEDE8;">
                            {currency_symbol}{mom['cur_month_total']:,.2f}
                        </div>
                    </div>
                    <div style="text-align: right;">
                        <div class="stat-label">Prior Month</div>
                        <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.4rem; font-weight: 600; color: #8C8B82;">
                            {currency_symbol}{mom['prev_month_total']:,.2f}
                        </div>
                    </div>
                </div>
                <div style="border-top: 1px solid #232521; padding-top: 0.85rem; display: flex; justify-content: space-between; align-items: center; font-size: 0.85rem;">
                    <span style="color: #8C8B82;">Net Change:</span>
                    <span style="font-family: 'IBM Plex Mono', monospace; font-weight: 600; color: {delta_color};">
                        {currency_symbol}{abs(mom['delta']):,.2f} ({delta_pct_str} {delta_direction})
                    </span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )
