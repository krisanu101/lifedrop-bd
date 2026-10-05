"""
LifeDrop BD - Database connection helper
Uses PyMySQL to connect to the MySQL database defined in config.py.
"""
import pymysql
import pymysql.cursors
from config import DB_CONFIG


def get_connection():
    """Return a new MySQL connection with dict-style cursors."""
    return pymysql.connect(
        host=DB_CONFIG["host"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
        database=DB_CONFIG["database"],
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def query(sql, params=None, fetchone=False):
    """Run a SELECT query and return results as a list of dicts (or one dict)."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            return cur.fetchone() if fetchone else cur.fetchall()
    finally:
        conn.close()


def execute(sql, params=None):
    """Run an INSERT / UPDATE / DELETE statement. Returns the new row id (if any)."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            return cur.lastrowid
    finally:
        conn.close()


def call_procedure(name, params=None):
    """Call a stored procedure and return whatever result set it produces."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc(name, params or ())
            results = cur.fetchall()
            return results
    finally:
        conn.close()
