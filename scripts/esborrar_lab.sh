#!/bin/bash
for i in $(seq -w 1 20); do
    NUM=$((10#$i))
    VLAN_ID=$((100 + NUM))
    for m in $(seq 1 4); do
        VMID=$((VLAN_ID * 10 + m))
        qm stop $VMID 2>/dev/null
        qm destroy $VMID --purge 2>/dev/null
    done
    pvesh delete "/pools/Lab-Alumne${i}" 2>/dev/null
    pveum user delete "alumne${i}@pve" 2>/dev/null
done
echo "Laboratori eliminat completament."
