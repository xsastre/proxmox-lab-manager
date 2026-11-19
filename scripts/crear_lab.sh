#!/bin/bash
# scripts/crear_lab.sh
# ==============================================================================
# DESPLEGAMENT AUTOMÀTIC LABORATORI PROXMOX VE 
# ==============================================================================

NUM_ALUMNES=20
MAQUINES_PER_ALUMNE=4
TEMPLATE_ID=9000           # ID de la teva plantilla base a Proxmox
BRIDGE="vmbr1"             # Bridge intern VLAN-aware
PASSWORD_BASE="LabAlumne2026!" # Contrasenya inicial per als alumnes

for i in $(seq -w 1 $NUM_ALUMNES); do
    NUM=$((10#$i))
    VLAN_ID=$((100 + NUM))
    USUARI="alumne${i}@pve"
    POOL="Lab-Alumne${i}"

    echo "=========================================================="
    echo "Configurant Alumne $i (Usuari: $USUARI | Pool: $POOL | VLAN: $VLAN_ID)"
    echo "=========================================================="

    # 1. Crear l'usuari al realm intern de Proxmox (pve)
    pveum user add "$USUARI" --password "$PASSWORD_BASE" --comment "Alumne $i Laboratori"

    # 2. Crear el Resource Pool de l'alumne
    pvesh create /pools --poolid "$POOL" --comment "Màquines de l'alumne $i"

    # 3. Assignar permisos (Rol PVEVMUser)
    pveum acl modify "/pool/$POOL" --users "$USUARI" --roles PVEVMUser

    # 4. Clonar les màquines virtuals de l'alumne i assignar VLAN
    for m in $(seq 1 $MAQUINES_PER_ALUMNE); do
        VMID=$((VLAN_ID * 10 + m))
        VM_NAME="al${i}-vm0${m}"

        echo "  -> Creant MV $VM_NAME (ID: $VMID) a la VLAN $VLAN_ID..."

        # Linked Clone dins del Pool de l'alumne
        qm clone $TEMPLATE_ID $VMID --name "$VM_NAME" --pool "$POOL" --full 0

        # Configurar la targeta de xarxa net0 al bridge intern
        qm set $VMID --net0 virtio,bridge=$BRIDGE,tag=$VLAN_ID
    done
done

echo "Desplegament finalitzat amb èxit!"
