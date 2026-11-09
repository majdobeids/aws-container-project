import os
from pathlib import Path

import psycopg
from flask import Flask, jsonify

app = Flask(__name__)


def database_ping():
    password_file = os.environ.get(
        "DB_PASSWORD_FILE",
        "/run/secrets/db_password",
    )
    password = Path(password_file).read_text().strip()

    with psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=password,
        connect_timeout=3,
        options="-c statement_timeout=3000",
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")

            if cursor.fetchone() != (1,):
                raise RuntimeError("Database probe failed")


@app.get("/")
def index():
    return jsonify(
        message="Automated deployment on AWS",
        stack=["Nginx", "Flask", "Postgres"],
        health="/health",
    )


@app.get("/health")
def health():
    try:
        database_ping()
        return jsonify(
            status="ok",
            database="reachable",
        ), 200

    except (psycopg.Error, OSError, KeyError, RuntimeError):
        return jsonify(
            status="unhealthy",
            database="unreachable",
        ), 503
