import os
import io
import csv
import secrets
from datetime import datetime, date
from flask import (
    Flask,
    render_template,
    request,
    redirect,
    url_for,
    flash,
    session,
    abort,
    Response,
    jsonify
)

import database

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", secrets.token_hex(32))

def parse_amount_to_paise(amount_str):
    if not amount_str or not str(amount_str).strip():
        raise ValueError("Amount cannot be empty.")
    cleaned = str(amount_str).strip().replace("₹", "").replace(",", "").strip()
    try:
        val = float(cleaned)
    except ValueError:
        raise ValueError(f"Invalid monetary amount: '{amount_str}'")
    if val <= 0:
        raise ValueError("Amount must be greater than zero.")
    paise = int(round(val * 100))
    if paise <= 0:
        raise ValueError("Amount must be at least 1 paisa (0.01 INR).")
    return paise

def format_inr(paise, include_symbol=True):
    sign = "-" if paise < 0 else ""
    abs_p = abs(paise)
    rupees_part = abs_p // 100
    paise_part = abs_p % 100
    s = str(rupees_part)
    if len(s) > 3:
        last3 = s[-3:]
        rest = s[:-3]
        groups = []
        while len(rest) > 2:
            groups.insert(0, rest[-2:])
            rest = rest[:-2]
        if rest:
            groups.insert(0, rest)
        rupees_formatted = ",".join(groups) + "," + last3
    else:
        rupees_formatted = s
    formatted = f"{rupees_formatted}.{paise_part:02d}"
    return f"{sign}₹{formatted}" if include_symbol else f"{sign}{formatted}"

def paise_to_rupees(paise):
    return round(paise / 100.0, 2)

def format_display_date(date_str):
    try:
        dt = datetime.strptime(date_str.strip(), "%Y-%m-%d")
        return dt.strftime("%d %b %Y")
    except Exception:
        return date_str

def format_month_label(month_str):
    try:
        dt = datetime.strptime(month_str.strip(), "%Y-%m")
        return dt.strftime("%B %Y")
    except Exception:
        return month_str

@app.template_filter("inr")
def inr_filter(paise):
    return format_inr(paise)

@app.template_filter("rupees")
def rupees_filter(paise):
    return f"{paise_to_rupees(paise):.2f}"

@app.template_filter("display_date")
def display_date_filter(date_str):
    return format_display_date(date_str)

@app.template_filter("month_label")
def month_label_filter(month_str):
    return format_month_label(month_str)

@app.before_request
def ensure_csrf_token():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_hex(16)

@app.context_processor
def inject_globals():
    return {
        "csrf_token": session.get("csrf_token"),
        "categories": database.CATEGORIES,
        "payment_methods": database.PAYMENT_METHODS,
        "category_colors": database.CATEGORY_COLORS,
        "today_str": date.today().strftime("%Y-%m-%d")
    }

def verify_csrf():
    token = request.form.get("csrf_token")
    if not token or token != session.get("csrf_token"):
        abort(403)

@app.route("/")
def index():
    return redirect(url_for("dashboard"))

@app.route("/dashboard")
def dashboard():
    current_month = date.today().strftime("%Y-%m")
    summary = database.get_monthly_summary(current_month)
    recent_expenses = database.get_recent_expenses(5)
    category_breakdown = database.get_category_breakdown(current_month)
    total_count = database.get_total_count()

    return render_template(
        "dashboard.html",
        active_page="dashboard",
        current_month=current_month,
        current_month_label=format_month_label(current_month),
        summary=summary,
        recent_expenses=recent_expenses,
        category_breakdown=category_breakdown,
        total_count=total_count
    )

@app.route("/expenses")
def expenses():
    search_query = request.args.get("q", "").strip()
    category = request.args.get("category", "All").strip()
    start_date = request.args.get("start_date", "").strip()
    end_date = request.args.get("end_date", "").strip()
    sort_by = request.args.get("sort_by", "date_desc").strip()

    expenses_list = database.get_expenses(
        search_query=search_query,
        category=category,
        start_date=start_date,
        end_date=end_date,
        sort_by=sort_by
    )

    total_filtered_paise = sum(exp["amount_paise"] for exp in expenses_list)

    return render_template(
        "expenses.html",
        active_page="expenses",
        expenses=expenses_list,
        total_filtered_paise=total_filtered_paise,
        search_query=search_query,
        category=category,
        start_date=start_date,
        end_date=end_date,
        sort_by=sort_by
    )

@app.route("/expenses/add", methods=["POST"])
def add_expense():
    verify_csrf()
    amount_str = request.form.get("amount", "").strip()
    description = request.form.get("description", "").strip()
    category = request.form.get("category", "").strip()
    expense_date = request.form.get("expense_date", "").strip()
    payment_method = request.form.get("payment_method", "").strip()

    try:
        amount_paise = parse_amount_to_paise(amount_str)
        new_id = database.add_expense(
            amount_paise=amount_paise,
            description=description,
            category=category,
            expense_date=expense_date,
            payment_method=payment_method
        )
        flash(f"Expense added successfully (ID #{new_id})", "success")
    except ValueError as e:
        flash(str(e), "error")
    except Exception:
        flash("Failed to add expense. Please check your inputs.", "error")

    next_url = request.form.get("next") or request.referrer or url_for("expenses")
    return redirect(next_url)

@app.route("/expenses/edit/<int:expense_id>", methods=["POST"])
def edit_expense(expense_id):
    verify_csrf()
    amount_str = request.form.get("amount", "").strip()
    description = request.form.get("description", "").strip()
    category = request.form.get("category", "").strip()
    expense_date = request.form.get("expense_date", "").strip()
    payment_method = request.form.get("payment_method", "").strip()

    try:
        amount_paise = parse_amount_to_paise(amount_str)
        updated = database.update_expense(
            expense_id=expense_id,
            amount_paise=amount_paise,
            description=description,
            category=category,
            expense_date=expense_date,
            payment_method=payment_method
        )
        if updated:
            flash(f"Expense #{expense_id} updated successfully", "success")
        else:
            flash(f"Expense #{expense_id} not found", "error")
    except ValueError as e:
        flash(str(e), "error")
    except Exception:
        flash("Failed to update expense.", "error")

    next_url = request.form.get("next") or url_for("expenses")
    return redirect(next_url)

@app.route("/expenses/delete/<int:expense_id>", methods=["POST"])
def delete_expense(expense_id):
    verify_csrf()
    deleted = database.delete_expense(expense_id)
    if deleted:
        flash(f"Expense #{expense_id} deleted successfully", "success")
    else:
        flash(f"Expense #{expense_id} could not be deleted", "error")

    next_url = request.form.get("next") or url_for("expenses")
    return redirect(next_url)

@app.route("/expenses/export")
def export_csv():
    search_query = request.args.get("q", "").strip()
    category = request.args.get("category", "All").strip()
    start_date = request.args.get("start_date", "").strip()
    end_date = request.args.get("end_date", "").strip()
    sort_by = request.args.get("sort_by", "date_desc").strip()

    expenses_list = database.get_expenses(
        search_query=search_query,
        category=category,
        start_date=start_date,
        end_date=end_date,
        sort_by=sort_by
    )

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["date", "description", "category", "payment_method", "amount"])
    for exp in expenses_list:
        writer.writerow([
            exp.get("expense_date", ""),
            exp.get("description", ""),
            exp.get("category", ""),
            exp.get("payment_method", ""),
            paise_to_rupees(exp.get("amount_paise", 0))
        ])

    csv_data = output.getvalue()
    today_str = date.today().strftime("%Y%m%d")
    filename = f"expensify_records_{today_str}.csv"

    return Response(
        csv_data,
        mimetype="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@app.route("/analytics")
def analytics():
    current_month = date.today().strftime("%Y-%m")
    selected_month = request.args.get("month", current_month).strip()

    available_months = [
        {
            "month": database.shift_month(current_month, -i),
            "label": format_month_label(database.shift_month(current_month, -i))
        }
        for i in range(12)
    ]

    month_summary = database.get_monthly_summary(selected_month)
    category_breakdown = database.get_category_breakdown(selected_month)
    six_months_trend = database.get_six_months_trend(current_month)
    total_count = database.get_total_count()

    return render_template(
        "analytics.html",
        active_page="analytics",
        current_month=current_month,
        selected_month=selected_month,
        selected_month_label=format_month_label(selected_month),
        available_months=available_months,
        month_summary=month_summary,
        category_breakdown=category_breakdown,
        six_months_trend=six_months_trend,
        total_count=total_count
    )

@app.route("/api/analytics/category")
def api_category():
    current_month = date.today().strftime("%Y-%m")
    selected_month = request.args.get("month", current_month).strip()
    breakdown = database.get_category_breakdown(selected_month)
    summary = database.get_monthly_summary(selected_month)
    return jsonify({
        "month": selected_month,
        "month_label": format_month_label(selected_month),
        "summary": summary,
        "categories": [
            {
                "category": b["category"],
                "total_rupees": paise_to_rupees(b["total_paise"]),
                "count": b["count"],
                "color": database.CATEGORY_COLORS.get(b["category"], "#8395A7")
            }
            for b in breakdown
        ]
    })

@app.route("/api/analytics/trend")
def api_trend():
    current_month = date.today().strftime("%Y-%m")
    trend = database.get_six_months_trend(current_month)
    return jsonify({
        "current_month": current_month,
        "trend": [
            {
                "month": item["month"],
                "label": item["label"],
                "total_rupees": paise_to_rupees(item["total_paise"]),
                "count": item["count"]
            }
            for item in trend
        ]
    })

def main():
    database.init_db()
    print("Expensify Lite running at http://127.0.0.1:5000")
    app.run(host="127.0.0.1", port=5000, debug=False)

if __name__ == "__main__":
    main()
