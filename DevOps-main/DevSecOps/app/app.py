"""DevSecOps Dashboard - Flask app shipped by the Session 17 pipeline.

Security notes (things the SAST stage checks for):
  * debug mode is never enabled (Bandit B201)
  * the dev server binds to 127.0.0.1 by default; containers use gunicorn (Bandit B104)
  * randomness comes from secrets.SystemRandom, not the `random` module (Bandit B311)
"""

import datetime
import os
import platform
import secrets
import sys

from flask import Flask, jsonify, render_template, request

APP_VERSION = os.environ.get("APP_VERSION", "dev")

app = Flask(__name__)

_rng = secrets.SystemRandom()
_request_count = 0
_start_time = datetime.datetime.now(datetime.timezone.utc)


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _timestamp():
    return _now().isoformat().replace("+00:00", "Z")


@app.before_request
def _count_request():
    global _request_count
    _request_count += 1


@app.after_request
def _security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response


# ── Pages ──────────────────────────────────────────────────


@app.route("/")
def home():
    return render_template("index.html")


# ── Health & status ────────────────────────────────────────


@app.route("/health")
def health():
    uptime_seconds = (_now() - _start_time).total_seconds()
    return jsonify(status="healthy", uptime_seconds=round(uptime_seconds, 2), timestamp=_timestamp())


@app.route("/api/status")
def status():
    uptime = _now() - _start_time
    hours, remainder = divmod(int(uptime.total_seconds()), 3600)
    minutes, seconds = divmod(remainder, 60)
    return jsonify(
        app="DevSecOps Dashboard",
        version=APP_VERSION,
        status="running",
        python_version=sys.version.split()[0],
        platform=platform.system(),
        uptime=f"{hours:02d}h {minutes:02d}m {seconds:02d}s",
        total_requests=_request_count,
        timestamp=_timestamp(),
    )


# ── Greeting ───────────────────────────────────────────────


@app.route("/api/greet/<name>")
def greet(name):
    name = name[:50]
    greetings = [
        f"Hello, {name}!",
        f"Hey {name}, welcome aboard!",
        f"Greetings, {name}! You rock!",
        f"What's up, {name}! Happy coding!",
        f"Hi {name}! May your pipelines always pass!",
    ]
    return jsonify(message=_rng.choice(greetings), name=name, timestamp=_timestamp())


# ── Math ───────────────────────────────────────────────────


def _parse_numbers(data, *keys):
    values = [data.get(k) for k in keys]
    if any(v is None for v in values):
        raise KeyError
    return [float(v) for v in values]


@app.route("/api/add", methods=["POST"])
def add_numbers():
    data = request.get_json(silent=True)
    if not data:
        return jsonify(error="No JSON body provided"), 400
    try:
        n1, n2 = _parse_numbers(data, "number1", "number2")
    except KeyError:
        return jsonify(error="Both number1 and number2 are required"), 400
    except (TypeError, ValueError):
        return jsonify(error="Values must be numbers"), 400
    return jsonify(number1=n1, number2=n2, operation="addition", result=n1 + n2)


_OPERATIONS = {
    "add": (lambda a, b: a + b, "+"),
    "subtract": (lambda a, b: a - b, "-"),
    "multiply": (lambda a, b: a * b, "×"),
    "divide": (lambda a, b: a / b, "÷"),
    "power": (lambda a, b: a ** b, "^"),
    "modulo": (lambda a, b: a % b, "%"),
}


@app.route("/api/calculate", methods=["POST"])
def calculate():
    data = request.get_json(silent=True)
    if not data:
        return jsonify(error="No JSON body provided"), 400

    op = data.get("operation", "add")
    if op not in _OPERATIONS:
        return jsonify(error=f"Unknown operation '{op}'. Valid: {list(_OPERATIONS)}"), 400

    try:
        a, b = _parse_numbers(data, "a", "b")
    except KeyError:
        return jsonify(error="Fields 'a' and 'b' are required"), 400
    except (TypeError, ValueError):
        return jsonify(error="Values must be numbers"), 400

    func, symbol = _OPERATIONS[op]
    if op == "power" and abs(b) > 1000:
        return jsonify(error="Exponent too large"), 400
    try:
        result = round(func(a, b), 10)
    except ZeroDivisionError:
        return jsonify(error="Division by zero"), 400
    except OverflowError:
        return jsonify(error="Result too large"), 400

    return jsonify(
        a=a, b=b, operation=op, symbol=symbol, result=result,
        expression=f"{a} {symbol} {b} = {result}",
    )


# ── Pipeline simulator ─────────────────────────────────────

PIPELINE_STAGES = [
    {"name": "Build", "icon": "📦"},
    {"name": "Unit Test", "icon": "🧪"},
    {"name": "SAST", "icon": "🔍"},
    {"name": "SCA", "icon": "📚"},
    {"name": "Secret Scan", "icon": "🔑"},
    {"name": "Docker Build", "icon": "🐳"},
    {"name": "Image Scan", "icon": "🛡️"},
    {"name": "Security Gate", "icon": "🚦"},
    {"name": "Push Image", "icon": "📤"},
    {"name": "Deploy to K8s", "icon": "☸️"},
]


@app.route("/api/pipeline/run", methods=["POST"])
def run_pipeline():
    data = request.get_json(silent=True) or {}
    branch = str(data.get("branch", "main"))[:100]
    try:
        fail_chance = min(max(float(data.get("fail_chance", 0.1)), 0.0), 1.0)
    except (TypeError, ValueError):
        return jsonify(error="fail_chance must be a number between 0 and 1"), 400

    stages = []
    failed = False
    for stage in PIPELINE_STAGES:
        if failed:
            status, duration = "skipped", 0
        elif _rng.random() < fail_chance:
            status, duration, failed = "failed", round(_rng.uniform(0.5, 5.0), 2), True
        else:
            status, duration = "passed", round(_rng.uniform(0.5, 15.0), 2)
        stages.append({**stage, "status": status, "duration_s": duration})

    return jsonify(
        run_id=f"run-{_rng.randint(1000, 9999)}",
        branch=branch,
        overall_status="failed" if failed else "passed",
        total_time_s=round(sum(s["duration_s"] for s in stages), 2),
        stages=stages,
        triggered_at=_timestamp(),
    )


# ── Error handlers ─────────────────────────────────────────


@app.errorhandler(404)
def not_found(_error):
    return jsonify(error="Route not found", code=404), 404


@app.errorhandler(500)
def server_error(_error):
    return jsonify(error="Internal server error", code=500), 500


if __name__ == "__main__":
    # Local development only - production runs under gunicorn (see Dockerfile)
    app.run(host=os.environ.get("HOST", "127.0.0.1"), port=int(os.environ.get("PORT", "5001")))
