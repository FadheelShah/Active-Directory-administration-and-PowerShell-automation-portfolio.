# LabPortal — Windows Server DNS and IIS Lab

## Overview
LabPortal is a personal Windows Server 2022 infrastructure lab project built in Oracle VirtualBox. Phase 1 establishes a custom hostname, deploys a dedicated IIS website, and verifies access from both the server VM and the physical Windows host.

**Status:** Phase 1 complete — static welcome page accessible from the physical host. This is not yet an authentication portal.

## Environment
| Component | Configuration |
|---|---|
| Virtualization | Oracle VirtualBox |
| Server | Windows Server 2022 VM |
| Active Directory domain / DNS zone | `testlab.local` |
| NAT adapter | `10.0.2.15` (outbound connectivity) |
| Host-only adapter | `192.168.198.10` (server), `192.168.198.1` (physical host) |
| LabPortal hostname | `login.testlab.local` |
| IIS site | `LabPortal` |
| Website directory | `C:\inetpub\LabPortal` |
| HTTP binding | `192.168.198.10:80`, host name `login.testlab.local` |

## Architecture
```text
Physical Windows PC
  |  hosts file: login.testlab.local -> 192.168.198.10
  |  VirtualBox host-only network
  v
Windows Server 2022 VM (192.168.198.10)
  |  IIS binding: login.testlab.local, HTTP port 80
  v
C:\inetpub\LabPortal\index.html

Server DNS zone testlab.local also contains:
  login (A) -> 192.168.198.10
```

> The physical PC currently resolves LabPortal through its local hosts file. The DNS A record on the server was independently verified, but the PC's default DNS configuration did not resolve it.

## Phase 1 accomplishments
- Created an A record for `login.testlab.local` pointing to `192.168.198.10`.
- Installed the **Web Server (IIS)** role and verified the default page at `http://localhost`.
- Created `C:\inetpub\LabPortal\index.html` with a basic welcome message.
- Created a dedicated IIS site named `LabPortal` with a hostname-specific HTTP binding.
- Verified the welcome page at `http://login.testlab.local` on the server VM.
- Verified host-to-server TCP connectivity on port 80.
- Confirmed the physical PC initially reached the default IIS site when browsing by IP, demonstrating the effect of hostname bindings.
- Verified the lab DNS server could answer a direct query for `login.testlab.local`.
- Added a local hosts-file mapping on the physical PC and confirmed the LabPortal page loaded by hostname.

## Verification summary
| Check | Result |
|---|---|
| `Resolve-DnsName login.testlab.local -Type A -Server 192.168.198.10` | Returned `192.168.198.10` |
| `http://localhost` on VM | Default IIS page displayed |
| `http://login.testlab.local` on VM | LabPortal welcome page displayed |
| `Test-NetConnection 192.168.198.10 -Port 80` on physical PC | `TcpTestSucceeded : True` |
| `http://192.168.198.10` on physical PC | Default IIS page displayed |
| `Resolve-DnsName login.testlab.local -Type A` on physical PC before hosts-file change | Name not found |
| `http://login.testlab.local` on physical PC after hosts-file change | LabPortal welcome page displayed |

See [Phase 1 setup and troubleshooting notes](docs/phase-1-setup.md) for the rationale and step-by-step verification.

## Limitations and next steps
- The physical host uses a **hosts-file entry**, not centrally configured DNS resolution, for LabPortal.
- The site uses **HTTP without TLS** and is suitable only for this isolated learning lab. Do not enter real credentials.
- The current page is static HTML; **no login or authentication functionality** has been implemented.
- An earlier DNS investigation found that the domain controller also advertised its NAT IP (`10.0.2.15`) in some records. That issue was deferred and should be revisited if it causes domain discovery problems.
- Future phases may add a styled interface, HTTPS, and an authentication design appropriate to a test environment.

## Evidence
Place your own screenshots in `screenshots/` (DNS A record, DNS query, IIS binding, connectivity check, and working page). Remove or obscure any sensitive information before publishing.
