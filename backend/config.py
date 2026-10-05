"""
LifeDrop BD - configuration
Change these values to match your local MySQL setup, or set them as
environment variables (recommended before pushing to GitHub / deploying).
"""
import os

DB_CONFIG = {
    "host": os.environ.get("LIFEDROP_DB_HOST", "localhost"),
    "user": os.environ.get("LIFEDROP_DB_USER", "root"),
    "password": os.environ.get("LIFEDROP_DB_PASSWORD", ""),
    "database": os.environ.get("LIFEDROP_DB_NAME", "lifedrop_bd"),
}

SECRET_KEY = os.environ.get("LIFEDROP_SECRET_KEY", "change-this-secret-key-in-production")
