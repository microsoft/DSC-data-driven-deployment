[![Build status](https://ci.appveyor.com/api/projects/status/uan12tf7tfxhg7m5/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xdhcpserver/branch/master)

# xDhcpServer

The **xDhcpServer** DSC resources are used for configuring and managing a DHCP server. They include **xDhcpServerScope**, **xDhcpServerReservation**, **xDhcpServerOptions** and **xDhcpServerAuthorization**.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Resources

* **xDhcpServerScope** sets a scope for consecutive range of possible IP addresses that the DHCP server can lease to clients on a subnet.
* **xDhcpServerReservation** sets lease assignments used to ensure that a specified client on a subnet can always use the same IP address.
* **xDhcpServerOptions** currently supports setting DNS domain and DNS Server IP Address options at a DHCP server scope level.
* **xDhcpServerAuthorization** authorizes a DHCP in Active Directory.
 * *This resource must run on an Active Directory domain controller.*

### xDhcpServerScope

* **IPStartRange**: Starting address to set for this scope
* **IPEndRange**: Ending address to set for this scope
* **Name**: Name of this DHCP Scope
* **SubnetMask**: Subnet mask for the scope specified in IP address format
* **LeaseDuration**: Time interval for which an IP address should be leased
 * This should be specified in the following format: `Days.Hours:Minutes:Seconds`
 * For example, '`02.00:00:00`' is 2 days and '`08:00:00`' is 8 hours.
* **State**: Whether scope should be active or inactive.
* **Ensure**: Whether DHCP scope should be present or removed
* **ScopeID**: Scope Identifier. This is a read-only property for this resource.

### xDhcpServerReservation

* **ScopeID**: ScopeId for which reservations are set
* **IPAddress**: IP address of the reservation for which the properties are modified
* **ClientMACAddress**: Client MAC Address to set on the reservation
* **Name**: Reservation name
* **AddressFamily**: Address family type. Note: at this time, only IPv4 is supported.
* **Ensure**: Whether option should be set or removed

### xDhcpServerOption

* **ScopeID**: ScopeID for which options are set
* **DnsServerIPAddress**: IP address of DNS Servers
* **DnsDomain**: Domain name of DNS Server
* **AddressFamily**: Address family type
* **Ensure**: Whether option should be set or removed

### xDhcpServerAuthorization

* **Ensure**: Whether the DHCP server should be authorized.
* **DnsName**: FQDN of the server to authorize. If not specified, it defaults to the local hostname of the enacting node.
* **IPAddress**: IP v4 address of the server to authorized. If not specified, it default to the first IPv4 address of the enacting node.

## Versions

### Unreleased

### 1.5.0.0
* Converted AppVeyor.yml to pull Pester from PSGallery instead of Chocolatey
* Bug Fix fixes xDhcpServerOption\Get-TargetResource not returning Router property

### 1.4.0.0

* Bug Fix fixes localization bug in xDhcpServerScope option enumeration

### 1.3.0.0

* Added **xDhcpServerAuthorization** resource.
* Bug Fix LeaseDuration is no longer mandatory for xDhcpServerScope resource.
* Bug Fix DnsServerIPAddress is no longer mandatory for xDhcpServerOption resource.
* Bug Fix corrects verbose display output in xDhcpServerOption resource.

### 1.2

* Fix "Cannot set default gateway on xDhcpServerOption".

### 1.1

* Bug fix, enables creating more than 1 DHCP server scope.

### 1.0

* Initial release with the following resources
    * **xDhcpServerScope**
    * **xDhcpServerReservation**
    * **xDhcpServerOptions**

## Examples

### Creating a DHCP Server Scope

```powershell
configuration Sample_xDhcpsServerScope_NewScope
{
    Import-DscResource -module xDHCpServer
    xDhcpServerScope Scope
    {
        Ensure = 'Present'
        IPEndRange = '192.168.1.254'
        IPStartRange = '192.168.1.1'
        Name = 'PowerShellScope'
        SubnetMask = '255.255.255.0'
        LeaseDuration = ((New-TimeSpan -Hours 8 ).ToString())
        State = 'Active'
        AddressFamily = 'IPv4'
    }
}
```

### Reserving an IP address within a DHCP server

```powershell
configuration Sample_xDhcpServerReservation_IPReservation
{
    Import-DscResource -module xDHCpServer
    xDhcpServerReservation PullServerIP
    {
        Ensure = 'Present'
        ScopeID = '192.168.1.0'
        ClientMACAddress = '00155D8A54A1'
        IPAddress = '192.168.1.2'
        Name = 'DSCPullServer'
        AddressFamily = 'IPv4'
    }
}
```

### Setting the domain name, DNS server and default gateway option for a DHCP scope

```powershell
configuration Sample_xDhcpServerOption_SetScopeOption
{
    Import-DscResource -module xDHCpServer
    xDhcpServerOption Option
    {
        Ensure = 'Present'
        ScopeID = '192.168.1.0'
        DnsDomain = 'contoso.com'
        DnsServerIPAddress = '192.168.1.22','192.168.1.1'
        AddressFamily = 'IPv4'
        Router = '192.168.1.1'
    }
}
```

### Authorizing the local DHCP server

```powershell
configuration Sample_Local_xDhcpServerAuthorization
{
    Import-DscResource -module xDHCpServer
    xDhcpServerAuthorization LocalServerActivation
    {
        Ensure = 'Present'
    }
}
```

### Authorizing a remote DHCP server

```powershell
configuration Sample_Remote_xDhcpServerAuthorization
{
    Import-DscResource -module xDHCpServer
    xDhcpServerAuthorization RemoteServerActivation
    {
        Ensure = 'Present'
        DnsName = 'servertoauthorize.contoso.com'
        IPAddress = '192.168.0.1'
    }
}
```
