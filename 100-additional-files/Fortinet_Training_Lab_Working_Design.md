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
Router NVA
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
- management
- internal
- services

FortiGate:
- port1 = 10.0.0.4
- port2 = 10.0.30.4
- port3 = 10.0.10.4

## Routing

- Student default route -> Router NVA.
- Instructor FortiGate has deterministic routes for:
  - 10.1.0.0/24
  - ...
  - 10.8.0.0/24
  via Router NVA.
- Do NOT broadly route 10/8 in Azure.
- Future LAN/DMZ traffic will traverse IPSec overlay.

## VM Inventory

Instructor:
- Instructor FortiGate
- Router NVA
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
