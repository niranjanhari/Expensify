"""
Budgets UI component (Phase 9 - Redesigned Editorial).
Provides overall monthly and category-specific budget tracking with neutral,
understated progress metrics and calm visibility into limits.
"""

from decimal import Decimal
import streamlit as st

from services.budget_service import (
    delete_budget,
    get_budget_progress,
    set_budget,
)
from services.tag_service import get_all_tags


def render_budgets_view(currency_symbol: str = "₹") -> None:
    """Render the minimal, editorial Budgets management view."""
    st.markdown('<div class="section-label">Targets</div>', unsafe_allow_html=True)
    st.markdown('<h1 class="page-title">Budgets & Limits</h1>', unsafe_allow_html=True)

    all_tags = get_all_tags()
    tag_options = {t.name: t.id for t in all_tags}

    # Top Action Buttons
    col1, col2 = st.columns(2)
    with col1:
        with st.popover("Set Overall Monthly Target", use_container_width=True):
            st.markdown("**Monthly Spending Target**")
            cur_amt = st.number_input(
                f"Overall Monthly Target ({currency_symbol})",
                min_value=100.0,
                value=15000.0,
                step=500.0,
                format="%.2f",
                key="overall_b_input",
            )
            if st.button("Save Overall Target", type="primary", use_container_width=True):
                set_budget(amount=Decimal(str(cur_amt)), tag_id=None)
                st.success("Overall monthly budget updated.")
                st.rerun()

    with col2:
        with st.popover("Set Category Limit", use_container_width=True):
            st.markdown("**Category Specific Limit**")
            sel_cat = st.selectbox("Category", options=list(tag_options.keys()), key="cat_b_select")
            cat_amt = st.number_input(
                f"Monthly Category Limit ({currency_symbol})",
                min_value=50.0,
                value=3000.0,
                step=100.0,
                format="%.2f",
                key="cat_b_input",
            )
            if st.button("Save Category Limit", type="primary", use_container_width=True):
                tag_id = tag_options[sel_cat]
                set_budget(amount=Decimal(str(cat_amt)), tag_id=tag_id)
                st.success(f"{sel_cat} budget updated.")
                st.rerun()

    progress = get_budget_progress()

    if not progress["has_budgets"]:
        st.markdown(
            """
            <div class="empty-state">
                <div class="empty-state-title">No budget targets configured</div>
                <div class="empty-state-desc">Set an overall monthly target or category limits using the controls above.</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
        return

    # 1. Overall Monthly Budget Card
    overall = progress["overall"]
    if overall:
        st.markdown('<div class="section-label">Monthly Trajectory</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.1rem; color: #EDEDE8; margin-bottom: 0.75rem;">Overall Monthly Target</div>', unsafe_allow_html=True)
        pct = overall["percentage_used"]
        bar_color = "#3E6B56" if pct <= 80 else ("#A67C52" if pct <= 100 else "#C25D53")

        st.markdown(
            f"""
            <div class="editorial-card" style="padding: 1.3rem 1.5rem;">
                <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px;">
                    <div>
                        <div class="stat-label">Spent in {progress['month_name']}</div>
                        <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.6rem; font-weight: 600; color: #EDEDE8;">
                            {currency_symbol}{overall['spent_amount']:,.2f} 
                            <span style="font-size: 0.95rem; color: #8C8B82; font-weight: 400;">/ {currency_symbol}{overall['budget_amount']:,.2f}</span>
                        </div>
                    </div>
                    <div style="text-align: right;">
                        <span style="font-family: 'IBM Plex Mono', monospace; font-size: 1.3rem; font-weight: 600; color: {bar_color};">{pct:.1f}%</span>
                        <div style="font-size: 0.75rem; color: #8C8B82;">of target used</div>
                    </div>
                </div>
                <div style="background: rgba(255, 255, 255, 0.05); border-radius: 4px; height: 6px; overflow: hidden; margin: 12px 0;">
                    <div style="background: {bar_color}; width: {min(100.0, pct)}%; height: 100%; border-radius: 4px;"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 0.82rem; color: #8C8B82;">
                    <span>{overall['status_message']}</span>
                    <span>Remaining: <b style="font-family: 'IBM Plex Mono', monospace; color: #EDEDE8;">{currency_symbol}{overall['remaining_amount']:,.2f}</b></span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<div style='margin-top: 2rem;'></div>", unsafe_allow_html=True)

    # 2. Category Budgets Grid
    categories = progress["categories"]
    if categories:
        st.markdown('<div class="section-label">Categories</div>', unsafe_allow_html=True)
        st.markdown('<div style="font-weight: 600; font-size: 1.1rem; color: #EDEDE8; margin-bottom: 0.75rem;">Category Targets</div>', unsafe_allow_html=True)
        c_cols = st.columns(2)
        for idx, cat_b in enumerate(categories):
            col = c_cols[idx % 2]
            with col:
                pct = cat_b["percentage_used"]
                bar_color = "#3E6B56" if pct <= 80 else ("#A67C52" if pct <= 100 else "#C25D53")

                st.markdown(
                    f"""
                    <div class="editorial-card" style="padding: 1.1rem 1.25rem;">
                        <div style="display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 6px;">
                            <div>
                                <span class="subtle-tag">{cat_b['category']}</span>
                                <div style="font-family: 'IBM Plex Mono', monospace; font-size: 1.15rem; font-weight: 600; color: #EDEDE8; margin-top: 6px;">
                                    {currency_symbol}{cat_b['spent_amount']:,.2f}
                                    <span style="font-size: 0.8rem; color: #8C8B82; font-weight: 400;">/ {currency_symbol}{cat_b['budget_amount']:,.2f}</span>
                                </div>
                            </div>
                            <span style="font-family: 'IBM Plex Mono', monospace; font-size: 1rem; font-weight: 600; color: {bar_color};">{pct:.1f}%</span>
                        </div>
                        <div style="background: rgba(255, 255, 255, 0.05); border-radius: 4px; height: 5px; overflow: hidden; margin: 10px 0;">
                            <div style="background: {bar_color}; width: {min(100.0, pct)}%; height: 100%; border-radius: 4px;"></div>
                        </div>
                        <div style="font-size: 0.78rem; color: #8C8B82;">
                            {cat_b['status_message']}
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
                if st.button("Delete Target", key=f"del_b_{cat_b['id']}", use_container_width=True):
                    delete_budget(cat_b["id"])
                    st.rerun()
