from flask import Flask, request
from flask_cors import CORS

from helpers.Actions import Actions
from exceptions.SomethingError import SomethingError
from helpers import Variables
from helpers.Outputs import Outputs
from helpers.responses import success, fail, error

app = Flask(__name__)
CORS(app, origins="*")


@app.route("/", methods=["GET"])
def hello():
    return success(message="Trash Can Sensor API")


@app.route("/register", methods=["PUT"])
def register_device():
    """
    Registers a device.
    _______
    Method: PUT
        parameters:
        - deviceId (string): ID of the trash can sensor device
        - totalLevels (int): Total amount of levels the trash can sensor checks

        response (json):
            success:
                - status
                - data
                    - message (string): Message explaining that the registration succeeded
                    - device_id (string): ID of the registered device
                    - total_levels (int): Total amount of levels the trash can sensor checks
            fail:
                - status
                - data
                    - message: Message explaining what went wrong
            error:
                - status
                - message: Message explaining what went wrong
                - code: An error code for the event
    """
    if request.method == "PUT":
        device_id = request.args.get("deviceId")
        total_levels = request.args.get("totalLevels")

        if device_id is None:
            return fail(message="The parameter 'deviceId' is required.")
        if total_levels is None or not total_levels.isdigit():
            return fail(message="The parameter 'totalLevels' is required and must be an integer.")

        try:
            Actions.register(device_id, total_levels)
            return success(message="Registered device.", device_id=device_id, total_levels=int(total_levels))
        except SomethingError as e:
            return error(message=e.message, code=e.code)


@app.route("/report", methods=["PUT"])
def report():
    """
    Registers the sensor readings of a device.
    _______
    Method: PUT
        parameters:
        - deviceId (string): ID of the trash can sensor device
        - fillLevel (int): Current fill level of the trash can

        response (json):
            success:
                - status
                - data
                    - message (string): Message explaining that the report succeeded
                    - device_id (string): ID of the registered device
                    - fill_level (int): Current fill level of the trash can
            fail:
                - status
                - data
                    - message: Message explaining what went wrong
            error:
                - status
                - message: Message explaining what went wrong
                - code: An error code for the event
    """
    if request.method == "PUT":
        device_id = request.args.get("deviceId")
        fill_level = request.args.get("fillLevel")

        if device_id is None:
            return fail(message="The parameter 'deviceId' is required.")
        if fill_level is None or not fill_level.isdigit():
            return fail(message="The parameter 'fillLevel' is required and must be an integer.")

        try:
            Actions.report(device_id, fill_level)
            return success(message="Reported device status.", device_id=device_id, fill_level=fill_level)
        except SomethingError as e:
            return error(message=e.message, code=e.code)


@app.route("/devices", methods=["GET", "OPTIONS"])
def devices():
    """
    Fetches all of the devices and their current status information.
    _______
    Method: GET
        parameters:
            None

        response (json):
            success:
                - status
                - data (list of dict)
                    - id (string): ID of the device
                    - fill_level (int): Current fill level of the trash can
                    - total_levels (int): Total possible fill level of the trash can
                    - creation_timestamp (string): Creation timestamp in ISO8601
                    - updated_timestamp (string): Last updated timestamp in ISO8601
            fail:
                - status
                - data
                    - message: Message explaining what went wrong
            error:
                - status
                - message: Message explaining what went wrong
                - code: An error code for the event
    """
    try:
        devices_result = Actions.fetch_devices()
    except SomethingError as e:
        return error(message=e.message, code=e.code)

    return success(devices=Outputs.devices(devices_result))


@app.route("/device", methods=["GET", "OPTIONS"])
def device_information():
    """
    Fetches the device information and its most recent history.
    _______
    Method: GET
        parameters:
            - deviceId (string): ID of the trash can sensor device

        response (json):
            success:
                - status
                - data (list of dict)
                    - device
                        - id (string): ID of the device
                        - total_levels (int): Total possible fill level of the trash can
                        - creation_timestamp (string): Creation timestamp in ISO8601
                    - history
                        - id (string): ID of the device
                        - fill_level (int): Current fill level of the trash can
                        - total_levels (int): Total possible fill level of the trash can
                        - creation_timestamp (string): Creation timestamp in ISO8601
            fail:
                - status
                - data
                    - message: Message explaining what went wrong
            error:
                - status
                - message: Message explaining what went wrong
                - code: An error code for the event
    """
    device_id = request.args.get("deviceId")

    if device_id is None:
        return error(message="Something went wrong fetching the device id.", code="TCS_4")

    try:
        device_details, device_history = Actions.fetch_device(device_id)
    except SomethingError as e:
        return error(message=e.message, code=e.code)

    return success(device=Outputs.device_detail(device_details), history=Outputs.device_history(device_history))


if __name__ == "__main__":
    if Variables.STAGE == "production":
        app.run(host="0.0.0.0", port=80)
    else:
        app.run()
