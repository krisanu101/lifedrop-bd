# LifeDrop BD
### Advanced DBMS-based Blood Donation Management System

LifeDrop BD is a full-stack web application that connects blood donors, recipients and
blood banks across Bangladesh. It's built to demonstrate a complete, production-style
relational database design (triggers, stored procedures, views, transactions, indexing,
audit logging) alongside a working Flask web application on top of it.

---

## Features

**Public / Donor**
- Donor registration & login (passwords hashed with Werkzeug)
- Search compatible, *eligible* donors by blood group and area
- Submit a blood request (with an Emergency flag)
- Blood bank directory with live inventory
- Donor dashboard: profile, donation history, log a new donation

**Admin**
- Dashboard with live charts (donors by blood group, requests by blood group)
- Manage donors (view eligibility status, remove donors)
- Manage requests: assign a blood bank, approve (via stored procedure + transaction),
  or reject — emergency requests are highlighted
- Manage inventory: set/update stock per bank per blood group

**Database (the "advanced DBMS" part)**
- **Triggers** — donations auto-update inventory & donor history; approved requests
  auto-deduct inventory; donor changes are auto-logged
- **Stored Procedures** — `sp_find_compatible_donors` (blood-group compatibility +
  90-day eligibility), `sp_approve_request` (stock check + deduction as one transaction)
- **Views** — `view_available_inventory`, `view_active_donors`, `view_monthly_donations`,
  `view_request_summary`
- **Transactions** — approving a request either fully succeeds (status updated + stock
  deducted) or fully rolls back (e.g. insufficient stock) — never a half-done state
- **Indexes** — on blood group / area / status columns used in every search
- **Audit log** — every donor change and request approval is recorded automatically

See [`ER_DIAGRAM.md`](ER_DIAGRAM.md) for the full schema diagram and normalization notes.

---

## 🗂️ Project Structure

```
lifedrop-bd/
├── start.bat                 
├── start.sh                 
├── README.md
├── ER_DIAGRAM.md             # ER diagram (Mermaid) + normalization notes
├── CV_AND_INTERVIEW_GUIDE.md # CV bullet points + interview Q&A (Bangla)
├── database/                 # SQL — run once, or let start.bat/start.sh do it
│   ├── 01_schema.sql         # Tables, constraints, indexes
│   ├── 02_triggers.sql       # All triggers
│   ├── 03_procedures.sql     # Stored procedures
│   ├── 04_views.sql          # Views
│   └── 05_seed_data.sql      # Blood compatibility rules + sample data + admin login
├── backend/                  # Flask application (Python)
│   ├── app.py                 # All routes
│   ├── db.py                  # MySQL connection helper (PyMySQL)
│   ├── config.py               # DB config (reads from environment variables)
│   ├── setup_database.py       # Auto-runs the database/ SQL files
│   └── requirements.txt
└── frontend/                 # Templates & static assets
    ├── templates/              # Jinja2 + Bootstrap 5 pages
    │   ├── base.html, home.html, login.html, register.html, ...
    │   └── admin/               # Admin-only pages
    └── static/
        └── css/style.css
```

## Why two separate scenarios exist in the code

- `sp_find_compatible_donors` filters by **both** blood-group compatibility (via the
  `blood_compatibility` lookup table) **and** eligibility (≥90 days since last donation),
  so the search results are people who can actually donate right now — not just a
  blood-group match.
- `sp_approve_request` is wrapped in an explicit `START TRANSACTION` / `COMMIT` /
  `ROLLBACK` so that "check stock" and "deduct stock" can never happen as two separate,
  interruptible steps — a common real-world bug in systems that check-then-update without
  a transaction (race conditions, overselling stock, etc.).

---

## Tech Stack

Python (Flask) · MySQL · PyMySQL · Jinja2 · Bootstrap 5 · Chart.js

## Disclaimer

This is an educational / portfolio project. It is not a certified medical or emergency
service. In a real emergency, contact a hospital or blood bank directly.

## 👤 Author

Krisanu Das
www.linkedin.com/in/krisanu-das


