"""Calculator web API - the service the CD pipeline ships to Kubernetes."""

import os

from flask import Flask, jsonify, request

from app.calculator import OPERATIONS

APP_VERSION = os.environ.get("APP_VERSION", "dev")

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        app="session16-calculator",
        version=APP_VERSION,
        endpoints=["/health", "/api/<operation>?a=<num>&b=<num>"],
        operations=sorted(OPERATIONS),
    )


@app.get("/health")
def health():
    return jsonify(status="ok", version=APP_VERSION)


@app.get("/api/<operation>")
def calculate(operation):
    func = OPERATIONS.get(operation)
    if func is None:
        return jsonify(error=f"unknown operation '{operation}'"), 404

    try:
        a = float(request.args["a"])
        b = float(request.args["b"])
    except KeyError:
        return jsonify(error="query parameters 'a' and 'b' are required"), 400
    except ValueError:
        return jsonify(error="'a' and 'b' must be numbers"), 400

    try:
        result = func(a, b)
    except ValueError as exc:
        return jsonify(error=str(exc)), 400

    return jsonify(operation=operation, a=a, b=b, result=result)
