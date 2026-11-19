#!/bin/bash

echo "=== 1. Eliminant contenidors LXC amb ID > 2000 ==="
for ctid in $(pct list | awk 'NR>1 && $1>2000 {print $1}'); do
    echo "Aturant i eliminant CT $ctid..."
    pct stop $ctid 2>/dev/null
    pct destroy $ctid --purge 1
done

echo "=== 2. Eliminant VMs 2014 i 2024 ==="
for vmid in 2014 2024; do
    if qm status $vmid &>/dev/null; then
        echo "Aturant i eliminant VM $vmid..."
        qm stop $vmid --skiplock 1 2>/dev/null
        qm destroy $vmid --purge 1 --destroy-unreferenced-disks 1
    else
        echo "La VM $vmid no existeix."
    fi
done

echo "=== 3. Eliminant Resource Pools que comencen per 'lab' ==="
for pool in $(pvesh get /pools --output-format json | python3 -c "import sys,json; print('\n'.join(p['poolid'] for p in json.load(sys.stdin) if p['poolid'].lower().startswith('lab')))"); do
    echo "Eliminant Pool $pool..."
    pvesh delete "/pools/$pool"
done

echo "=== Neteja completada! ==="
