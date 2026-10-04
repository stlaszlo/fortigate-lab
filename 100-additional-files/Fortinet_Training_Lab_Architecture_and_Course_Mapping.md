# Fortinet Training Lab Platform — Architecture, Course Mapping & Content Development Brief

> **Status:** Living design document  
> **Purpose:** Working memory and source-of-truth brief for infrastructure development, PowerPoint deck updates, and the future hands-on lab guide.  
> **Course scope:** 2-day Foundations + 2-day Advanced Fortinet training.  
> **Architecture principle:** Hide Azure complexity from students as much as possible; Azure is the underlay, FortiGate is the subject.

---

## 1. Current Platform Status

### Completed and validated

The Azure underlay and FortiGate fleet are now at the **basic infrastructure complete** checkpoint:

- Instructor VNet deployed.
- Eight student VNets deployed.
- VNet peerings deployed between the instructor environment and each student pod.
- Per-subnet Azure route tables exist to support controlled UDR insertion.
- Instructor FortiGate deployed and registered.
- Router NVA deployed and forwarding correctly.
- Student WAN UDRs steer default traffic toward the Router NVA.
- Instructor FortiGate provides shared Internet breakout and NAT.
- Eight student FortiGate VMs are deployed.
- All eight student FortiGate WAN interfaces use deterministic addresses.
- All eight student FortiGates are reachable on the designed underlay path.
- FortiGates can reach Fortinet cloud services / FortiCloud.
- Internet ICMP reachability has been validated from the student side.
- Student pod addressing is generated deterministically from Terraform `local.student_pods`.

### Next infrastructure milestone

Before exercise development begins, complete and thoroughly test:

1. Student Linux client VM in each pod.
2. Student Linux DMZ/server VM in each pod.
3. Central Apache Guacamole deployment.
4. Guacamole access paths to the systems students need to operate.
5. Startup/shutdown and recovery behaviour.
6. At least one destructive recovery test to prove that a damaged student component can be rebuilt reliably with Terraform.

**Important:** Do not begin polishing exercise content until this platform is boring, repeatable, and recoverable.

---

# 2. Design Goals

The training environment should:

- provide realistic FortiGate administration workflows;
- keep Azure implementation details mostly invisible to students;
- give each student an isolated pod;
- allow the instructor to observe and troubleshoot every pod;
- support both foundational and advanced networking/security exercises;
- be reproducible through Terraform;
- be inexpensive enough to destroy/rebuild between cohorts;
- avoid unnecessary infrastructure that does not support a course objective;
- prefer deterministic IP addressing and naming;
- separate the Azure underlay from the FortiGate overlay;
- support future IPSec/ADVPN overlay exercises without Azure routing interfering with them.

---

# 3. High-Level Architecture

```text
                              Internet
                                  |
                         Instructor FortiGate
                         Shared NAT / Internet
                         Edge policy / logging
                                  |
                          Instructor Transit
                                  |
                         Linux Router NVA
                            10.0.0.5
                                  |
                  Azure VNet peering / underlay
          +-----------+-----------+-----------+-----------+
          |           |           |                       |
      Student01   Student02   Student03 ...            Student08
          |           |           |                       |
      FortiGate   FortiGate   FortiGate               FortiGate
       WAN/LAN/    WAN/LAN/    WAN/LAN/                WAN/LAN/
        DMZ         DMZ         DMZ                      DMZ
          |                                                   |
      Linux Client + Linux DMZ Server in each isolated pod
```

The Azure topology exists to make the FortiGate training environment possible. Students should primarily interact with FortiOS, Guacamole, and the Linux endpoints.

---

# 4. Instructor Network

Instructor VNet:

```text
10.0.0.0/16
```

Current logical subnets:

| Role | Prefix |
|---|---|
| Transit | `10.0.0.0/24` |
| Management | `10.0.10.0/24` |
| Services | `10.0.20.0/24` |
| Internal | `10.0.30.0/24` |

Instructor FortiGate:

| FortiGate interface | Address | Role |
|---|---:|---|
| port1 | `10.0.0.4` | Transit / student underlay-facing |
| port2 | `10.0.30.4` | Internal |
| port3 | `10.0.10.4` | Management / Internet-facing Azure path |

Router NVA:

```text
10.0.0.5
```

The Router NVA is a lightweight Linux forwarding appliance. It is part of the Azure underlay and should not become a teaching focus.

---

# 5. Student Pod Design

Terraform source-of-truth mapping:

```hcl
locals {
  student_pods = {
    student01 = { octet = 1, username = "student01" }
    student02 = { octet = 2, username = "student02" }
    student03 = { octet = 3, username = "student03" }
    student04 = { octet = 4, username = "student04" }
    student05 = { octet = 5, username = "student05" }
    student06 = { octet = 6, username = "student06" }
    student07 = { octet = 7, username = "student07" }
    student08 = { octet = 8, username = "student08" }
  }
}
```

For student **N**:

| Network | Prefix | FortiGate interface | FortiGate IP |
|---|---|---|---|
| WAN | `10.N.0.0/24` | port1 | `10.N.0.4` |
| LAN | `10.N.10.0/24` | port2 | `10.N.10.4` |
| DMZ | `10.N.20.0/24` | port3 | `10.N.20.4` |

Example Student01:

```text
WAN  10.1.0.0/24     FG port1  10.1.0.4
LAN  10.1.10.0/24    FG port2  10.1.10.4
DMZ  10.1.20.0/24    FG port3  10.1.20.4
```

---

# 6. Underlay Routing Philosophy

## Student Internet breakout

Each student WAN route table contains:

```text
0.0.0.0/0
  -> Virtual Appliance
  -> 10.0.0.5
```

Traffic path:

```text
Student FortiGate port1
    -> Azure WAN subnet UDR
    -> Router NVA
    -> Instructor FortiGate
    -> NAT / policy
    -> Internet
```

## Instructor return path

The instructor FortiGate must know how to return traffic to deterministic student WAN addresses through the Router NVA.

Prefer specific underlay routes for the student WAN space rather than making LAN/DMZ Azure underlay routes authoritative.

The design intention is:

```text
Student WAN prefixes / addresses
    -> Router NVA
```

while future student LAN/DMZ routes are carried by the FortiGate overlay.

## Why not route all RFC1918 student space through Azure?

The advanced course will use IPSec/ADVPN overlays. Student LAN and DMZ traffic should eventually be learned/reached through FortiGate VPN routing, not accidentally bypass the overlay through Azure peering.

Azure is therefore the **underlay transport**, while FortiGate becomes the **overlay control/security plane**.

---

# 7. Planned Endpoint Infrastructure

## Per student

### Linux Client VM — LAN

Purpose:

- generate normal user traffic;
- perform DNS and HTTP tests;
- run troubleshooting commands;
- generate controlled security events;
- act as the source system for policy, NAT, inspection and VPN exercises.

Suggested packages:

```text
curl
iproute2
net-tools
tcpdump
traceroute
nmap
dnsutils
netcat-openbsd
iperf3
hping3
jq
```

CLI-first is sufficient. A graphical Linux desktop is optional and should only be added if Guacamole usability testing proves that it materially improves the student experience.

### Linux DMZ Server

Purpose:

- HTTP/HTTPS application target;
- SSH target;
- source/destination for segmentation exercises;
- security-profile inspection target;
- controlled traffic-generation target.

Suggested baseline:

```text
nginx
openssh-server
python3
python3-flask
```

Optional lab content:

- simple Flask application;
- self-signed HTTPS endpoint;
- static downloadable files;
- safe EICAR test file for AV exercises.

Do not turn the DMZ server into a full penetration-testing target unless a specific exercise requires it.

---

# 8. Guacamole

Guacamole is intended to be the primary student access plane.

Design goal:

```text
Student browser
    -> Guacamole
       -> assigned Linux client
       -> assigned DMZ server where appropriate
       -> FortiGate GUI/CLI access as required
```

Guacamole must be treated as a **critical lab component**, not an afterthought.

Required validation:

- simultaneous student sessions;
- reconnect behaviour;
- clipboard behaviour;
- keyboard-layout behaviour;
- browser compatibility;
- SSH sessions;
- RDP/VNC only if later required;
- timeout behaviour;
- credential handling;
- session isolation;
- recovery after service restart;
- Guacamole VM restart;
- full lab restart;
- student cannot accidentally access another student's endpoint;
- acceptable responsiveness during all eight simultaneous pods.

Do not declare the lab production-ready until Guacamole has been mercilessly tested.

---

# 9. Security Exercise Philosophy

This is a FortiGate administration course, **not an offensive-security course**.

Prefer small, deterministic traffic generators over a Kali environment.

Useful tools:

```text
curl
nmap
hping3
tcpdump
openssl
netcat
iperf3
```

Safe security demonstrations can include:

- port scan detection;
- simple HTTP attack-like strings that match FortiGuard IPS signatures;
- controlled connection-rate anomalies;
- EICAR AV detection;
- SSL certificate inspection;
- HTTPS deep inspection;
- application/web filtering;
- traffic/session troubleshooting.

The goal is to create traffic that makes FortiGate behaviour observable, configurable and troubleshootable.

---

# 10. Course Source Mapping

The following course structure is sourced from the ClickUp **Fortinet Training - Foundations** and **Fortinet Training - Advanced** plans.

The **module scopes below reflect the current ClickUp agenda**. Proposed labs in later sections are design proposals and may be refined during lab-guide production.

---

# 11. Foundations — Day 1: Firewall Foundations & Network Security

## 09:00–10:30 — Network Foundations & FortiGate Packet Flow

Current agenda scope:

- TCP/IP review
- DNS operation
- TCP and UDP communication
- routing basics, default route and default gateway
- network segmentation best practices
- stateful inspection
- session table operation
- connection tracking
- FortiGate packet-flow stages
- flow mode vs proxy mode
- implicit deny

### Proposed high-level lab

**Packet Flow and Session Visibility**

Student:

1. verifies Linux client addressing and gateway;
2. generates ICMP, DNS, HTTP and HTTPS traffic;
3. observes FortiGate routing and session state;
4. compares allowed traffic with implicit-deny behaviour;
5. uses packet capture / flow debug to explain where a deliberately blocked connection stops.

Infrastructure fit: **excellent** with current student LAN + DMZ + Internet topology.

---

## 10:30–12:00 — FortiGate Introduction & Initial Configuration

Current agenda scope:

- Fortinet ecosystem and FortiOS overview
- GUI and CLI access
- interface configuration
- administrative access
- DNS configuration
- configuration backup and restore
- initial operational checks

### Proposed high-level lab

**Take Ownership of Your FortiGate**

Student:

1. logs into their assigned FortiGate;
2. validates port1/port2/port3 addressing;
3. sets hostname / administrative preferences;
4. validates FortiGuard/DNS reachability;
5. performs config backup;
6. performs selected operational checks from GUI and CLI.

Infrastructure fit: **already available** once Guacamole/access is complete.

---

## 13:00–14:30 — Segmentation, Zones & Firewall Policy Design

Current agenda scope:

- LAN, WAN and DMZ concepts
- least-privilege segmentation
- microsegmentation and macrosegmentation
- FortiSwitch and FortiLink concepts
- firewall policy elements
- source and destination objects
- service objects
- logging within policies
- policy ordering
- First Match Wins

### Proposed high-level lab

**Build LAN-to-DMZ Segmentation**

Student:

1. confirms LAN client and DMZ server cannot communicate under implicit deny;
2. creates address/service objects;
3. creates narrowly scoped LAN-to-DMZ policies;
4. enables logging;
5. adds an intentionally conflicting rule;
6. demonstrates First Match Wins;
7. fixes policy order.

FortiSwitch/FortiLink should remain theory/demo unless dedicated switching hardware or virtual capability is later added.

Infrastructure fit: **excellent**.

---

## 14:30–16:00 — NAT, Logging & CLI Troubleshooting

Current agenda scope:

- SNAT
- PAT
- DNAT
- Virtual IP
- hairpin NAT
- Traffic Log
- Event Log
- Security Log
- session monitoring
- `diagnose debug flow`
- `diagnose sniffer packet`
- `diagnose sys session`

### Proposed high-level lab

**Publish, NAT and Troubleshoot a DMZ Service**

Student:

1. enables client Internet access through SNAT;
2. publishes a selected DMZ HTTP service using VIP/DNAT where the topology permits;
3. generates sessions;
4. finds corresponding traffic/security logs;
5. uses session-table inspection;
6. uses `diagnose sniffer packet`;
7. uses `diagnose debug flow` to isolate a deliberately introduced policy/NAT mistake.

Hairpin NAT should be included only if it produces a clean and teachable path in the final topology.

Infrastructure fit: **very good**, subject to final external/published-service path design.

---

# 12. Foundations — Day 2: FortiGate Services: Networking & Security

## 09:00–10:30 — Routing Fundamentals & Route Selection

Current agenda scope:

- static routes
- Administrative Distance
- ECMP
- routing table interpretation
- default-route behaviour

### Proposed high-level lab

**Route Selection and Failure Analysis**

Student:

1. inspects connected/static/default routes;
2. adds a controlled static route;
3. changes administrative distance;
4. predicts and verifies the selected route;
5. introduces a bad route and diagnoses the outcome.

Optional ECMP demonstration may require a second usable underlay path.

Infrastructure fit: **good** for static routing/AD; **additional path may be needed** for meaningful ECMP.

---

## 10:30–12:00 — Object Management & Policy Design Best Practices

Current agenda scope:

- address objects
- service objects
- object groups
- naming conventions
- reusability
- maintainability and operational clarity
- policy design best practices

### Proposed high-level lab

**Refactor a Bad Firewall Rulebase**

Student receives a deliberately messy policy/object set and must:

1. replace raw IPs with named objects;
2. build logical groups;
3. replace broad services with reusable service objects;
4. apply a naming standard;
5. consolidate/refactor rules;
6. preserve intended connectivity.

Infrastructure fit: **excellent**; mostly FortiGate configuration.

---

## 13:00–14:30 — Security Services & SSL Inspection

Current agenda scope:

- Antivirus
- IPS
- Web Filter
- Application Control
- security-profile interaction
- SSL Inspection fundamentals
- Certificate Inspection
- Deep Inspection
- PKI fundamentals
- typical operational issues caused by encrypted-traffic inspection

### Proposed high-level lab

**Inspect and Block Controlled Security Events**

Traffic generated from the Linux client toward DMZ/Internet:

- EICAR test file for AV;
- `nmap` / controlled scan for IPS visibility;
- deterministic HTTP strings chosen to trigger safe IPS signatures;
- HTTP/HTTPS web categorisation / filtering;
- application-control observation;
- self-signed HTTPS endpoint;
- certificate inspection followed by deep inspection;
- certificate trust troubleshooting.

This lab should emphasise **policy + profile + logs + troubleshooting**, not offensive technique.

Infrastructure fit: **excellent** once client/server cloud-init is complete.

---

## 14:30–16:00 — FortiGate Hardware Architecture, Monitoring & Operations

Current agenda scope:

- Control Plane vs Data Plane vs Management Plane
- FortiASIC overview: NP and CP
- hardware offload
- Fast Path and Slow Path
- firmware management
- configuration management
- backup/restore
- session utilisation
- CPU monitoring
- memory usage
- Conserve Mode

### Proposed high-level lab

**Operate and Observe the Firewall**

Student:

1. inspects CPU, memory and sessions;
2. generates controlled connection load with `iperf3`, `curl`, or `hping3`;
3. compares baseline vs inspected traffic;
4. checks available offload/session information;
5. backs up/restores configuration;
6. performs a guided operational troubleshooting workflow.

Because FGVM hardware acceleration differs from physical FortiGate appliances, NP/CP and hardware-offload sections must clearly distinguish **theory/physical appliance behaviour** from what is observable on the Azure VM.

Infrastructure fit: **good**, with careful VM-vs-hardware framing.

---

# 13. Advanced — Day 3: Enterprise Routing & VPN

## 09:00–10:30 — Route Selection, PBR & OSPF

Current agenda scope:

- route selection
- Policy-Based Routing
- route redistribution
- OSPF areas
- OSPF neighbor relationships
- LSAs
- route exchange

### Proposed high-level lab

**Build the Dynamic Overlay**

Use instructor FortiGate as hub and student FortiGates as spokes.

Student:

1. establishes initial overlay reachability;
2. configures OSPF across the overlay;
3. observes neighbor formation and learned prefixes;
4. compares connected/static/dynamic route preference;
5. applies a controlled PBR case;
6. diagnoses a deliberately broken neighbor or route advertisement.

This directly supports the intended separation between Azure underlay and FortiGate overlay.

Infrastructure fit: **excellent after VPN overlay is built**.

---

## 10:30–12:00 — BGP Fundamentals & Practical Use

Current agenda scope:

- Autonomous Systems
- eBGP vs iBGP
- neighbor relationships
- path selection
- prefix advertisement
- route filtering

### Proposed high-level lab

**Small BGP Overlay / Route Exchange**

Possible implementation:

- Instructor FG acts as central BGP peer/hub.
- Each student peer uses a deterministic private ASN.
- Students advertise only their LAN/DMZ prefixes.
- Students inspect best path and apply a simple prefix filter.

Alternative: keep BGP as an instructor-led demo if the OSPF + ADVPN lab already consumes significant time.

Infrastructure fit: **supported by current topology**, configuration effort only.

---

## 13:00–14:30 — IPsec VPN Architecture & ADVPN

Current agenda scope:

- IKEv2
- Phase 1
- Phase 2
- Route-Based VPN
- VPN design considerations
- ADVPN architecture
- Hub-and-Spoke topology
- Dynamic Shortcut Tunnels
- Overlay networks
- OSPF over ADVPN
- sizing considerations

### Proposed high-level lab

**Build Hub-and-Spoke IPsec and Observe the Overlay**

Student:

1. configures route-based IKEv2 tunnel to instructor hub;
2. validates Phase 1 / Phase 2;
3. routes LAN/DMZ prefixes over VPN;
4. validates spoke-to-hub communication;
5. introduces OSPF over the tunnel;
6. if practical, enables/observes ADVPN shortcut behaviour between two controlled student spokes.

The current Azure architecture was deliberately designed so LAN/DMZ prefixes can be owned by this overlay rather than by Azure UDRs.

Infrastructure fit: **core use case of the design**.

---

## 14:30–16:00 — VPN Troubleshooting & Operational Validation

Current agenda scope:

- tunnel-establishment process
- routing and VPN interaction
- session handling in VPN environments
- Phase 1 / Phase 2 validation
- route and selector verification
- packet capture and CLI diagnostics

### Proposed high-level lab

**Broken VPN Ticket**

Students receive one or more controlled faults, for example:

- mismatched PSK;
- wrong Phase 2 selector;
- missing route;
- wrong policy;
- wrong interface binding;
- intentionally missing prefix advertisement.

Student must identify the fault using FortiGate diagnostics, not by reading the answer.

Infrastructure fit: **excellent** once overlay is operational.

---

# 14. Advanced — Day 4: Advanced Architectures: FortiClient, HA & SD-WAN

## 09:00–10:30 — FortiClient Architecture & EMS Awareness

Current agenda scope:

- FortiClient architecture
- VPN profiles
- endpoint integration
- EMS awareness
- EMS purpose
- telemetry and centralized client management
- EMS vs / alongside Intune

### Proposed treatment

The current Linux-only client design does **not** provide a natural FortiClient endpoint lab.

Recommended approach:

- keep architecture/EMS positioning in theory;
- provide instructor demo where licensing/platform availability permits;
- optionally add one shared Windows/FortiClient demonstration endpoint later;
- do not deploy eight Windows endpoints merely to satisfy an awareness module.

Infrastructure fit: **partial / optional extension**.

---

## 10:30–12:00 — FortiGate High Availability Fundamentals

Current agenda scope:

- FGCP overview
- Active-Passive operation
- session synchronization
- failover process
- typical operational issues

### Proposed treatment

Current student pods contain a single FortiGate each, so a true FGCP hands-on exercise requires additional infrastructure.

Options:

1. **Instructor demo cluster** — preferred for cost and simplicity.
2. Temporarily add a second FortiGate only to one designated demo pod.
3. Build a reusable optional Terraform HA module that is enabled only for this module.

Proposed lab/demo:

- establish HA pair;
- inspect primary/secondary state;
- generate continuous traffic;
- trigger controlled failover;
- observe session/traffic behaviour;
- inspect HA health and diagnose one fault.

Infrastructure fit: **requires additional FortiGate and HA-specific network design**.

---

## 13:00–14:30 — Fortinet SD-WAN & Design Considerations

Current agenda scope:

- SD-WAN architecture
- SLA-based path selection
- link monitoring
- application steering
- failover mechanisms
- FortiOS capabilities
- when FortiAnalyzer is useful
- when FortiManager is useful
- role of Security Services in the overall design

### Proposed treatment

A meaningful SD-WAN lab needs **two independently controllable WAN paths**.

Preferred future extension:

```text
Student FortiGate
   WAN1 -> current Azure underlay
   WAN2 -> second simulated ISP / alternate transit path
```

Then students can:

1. create SD-WAN members;
2. configure Performance SLA;
3. manipulate latency/loss/path availability;
4. observe path selection;
5. configure simple application steering;
6. force failover and validate recovery.

FortiAnalyzer/FortiManager positioning can remain architecture/design discussion unless separate shared appliances are later added.

Infrastructure fit: **requires second WAN path / simulated ISP**.

---

## 14:30–16:00 — Performance Optimization, Advanced Troubleshooting & Capstone

Current agenda scope:

- session-table sizing
- hardware-offload validation
- CPU troubleshooting
- memory management
- SSL Inspection performance impact
- Security Profile resource consumption
- Conserve Mode troubleshooting
- final integrated lab review
- Q&A / wrap-up

### Proposed high-level capstone

**Enterprise Branch Incident**

Give students a multi-symptom scenario combining previously learned skills:

- client cannot reach selected DMZ service;
- VPN is partially operational;
- a route is preferred incorrectly;
- security inspection causes a certificate/application symptom;
- log/session evidence must be gathered;
- final configuration must restore intended access without broadening policy unnecessarily.

Students should demonstrate a structured troubleshooting process rather than simply find one hidden typo.

Infrastructure fit: **excellent after overlay is complete**.

---

# 15. Course-to-Lab Capability Matrix

| Topic | Current architecture | Extra infrastructure required? | Proposed mode |
|---|---|---:|---|
| Packet flow / sessions | Supported | No | Hands-on |
| Initial FortiGate config | Supported | Guacamole/access only | Hands-on |
| Segmentation / policies | Supported | Linux client + DMZ | Hands-on |
| NAT / VIP / logs | Supported | Linux endpoints | Hands-on |
| Static routing / AD | Supported | No | Hands-on |
| Objects / policy hygiene | Supported | No | Hands-on |
| AV / IPS / Web Filter / App Control | Supported | Linux endpoints | Hands-on |
| SSL inspection | Supported | HTTPS endpoint / certificates | Hands-on |
| Monitoring / operations | Supported | Traffic generation | Hands-on |
| PBR | Supported | Overlay/endpoints | Hands-on |
| OSPF | Supported | VPN overlay | Hands-on |
| BGP | Supported | Overlay config | Hands-on or demo |
| IKEv2/IPsec | Supported by design | Overlay config | Hands-on |
| ADVPN | Supported by design | Overlay config | Hands-on |
| VPN troubleshooting | Supported | Overlay faults | Hands-on |
| FortiClient / EMS | Partial | Optional Windows/FortiClient/EMS | Theory/demo |
| HA / FGCP | Not yet | Second FortiGate + HA topology | Demo or optional lab |
| SD-WAN | Not yet meaningful | Second WAN path | Hands-on extension |
| FortiAnalyzer / FortiManager | Not deployed | Optional shared appliances | Awareness/demo |
| Performance capstone | Supported | Completed full platform | Hands-on |

---

# 16. Infrastructure Roadmap Driven by the Course

## Phase A — Complete base platform

Must complete now:

- all eight FortiGates — **done/basic connectivity validated**;
- reusable Linux VM module;
- 8× LAN client VMs;
- 8× DMZ server VMs;
- cloud-init package/service bootstrap;
- Guacamole;
- Guacamole user/session isolation;
- full access testing;
- Terraform recovery testing.

## Phase B — Foundations capability

Add/configure:

- nginx HTTP/HTTPS;
- self-signed certificate or lab CA model;
- EICAR hosting path;
- Flask traffic target if useful;
- deterministic safe IPS-trigger traffic;
- traffic-generation scripts;
- logging/troubleshooting seed scenarios.

## Phase C — Advanced overlay

Add/configure:

- instructor hub VPN design;
- student-spoke route-based IKEv2;
- OSPF over overlay;
- optional BGP exercise;
- ADVPN support;
- fault-injection patterns.

## Phase D — Advanced architecture extensions

Only build if justified:

- optional HA demo pair;
- optional second WAN / simulated ISP for SD-WAN;
- optional FortiClient demo endpoint;
- optional FortiAnalyzer/FortiManager shared appliances.

---

# 17. Content Production Rules

This architecture document should feed **two separate deliverables**.

## PowerPoint / instructor deck

For each module:

- learning objectives;
- concise theory;
- diagram(s) matching the actual lab;
- important FortiOS GUI/CLI views;
- lab transition slide;
- common mistakes;
- troubleshooting decision tree;
- key takeaways.

The deck should **not** expose unnecessary Azure implementation complexity. Azure may be shown in instructor architecture notes, but the student-facing diagrams should describe the network primarily in FortiGate terms.

## Lab guide

Every exercise should include:

1. purpose;
2. learning objectives;
3. starting state;
4. topology fragment;
5. assigned addresses/placeholders;
6. task steps;
7. expected validation;
8. diagnostic commands;
9. troubleshooting hints;
10. optional challenge;
11. cleanup/reset requirement;
12. instructor answer/verification notes.

Avoid click-by-click screenshots for every GUI action. Prefer teaching the concept and giving students enough structure to navigate FortiOS themselves.

---

# 18. Codex Prompt — Infrastructure + Future Lab Guide

Use the following as the working prompt when handing the project to Codex.

```text
You are working on a Terraform-built Azure lab for a four-day Fortinet training course:
two days Foundations and two days Advanced.

Treat the repository and this architecture document as the source of truth.

PRIMARY DESIGN PRINCIPLES

1. The subject is FortiGate, not Azure.
2. Hide Azure implementation complexity from students wherever possible.
3. Azure is the underlay transport.
4. FortiGate IPSec/ADVPN is the future overlay for student LAN/DMZ traffic.
5. Do not introduce Azure routes that accidentally bypass the intended FortiGate overlay.
6. Preserve deterministic addressing and naming.
7. Preserve isolation between eight student pods.
8. Prefer reusable Terraform modules and for_each patterns.
9. Prefer cloud-init for Linux endpoint configuration.
10. Minimize recurring Azure cost.
11. Every infrastructure component must support an identified course objective.
12. Do not introduce Kali, Windows, Active Directory, FortiManager, FortiAnalyzer or EMS unless the specific course capability justifies it.
13. Build and validate infrastructure before writing detailed exercise procedures.
14. Changes must remain reproducible from Terraform wherever practical.

CURRENT CORE TOPOLOGY

Instructor:
- FortiGate
  - port1 10.0.0.4 transit
  - port2 10.0.30.4 internal
  - port3 10.0.10.4 management/upstream
- Linux Router NVA: 10.0.0.5
- future Guacamole in services network

Students 01–08:
- each student has an isolated VNet
- WAN 10.N.0.0/24; FortiGate port1 10.N.0.4
- LAN 10.N.10.0/24; FortiGate port2 10.N.10.4
- DMZ 10.N.20.0/24; FortiGate port3 10.N.20.4
- N is driven by local.student_pods[N].octet
- student WAN default route uses Azure UDR -> 10.0.0.5
- instructor FortiGate provides shared Internet egress/NAT
- student LAN and DMZ must remain available for future IPsec/ADVPN overlay routing

CURRENT STATUS

- instructor infrastructure is operational
- Router NVA is operational
- eight student VNets exist
- eight student FortiGate VMs exist
- all student FortiGate WAN interfaces are reachable
- FortiGates can reach Fortinet cloud services
- basic Internet reachability has been validated

NEXT BUILD TARGET

Create:
- reusable Linux lab VM module
- per-student LAN client VM
- per-student DMZ server VM
- cloud-init package/config bootstrap
- Guacamole
- robust access/isolation testing

CLIENT TOOLSET

Use lightweight Linux tooling:
curl, iproute2, net-tools, tcpdump, traceroute, nmap, dnsutils,
netcat-openbsd, iperf3, hping3, jq.

DMZ SERVER

Use a lightweight Linux server with:
nginx, openssh-server, python3 and optional Flask app.
Support HTTP, HTTPS, safe EICAR and deterministic security-event traffic.

COURSE ALIGNMENT

Foundations covers:
- packet flow/session handling
- initial FortiGate configuration
- segmentation/zones/policies
- NAT/logging/CLI troubleshooting
- static routing/AD/ECMP
- object/policy design
- AV/IPS/Web Filter/Application Control
- SSL inspection and PKI
- hardware architecture/monitoring/operations

Advanced covers:
- PBR/OSPF
- BGP
- IKEv2/IPsec/ADVPN/overlay routing
- VPN troubleshooting
- FortiClient/EMS awareness
- HA/FGCP
- SD-WAN
- performance troubleshooting/capstone

When proposing Terraform changes:
- state exactly which course capabilities they enable;
- distinguish mandatory base infrastructure from optional advanced extensions;
- do not build HA or SD-WAN infrastructure until requested;
- do not change existing address space without explicit approval;
- show expected Terraform plan impact and identify any resource replacement risk.

When later asked to generate a LAB GUIDE:
- use the actual topology and deterministic addressing;
- produce progressive exercises mapped to the course agenda;
- emphasize validation and troubleshooting;
- use safe deterministic traffic generation, not offensive-security complexity;
- give instructor verification/answer notes separately;
- include reset/recovery expectations;
- make exercises reusable for student01–student08 using placeholders rather than hard-coded student01-only instructions.

When later asked to update the POWERPOINT:
- align slides to the same course modules and lab topology;
- include diagrams that match the real environment;
- clearly separate physical FortiGate ASIC concepts from FGVM behavior;
- keep Azure underlay details minimal in student-facing material;
- use the lab guide as the practical reference.
```

---

# 19. Architecture Decisions / ADR Notes

## ADR-001 — Azure should be hidden from students

Accepted.

Azure provides scalable lab infrastructure but is not the course subject.

## ADR-002 — Eight isolated student pods

Accepted.

Each student receives a deterministic WAN/LAN/DMZ design and their own FortiGate.

## ADR-003 — Shared Instructor FortiGate provides Internet egress

Accepted and validated.

## ADR-004 — Linux Router NVA provides underlay transit

Accepted and validated.

The NVA should remain operationally simple and mostly invisible to students.

## ADR-005 — LAN/DMZ reserved for FortiGate overlay

Accepted.

Do not make Azure routing the preferred path for future student LAN/DMZ inter-site communication.

## ADR-006 — Linux endpoints rather than Windows by default

Accepted.

Linux is sufficient for the current Foundations and most Advanced exercises and substantially reduces cost/complexity.

## ADR-007 — No full Kali deployment

Accepted for the baseline design.

Use deterministic traffic-generation tools instead.

## ADR-008 — Guacamole is a production-critical training component

Accepted.

It must receive load, usability, isolation and recovery testing.

## ADR-009 — HA and SD-WAN are optional infrastructure extensions

Accepted for now.

They require topology additions that should be built only when the base environment is stable.

---

# 20. ClickUp Agenda Sources

Course mapping in this document was derived from the current ClickUp tasks in:

- **Fortinet Training - Foundations**
  - Day 1 – Firewall Foundations & Network Security
  - Day 2 – FortiGate Services: Networking & Security
- **Fortinet Training - Advanced**
  - Day 3 – Enterprise Routing & VPN
  - Day 4 – Advanced Architectures: FortiClient, HA & SD-WAN

Module descriptions were read from the individual ClickUp agenda tasks.

This document intentionally separates:

- **Course scope** — sourced from ClickUp;
- **Infrastructure design** — current project architecture;
- **Proposed labs** — working design proposals to be validated and later expanded into the lab guide.
