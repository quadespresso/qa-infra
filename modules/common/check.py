#!/usr/bin/env python
"""Attempt to discover our public IP, using a list of sites that do this."""

import requests
import yaml
import json


IP_SERVICES_FILE = "ip_services.yaml"


class DeadServiceException(Exception):
    """Exception raised when all services are dead."""

    # pass


def get_ip_address(url):
    """Attempt to retrieve our public IP address from the given URL."""
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            return response.text.strip()
    except requests.RequestException:
        pass

    return None


def main():
    """Loop through list of IP addresses and check each one."""
    with open(IP_SERVICES_FILE, "r", encoding="utf-8") as file:
        urls = yaml.safe_load(file)

    for url in urls:
        ip_address = get_ip_address(url)
        if ip_address:
            ip_json = json.dumps({"ip": ip_address})
            print(ip_json)
            return

    raise DeadServiceException("Unable to retrieve IP address from any URL.")


if __name__ == "__main__":
    main()
