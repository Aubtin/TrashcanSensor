import boto3
import logging

from exceptions.SomethingError import SomethingError
from helpers import Variables
from datetime import datetime, timezone

from helpers.DB import DB

dynamodb = boto3.client("dynamodb")
dynamodb_paginator = dynamodb.get_paginator("query")


class Actions:
    @staticmethod
    def register(device_id: str, total_levels: int or str):
        """
        Registers a trashcan sensor.
        :param device_id: The device ID of the sensor
        :param total_levels: The total fill levels for the trashcan sensor
        :raise SomethingError: Something went wrong
        """
        register_time = datetime.now(tz=timezone.utc)
        try:
            dynamodb.transact_write_items(
                TransactItems=[
                    {
                        "Put": {
                            "TableName": Variables.DB_TABLE,
                            "Item": {
                                "pk": {"S": DB.generate_device_id(device_id)},
                                "sk": {"S": DB.DETAILS},
                                "total_levels": {"N": str(total_levels)},
                                "creation_timestamp": {"S": register_time.isoformat()}
                            },
                            "ConditionExpression": "attribute_not_exists(pk) AND attribute_not_exists(sk)"
                        }
                    },
                    {
                        "Put": {
                            "TableName": Variables.DB_TABLE,
                            "Item": {
                                "pk": {"S": DB.REPORT_CURRENT},
                                "sk": {"S": DB.generate_device_id(device_id)},
                                "total_levels": {"N": str(total_levels)},
                                "creation_timestamp": {"S": register_time.isoformat()},
                            },
                            "ConditionExpression": "attribute_not_exists(pk) AND attribute_not_exists(sk)"
                        }
                    }
                ]
            )

            return None
        except dynamodb.exceptions.TransactionCanceledException as e:
            cancellation_reason = e.response["CancellationReasons"]

            for cancellation in cancellation_reason:
                if cancellation["Code"] == "ConditionalCheckFailed":
                    return None

            logging.exception(e)
            raise SomethingError(message="An error occurred saving the device data.", code="TSC_8")
        except Exception as e:
            logging.exception(e)
            raise SomethingError(message="Something went wrong registering the device!", code="TSC_1")

    @staticmethod
    def report(device_id: str, fill_level: int):
        """
        Reports the current status of the trashcan sensor.
        :param device_id: The device ID of the sensor
        :param fill_level: The current fill level relative to the total amount of levels
        :raise SomethingError: Something went wrong
        """
        report_time = datetime.now(tz=timezone.utc)

        try:
            dynamodb.transact_write_items(
                TransactItems=[
                    {
                        "Put": {
                            "TableName": Variables.DB_TABLE,
                            "Item": {
                                "pk": {"S": DB.generate_device_id(device_id)},
                                "sk": {"S": DB.generate_report_timestamp(report_time.isoformat())},
                                "fill_level": {"N": str(fill_level)},
                                "creation_timestamp": {"S": report_time.isoformat()}
                            }
                        }
                    },
                    {
                        "Update": {
                            "TableName": Variables.DB_TABLE,
                            "Key": {
                                "pk": {"S": DB.REPORT_CURRENT},
                                "sk": {"S": DB.generate_device_id(device_id)}
                            },
                            "ExpressionAttributeValues": {
                                ":fill_level": {"N": str(fill_level)},
                                ":updated_timestamp": {"S": report_time.isoformat()}
                            },
                            "UpdateExpression": "SET fill_level = :fill_level, updated_timestamp = :updated_timestamp"
                        }
                    }
                ]
            )

            return None
        except Exception as e:
            logging.exception(e)
            raise SomethingError(message="Something went wrong reporting the device status!", code="TSC_2")

    @staticmethod
    def fetch_devices() -> list:
        """
        Fetches all of the devices and their current status.
        :return: [a dictionary of all the current device status]
        :raise SomethingError: Something went wrong
        """
        results = []

        try:
            devices_result = dynamodb_paginator.paginate(
                TableName=Variables.DB_TABLE,
                ExpressionAttributeValues={
                    ":pk": {"S": DB.REPORT_CURRENT},
                    ":sk_beginning": {"S": DB.generate_device_id("")}
                },
                KeyConditionExpression="pk = :pk AND begins_with(sk, :sk_beginning)"
            )

            for result_list in devices_result:
                results.extend([DB.unmarshall(item) for item in result_list["Items"]])

            return results
        except Exception as e:
            logging.exception(e)
            raise SomethingError("Something went wrong fetching the devices data.", "TSC_3")

    @staticmethod
    def fetch_device(device_id: str) -> (dict, [dict]):
        """
        Fetches the specific device information and a limited history.
        :param device_id: The device ID of the sensor
        :return: (device information, [device history])
        """
        # Fetch the device information.
        try:
            device_results = dynamodb.get_item(
                TableName=Variables.DB_TABLE,
                Key={
                    "pk": {"S": DB.generate_device_id(device_id)},
                    "sk": {"S": DB.DETAILS}
                }
            )
        except Exception as e:
            logging.exception(e)
            raise SomethingError(message="An error occurred finding the device details.", code="TSC_5")

        if "Item" not in device_results or not device_results["Item"]:
            raise SomethingError(message="There was no device status information available.", code="TSC_6")

        # Fetch the sensor's historical data.
        try:
            device_history = dynamodb.query(
                TableName=Variables.DB_TABLE,
                ExpressionAttributeValues={
                    ":pk": {"S": DB.generate_device_id(device_id)},
                    ":sk_beginning": {"S": DB.generate_report_timestamp("")}
                },
                KeyConditionExpression="pk = :pk AND begins_with(sk, :sk_beginning)",
                ScanIndexForward=False
            )
        except Exception as e:
            logging.exception(e)
            raise SomethingError(message="An error occurred retrieving the sensor's historical data.", code="TSC_7")

        return DB.unmarshall(device_results["Item"]), [DB.unmarshall(item) for item in device_history["Items"]]
