import os
import calendar
from datetime import datetime, date, timedelta
import mysql.connector

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

CATEGORIES = [
    "Food",
    "Transport",
    "Shopping",
    "Education",
    "Entertainment",
    "Bills",
    "Other"
]

PAYMENT_METHODS = ["UPI", "Cash", "Card", "Bank Transfer", "Other"]

CATEGORY_COLORS = {
    "Food": "#FF9F43",
    "Transport": "#F7B731",
    "Shopping": "#00CFDE",
    "Education": "#54A0FF",
    "Entertainment": "#EE5253",
    "Bills": "#5F27CD",
    "Other": "#8395A7"
}

def get_db_config():
    return {
        "host": os.environ.get("MYSQL_HOST", "localhost"),
        "port": int(os.environ.get("MYSQL_PORT", 3306)),
        "user": os.environ.get("MYSQL_USER", "root"),
        "password": os.environ.get("MYSQL_PASSWORD", ""),
        "database": os.environ.get("MYSQL_DATABASE", "expensify")
    }

def get_connection(include_db=True):
    config = get_db_config()
    if not include_db:
        config.pop("database", None)
    return mysql.connector.connect(**config)

def init_db():
    config = get_db_config()
    db_name = config["database"]

    try:
        server_conn = get_connection(include_db=False)
        try:
            cur = server_conn.cursor()
            cur.execute(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
            server_conn.commit()
            cur.close()
        finally:
            server_conn.close()
    except Exception:
        pass

    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        cur.execute(
            "CREATE TABLE IF NOT EXISTS expenses ("
            "id INT AUTO_INCREMENT PRIMARY KEY, "
            "amount_paise BIGINT NOT NULL, "
            "description VARCHAR(255) NOT NULL, "
            "category VARCHAR(50) NOT NULL, "
            "expense_date VARCHAR(10) NOT NULL, "
            "payment_method VARCHAR(50) NOT NULL, "
            "created_at VARCHAR(30) NOT NULL, "
            "INDEX idx_expenses_date (expense_date), "
            "INDEX idx_expenses_category (category)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
        )
        cur.execute(
            "CREATE TABLE IF NOT EXISTS app_meta ("
            "`key` VARCHAR(100) PRIMARY KEY, "
            "`value` TEXT"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()

def seed_sample_data(force=False):
    today = date.today()
    sample_templates = [
        ("College canteen lunch", "Food", 120, "UPI", 1),
        ("Bus pass monthly recharge", "Transport", 450, "UPI", 2),
        ("Notebooks and ball pens", "Education", 180, "Cash", 3),
        ("Hostel WiFi bill share", "Bills", 250, "UPI", 5),
        ("Coffee and snacks at cafe", "Food", 160, "Card", 6),
        ("Metro card recharge", "Transport", 300, "UPI", 8),
        ("Pharmacy - cold medicine", "Other", 140, "Cash", 9),
        ("Swiggy dinner after exams", "Food", 280, "UPI", 11),
        ("Movie ticket - Weekend show", "Entertainment", 350, "Card", 12),
        ("Mobile data add-on pack", "Bills", 155, "UPI", 13),
        ("Python programming textbook", "Education", 650, "Card", 20),
        ("Canteen lunch and tea", "Food", 95, "Cash", 23),
        ("Auto fare to exam centre", "Transport", 110, "UPI", 26),
        ("Spotify student plan", "Entertainment", 59, "UPI", 29),
        ("Swiggy groceries snack pack", "Food", 220, "UPI", 33),
        ("Semester assignment printouts", "Education", 85, "Cash", 37),
        ("Electricity bill share", "Bills", 320, "Bank Transfer", 41),
        ("College fest t-shirt", "Shopping", 400, "UPI", 48),
        ("Dominos pizza treat", "Food", 550, "Card", 52),
        ("Scientific calculator", "Education", 750, "UPI", 56),
        ("Bus fare tickets", "Transport", 60, "Cash", 61),
        ("Netflix mobile subscription", "Entertainment", 149, "Card", 65),
        ("Fruit market bananas & apples", "Food", 130, "Cash", 70),
        ("Lab journal and drawing sheets", "Education", 240, "Cash", 78),
        ("Dinner at mess canteen", "Food", 110, "UPI", 84),
        ("New earphones", "Shopping", 499, "UPI", 89),
        ("Metro travel recharge", "Transport", 200, "UPI", 94),
        ("Mobile postpaid recharge", "Bills", 299, "UPI", 99),
        ("Backpack for college", "Shopping", 899, "Card", 108),
        ("College library late fine", "Education", 50, "Cash", 114),
        ("Burger and fries with friends", "Food", 210, "UPI", 121),
        ("Shared cab fare", "Transport", 140, "UPI", 128),
        ("Semester registration guide", "Education", 150, "UPI", 140),
        ("Canteen tea and samosas", "Food", 60, "Cash", 148),
        ("Hostel room water dispenser can", "Bills", 90, "Cash", 155),
        ("Gaming lounge hour", "Entertainment", 180, "UPI", 162)
    ]
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        try:
            if force:
                cur.execute("DELETE FROM expenses;")
            inserted = 0
            for desc, cat, rupees, pm, days_ago in sample_templates:
                tx_date = (today - timedelta(days=days_ago)).strftime("%Y-%m-%d")
                created_at = (today - timedelta(days=days_ago)).strftime("%Y-%m-%dT12:00:00")
                amount_paise = int(rupees * 100)
                cur.execute(
                    "INSERT INTO expenses ("
                    "amount_paise, description, category, "
                    "expense_date, payment_method, created_at"
                    ") VALUES (%s, %s, %s, %s, %s, %s);",
                    (amount_paise, desc, cat, tx_date, pm, created_at)
                )
                inserted += 1
            cur.execute("REPLACE INTO app_meta (`key`, `value`) VALUES ('demo_seeded', '1');")
            conn.commit()
            return inserted
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()
    finally:
        conn.close()

def reset_demo_data():
    return seed_sample_data(force=True)

def validate_date(date_str):
    if not date_str or not isinstance(date_str, str):
        return False
    try:
        datetime.strptime(date_str.strip(), "%Y-%m-%d")
        return True
    except ValueError:
        return False

def validate_expense(amount_paise, description, category, expense_date, payment_method):
    if not isinstance(amount_paise, int) or amount_paise <= 0:
        raise ValueError("Amount must be a positive number greater than zero.")
    if not description or not str(description).strip():
        raise ValueError("Description is required.")
    if not category or category not in CATEGORIES:
        raise ValueError(f"Category must be one of: {', '.join(CATEGORIES)}")
    if not validate_date(expense_date):
        raise ValueError("Date must be in valid YYYY-MM-DD format.")
    if not payment_method or payment_method not in PAYMENT_METHODS:
        raise ValueError(f"Payment method must be one of: {', '.join(PAYMENT_METHODS)}")

def add_expense(amount_paise, description, category, expense_date, payment_method):
    desc_clean = description.strip()
    cat_clean = category.strip()
    date_clean = expense_date.strip()
    pm_clean = payment_method.strip()
    validate_expense(amount_paise, desc_clean, cat_clean, date_clean, pm_clean)
    created_at = datetime.now().isoformat()
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        try:
            cur.execute(
                "INSERT INTO expenses ("
                "amount_paise, description, category, "
                "expense_date, payment_method, created_at"
                ") VALUES (%s, %s, %s, %s, %s, %s);",
                (amount_paise, desc_clean, cat_clean, date_clean, pm_clean, created_at)
            )
            conn.commit()
            return cur.lastrowid
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()
    finally:
        conn.close()

def update_expense(expense_id, amount_paise, description, category, expense_date, payment_method):
    desc_clean = description.strip()
    cat_clean = category.strip()
    date_clean = expense_date.strip()
    pm_clean = payment_method.strip()
    validate_expense(amount_paise, desc_clean, cat_clean, date_clean, pm_clean)
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        try:
            cur.execute(
                "UPDATE expenses "
                "SET amount_paise = %s, "
                "description = %s, "
                "category = %s, "
                "expense_date = %s, "
                "payment_method = %s "
                "WHERE id = %s;",
                (amount_paise, desc_clean, cat_clean, date_clean, pm_clean, expense_id)
            )
            conn.commit()
            return cur.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()
    finally:
        conn.close()

def delete_expense(expense_id):
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        try:
            cur.execute("DELETE FROM expenses WHERE id = %s;", (expense_id,))
            conn.commit()
            return cur.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()
    finally:
        conn.close()

def get_expense(expense_id):
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor(dictionary=True)
        try:
            cur.execute("SELECT * FROM expenses WHERE id = %s;", (expense_id,))
            row = cur.fetchone()
            return dict(row) if row else None
        finally:
            cur.close()
    finally:
        conn.close()

def get_expenses(search_query="", category="All", start_date="", end_date="", sort_by="date_desc", limit=None):
    conditions = []
    params = []
    if search_query and search_query.strip():
        conditions.append("description LIKE %s")
        params.append(f"%{search_query.strip()}%")
    if category and category != "All" and category in CATEGORIES:
        conditions.append("category = %s")
        params.append(category)
    if start_date and start_date.strip():
        conditions.append("expense_date >= %s")
        params.append(start_date.strip())
    if end_date and end_date.strip():
        conditions.append("expense_date <= %s")
        params.append(end_date.strip())

    where_clause = " WHERE " + " AND ".join(conditions) if conditions else ""
    sort_map = {
        "date_desc": "expense_date DESC, id DESC",
        "date_asc": "expense_date ASC, id ASC",
        "amount_desc": "amount_paise DESC, expense_date DESC",
        "amount_asc": "amount_paise ASC, expense_date DESC"
    }
    order_clause = sort_map.get(sort_by, "expense_date DESC, id DESC")
    limit_clause = f" LIMIT {int(limit)}" if limit is not None else ""
    sql = f"SELECT * FROM expenses{where_clause} ORDER BY {order_clause}{limit_clause};"

    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor(dictionary=True)
        try:
            cur.execute(sql, tuple(params))
            return [dict(row) for row in cur.fetchall()]
        finally:
            cur.close()
    finally:
        conn.close()

def get_recent_expenses(limit=5):
    return get_expenses(sort_by="date_desc", limit=limit)

def get_total_count():
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        try:
            cur.execute("SELECT COUNT(*) FROM expenses;")
            row = cur.fetchone()
            return row[0] if row else 0
        finally:
            cur.close()
    finally:
        conn.close()

def get_month_range(month_str):
    dt = datetime.strptime(month_str.strip(), "%Y-%m")
    last_day = calendar.monthrange(dt.year, dt.month)[1]
    return f"{month_str}-01", f"{month_str}-{last_day:02d}"

def get_monthly_summary(month_str):
    start_date, end_date = get_month_range(month_str)
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor()
        try:
            cur.execute(
                "SELECT COUNT(*), COALESCE(SUM(amount_paise), 0) "
                "FROM expenses "
                "WHERE expense_date >= %s AND expense_date <= %s;",
                (start_date, end_date)
            )
            row = cur.fetchone()
            count = int(row[0]) if row and row[0] else 0
            total_paise = int(row[1]) if row and row[1] else 0
            avg_paise = (total_paise // count) if count > 0 else 0
            return {
                "total_paise": total_paise,
                "expense_count": count,
                "avg_paise": avg_paise
            }
        finally:
            cur.close()
    finally:
        conn.close()

def get_category_breakdown(month_str):
    start_date, end_date = get_month_range(month_str)
    conn = get_connection(include_db=True)
    try:
        cur = conn.cursor(dictionary=True)
        try:
            cur.execute(
                "SELECT category, SUM(amount_paise) as cat_total, COUNT(*) as cat_count "
                "FROM expenses "
                "WHERE expense_date >= %s AND expense_date <= %s "
                "GROUP BY category "
                "ORDER BY cat_total DESC;",
                (start_date, end_date)
            )
            rows = cur.fetchall()
            return [
                {
                    "category": row["category"],
                    "total_paise": int(row["cat_total"]) if row["cat_total"] is not None else 0,
                    "count": int(row["cat_count"]) if row["cat_count"] is not None else 0
                }
                for row in rows
            ]
        finally:
            cur.close()
    finally:
        conn.close()

def shift_month(month_str, delta):
    dt = datetime.strptime(month_str.strip(), "%Y-%m")
    year = dt.year
    month = dt.month + delta
    while month > 12:
        month -= 12
        year += 1
    while month < 1:
        month += 12
        year -= 1
    return f"{year:04d}-{month:02d}"

def get_six_months_trend(curr_month_str):
    month_keys = [shift_month(curr_month_str, -i) for i in range(5, -1, -1)]
    conn = get_connection(include_db=True)
    trend = []
    try:
        cur = conn.cursor()
        try:
            for m in month_keys:
                start_date, end_date = get_month_range(m)
                cur.execute(
                    "SELECT COALESCE(SUM(amount_paise), 0), COUNT(*) "
                    "FROM expenses "
                    "WHERE expense_date >= %s AND expense_date <= %s;",
                    (start_date, end_date)
                )
                row = cur.fetchone()
                total = int(row[0]) if row and row[0] else 0
                count = int(row[1]) if row and row[1] else 0
                dt = datetime.strptime(m, "%Y-%m")
                label = dt.strftime("%b %Y")
                trend.append({
                    "month": m,
                    "label": label,
                    "total_paise": total,
                    "count": count
                })
            return trend
        finally:
            cur.close()
    finally:
        conn.close()

def migrate_from_sqlite(sqlite_path="expenses.db"):
    if not os.path.exists(sqlite_path):
        return 0, 0
    import sqlite3
    init_db()
    sqlite_conn = sqlite3.connect(sqlite_path)
    sqlite_conn.row_factory = sqlite3.Row
    try:
        s_cur = sqlite_conn.cursor()
        s_cur.execute("SELECT id, amount_paise, description, category, expense_date, payment_method, created_at FROM expenses;")
        rows = s_cur.fetchall()
        if not rows:
            return 0, 0
        mysql_conn = get_connection(include_db=True)
        try:
            m_cur = mysql_conn.cursor()
            try:
                migrated = 0
                skipped = 0
                for row in rows:
                    m_cur.execute(
                        "INSERT INTO expenses (id, amount_paise, description, category, expense_date, payment_method, created_at) "
                        "VALUES (%s, %s, %s, %s, %s, %s, %s) "
                        "ON DUPLICATE KEY UPDATE id = id;",
                        (
                            row["id"],
                            row["amount_paise"],
                            row["description"],
                            row["category"],
                            row["expense_date"],
                            row["payment_method"],
                            row["created_at"]
                        )
                    )
                    if m_cur.rowcount == 1:
                        migrated += 1
                    else:
                        skipped += 1
                mysql_conn.commit()
                return migrated, skipped
            except Exception:
                mysql_conn.rollback()
                raise
            finally:
                m_cur.close()
        finally:
            mysql_conn.close()
    finally:
        sqlite_conn.close()
