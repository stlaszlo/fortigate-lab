# Fortinet Training Lab — Instructor Guide

> Operational guide for running the FortiGate training environment.
>
> This guide deliberately separates **platform readiness** from **course exercises**. The infrastructure is validated; the detailed Foundation/Advanced exercise sequence should be inserted once the final course mapping is approved.

## 1. Instructor objective

The lab should feel like a FortiGate environment, not an Azure lab. Students should receive predictable endpoints and a working routed path while the instructor retains enough observability to diagnose mistakes quickly.

Platform model:

```text
Student Client / DMZ
       |
       v
Student FortiGate
       |
       v
Transit NVA
       |
       v
Instructor FortiGate
       |
       v
Internet
```

Eight isolated student pods are available: `student01` through `student08`.

## 2. What students have

For student `N`:

```text
FortiGate WAN:   10.N.0.4
FortiGate LAN:   10.N.10.4
FortiGate DMZ:   10.N.20.4
Linux client:    10.N.10.10
DMZ server:      10.N.20.10
```

The client VM is equipped with common traffic-generation and troubleshooting tools including `curl`, `dig`, `nmap`, `hping3`, `iperf3`, `tcpdump`, `traceroute`, `jq` and netcat.

The intended DMZ-server role includes web/SSH/Python services for policy and inspection exercises.

## 3. Pre-class platform check

Run this before students are given access.

### Terraform / Azure

- `terraform plan` shows no unexpected drift.
- NVA address is `10.0.40.4`.
- Student WAN default routes point to `10.0.40.4`.
- NVA subnet default route points to Instructor FG `10.0.0.4`.
- Instructor transit routes for `10.1.0.0/16` through `10.8.0.0/16` point to `10.0.40.4`.
- NVA NIC IP forwarding is enabled.

### Student Linux baseline

On at least `student01`:

```bash
cloud-init status --wait
cloud-init status --long
ping -c 3 8.8.8.8
curl -I http://archive.ubuntu.com
curl -I https://archive.ubuntu.com
dig google.com
sudo traceroute 8.8.8.8 -T -p 443
```

Expected first three traceroute hops:

```text
10.1.10.4
10.0.40.4
10.0.0.4
```

Spot-check a second pod near the other end of the range, for example `student08`, to catch templating/addressing mistakes.

### FortiGate baseline

On Instructor FG:

```text
get system status
get router info routing-table all
show system interface
show router static
show firewall policy
```

Confirm the Internet policy allows whatever protocols the opening labs require. Do not accidentally leave the platform in the historical `HTTPS + PING only` state unless that restriction is intentional for an exercise.

On a representative student FG, capture the same baseline commands before class.

## 4. Golden configuration strategy

Before students start changing FortiGate state, export known-good configurations.

Minimum set:

```text
configs/
  instructor-baseline.conf
  student-baseline.conf
```

If student FortiGate configuration differs by pod, store one export per student instead.

The infrastructure source does not currently automate FortiOS configuration recovery, so these exports are the fastest recovery path when a student removes a route, interface configuration or critical policy.

## 5. Recommended student starting point

The current platform design supports the following teaching split well:

**Preconfigured platform plumbing**

- Azure VNets/subnets/peerings/UDRs;
- FortiGate NIC placement and IP addressing;
- Linux client and DMZ addressing;
- transit NVA and Instructor Internet breakout path;
- management access.

**Good candidates for student-owned FortiGate work**

- address/service objects;
- firewall policies;
- NAT behavior;
- security profiles;
- logging and traffic inspection;
- routing verification/troubleshooting;
- policy troubleshooting using debug flow/sniffers.

The exact lab-by-lab ownership is intentionally not invented here; align it with the final Foundation/Advanced course mapping.

## 6. Instructor visibility during a lab

When a student reports “the Internet is broken,” establish where the packet stops rather than immediately changing Azure.

### Student FG

```text
diagnose sniffer packet any '<filter>' 4 0 l
```

For policy/session analysis:

```text
diagnose debug flow filter clear
diagnose debug flow filter addr <destination-or-source>
diagnose debug flow trace start 100
diagnose debug enable
```

Stop debug when finished:

```text
diagnose debug disable
diagnose debug reset
```

### Instructor FG

Use a matching filter on `port1`:

```text
diagnose sniffer packet port1 '<filter>' 4 0 l
```

This quickly answers whether the flow reached the hub firewall.

### Transit NVA

```bash
sudo tcpdump -ni any <filter>
```

If the flow appears on the Student FG WAN but not the NVA, inspect Azure effective routes. If it reaches the Instructor FG but is not forwarded, inspect the Instructor FortiGate policy/session rather than the UDR.

## 7. Fast diagnostic decision tree

```text
Client cannot reach destination
        |
        v
Does Student FG see ingress packet?
   | no -> client route / local host / LAN path
   |
  yes
   v
Does Student FG emit packet on WAN?
   | no -> student route / policy / NAT / session
   |
  yes
   v
Does NVA see packet?
   | no -> student WAN effective route / Azure fabric
   |
  yes
   v
Does Instructor FG see packet on port1?
   | no -> NVA forwarding / NVA subnet UDR
   |
  yes
   v
Does Instructor FG forward it?
   | no -> Instructor policy / NAT / route
   |
  yes
   v
Check return traffic / destination behavior
```

## 8. Important troubleshooting lessons from platform build

### Port-specific failure usually means policy before routing

A UDR does not decide that TCP/443 is allowed while TCP/80 or TCP/8443 is not. If one protocol/port consistently works and another does not on the same IP path, inspect firewall policy/NSG/security controls.

The build process exposed exactly this when Instructor FG policy contained only `HTTPS` and `PING`.

### Local FortiGate tests are not forwarded-traffic tests

For example:

```text
execute telnet <ip> 80
```

originates from the FortiGate itself. Success proves local-out connectivity, but does not prove student traffic will match a forward policy.

### Trace one flow end to end

Use the same source, destination and port on every capture. Changing target hosts or protocols while moving between packet captures creates false contradictions.

### Keep the NVA routing boundary clean

The dedicated `10.0.40.0/24` NVA subnet exists specifically to prevent the shared-subnet UDR loop encountered during platform development. Do not move the NVA back to `snet-transit` casually.

## 9. Resetting Linux endpoints

If a client or DMZ host is damaged during a lab, it is disposable.

Preview matching Linux VMs:

```bash
terraform state list \
  | grep 'azurerm_linux_virtual_machine' \
  | grep -Ei '(client|dmz)'
```

Force-rebuild all student client/DMZ VMs when needed:

```bash
terraform apply $(
  terraform state list \
    | grep 'azurerm_linux_virtual_machine' \
    | grep -Ei '(client|dmz)' \
    | sed 's|^|-replace=|'
)
```

A single-pod replacement is preferable during class if only one student's Linux VM is damaged.

## 10. End-of-day checks

Before ending a training day:

- verify Instructor FG management remains accessible;
- export any FortiGate state that must carry into the next day;
- identify which exercises intentionally changed student baseline state;
- decide whether the next day starts from the current configuration or the golden baseline;
- check for unexpectedly stopped/deallocated VMs if the next session depends on them;
- run one representative end-to-end client test.

## 11. Suggested course dry-run process

Before the first live cohort, complete every exercise as `student01` without using instructor-only knowledge.

For each exercise, record:

| Item | Record |
|---|---|
| Starting FortiGate state | What must already exist |
| Student task | Exact configuration objective |
| Traffic generator | Client/DMZ command or application |
| Expected FortiGate evidence | Log/session/sniffer/debug result |
| Success criterion | What proves the task is complete |
| Likely mistakes | Top 2–3 student failure modes |
| Reset point | Whether next exercise depends on this state |

Anything that requires the instructor to silently repair Azure should be fixed in the platform or documented as an instructor-only prerequisite before course delivery.

## 12. Exercise framework

The current working design establishes the platform but does not contain the final Foundation/Advanced lab sequence. Use this structure when importing the approved course mapping:

```text
Lab <n>: <title>

Objective
Prerequisites / starting state
Student steps
Validation traffic
Expected FortiGate output/logs
Instructor notes
Common failure modes
Reset / carry-forward state
```

This keeps the infrastructure documentation stable while allowing the training material to evolve independently.

## 13. Current readiness checkpoint

The platform has passed the following representative tests:

- client cloud-init completed successfully;
- required tools installed;
- DNS works;
- ICMP works;
- HTTP and HTTPS Internet access work;
- Network Watcher reports the expected path;
- Instructor FG sees matching student traffic;
- traceroute confirms Student FG -> NVA -> Instructor FG.

The next meaningful readiness gate is not another Azure change. It is:

> **Complete the first training exercise from a clean `student01` pod without instructor intervention.**

Once that succeeds, repeat a short smoke test on another pod and treat the environment as ready for course rehearsal.
