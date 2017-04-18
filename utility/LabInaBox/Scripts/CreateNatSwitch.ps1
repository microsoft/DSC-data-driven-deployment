$IpRange = '192.168.170.'

New-VMSwitch -Name "Nat_$IpRange.1" -SwitchType Internal
New-NetIPAddress –IPAddress $IpRange -PrefixLength 24 -InterfaceAlias "vEthernet (Nat_$IpRange.1)"
New-NetNat -Name "NATNetwork" -InternalIPInterfaceAddressPrefix "$IpRange.0/24"