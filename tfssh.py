#!/usr/bin/env python3
"""
Ssh to remote system.

arg: ansible host alias
"""

# pylint: disable=invalid-name

import json
import os
import sys
from operator import itemgetter

import ansible_runner
import typer

INVENTORY = "hosts.ini"
__version__ = "0.1.0"


def version_callback(value: bool):
    """
    Report the version of this script
    """
    if value:
        print(f"Version v{__version__}")
        raise typer.Exit()


def main(
    ansible_host_alias: str = typer.Argument(
        "manager0", help="Ansible hostname alias to connect to"
    ),
    version: bool | None = typer.Option(
        None, "--version", callback=version_callback, help="Version of this script."
    ),
):
    """
    Main function
    """

    if not os.path.exists(INVENTORY):
        sys.exit(f"Inventory file not found: {INVENTORY}")

    host_list_raw = ansible_runner.get_inventory(
        inventories=["hosts.ini"], action="list", quiet=True
    )
    hosts_l = list(json.loads(host_list_raw[0])["_meta"]["hostvars"].keys())
    if ansible_host_alias not in hosts_l:
        print(f"'{ansible_host_alias}' not found in inventory. Try one of these hosts instead:")
        for h in hosts_l:
            print(f"\t{h}")
        sys.exit(1)

    host_raw = ansible_runner.get_inventory(
        inventories=[INVENTORY], action="host", host=ansible_host_alias, quiet=True
    )

    try:
        host_json = json.loads(host_raw[0])
    except json.JSONDecodeError:
        sys.exit(f"{ansible_host_alias} not a valid ansible host alias")

    user, host, ssh_key_path = itemgetter(
        "ansible_user", "ansible_host", "ansible_ssh_private_key_file"
    )(host_json)

    # Execute ssh command
    ssh_command = f"ssh -i {ssh_key_path} {user}@{host}"
    os.system(ssh_command)


if __name__ == "__main__":
    typer.run(main)
