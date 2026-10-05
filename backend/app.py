"""
LifeDrop BD - Blood Donation Management System
Main Flask application.
"""
import os
from flask import Flask, render_template, request, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps
from datetime import date

import db
from config import SECRET_KEY

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.join(BASE_DIR, "..", "frontend")

app = Flask(
    __name__,
    template_folder=os.path.join(FRONTEND_DIR, "templates"),
    static_folder=os.path.join(FRONTEND_DIR, "static"),
)
app.secret_key = SECRET_KEY

BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']


# ---------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------
def login_required(role=None):
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            if "user_id" not in session:
                flash("Please log in first.", "warning")
                return redirect(url_for("login"))
            if role and session.get("role") != role:
                flash("You don't have permission to view that page.", "danger")
                return redirect(url_for("home"))
            return f(*args, **kwargs)
        return wrapped
    return decorator


# ---------------------------------------------------------------------
# Public pages
# ---------------------------------------------------------------------
@app.route("/")
def home():
    stats = {
        "total_donors": db.query("SELECT COUNT(*) AS c FROM donors", fetchone=True)["c"],
        "total_banks": db.query("SELECT COUNT(*) AS c FROM blood_banks", fetchone=True)["c"],
        "total_donations": db.query("SELECT COUNT(*) AS c FROM donations", fetchone=True)["c"],
        "pending_requests": db.query(
            "SELECT COUNT(*) AS c FROM blood_requests WHERE status='pending'", fetchone=True
        )["c"],
    }
    return render_template("home.html", stats=stats)


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        name = request.form["name"].strip()
        email = request.form["email"].strip().lower()
        phone = request.form["phone"].strip()
        password = request.form["password"]
        blood_group = request.form["blood_group"]
        gender = request.form["gender"]
        age = int(request.form["age"])
        area = request.form["area"].strip()
        district = request.form.get("district", "Dhaka").strip() or "Dhaka"

        existing = db.query("SELECT user_id FROM users WHERE email=%s", (email,), fetchone=True)
        if existing:
            flash("This email is already registered.", "danger")
            return redirect(url_for("register"))

        password_hash = generate_password_hash(password)
        user_id = db.execute(
            "INSERT INTO users (name, email, password_hash, phone, role) VALUES (%s,%s,%s,%s,'donor')",
            (name, email, password_hash, phone),
        )
        db.execute(
            """INSERT INTO donors (donor_id, blood_group, gender, age, area, district)
               VALUES (%s,%s,%s,%s,%s,%s)""",
            (user_id, blood_group, gender, age, area, district),
        )
        flash("Registration successful! Please log in.", "success")
        return redirect(url_for("login"))

    return render_template("register.html", blood_groups=BLOOD_GROUPS)


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form["email"].strip().lower()
        password = request.form["password"]
        user = db.query("SELECT * FROM users WHERE email=%s", (email,), fetchone=True)

        if user and check_password_hash(user["password_hash"], password):
            session["user_id"] = user["user_id"]
            session["name"] = user["name"]
            session["role"] = user["role"]
            flash(f"Welcome back, {user['name']}!", "success")
            return redirect(url_for("admin_dashboard") if user["role"] == "admin" else url_for("donor_dashboard"))

        flash("Invalid email or password.", "danger")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("Logged out.", "info")
    return redirect(url_for("home"))


# ---------------------------------------------------------------------
# Search & Request (public)
# ---------------------------------------------------------------------
@app.route("/search", methods=["GET", "POST"])
def search():
    results = None
    selected_group, selected_area = "", ""
    if request.method == "POST":
        selected_group = request.form.get("blood_group") or None
        selected_area = request.form.get("area") or None
        results = db.call_procedure("sp_find_compatible_donors", (selected_group, selected_area))

    areas = [r["area"] for r in db.query("SELECT DISTINCT area FROM donors ORDER BY area")]
    return render_template(
        "search.html", blood_groups=BLOOD_GROUPS, areas=areas,
        results=results, selected_group=selected_group, selected_area=selected_area
    )


@app.route("/request-blood", methods=["GET", "POST"])
def request_blood():
    if request.method == "POST":
        name = request.form["requester_name"].strip()
        phone = request.form["requester_phone"].strip()
        blood_group = request.form["blood_group"]
        units = int(request.form["units_needed"])
        hospital = request.form["hospital"].strip()
        bank_id = request.form.get("bank_id") or None
        urgency = request.form.get("urgency", "normal")
        requested_by = session.get("user_id")

        db.execute(
            """INSERT INTO blood_requests
               (requested_by, requester_name, requester_phone, blood_group,
                units_needed, hospital, bank_id, urgency)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
            (requested_by, name, phone, blood_group, units, hospital, bank_id, urgency),
        )
        flash("Blood request submitted. Our team / admin will review it shortly.", "success")
        return redirect(url_for("home"))

    banks = db.query("SELECT bank_id, name, area FROM blood_banks ORDER BY name")
    return render_template("request_blood.html", blood_groups=BLOOD_GROUPS, banks=banks)


@app.route("/blood-banks")
def blood_banks():
    banks = db.query("SELECT * FROM blood_banks ORDER BY name")
    inventory = db.query("SELECT * FROM view_available_inventory")
    return render_template("blood_banks.html", banks=banks, inventory=inventory)


# ---------------------------------------------------------------------
# Donor dashboard
# ---------------------------------------------------------------------
@app.route("/dashboard")
@login_required(role="donor")
def donor_dashboard():
    donor = db.query(
        """SELECT u.name, u.email, u.phone, d.* FROM donors d
           JOIN users u ON u.user_id = d.donor_id WHERE d.donor_id=%s""",
        (session["user_id"],), fetchone=True
    )
    history = db.query(
        """SELECT dn.donation_date, dn.units, b.name AS bank_name
           FROM donations dn JOIN blood_banks b ON b.bank_id = dn.bank_id
           WHERE dn.donor_id=%s ORDER BY dn.donation_date DESC""",
        (session["user_id"],)
    )
    banks = db.query("SELECT bank_id, name FROM blood_banks ORDER BY name")
    return render_template("donor_dashboard.html", donor=donor, history=history, banks=banks)


@app.route("/dashboard/log-donation", methods=["POST"])
@login_required(role="donor")
def log_donation():
    bank_id = request.form["bank_id"]
    units = int(request.form.get("units", 1))
    donation_date = request.form.get("donation_date") or date.today().isoformat()
    db.execute(
        "INSERT INTO donations (donor_id, bank_id, donation_date, units) VALUES (%s,%s,%s,%s)",
        (session["user_id"], bank_id, donation_date, units),
    )
    flash("Donation recorded. Thank you for saving lives!", "success")
    return redirect(url_for("donor_dashboard"))


# ---------------------------------------------------------------------
# Admin area
# ---------------------------------------------------------------------
@app.route("/admin")
@login_required(role="admin")
def admin_dashboard():
    totals = {
        "donors": db.query("SELECT COUNT(*) c FROM donors", fetchone=True)["c"],
        "banks": db.query("SELECT COUNT(*) c FROM blood_banks", fetchone=True)["c"],
        "pending": db.query("SELECT COUNT(*) c FROM blood_requests WHERE status='pending'", fetchone=True)["c"],
        "emergency": db.query(
            "SELECT COUNT(*) c FROM blood_requests WHERE status='pending' AND urgency='emergency'", fetchone=True
        )["c"],
    }
    group_distribution = db.query(
        "SELECT blood_group, COUNT(*) AS total FROM donors GROUP BY blood_group ORDER BY blood_group"
    )
    request_summary = db.query("SELECT * FROM view_request_summary")
    monthly = db.query("SELECT * FROM view_monthly_donations LIMIT 6")
    return render_template(
        "admin/dashboard.html", totals=totals,
        group_distribution=group_distribution, request_summary=request_summary, monthly=monthly
    )


@app.route("/admin/donors")
@login_required(role="admin")
def manage_donors():
    donors = db.query("SELECT * FROM view_active_donors ORDER BY name")
    return render_template("admin/manage_donors.html", donors=donors)


@app.route("/admin/donors/<int:donor_id>/delete", methods=["POST"])
@login_required(role="admin")
def delete_donor(donor_id):
    db.execute("DELETE FROM users WHERE user_id=%s", (donor_id,))  # cascades to donors
    flash("Donor removed.", "info")
    return redirect(url_for("manage_donors"))


@app.route("/admin/requests")
@login_required(role="admin")
def manage_requests():
    requests_ = db.query(
        """SELECT r.*, b.name AS bank_name FROM blood_requests r
           LEFT JOIN blood_banks b ON b.bank_id = r.bank_id
           ORDER BY (r.urgency='emergency') DESC, r.created_at DESC"""
    )
    banks = db.query("SELECT bank_id, name FROM blood_banks ORDER BY name")
    return render_template("admin/manage_requests.html", requests=requests_, banks=banks)


@app.route("/admin/requests/<int:request_id>/assign-bank", methods=["POST"])
@login_required(role="admin")
def assign_bank(request_id):
    bank_id = request.form["bank_id"]
    db.execute("UPDATE blood_requests SET bank_id=%s WHERE request_id=%s", (bank_id, request_id))
    flash("Blood bank assigned to request.", "info")
    return redirect(url_for("manage_requests"))


@app.route("/admin/requests/<int:request_id>/approve", methods=["POST"])
@login_required(role="admin")
def approve_request(request_id):
    """Calls the sp_approve_request stored procedure, which runs the
    inventory-check + status-update as a single transaction."""
    message = "Unknown error"
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc("sp_approve_request", (request_id, ""))
            cur.execute("SELECT @_sp_approve_request_1 AS message")
            row = cur.fetchone()
            if row and row.get("message"):
                message = row["message"]
    finally:
        conn.close()

    if message.startswith("Request approved"):
        flash(message, "success")
    else:
        flash(message, "danger")
    return redirect(url_for("manage_requests"))


@app.route("/admin/requests/<int:request_id>/reject", methods=["POST"])
@login_required(role="admin")
def reject_request(request_id):
    db.execute(
        "UPDATE blood_requests SET status='rejected', resolved_at=NOW() WHERE request_id=%s",
        (request_id,),
    )
    flash("Request rejected.", "info")
    return redirect(url_for("manage_requests"))


@app.route("/admin/inventory")
@login_required(role="admin")
def manage_inventory():
    rows = db.query("SELECT * FROM view_available_inventory")
    banks = db.query("SELECT bank_id, name FROM blood_banks ORDER BY name")
    return render_template("admin/inventory.html", rows=rows, banks=banks, blood_groups=BLOOD_GROUPS)


@app.route("/admin/inventory/update", methods=["POST"])
@login_required(role="admin")
def update_inventory():
    bank_id = request.form["bank_id"]
    blood_group = request.form["blood_group"]
    units = int(request.form["units_available"])
    db.execute(
        """INSERT INTO inventory (bank_id, blood_group, units_available)
           VALUES (%s,%s,%s)
           ON DUPLICATE KEY UPDATE units_available=%s""",
        (bank_id, blood_group, units, units),
    )
    flash("Inventory updated.", "success")
    return redirect(url_for("manage_inventory"))


if __name__ == "__main__":
    app.run(debug=True)
