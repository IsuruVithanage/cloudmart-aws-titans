# ADR-001: Kubernetes Node Instance Type Selection

## Status
Accepted

## Context
CloudMart's EKS cluster requires worker nodes that can reliably host all five microservices in production (`product-service`, `order-service`, `user-service`, `notification-service`, `frontend`) plus cluster-level add-ons (AWS Load Balancer Controller, External Secrets Operator, KEDA, Kyverno, CoreDNS, `kube-proxy`, and the Amazon CloudWatch Observability agent).

The cluster is configured with `min_size = 2 / max_size = 3 / desired_size = 3` nodes (Section 3.3 [R] — Cluster Autoscaler must scale within this range). Key constraints are:

- **Cost**: Must stay within a minimal-spend budget; the Free Tier does not cover EKS worker nodes.
- **Capacity**: Must comfortably fit all workloads with headroom for rolling updates (`maxSurge: 1`).
- **Architecture**: `x86_64` required because both Python (Flask/gunicorn) and Node.js images are built for `linux/amd64`.
- **Memory per Pod**: The aggregate memory *requests* across all five services equals approximately **512 Mi** per node at minimum load, rising to ~800 Mi under HPA scaling — a `t3.micro` (1 GiB) is immediately eliminated.
- **Network**: VPC CNI requires ENI capacity; smaller instances have very few ENIs and secondary IPs.

We evaluated three candidate instance families:

| Instance | vCPU | RAM | On-Demand Price (ap-south-1) | Max Pods (VPC CNI) |
|---|---|---|---|---|
| `t3.small` | 2 | 2 GiB | ~$0.023/hr (~$16.56/mo) | 11 |
| `t3.medium` | 2 | 4 GiB | ~$0.046/hr (~$33.12/mo) | 17 |
| `t3a.small` (ARM-equiv: `t4g.small`) | 2 | 2 GiB | ~$0.018/hr (~$12.96/mo) | 11 |

> `t4g.small` (Graviton2 ARM) offers the lowest cost but is excluded because the service images are built for `linux/amd64`.

## Decision
Use **`t3.small`** instances (`AL2023_x86_64_STANDARD` AMI) for the EKS managed node group.

- 3 nodes × $0.023/hr = **~$0.069/hr** (~**$49.68/month** total)
- 3 nodes × 11 max-pods = 33 total pod slots — sufficient for 5 services (2 replicas each = 10 pods) + add-ons (~8 pods) + 5 surge pods during rolling updates = 23 pods peak

## Consequences

**Positive:**
- **Cost-effective:** At $16.56/node/month it is the lowest-cost `x86_64` instance that fits the aggregate workload; 43% cheaper than `t3.medium` with identical vCPU count.
- **Burstable CPU:** T3 instances provide CPU burst credits, which suits CloudMart's bursty retail traffic well — sustained bursts trigger HPA scaling rather than sustained CPU consumption.
- **ENI capacity sufficient:** 11 max-pods per node is adequate; the VPC CNI add-on (`ENABLE_PREFIX_DELEGATION`) can extend this further if needed without a node size change.
- **Proven ecosystem fit:** `AL2023_x86_64_STANDARD` AMI is the recommended default for EKS 1.30+ and includes containerd and `kubectl` tooling pre-installed.

**Negative:**
- **CPU throttling under sustained load:** Once CPU credits are exhausted, `t3.small` instances throttle. If CloudMart experiences sustained traffic (not bursts), a `t3.medium` or `m6i.large` would be more appropriate.
- **Limited pod density:** 11 max-pods per node (without prefix delegation) constrains future service additions without a node size upgrade.
- **No ARM savings:** Graviton2 (`t4g`) would save ~22% further, but is incompatible with the current `linux/amd64` images.

## Alternatives Considered

1. **`t3.medium` (2 vCPU / 4 GiB RAM):**
   - *Why rejected:* Doubles the memory headroom but at twice the cost ($33.12/node/month). The current workload aggregate leaves ample headroom on `t3.small`; paying for 4 GiB per node when only ~1.5 GiB is consumed is economically unjustifiable at this project scale.

2. **`t4g.small` (Graviton2 ARM, 2 vCPU / 2 GiB):**
   - *Why rejected:* The service Dockerfiles currently build single-platform `linux/amd64` images. Running them under QEMU emulation on Graviton2 nodes would cause significant performance degradation and is not production-appropriate. Multi-arch builds would be required, adding CI pipeline complexity beyond the current scope.

3. **`m6i.large` (General Purpose, 2 vCPU / 8 GiB):**
   - *Why rejected:* Priced at approximately $0.096/hr ($69.12/node/month) — nearly 4× the cost of `t3.small`. The memory and CPU capacity is excessive for this workload and cannot be justified within the project's cost constraints. This instance class is better suited for stateful workloads or high-throughput APIs.
