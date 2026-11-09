#!/usr/bin/env python3
"""Generate an Ansible inventory from Terraform JSON outputs."""

import argparse
import ipaddress
import json
import os
from pathlib import Path
import shlex
import sys


def build_inventory(outputs, key_path, known_hosts_path):
    def value(name):
        result = outputs[name]["value"]
        if not isinstance(result, str) or not result:
            raise ValueError(f"Invalid Terraform output: {name}")
        return result

    addresses = {
        name: str(ipaddress.IPv4Address(value(name)))
        for name in (
            "web_public_ip",
            "db_public_ip",
            "db_private_ip",
        )
    }

    ssh_options = (
        "-o StrictHostKeyChecking=accept-new "
        "-o UserKnownHostsFile="
        + shlex.quote(str(Path(known_hosts_path).resolve()))
    )

    return {
        "all": {
            "vars": {
                "ansible_user": "ubuntu",
                "ansible_python_interpreter": "/usr/bin/python3",
                "ansible_ssh_private_key_file": str(
                    Path(key_path).resolve()
                ),
                "ansible_ssh_common_args": ssh_options,
                "db_private_ip": addresses["db_private_ip"],
                "backup_bucket": value("backup_bucket"),
                "aws_region": value("aws_region"),
            },
            "children": {
                "web": {
                    "hosts": {
                        "web1": {
                            "ansible_host": addresses["web_public_ip"]
                        }
                    }
                },
                "db": {
                    "hosts": {
                        "db1": {
                            "ansible_host": addresses["db_public_ip"]
                        }
                    }
                },
            },
        }
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", required=True)
    parser.add_argument("--known-hosts", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    try:
        outputs = json.load(sys.stdin)
        inventory = build_inventory(
            outputs, args.key, args.known_hosts
        )

        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)

        descriptor = os.open(
            output,
            os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
            0o600,
        )

        with os.fdopen(descriptor, "w") as stream:
            os.fchmod(stream.fileno(), 0o600)
            json.dump(inventory, stream, indent=2)
            stream.write("\n")

    except (KeyError, TypeError, ValueError, OSError) as error:
        parser.exit(1, f"Inventory generation failed: {error}\n")


if __name__ == "__main__":
    main()
