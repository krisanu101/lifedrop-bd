"""
LifeDrop BD - Automatic database setup

Runs all the .sql files in ../database/ (schema, triggers, procedures,
views, seed data) in the correct order, using only PyMySQL — no need to
manually open a MySQL client. Safe to run more than once: if the database
is already set up, it skips straight to done.

This is called automatically by start.bat / start.sh, but you can also
run it directly:  python setup_database.py
"""
import os
import sys
import pymysql

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import DB_CONFIG

DATABASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "database")
SQL_FILES = [
    "01_schema.sql",
    "02_triggers.sql",
    "03_procedures.sql",
    "04_views.sql",
    "05_seed_data.sql",
]


def split_statements(sql_text: str):
    """Split a .sql file into individual statements.
    Files that use `DELIMITER $$` (triggers/procedures) are split on $$;
    plain files are split on ; . DELIMITER lines themselves are dropped —
    they're a mysql-CLI-only instruction, not needed when we send each
    statement to the server ourselves."""
    lines = [ln for ln in sql_text.splitlines() if not ln.strip().upper().startswith("DELIMITER")]
    text = "\n".join(lines)
    if "$$" in text:
        parts = [p.strip() for p in text.split("$$")]
    else:
        parts = [p.strip() for p in text.split(";")]
    return [p for p in parts if p]


def already_set_up(conn) -> bool:
    try:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {DB_CONFIG['database']}.users")
        return True
    except Exception:
        return False


def main():
    print("LifeDrop BD - checking database...")
    try:
        conn = pymysql.connect(
            host=DB_CONFIG["host"],
            user=DB_CONFIG["user"],
            password=DB_CONFIG["password"],
            autocommit=True,
        )
    except Exception as e:
        print("\n❌ Could not connect to MySQL.")
        print(f"   Error: {e}")
        print("   Make sure MySQL is running (e.g. start it from the XAMPP control panel)")
        print("   and that backend/config.py has the correct host/user/password.")
        sys.exit(1)

    if already_set_up(conn):
        print("✅ Database already set up. Skipping.")
        conn.close()
        return

    print("Setting up database for the first time, this takes a few seconds...")
    for fname in SQL_FILES:
        path = os.path.join(DATABASE_DIR, fname)
        print(f"  -> running {fname}")
        with open(path, "r", encoding="utf-8") as f:
            sql_text = f.read()
        with conn.cursor() as cur:
            for statement in split_statements(sql_text):
                cur.execute(statement)

    conn.close()
    print("✅ Database setup complete.")


if __name__ == "__main__":
    main()
