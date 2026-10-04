# Fortinet Training Lab – Working Design Notes

> Working memory for the Azure/Terraform Fortinet lab.

## Goals
- Reproducible Azure lab built with Terraform.
- 1 instructor environment.
- 8 isolated student pods.
- Browser access via Guacamole.
- Build platform first, exercises second.

## Topology

Internet
    |
Instructor FortiGate (Internet Breakout)
    |
Transit Router NVA
    |
+----------------------------+
| Instructor VNet            |
| - Instructor FortiGate     |
| - Guacamole                |
| - Shared services          |
+----------------------------+

        |
        +-- Student01
        +-- Student02
        ...
        +-- Student08

## Student Pod

Subnets:
- WAN: 10.<N>.0.0/24
- LAN: 10.<N>.10.0/24
- DMZ: 10.<N>.20.0/24

FortiGate:
- port1 = 10.<N>.0.4
- port2 = 10.<N>.10.4
- port3 = 10.<N>.20.4

N comes from:
locals.student_pods[student].octet

## Instructor

Subnets:
- transit
- nva (10.0.40.0/24)
- management
- internal
- services

FortiGate:
- port1 = 10.0.0.4
- port2 = 10.0.30.4
- port3 = 10.0.10.4

## Packet Flow (Validated Baseline)

Student Client
→ Student FortiGate
→ Transit Router NVA (10.0.40.4)
→ Instructor FortiGate (10.0.0.4)
→ Internet

## Routing

- Student default route -> Instructor FortiGate (Internet Breakout)
    |
Transit Router NVA.
- Instructor FortiGate has deterministic routes for:
  - 10.1.0.0/24
  - ...
  - 10.8.0.0/24
  via Instructor FortiGate (Internet Breakout)
    |
Transit Router NVA.
- Do NOT broadly route 10/8 in Azure.
- Future LAN/DMZ traffic will traverse IPSec overlay.

## VM Inventory

Instructor:
- Instructor FortiGate
- Instructor FortiGate (Internet Breakout)
    |
Transit Router NVA
- Guacamole

Each student:
- FortiGate
- Linux Client
- Linux DMZ Server

## Linux Client Packages

- curl
- tcpdump
- traceroute
- iproute2
- net-tools
- nmap
- dnsutils
- netcat
- iperf3
- hping3
- jq

## DMZ Server

- nginx
- openssh-server
- python3
- Flask demo app

## Lab Philosophy

Focus on FortiGate administration, not penetration testing.

Traffic generators:
- nmap
- curl
- hping3
- tcpdump
- EICAR
- self-signed HTTPS

Avoid maintaining Kali unless later required.

## Current Roadmap

1. Deploy all student FortiGates.
2. Create reusable Linux VM module.
3. Deploy client VMs.
4. Deploy DMZ VMs.
5. Deploy Guacamole.
6. Validate platform.
7. Build lab exercises.

# Codex Prompt

You are assisting with an Azure + Terraform Fortinet training lab.

Constraints:
- Preserve architecture.
- Prefer reusable Terraform modules.
- Deterministic naming and IP addressing.
- Student isolation is mandatory.
- Optimise for low Azure cost.
- Assume future IPSec overlay routing.
- Prefer cloud-init.
- Keep solutions simple and reproducible.
- Optimise for teaching FortiGate administration rather than offensive security.

Treat this document as the source of truth unless explicitly updated.


## October 2026 Architecture Update

### Dedicated Transit NVA
- Transit Router moved onto dedicated subnet: `10.0.40.0/24`
- Student WAN default route points to Transit NVA.
- Transit NVA default route points to Instructor FortiGate.
- Instructor transit subnet contains explicit routes for each student pod via the Transit NVA.

### Validation Baseline
- cloud-init completes successfully
- apt update works
- DNS resolution verified
- HTTP/HTTPS connectivity verified
- ICMP connectivity verified
- Azure Network Watcher path validated:
  Student → Student FG → Transit NVA → Instructor FG → Internet
