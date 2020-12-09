import re
from datetime import datetime, timezone
from boto3.dynamodb.types import TypeDeserializer, Decimal


class DB:
    DETAILS = "details"
    REPORT_CURRENT = "report#current"

    @staticmethod
    def generate_device_id(device_id: str) -> str:
        return f"device#{device_id}"

    @staticmethod
    def extract_device_id(content: str):
        content_regex = re.match(r"^device#(.+)$", content)

        return content_regex[1] if content_regex else None

    @staticmethod
    def generate_report_timestamp(timestamp: str = datetime.now(tz=timezone.utc).isoformat()):
        return f"report#timestamp#{timestamp}"

    @staticmethod
    def unmarshall(content: dict):
        def fix_decimal(value: Decimal or float or int):
            if isinstance(value, Decimal):
                value_float = float(value)

                return int(value_float) if value_float.is_integer() else value_float

            return value

        # Will not work as-is for all value types if converting to JSON.
        deserializer = TypeDeserializer()
        return {key: fix_decimal(deserializer.deserialize(value)) for key, value in content.items()}