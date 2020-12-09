from flask import jsonify


def success(**kwargs):
    return jsonify(status="success", data=kwargs), 200


def fail(**kwargs):
    return jsonify(status="fail", data=kwargs), 400


def error(code: str, message: str):
    return jsonify(status="error", code=code, message=message), 500
