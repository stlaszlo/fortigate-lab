# Fortinet Training Lab — Architecture

> Stable architecture reference for the Azure/Terraform Fortinet training platform.
>
> Status: **student pods ready / validated baseline** (October 2026).

## 1. Purpose

The platform provides a reproducible Azure lab for FortiGate administration training. It consists of one instructor environment and eight isolated student pods. Terraform is the infrastructure source of truth, with cloud-init used for the Linux training hosts.

The design goal is to make Azure networking predictable and unobtrusive so the exercises teach FortiGate administration rather than Azure troubleshooting.

## 2. High-level topology

```text
                                      Internet
                                         |
                                         v
                              +---------------------+
                              | Instructor FortiGate|
                              | fg-instructor-01    |
                              | port1: 10.0.0.4     |
                              +----------+----------+
                                         |
                                snet-transit
                                10.0.0.0/24
                                         |
                  student return UDRs -> | -> 10.0.40.4
                                         v
                              +---------------------+
                              | Transit Router NVA  |
                              | nva-router-01       |
                              | 10.0.40.4           |
                              +----------+----------+
                                         |
                                  snet-nva
                                10.0.40.0/24
                                         |
                              Instructor VNet peering
                           _________|_____|_________
                          /         |     |         \
                         v          v    ...         v
                    Student01   Student02          Student08
```

The validated outbound path from a student LAN client is:

```text
Student Client
  -> Student FortiGate
  -> Transit Router NVA (10.0.40.4)
  -> Instructor FortiGate (10.0.0.4)
  -> Internet
```

The return path is forced through the same NVA before Azure peering delivers traffic back to the appropriate student VNet.

## 3. Instructor environment

### Instructor VNet

- VNet: `vnet-fortinet-instructor`
- Address space: `10.0.0.0/16`

| Subnet | Prefix | Purpose |
|---|---|---|
| `snet-transit` | `10.0.0.0/24` | Instructor FortiGate port1 / transit side |
| `snet-management` | `10.0.10.0/24` | Instructor management network |
| `snet-services` | `10.0.20.0/24` | Shared/instructor services |
| `snet-internal` | `10.0.30.0/24` | Instructor internal network |
| `snet-nva` | `10.0.40.0/24` | Dedicated Linux transit NVA subnet |

### Instructor FortiGate

| Interface | Address | Role in lab |
|---|---|---|
| `port1` | `10.0.0.4` | Student transit / Internet breakout path |
| `port2` | `10.0.30.4` | Instructor internal |
| `port3` | `10.0.10.4` | Instructor management |

The instructor FortiGate provides the final Internet security policy and NAT/breakout for student traffic.

### Transit Router NVA

- VM: `nva-router-01`
- Address: `10.0.40.4`
- Subnet: `snet-nva`
- Linux IPv4 forwarding: enabled
- Azure NIC IP forwarding: required

The NVA is intentionally placed on a dedicated subnet. It keeps Azure's normal guest default gateway; Azure UDRs, rather than a guest-level off-subnet default route, steer traffic toward the Instructor FortiGate.

## 4. Student pod design

There are eight pods: `student01` through `student08`.

For student number `N`:

| Network | Prefix |
|---|---|
| VNet | `10.<N>.0.0/16` |
| WAN | `10.<N>.0.0/24` |
| LAN | `10.<N>.10.0/24` |
| DMZ | `10.<N>.20.0/24` |

### Student FortiGate addressing

| Interface | Address |
|---|---|
| `port1` | `10.<N>.0.4` |
| `port2` | `10.<N>.10.4` |
| `port3` | `10.<N>.20.4` |

### Student Linux hosts

| Host | Address | Default next hop |
|---|---|---|
| Client | `10.<N>.10.10` | Student FG LAN `10.<N>.10.4` |
| DMZ server | `10.<N>.20.10` | Student FG DMZ `10.<N>.20.4` |

The Terraform pod index comes from `locals.student_pods[student].octet`.

## 5. VNet peering

Each student VNet is bidirectionally peered with the Instructor VNet.

The peerings allow:

- virtual network access;
- forwarded traffic;
- no remote gateway use.

Student-to-student connectivity is not part of the design. Student isolation remains a core platform requirement.

## 6. Azure routing model

### Student LAN and DMZ

The student LAN and DMZ route tables force default and cross-zone traffic through the local student FortiGate.

```text
LAN default:  0.0.0.0/0 -> 10.<N>.10.4
DMZ default:  0.0.0.0/0 -> 10.<N>.20.4
LAN -> DMZ:   10.<N>.20.0/24 -> 10.<N>.10.4
DMZ -> LAN:   10.<N>.10.0/24 -> 10.<N>.20.4
```

### Student WAN

Each student WAN route table has:

```text
0.0.0.0/0 -> VirtualAppliance 10.0.40.4
```

This sends Internet-bound student traffic to the dedicated transit NVA.

### NVA subnet

The NVA subnet has:

```text
0.0.0.0/0 -> VirtualAppliance 10.0.0.4
```

This sends the NVA's Internet-bound forwarded traffic to the Instructor FortiGate.

More-specific VNet/peering routes for student address spaces win over the NVA subnet default route for return traffic toward student VNets.

### Instructor transit subnet

The Instructor FortiGate's transit subnet contains one route per student VNet:

```text
10.1.0.0/16 -> VirtualAppliance 10.0.40.4
10.2.0.0/16 -> VirtualAppliance 10.0.40.4
...
10.8.0.0/16 -> VirtualAppliance 10.0.40.4
```

This makes the return path symmetric through the NVA.

### FortiGate routing consideration

Terraform currently configures Azure infrastructure, not FortiOS routes. The Instructor FortiGate must therefore route student prefixes out `port1` toward Azure's fabric. The dedicated NVA address `10.0.40.4` must **not** be used as a directly connected FortiGate gateway because it is off-subnet from `port1`.

Do not introduce a broad Azure `10.0.0.0/8` UDR. Explicit student prefixes are intentional and make the data path deterministic.

## 7. Why the NVA has a dedicated subnet

The original design placed the Linux transit NVA on the same subnet as the Instructor FortiGate. During testing, UDRs created a forwarding loop: packets could be redirected back toward the same transit segment/NVA repeatedly rather than progressing through a clean sequence of routing domains.

Moving the NVA to `snet-nva` (`10.0.40.0/24`) gives Azure a clear boundary where a subnet UDR can steer `0.0.0.0/0` to the Instructor FortiGate. The Instructor transit subnet can independently steer student return prefixes to the NVA. This removes the ambiguous/shared-subnet routing pattern and makes packet flow easier to validate.

## 8. Management access

The Instructor management subnet has an NSG named `nsg-management` with inbound management access restricted to the configured administrator public IP for:

- TCP/443
- TCP/22

The working design also calls for browser-based access via Guacamole. Guacamole is part of the intended instructor environment, but its final deployment/validation state is not documented in the current source material and should be recorded when completed.

## 9. Linux training hosts

### Client packages

The client VM baseline includes:

- `curl`
- `tcpdump`
- `traceroute`
- `iproute2`
- `net-tools`
- `nmap`
- `dnsutils`
- `netcat-openbsd`
- `iperf3`
- `hping3`
- `jq`

### DMZ server intent

The working design calls for:

- nginx
- OpenSSH server
- Python 3
- Flask demo application

The Terraform `linux_vm` module is reused for both client and server roles.

## 10. Validated baseline

The following has been validated on `student01` after the NVA redesign and Linux VM redeployment:

- cloud-init reaches `status: done` with no reported errors;
- required client packages are installed;
- ICMP Internet connectivity works;
- DNS resolution works;
- HTTP access to `archive.ubuntu.com` works;
- HTTPS access to `archive.ubuntu.com` works;
- Instructor FortiGate logs match generated student traffic;
- Azure Network Watcher reports the expected chain;
- TCP traceroute exposes the first three expected hops:

```text
1  10.1.10.4   Student FortiGate
2  10.0.40.4   Transit Router NVA
3  10.0.0.4    Instructor FortiGate
```

The known-good logical path is therefore:

```text
10.1.10.10 -> 10.1.10.4 -> 10.0.40.4 -> 10.0.0.4 -> Internet
```

## 11. Future direction

The working design anticipates an IPSec overlay for later LAN/DMZ traffic scenarios. That overlay is not part of the validated baseline documented here and should be treated as future work until implemented and tested.

## 12. Design principles

- Preserve deterministic addressing and naming.
- Keep student pods isolated.
- Prefer reusable Terraform modules.
- Prefer cloud-init for disposable Linux hosts.
- Keep Azure plumbing simple and reproducible.
- Optimise for FortiGate administration training rather than offensive security.
- Avoid maintaining Kali unless a future exercise explicitly requires it.
