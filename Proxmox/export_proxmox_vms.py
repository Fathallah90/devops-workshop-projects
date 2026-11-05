
#!/usr/bin/env python3

import subprocess
import json
import csv
import os

OUTPUT = "/root/proxmox_vms_export.csv"


def pvesh_get(path):
    result = subprocess.run(
        ["pvesh", "get", path, "--output-format", "json"],
        capture_output=True,
        text=True,
        check=True
    )
    return json.loads(result.stdout)


# Get all VMs and containers across the cluster
resources = pvesh_get("/cluster/resources") 

inventory = [
    item for item in resources
    if item.get("type") in ("qemu", "lxc")
]

export_data = []

for vm in inventory:

    vmid = vm["vmid"]
    node = vm["node"]
    vm_type = vm["type"]

    print(f"Exporting {vm_type.upper()} {vmid} from {node}")

    if vm_type == "qemu":
        config_path = f"/nodes/{node}/qemu/{vmid}/config"
    else:
        config_path = f"/nodes/{node}/lxc/{vmid}/config"

    try:
        config = pvesh_get(config_path)
    except Exception as e:
        print(f"ERROR exporting {vmid}: {e}")
        config = {}

    # Merge inventory properties and VM configuration
    record = {
        "vmid": vmid,
        "node": node,
        "type": vm_type,
        **vm,
        **config
    }

    # Convert complex values into CSV-compatible strings
    for key, value in record.items():
        if isinstance(value, (dict, list)):
            record[key] = json.dumps(value)

    export_data.append(record)


# Collect every available property into CSV columns
columns = sorted({
    key
    for record in export_data
    for key in record.keys()
})

with open(OUTPUT, "w", newline="", encoding="utf-8-sig") as csvfile:

    writer = csv.DictWriter(
        csvfile,
        fieldnames=columns,
        extrasaction="ignore"
    )

    writer.writeheader()
    writer.writerows(export_data)

print(f"\nExport completed successfully!")
print(f"Total VMs/containers: {len(export_data)}")
print(f"CSV file: {OUTPUT}")