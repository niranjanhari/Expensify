"""
AI Spending Advisor & Weekly Digest Service (Phase 13).
Generates calm, constructive financial observations, weekly digests,
and interactive AI answers using Gemini (with an offline algorithmic fallback).
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from decimal import Decimal
import os
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv
from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session, joinedload

from database.database import get_db_session
from database.models import Budget, Expense, RecurringExpense, Store, Tag

load_dotenv()


def get_weekly_digest(reference_date: Optional[date] = None, session: Optional[Session] = None) -> Dict[str, Any]:
    """
    Compute a week-over-week spending digest.
    Compares the last 7 days vs the prior 7 days.
    """
    ref_d = reference_date or date.today()
    current_start = ref_d - timedelta(days=6)
    prev_end = current_start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=6)

    def _calc(s: Session) -> Dict[str, Any]:
        # Current 7 days
        cur_stmt = select(
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")),
            func.count(Expense.id)
        ).where(Expense.date >= current_start, Expense.date <= ref_d)
        cur_total, cur_count = s.execute(cur_stmt).first() or (Decimal("0.00"), 0)

        # Prior 7 days
        prev_stmt = select(
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")),
            func.count(Expense.id)
        ).where(Expense.date >= prev_start, Expense.date <= prev_end)
        prev_total, prev_count = s.execute(prev_stmt).first() or (Decimal("0.00"), 0)

        # Delta calculation
        delta_amount = cur_total - prev_total
        if prev_total > Decimal("0.00"):
            delta_pct = float(((cur_total - prev_total) / prev_total) * Decimal("100.0"))
        else:
            delta_pct = 100.0 if cur_total > Decimal("0.00") else 0.0

        # Top category this week
        top_cat_row = s.execute(
            select(Tag.name, func.sum(Expense.amount).label("cat_sum"))
            .join(Expense.tag)
            .where(Expense.date >= current_start, Expense.date <= ref_d)
            .group_by(Tag.id)
            .order_by(desc("cat_sum"))
            .limit(1)
        ).first()
        top_category = top_cat_row[0] if top_cat_row else "None"
        top_category_spend = top_cat_row[1] if top_cat_row else Decimal("0.00")

        # Highest single purchase this week
        highest_exp = s.scalar(
            select(Expense)
            .options(joinedload(Expense.store), joinedload(Expense.tag))
            .where(Expense.date >= current_start, Expense.date <= ref_d)
            .order_by(Expense.amount.desc())
            .limit(1)
        )

        # Most frequented store this week
        top_store_row = s.execute(
            select(Store.name, func.count(Expense.id).label("visit_count"))
            .join(Expense.store)
            .where(Expense.date >= current_start, Expense.date <= ref_d)
            .group_by(Store.id)
            .order_by(desc("visit_count"))
            .limit(1)
        ).first()
        top_store = top_store_row[0] if top_store_row else "None"
        top_store_visits = top_store_row[1] if top_store_row else 0

        daily_avg = (cur_total / Decimal("7.0")).quantize(Decimal("0.01"))

        return {
            "current_start": current_start,
            "current_end": ref_d,
            "current_total": cur_total,
            "current_count": cur_count,
            "prev_total": prev_total,
            "prev_count": prev_count,
            "delta_amount": delta_amount,
            "delta_percentage": delta_pct,
            "daily_average": daily_avg,
            "top_category": top_category,
            "top_category_spend": top_category_spend,
            "highest_expense": {
                "amount": highest_exp.amount if highest_exp else Decimal("0.00"),
                "description": highest_exp.description if highest_exp else "",
                "store": highest_exp.store.name if highest_exp and highest_exp.store else "",
                "tag": highest_exp.tag.name if highest_exp and highest_exp.tag else "",
            } if highest_exp else None,
            "top_merchant": top_store,
            "top_merchant_visits": top_store_visits,
        }

    if session:
        return _calc(session)
    with get_db_session() as s:
        return _calc(s)


def get_spending_observations(session: Optional[Session] = None) -> List[Dict[str, Any]]:
    """
    Generate calm, constructive financial observations from recent activity.
    Categorized into: Pacing, Micro-Spending, Recurring, and Category Concentration.
    """
    today = date.today()
    month_start = today.replace(day=1)
    days_elapsed = max(1, today.day)

    def _observe(s: Session) -> List[Dict[str, Any]]:
        observations: List[Dict[str, Any]] = []

        # 1. Month total
        month_total = s.scalar(
            select(func.coalesce(func.sum(Expense.amount), Decimal("0.00")))
            .where(Expense.date >= month_start, Expense.date <= today)
        ) or Decimal("0.00")

        # 2. Overall Budget Check
        overall_b = s.scalar(select(Budget).where(Budget.tag_id.is_(None)))
        if overall_b and overall_b.amount > Decimal("0.00"):
            pct_used = float((month_total / overall_b.amount) * Decimal("100.0"))
            expected_pct = float(days_elapsed / 30.0 * 100.0)
            if pct_used > expected_pct + 15.0:
                observations.append({
                    "type": "pacing",
                    "badge": "Budget Alert",
                    "color": "#F59E0B",
                    "title": "Spending Velocity Notice",
                    "message": (
                        f"You have used {pct_used:.1f}% of your monthly target across the first {days_elapsed} days. "
                        f"Pacing is slightly ahead of the {expected_pct:.0f}% expected baseline."
                    ),
                    "action_tip": "Focusing on discretionary expenses this week will smoothly rebalance your monthly flow."
                })
            elif pct_used <= expected_pct:
                observations.append({
                    "type": "pacing",
                    "badge": "Healthy Pacing",
                    "color": "#10B981",
                    "title": "Steady Monthly Cadence",
                    "message": (
                        f"You have consumed {pct_used:.1f}% of your budget over {days_elapsed} days. "
                        f"Your current run rate is well within planned parameters."
                    ),
                    "action_tip": "Keep following this rhythm; you are on track to end the month with a surplus."
                })

        # 3. Micro-transaction Cumulative Impact Check (< ₹150)
        micro_row = s.execute(
            select(
                func.coalesce(func.sum(Expense.amount), Decimal("0.00")),
                func.count(Expense.id)
            ).where(
                Expense.date >= month_start,
                Expense.date <= today,
                Expense.amount <= Decimal("150.00")
            )
        ).first()

        if micro_row and micro_row[1] >= 5:
            micro_sum, micro_count = micro_row
            pct_of_month = float((micro_sum / month_total) * Decimal("100.0")) if month_total > Decimal("0.00") else 0.0
            observations.append({
                "type": "micro_spend",
                "badge": "Micro-Habits",
                "color": "#6366F1",
                "title": "Small Daily Purchases",
                "message": (
                    f"You have logged {micro_count} small purchases under ₹150 this month, totaling {micro_sum:,.2f} "
                    f"({pct_of_month:.1f}% of this month's spending)."
                ),
                "action_tip": "Micro-expenses like daily snacks or teas add up quietly. Bundling or planning them can yield easy savings."
            })

        # 4. Recurring Commitments Ratio
        recurring_sum = s.scalar(
            select(func.coalesce(func.sum(RecurringExpense.amount), Decimal("0.00")))
            .where(RecurringExpense.active == True)
        ) or Decimal("0.00")

        if recurring_sum > Decimal("0.00") and month_total > Decimal("0.00"):
            rec_ratio = float((recurring_sum / month_total) * Decimal("100.0"))
            observations.append({
                "type": "recurring",
                "badge": "Fixed Commitments",
                "color": "#8B5CF6",
                "title": "Recurring vs. Variable",
                "message": (
                    f"Your active subscriptions and routines total ~{recurring_sum:,.2f} per cycle, "
                    f"representing {rec_ratio:.1f}% of your typical monthly volume."
                ),
                "action_tip": "Review your active subscriptions in the Recurring tab periodically to weed out dormant tools or services."
            })

        # 5. Top Category Dominance
        top_cat = s.execute(
            select(Tag.name, func.sum(Expense.amount).label("s_amt"))
            .join(Expense.tag)
            .where(Expense.date >= month_start, Expense.date <= today)
            .group_by(Tag.id)
            .order_by(desc("s_amt"))
            .limit(1)
        ).first()

        if top_cat and month_total > Decimal("0.00"):
            c_name, c_amt = top_cat
            c_pct = float((c_amt / month_total) * Decimal("100.0"))
            if c_pct >= 45.0:
                observations.append({
                    "type": "concentration",
                    "badge": "Category Focus",
                    "color": "#06B6D4",
                    "title": f"High Concentration in {c_name}",
                    "message": (
                        f"{c_name} accounts for {c_pct:.1f}% ({c_amt:,.2f}) of all spending this month. "
                        f"Most of your financial activity is centralized here."
                    ),
                    "action_tip": f"Setting a specific category budget for {c_name} in the Budgets tab will give you peace of mind."
                })

        return observations

    if session:
        return _observe(session)
    with get_db_session() as s:
        return _observe(s)


def ask_advisor_ai(question: str, session: Optional[Session] = None) -> str:
    """
    Answer an interactive financial query with calm, constructive perspective.
    Uses Gemini when configured; otherwise provides tailored algorithmic financial guidance.
    """
    q_clean = question.strip()
    if not q_clean:
        return "Please ask a question regarding your spending patterns or budget."

    def _answer(s: Session) -> str:
        # Assemble high-level aggregated financial context (no sensitive individual records)
        today = date.today()
        month_start = today.replace(day=1)

        month_total = s.scalar(
            select(func.coalesce(func.sum(Expense.amount), Decimal("0.00")))
            .where(Expense.date >= month_start, Expense.date <= today)
        ) or Decimal("0.00")

        cat_breakdown = s.execute(
            select(Tag.name, func.sum(Expense.amount).label("amt"))
            .join(Expense.tag)
            .where(Expense.date >= month_start, Expense.date <= today)
            .group_by(Tag.id)
            .order_by(desc("amt"))
            .limit(4)
        ).all()

        cat_summary_str = ", ".join([f"{name}: {amt:,.2f}" for name, amt in cat_breakdown]) or "No categorized spend"
        budget_obj = s.scalar(select(Budget).where(Budget.tag_id.is_(None)))
        budget_str = f"{budget_obj.amount:,.2f}" if budget_obj else "Not set"

        api_key = os.getenv("GEMINI_API_KEY")
        if api_key and api_key.strip():
            try:
                from google import genai
                client = genai.Client(api_key=api_key)
                prompt = f"""
                You are a wise, supportive, and non-judgmental Personal Expense Intelligence Advisor.
                Answer the user's question with constructive financial coaching.
                Keep responses concise (2 to 4 bullet points, maximum 150 words). Never shame or guilt the user.

                Financial Context for current month:
                - Month-to-date total spend: {month_total:,.2f}
                - Target monthly budget: {budget_str}
                - Top categories: {cat_summary_str}
                - Current date: {today.strftime('%d %B %Y')}

                User Question:
                "{q_clean}"
                """
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt,
                )
                if response.text and response.text.strip():
                    return response.text.strip()
            except Exception:
                pass

        # Offline Algorithmic Advisor Response
        return _offline_advisory_reply(q_clean, month_total, cat_breakdown, budget_obj)

    if session:
        return _answer(session)
    with get_db_session() as s:
        return _answer(s)


def _offline_advisory_reply(
    question: str,
    month_total: Decimal,
    cat_breakdown: List[Any],
    budget_obj: Optional[Budget]
) -> str:
    """Intelligent offline rule-based response generator."""
    q_low = question.lower()
    top_cat = cat_breakdown[0][0] if cat_breakdown else "General"
    top_amt = cat_breakdown[0][1] if cat_breakdown else Decimal("0.00")

    if any(k in q_low for k in ["food", "eat", "dining", "canteen", "restaurant"]):
        return (
            f"**Food & Dining Spending Perspective:**\n\n"
            f"- Your spending in top categories currently stands at: **{top_cat}** ({top_amt:,.2f}).\n"
            f"- **Observation:** Frequent food delivery or canteen micro-orders often comprise 30-40% of discretionary outflow.\n"
            f"- **Actionable Step:** Try pre-setting a weekly meal allowance or batching groceries to preserve spontaneity without budget friction."
        )

    if any(k in q_low for k in ["save", "cut", "reduce", "surplus", "saving"]):
        return (
            f"**Practical Savings Opportunities:**\n\n"
            f"- **Review Micro-transactions:** Check purchases under ₹150. Even saving ₹100/day creates an extra ₹3,000 monthly cushion.\n"
            f"- **Audit Recurring Items:** Verify you are actively using all subscriptions in your Recurring tab.\n"
            f"- **Category Limit:** Place a category target on **{top_cat}** in the Budgets view for automated visual pacing."
        )

    if any(k in q_low for k in ["budget", "target", "limit", "pacing"]):
        if budget_obj:
            pct = float((month_total / budget_obj.amount) * 100.0) if budget_obj.amount > 0 else 0
            return (
                f"**Budget Health Overview:**\n\n"
                f"- You have used **{pct:.1f}%** of your monthly limit ({month_total:,.2f} / {budget_obj.amount:,.2f}).\n"
                f"- Your pacing is steady. Spreading remaining funds across discretionary tags will keep your month stress-free."
            )
        else:
            return (
                f"**Budget Recommendation:**\n\n"
                f"- You haven't set an overall monthly target yet. Based on your current spend of **{month_total:,.2f}**, "
                f"setting a benchmark in the **Budgets** view will unlock automatic velocity alerts."
            )

    # General financial overview
    return (
        f"**Financial Pattern Summary:**\n\n"
        f"- **Month Total:** You have recorded **{month_total:,.2f}** in transactions this month.\n"
        f"- **Primary Flow:** Your highest expenditure is in **{top_cat}** ({top_amt:,.2f}).\n"
        f"- **Note:** Maintaining a consistent logging habit provides clean visibility, which is the cornerstone of effortless financial confidence."
    )

