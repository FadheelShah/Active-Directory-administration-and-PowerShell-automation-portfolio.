# Phase 1 — DNS, IIS, and Host Connectivity

## Objective
Host a basic LabPortal webpage on a Windows Server 2022 VM and access it using `http://login.testlab.local` from both the VM and the physical Windows host.

## 1. Lab networking
The server runs in Oracle VirtualBox with two adapters:

- **NAT:** `10.0.2.15`, intended for outbound connectivity.
- **Host-only:** `192.168.198.10/24`, a stable address for access from the physical host (`192.168.198.1`). The host-only adapter has no default gateway and uses `192.168.198.10` as its preferred DNS server.

**Why:** Separating outbound NAT traffic from the private lab interface reduces exposure to the ordinary local network and gives the lab services a stable address. Host-only networking alone does not supply internet connectivity.

**Observation:** Windows showed a “No Internet access” taskbar indicator on the server, although the user confirmed that Edge could browse external sites. The indicator was not treated as proof that internet connectivity was unavailable.

## 2. Create the DNS A record
In **DNS Manager → Forward Lookup Zones → testlab.local**, create a **New Host (A or AAAA)** record:

| Field | Value |
|---|---|
| Name | `login` |
| FQDN | `login.testlab.local` |
| IPv4 address | `192.168.198.10` |
| Create associated PTR | Unchecked |

**Why:** An A record maps a hostname to an IPv4 address. The record belongs inside the existing `testlab.local` zone; a separate zone is unnecessary. A reverse PTR record is not required for this basic website test.

**Verification:**
```powershell
Resolve-DnsName login.testlab.local -Type A -Server 192.168.198.10
```
The answer contained `192.168.198.10`.

## 3. Install and test IIS
In **Server Manager → Manage → Add Roles and Features**, install **Web Server (IIS)** with its default role services. **IIS Hostable Web Core** is a separate feature and was not required.

**Why:** DNS only identifies the destination IP; IIS actually receives HTTP requests and serves webpage files.

**Verification:** Browse to `http://localhost` on the server VM. The default IIS welcome page appeared, confirming that IIS could serve a local page.

## 4. Create the website content
Create `C:\inetpub\LabPortal\index.html` with the following basic static page:

```html
<!DOCTYPE html>
<html>
<head>
    <title>LabPortal</title>
</head>
<body>
    <h1>Welcome to LabPortal</h1>
    <p>LabPortal is running on Windows Server 2022.</p>
    <p>Domain: testlab.local</p>
</body>
</html>
```

**Why:** A separate content directory keeps LabPortal files apart from the default IIS site at `C:\inetpub\wwwroot`. `index.html` serves as the site's default document.

## 5. Add a dedicated IIS website
In **IIS Manager → Sites → Add Website**, use:

| Setting | Value |
|---|---|
| Site name | `LabPortal` |
| Physical path | `C:\inetpub\LabPortal` |
| Type | `http` |
| IP address | `192.168.198.10` |
| Port | `80` |
| Host name | `login.testlab.local` |
| Start immediately | Enabled |

The site showed **Started**.

**Why:** IIS uses binding information, including the HTTP hostname, to choose which site should handle a request. A running site does not alone prove the page is accessible.

**Verification:** `http://login.testlab.local` on the VM displayed the LabPortal welcome page.

## 6. Test access from the physical Windows host
Check TCP connectivity:

```powershell
Test-NetConnection 192.168.198.10 -Port 80
```

The result included `TcpTestSucceeded : True`, showing that the host could establish a TCP connection to port 80.

Browsing `http://192.168.198.10` from the host showed the **default IIS page**, not LabPortal. This was consistent with the LabPortal site requiring the hostname `login.testlab.local` in its binding.

## 7. Diagnose name resolution from the physical host
The default lookup failed:

```powershell
Resolve-DnsName login.testlab.local -Type A
```

It returned a DNS name-does-not-exist error. A direct query to the lab DNS server succeeded:

```powershell
Resolve-DnsName login.testlab.local -Type A -Server 192.168.198.10
```

It returned `192.168.198.10`.

**Interpretation:** The record existed and the lab DNS service answered correctly, but the host's ordinary name-resolution path did not know the lab hostname.

## 8. Use a hosts-file mapping for the physical PC
Open Notepad as Administrator on the physical PC, then edit:

```text
C:\Windows\System32\drivers\etc\hosts
```

Add:

```text
192.168.198.10    login.testlab.local
```

Save the file. Browsing to `http://login.testlab.local` on the physical PC displayed the LabPortal welcome page.

**Why:** The hosts file supplies a local hostname-to-IP mapping without changing the PC's normal DNS server configuration. This is a practical single-machine test method, but it does not scale as well as central DNS. `Resolve-DnsName` directly queries DNS and is not a suitable verification of hosts-file resolution; the browser test confirmed success here.

## 9. What this proves — and what it does not
**Proven:** The DNS A record is present and queryable; IIS serves the intended static page; the physical host can connect to the server; and a local name mapping lets the host request the correct IIS site.

**Not proven:** That the physical host resolves the lab name through DNS by default, that HTTPS is configured, or that LabPortal authenticates users. None of these features was implemented in Phase 1.

## 10. Known issue and future work
A prior DNS investigation found some domain-controller records advertising both `192.168.198.10` and the NAT IP `10.0.2.15`. Disabling normal DNS Client registration on the NAT adapter did not eliminate every registration; Netlogon was identified as a possible source. The issue was intentionally deferred rather than making broad changes to Active Directory DNS records.

Potential next steps: document screenshots, replace the physical host's hosts-file workaround with appropriate DNS configuration, develop the login-page UI, and plan HTTPS and safe test-only authentication.

## Suggested screenshots
1. `dns-record.png` — `login` A record inside the `testlab.local` zone.
2. `dns-verification.png` — successful `Resolve-DnsName` response.
3. `iis-binding.png` — LabPortal site binding in IIS Manager.
4. `network-connectivity.png` — successful `Test-NetConnection` from the physical host.
5. `labportal-working.png` — browser showing `http://login.testlab.local` and the welcome page.

Capture these from your own lab; screenshots are not included in this document.
