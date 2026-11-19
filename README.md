# 🎓 Proxmox Lab Manager - Classic Edition

![Proxmox VE](https://img.shields.io/badge/Proxmox%20VE-8.x-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![MikroTik](https://img.shields.io/badge/MikroTik-RouterOS%20v7-231F20?style=for-the-badge)
![Nginx](https://img.shields.io/badge/Nginx-Proxy-009639?style=for-the-badge&logo=nginx&logoColor=white)
![HTML5](https://img.shields.io/badge/Frontend-Vanilla_HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)

**Proxmox Lab Manager** és una aplicació web lleugera, autònoma i sense dependències de backend dissenyada per a entorns educatius. Permet als docents desplegar de forma massiva laboratoris virtuals aïllats per a cada alumne utilitzant VLANs, integrant-se directament amb l'API de **Proxmox VE** i automatitzant l'enrutament amb l'API REST de **MikroTik RouterOS**.

---

## 📑 Índex
1. [Característiques](#-característiques)
2. [Arquitectura de Xarxa](#-arquitectura-de-xarxa)
3. [Requisits Previs](#-requisits-previs)
4. [Guia d'Instal·lació i Desplegament](#-guia-dinstal%C2%B7laci%C3%B3-i-desplegament)
   - [1. Preparació de Proxmox](#1-preparaci%C3%B3-de-proxmox-ve)
   - [2. Router MikroTik CHR](#2-configuraci%C3%B3-del-router-mikrotik-chr)
   - [3. Desplegament de l'App (LXC + Nginx)](#3-desplegament-de-lapp-web-lxc--nginx)
5. [Ús de l'Aplicació](#-manual-d%C3%BAs)

---

## ✨ Característiques

- 🚀 **Desplegament Massiu:** Crea Màquines Virtuals (QEMU) i Contenidors (LXC) per a desenes d'alumnes en segons.
- 🔒 **Aïllament per Alumne:** Cada alumne obté la seva pròpia subxarxa aïllada via VLANs (101, 102...).
- ⚙️ **Configuració Granular:** Defineix vCPUs, RAM i capacitat de Disc Dur de forma independent per a cada clon.
- 🌐 **Integració MikroTik (RouterOS v7):** Creació autòmatica i idempotent de VLANs, Gateways i DHCP via API REST.
- 🛡️ **Zero CORS:** Nginx actua de proxy invers per evitar bloquejos del navegador.

---

## 🏗️ Arquitectura de Xarxa

L'entorn es recolza en dos *bridges* virtuals de Proxmox:

- `vmbr0` **(WAN):** Connectat a la targeta física del servidor. Dona accés a la xarxa de l'institut/Internet.
- `vmbr1` **(LAN - VLAN Aware):** Bridge intern *sense targeta física*. Aquí es connecten les màquines dels alumnes etiquetades amb la seva VLAN corresponent.
- **Router MikroTik:** Connectat a `vmbr0` (ether1) i `vmbr1` (ether2, com a *trunk*).

---

## 📋 Requisits Previs

1. Un node **Proxmox VE** (versió 7 o 8).
2. Plantilles prèviament creades a Proxmox (Ex: *Debian 12 Cloud* en format `qemu template` o imatges `.tar.zst` per a LXC).
3. Imatge de **MikroTik CHR** importada a Proxmox.

---

## 🛠️ Guia d'Instal·lació i Desplegament

### 1. Preparació de Proxmox VE

#### A. Crear el Token d'API per a l'App
Des de la consola (Shell) de Proxmox, crea un token amb privilegis suficients per clonar i crear usuaris:
```bash
pveum user token add root@pam lab-manager --privsep 0
```
> ⚠️ **IMPORTANT:** Guarda l'UUID secret generat i el Token ID (`root@pam!lab-manager`). `--privsep 0` és obligatori.

#### B. Activar el Bridge Intern (`vmbr1`)
1. A la interfície web de Proxmox: **Node > System > Network**.
2. **Create > Linux Bridge**.
3. **Name:** `vmbr1`.
4. Marca la casella **VLAN aware**. (No posis cap *Bridge port*).
5. Prem **Apply Configuration**.

---

### 2. Configuració del Router MikroTik CHR

1. Desplega una VM amb MikroTik CHR.
2. Assigna `net0` a `vmbr0` (WAN) i `net1` a `vmbr1` (LAN Trunk).
3. Engega'l, obre la consola i activa l'API REST:
   ```rsc
   /ip service set www disabled=no
   ```
4. Comprova i anota la IP que rep de la teva xarxa per la WAN:
   ```rsc
   /ip address print where interface=ether1
   ```

---

### 3. Desplegament de l'App Web (LXC + Nginx)

Allotjarem el `index.html` (el frontend) en un contenidor LXC lleuger amb Nginx perquè faci de túnel segur.

#### A. Crear el contenidor de Gestió (Ex: ID 901)
*Ajusta la IP `192.168.2.155` i la passarel·la al teu rang de xarxa institut.*
```bash
TEMPLATE_LXC=$(pveam list local | awk '/debian-12/ {print $1; exit}')
pct create 901 "$TEMPLATE_LXC" \
    --hostname lab-manager \
    --storage local-lvm \
    --rootfs local-lvm:2 \
    --memory 256 \
    --cores 1 \
    --unprivileged 1 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.2.155/24,gw=192.168.2.1 \
    --start 1
```

#### B. Configurar Nginx i els túnels proxy
*Substitueix `192.168.2.124` per la IP real del teu node Proxmox.*
```bash
pct exec 901 -- bash -c '
apt update && apt install -y nginx
cat << "EOF" > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;

    # Túnel API Proxmox
    location /api2/ {
        proxy_pass https://192.168.2.124:8006/api2/;
        proxy_ssl_verify off;
        proxy_set_header Host 192.168.2.124:8006;
    }

    # Túnel API MikroTik
    location ~ ^/mikrotik-rest/(.*)$ {
        resolver 1.1.1.1 8.8.8.8 valid=300s;
        set $mt_target $http_x_mikrotik_url;
        proxy_pass $mt_target/rest/$1$is_args$args;
        proxy_ssl_verify off;
        proxy_set_header Host $http_host;
        proxy_set_header Authorization $http_authorization;
    }
}
EOF
nginx -t && systemctl restart nginx
'
```

#### C. Bolcar l'arxiu HTML
Copia l'únic fitxer font del projecte (`index.html`) a l'arrel web del contenidor:
```bash
pct push 901 /ruta/al/teu/index.html /var/www/html/index.html
```

---

## 📖 Manual d'Ús

1. **Accés:** Obre un navegador web a `http://<IP_DEL_CONTENIDOR_901>` (ex. `http://192.168.2.155`).
2. **Connexió Proxmox:** 
   - A la barra superior, posa la IP de l'aplicació web mateix com a Host (`http://192.168.2.155:80`), el *Token ID* i el *Secret*. 
   - Prem **Sincronitzar** per carregar les teves plantilles.
3. **Configuració del Laboratori:**
   - Selecciona quantes instàncies (CT/VM) rebrà cada alumne i defineix-ne els recursos (vCPU, RAM, HDD).
4. **Automatització MikroTik:**
   - Introdueix les dades d'accés del teu CHR (IP ether1, admin, password) i prem **🚀 Sincronitzar MikroTik** per preparar la xarxa automàticament per a tothom.
5. **Desplegament Massiu:** 
   - Prem **+ Desplegar Proxmox**. El sistema crearà els *Resource Pools*, usuaris i els *Linked Clones* ubicats en la seva VLAN corresponent.

---
*Creat per simplificar l'ensenyament en FP Informàtica i Sistemes.*