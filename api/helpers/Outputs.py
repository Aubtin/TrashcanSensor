from helpers.DB import DB


class Outputs:
    @staticmethod
    def devices(devices: list) -> list:
        """
        Converts the database results for the devices status list into a user-friendly format.
        :param devices: List of all the device information
        :return: The user-friendly formatted output
        """
        devices_formatted = []

        for index, item in enumerate(devices):
            devices_formatted.append({**item})

            del devices_formatted[index]["pk"]

            devices_formatted[index]["id"] = DB.extract_device_id(devices_formatted[index]["sk"])
            del devices_formatted[index]["sk"]

        return devices_formatted

    @staticmethod
    def device_detail(device: dict) -> dict:
        """
        Converts the database results for the device details into a user-friendly format.
        :param device: The device details
        :return: The user-friendly formatted output
        """
        device_formatted = {**device}

        device_formatted["id"] = DB.extract_device_id(device_formatted["pk"])
        del device_formatted["pk"]

        del device_formatted["sk"]

        return device_formatted

    @staticmethod
    def device_history(history: list) -> list:
        """
        Converts the database results for the device history into a user-friendly format.
        :param history: The history of the device
        :return: The user-friendly formatted output
        """
        history_formatted = []

        for index, item in enumerate(history):
            history_formatted.append({**item})

            history_formatted[index]["id"] = DB.extract_device_id(history_formatted[index]["pk"])
            del history_formatted[index]["pk"]

            del history_formatted[index]["sk"]

        return history_formatted
