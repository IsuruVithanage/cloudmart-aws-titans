# ADR-002: Database Technology for User Service

## Status
Accepted

## Context
CloudMart's `user-service` requires a persistent, production-grade data store for user registration, JWT authentication, and profile management. The data model is inherently relational and must operate under strict technical and business constraints:
- **Data Integrity & ACID Compliance:** Must enforce strict `UNIQUE` constraints on user emails at the database level to prevent duplicate accounts during concurrent requests.
- **Strong Consistency:** Requires immediate read-after-write consistency to guarantee users can log in immediately after registration.
- **Cost Management:** Must strictly fit within the AWS Free Tier or utilize minimal-cost compute resources.
- **Operational Overhead:** Must minimize manual database administration, offloading backups and patching to the cloud provider.

We evaluated Amazon RDS (Managed PostgreSQL), Amazon DynamoDB (Managed NoSQL), Amazon Aurora (Serverless Relational), and self-managed deployments.

## Decision
Provision **Amazon RDS for PostgreSQL (Managed Relational Database)** for the `user-service`, utilizing the `db.t3.micro` instance class.

## Consequences

**Positive:**
- **Data Integrity:** Natively enforces `UNIQUE` constraints and full ACID transactions without complex, application-level workarounds.
- **Immediate Consistency:** Inherently guarantees the strong read-after-write consistency required for secure authentication flows.
- **Low Operational Overhead:** AWS fully manages routine administration, eliminating the undifferentiated heavy lifting of automated backups and minor version patching.
- **Cost-Effectiveness:** The `db.t3.micro` instance class directly aligns with the project's strict minimal-cost constraints.
- **Ecosystem Alignment:** Integrates seamlessly with the existing Python/Flask application code and standard `psycopg2` connection pooling.

**Negative:**
- **Fixed Cost Model:** Incurs a baseline compute and storage cost 24/7, even during periods of zero traffic, unlike a pay-per-request serverless model.
- **Scaling Complexity:** Vertical scaling (instance size upgrades) requires a brief downtime window. Horizontal read scaling requires manual provisioning of read replicas.
- **Connection Management:** Requires the application to strictly manage connection pooling to prevent connection exhaustion under heavy load.

## Alternatives Considered

1. **Amazon DynamoDB (Managed NoSQL):**
    - *Why it was rejected:* Fundamentally misaligned with the service's relational needs. Enforcing email uniqueness requires complex conditional writes or secondary lookup tables. Furthermore, enforcing the required strong consistency for authentication doubles the read capacity cost.

2. **Amazon Aurora PostgreSQL (Serverless / Managed Relational):**
    - *Why it was rejected:* Rejected strictly due to cost. While Aurora provides ideal enterprise-grade high availability and automated scaling, its baseline minimum cost significantly exceeds that of a standard RDS `db.t3.micro` instance, making it financially unviable for this project.

3. **Self-Managed PostgreSQL on EKS (StatefulSet):**
    - *Why it was rejected:* Managing persistent storage provisioning, backups, patching, and failover manually via Kubernetes StatefulSets directly contradicts the architectural mandate to utilize cloud-managed services to reduce operational toil.