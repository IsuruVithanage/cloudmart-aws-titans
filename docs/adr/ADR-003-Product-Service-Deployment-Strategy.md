# ADR-003: Deployment Strategy for `product-service`

## Status
Accepted

## Context
`product-service` is the most heavily trafficked backend in CloudMart — it serves the product catalogue to the `frontend` and is also called synchronously by `order-service` during every order creation. Downtime or errors in `product-service` directly block purchases, making its deployment strategy a critical operational decision.

CloudMart's current scale and team maturity constraints are:
- **Team size**: Small student team; limited capacity to operate complex deployment infrastructure.
- **RTO target**: < 5 minutes — a complete failure of `product-service` must be recovered within 5 minutes.
- **Traffic pattern**: Moderate, bursty retail traffic; no strict SLA on sub-millisecond response times.
- **HPA**: `product-service` already has CPU-based HPA (`minReplicas: 2`, `maxReplicas: 6`), meaning multiple healthy replicas are always running in production.
- **Kubernetes primitives**: The cluster already provisions 3 `t3.small` nodes with headroom for a `maxSurge: 1` pod.

We evaluated three deployment strategies:

| Strategy | Zero-Downtime | Complexity | Infrastructure Cost | Rollback Speed |
|---|---|---|---|---|
| **Rolling Update** | Yes (with `maxUnavailable: 0`) | Low | None (uses existing nodes) | Moderate (~3-5 min re-deploy old version) |
| **Blue/Green** | Yes | High | Doubles pod count during switch | Fast (instant traffic switch) |
| **Canary** | Yes | Very High | Requires Argo Rollouts / Flagger + Prometheus | Automatic (metric-gated halt) |

## Decision
Use **Rolling Update** as the primary deployment strategy for `product-service`, configured with:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

This configuration ensures:
- At least **2 healthy replicas** serve traffic at all times during a rollout (no downtime).
- Only **1 new pod** is started at a time, limiting blast radius if the new version is broken.
- Kubernetes readiness probes gate traffic from reaching the new pod until `/ready` returns `200 OK`.

## Consequences

**Positive:**
- **Zero operational overhead:** No additional controllers or infrastructure required. Rolling update is a native Kubernetes capability; the `minReplicas: 2` HPA setting guarantees live traffic is always served.
- **Cost-neutral:** The `maxSurge: 1` pod uses existing node capacity without requiring a dedicated extra node, unlike blue/green which would double pod count.
- **Automatic rollback path:** If the readiness probe on the new pod fails, Kubernetes halts the rollout and leaves the existing replicas serving traffic — providing de facto automatic rollback at no extra cost.
- **Appropriate for current RTO:** The 5-minute RTO target is comfortably met — a full rollout of 2→3→2 replicas completes in under 2 minutes on `t3.small` nodes.
- **Simple to operate:** A team of students can understand, debug, and re-trigger rolling updates via `kubectl rollout restart` without requiring expertise in Argo Rollouts or Flagger.

**Negative:**
- **Mixed-version traffic window:** During a rollout, both old and new versions of `product-service` simultaneously serve requests. If the new version changes API response schema in a backward-incompatible way, some requests will succeed (old pod) and some will fail (new pod) — requiring strict API versioning discipline.
- **Slower rollback than blue/green:** Rolling back requires re-deploying the previous image tag, which takes 1-3 minutes. Blue/green can switch traffic instantly by updating a Service selector.
- **No automatic metric gate:** Unlike canary with Flagger, a rolling update has no built-in mechanism to halt if error rate spikes. The CloudWatch alarm (>5% errors → SNS alert) provides detection, but remediation (manual `kubectl rollout undo`) is still required.

## Alternatives Considered

1. **Blue/Green Deployment:**
   - *Why rejected:* Blue/green requires running a complete second set of pods (`product-service-green`) simultaneously while performing the switch. At 2 replicas minimum, this doubles the pod count to 4 during deployment — consuming roughly 2 extra ENI slots and additional CPU/memory on the `t3.small` nodes, which already have limited capacity. Furthermore, the team would need to manage Service selector updates or use a tool like Argo Rollouts. The operational complexity and resource cost are not justified at CloudMart's current scale, where rolling update + readiness probe provides equivalent zero-downtime guarantees.

2. **Canary Deployment (Argo Rollouts / Flagger):**
   - *Why rejected:* Canary with a metric gate (e.g., halt if error rate > 1%) is the Distinction-level requirement (`[D]` in §3.5) and is the most resilient strategy. However, it requires installing Argo Rollouts or Flagger, configuring a Prometheus data source for metric querying, and writing `AnalysisTemplate` or `MetricTemplate` resources. This significantly increases the operational complexity and introduces new failure modes (e.g., analysis provider outage blocking all deployments). Given the team's operational maturity and the project's RTO target of 5 minutes, the risk/benefit ratio favours the simpler rolling update at this stage. Canary would be the recommended evolution once the team establishes a Prometheus stack and gains experience with the current rolling update baseline.
