"""
Anomaly Detection UI component (Phase 15 - Redesigned Editorial).
Visualizes statistical outliers and unusual transactions using IQR and Z-score methods.
"""

from decimal import Decimal
import streamlit as st

from services.anomaly_service import detect_all_anomalies


def render_anomalies_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Anomaly Detection view."""
    st.markdown('<div class="section-label">Audit</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Anomaly Detection</h1>', unsafe_allow_html=True)

    col1, col2 = st.columns([3, 1])
    with col1:
        st.caption("Transactions evaluated against 90-day category Interquartile Range (IQR) and merchant baselines.")
    with col2:
        sensitivity = st.selectbox(
            "Sensitivity",
            options=["Standard (1.5x IQR)", "High (1.2x IQR)", "Strict (2.0x IQR)"],
            index=0,
            key="anomaly_sensitivity_select",
        )

    iqr_thresh = 1.5
    if "High" in sensitivity:
        iqr_thresh = 1.2
    elif "Strict" in sensitivity:
        iqr_thresh = 2.0

    anomalies = detect_all_anomalies(days=90, threshold_iqr=iqr_thresh)

    # Top KPI Metrics
    c1, c2, c3 = st.columns(3)
    with c1:
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Flagged Outliers</div>
                <div class="stat-number">{len(anomalies)}</div>
                <div class="stat-subtext">Across past 90 days</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    with c2:
        max_amt = max([a["amount"] for a in anomalies]) if anomalies else Decimal("0.00")
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">Largest Spike</div>
                <div class="stat-number">{currency_symbol}{max_amt:,.2f}</div>
                <div class="stat-subtext">Highest flagged entry</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    with c3:
        high_sev_count = sum(1 for a in anomalies if a["severity"] == "High")
        st.markdown(
            f"""
            <div class="stat-block">
                <div class="stat-label">High Variance (Z > 3.0)</div>
                <div class="stat-number">{high_sev_count}</div>
                <div class="stat-subtext">Statistical variance</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<div style='margin-top: 1.5rem;'></div>", unsafe_allow_html=True)

    if not anomalies:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No statistical outliers detected</div>
                <div class="empty-state-desc">Your transaction patterns are consistent with historical category baselines.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
        return

    st.markdown('<div class="section-label">Discrepancies</div>', unsafe_allow_html=True)
    st.markdown('<div style="font-weight: 600; font-size: 1.05rem; color: #EDEDE8; margin-bottom: 0.75rem;">Flagged Transactions</div>', unsafe_allow_html=True)
    for a in anomalies:
        is_high = a["severity"] == "High"
        sev_color = "#C25D53" if is_high else "#A67C52"
        st.markdown(
            f"""
            <div class="editorial-card" style="margin-bottom: 0.75rem; padding: 1.15rem 1.3rem;">
                <div style="display: flex; justify-content: space-between; align-items: baseline;">
                    <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                        <span style="font-weight: 600; color: #EDEDE8; font-size: 0.95rem;">{a['store_name']}</span>
                        <span class="subtle-tag">{a['tag_name']}</span>
                        <span class="subtle-tag" style="color: {sev_color}; border-color: rgba(255, 255, 255, 0.1);">
                            {a['anomaly_type']} · {a['severity']}
                        </span>
                    </div>
                    <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.15rem; font-weight: 600; color: {sev_color};">
                        {currency_symbol}{a['amount']:,.2f}
                    </div>
                </div>
                <p style="font-size: 0.85rem; color: #8C8B82; margin: 8px 0 10px 0; line-height: 1.5;">
                    {a['message']}
                </p>
                <div style="display: flex; justify-content: space-between; font-size: 0.78rem; color: #8C8B82; border-top: 1px solid #232521; padding-top: 6px;">
                    <span>Date: <b style="color: #EDEDE8;">{a['date'].strftime('%d %b %Y')}</b></span>
                    <span>Note: <i>{a['description'] or 'None'}</i></span>
                    <span>Typical Range: <b style="color: #EDEDE8;">{a['typical_range']}</b></span>
                    <span>Z-Score: <b style="color: #EDEDE8;">{a['z_score']}σ</b></span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )
