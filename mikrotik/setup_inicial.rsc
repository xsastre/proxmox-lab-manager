{
:local numAlumnes 20
:local lanInterface "ether2"
:local wanInterface "ether1"

/ip dhcp-client add interface=$wanInterface disabled=no comment="WAN Institut"
/ip dns set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8

/ip firewall address-list
add list=Xarxes-Alumnes address=10.0.0.0/8 comment="Totes les subxarxes del Lab"
add list=Xarxa-Institut address=192.168.0.0/16 comment="Xarxes privades centre"
add list=Xarxa-Institut address=172.16.0.0/12 comment="Xarxes privades centre"

:for i from=1 to=$numAlumnes do={
    :local vlanId (100 + $i)
    :local vlanName ("vlan-alumne-" . $i)
    :local subnet ("10." . $i . ".0.0/24")
    :local gwIp ("10." . $i . ".0.1")
    :local gwIpMask ($gwIp . "/24")
    :local poolRange ("10." . $i . ".0.50-10." . $i . ".0.200")
    :local poolName ("pool-alumne-" . $i)
    :local dhcpName ("dhcp-alumne-" . $i)

    /interface vlan add name=$vlanName vlan-id=$vlanId interface=$lanInterface comment=("Lab Alumne " . $i)
    /ip address add address=$gwIpMask interface=$vlanName comment=("GW Alumne " . $i)
    /ip pool add name=$poolName ranges=$poolRange
    /ip dhcp-server network add address=$subnet gateway=$gwIp dns-server=$gwIp comment=("Xarxa Alumne " . $i)
    /ip dhcp-server add name=$dhcpName interface=$vlanName address-pool=$poolName disabled=no
}

/ip firewall filter
add chain=input connection-state=established,related,untracked action=accept comment="Accepta establert/relacionat (Router)"
add chain=forward connection-state=established,related,untracked action=accept comment="Accepta establert/relacionat (Forward)"
add chain=input src-address-list=Xarxes-Alumnes protocol=udp dst-port=53,67 action=accept comment="Permet DNS i DHCP al Lab"
add chain=input src-address-list=Xarxes-Alumnes protocol=tcp dst-port=53 action=accept comment="Permet DNS TCP al Lab"
add chain=input src-address-list=Xarxes-Alumnes action=drop comment="Bloqueja gestio router des dels alumnes"
add chain=forward src-address-list=Xarxes-Alumnes dst-address-list=Xarxa-Institut action=drop comment="BLOQUEIG: Alumnes -> Xarxa Institut"
add chain=forward src-address-list=Xarxes-Alumnes dst-address-list=Xarxes-Alumnes action=drop comment="BLOQUEIG: Alumne <-> Alumne"
add chain=forward src-address-list=Xarxes-Alumnes out-interface=$wanInterface action=accept comment="Permet sortida a Internet"
add chain=forward action=drop comment="Drop per defecte"

/ip firewall nat
add chain=srcnat out-interface=$wanInterface src-address-list=Xarxes-Alumnes action=masquerade comment="NAT Sortida Lab"

:put "Configuracio completada correctament per a 20 alumnes!"
}
