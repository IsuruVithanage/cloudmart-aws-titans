# CloudMart Implementation Evaluation

This document provides an evaluation of the current implementation against the assignment guidelines. It identifies missing features and partially/weakly implemented requirements for each category.

## 1. Networking & Virtual Network
* **Missing Implementation:** None identified.
* **Partially/Weakly Implemented:** None identified. (VPC, subnets, NAT, security groups, private endpoints, and flow logs are correctly configured).

## 2. Containerisation
* **Missing Implementation:** None identified.
* **Partially/Weakly Implemented:** None identified. (Dockerfiles use multi-stage builds, non-root users, ECR lifecycle policies are in place, and Trivy is integrated into CI).

## 3. Kubernetes on Managed K8s
* **Missing Implementation:** None identified.
* **Partially/Weakly Implemented:**
  * **Cluster Autoscaler:** A managed node group is defined with min/max sizes, but the Cluster Autoscaler (or Karpenter) deployment/Helm chart is missing to actively scale the nodes based on pending pods.

## 4. Security
* **Missing Implementation:**
  * **Cloud Threat Detection:** No threat detection service (e.g., AWS GuardDuty) is enabled.
  * **Web Application Firewall (WAF):** No WAF is attached to the load balancer.
  * **Policy Engine:** OPA/Gatekeeper or Kyverno is missing to enforce root container, privileged container, and registry restrictions.
* **Partially/Weakly Implemented:**
  * **Database Encryption & SSL:** While RDS uses default AWS managed encryption (`storage_encrypted = true`), a dedicated Customer Managed Key (KMS) is not explicitly provisioned as per requirements. Additionally, data in transit via SSL is not explicitly enforced via a DB Parameter Group (`rds.force_ssl = 1`).
  * **IMDSv2:** Instance metadata service hardening (IMDSv2) is not explicitly enforced in the EKS node group configuration.

## 5. CI/CD Pipeline
* **Missing Implementation:**
  * **Manual Approval Gate:** There is no manual approval gate in the CD pipeline before deploying to production.
  * **Post-Deployment Smoke Test:** The pipeline lacks HTTP health checks against readiness endpoints after deployment.
  * **Canary Deployment:** No canary deployment strategy (e.g., Argo Rollouts or Flagger) is implemented for `product-service` (uses standard rolling update).
* **Partially/Weakly Implemented:** None identified.

## 6. Observability
* **Missing Implementation:** None identified. 
* **Partially/Weakly Implemented:**
  * **Container Insights:** The `amazon-cloudwatch-observability` addon in `infra/modules/eks/main.tf` is commented out, meaning Container Insights/Kubernetes monitoring metrics are currently disabled.

## 7. Infrastructure as Code
* **Missing Implementation:** None identified.
* **Partially/Weakly Implemented:** None identified. (Terraform, Helm, and ArgoCD are used effectively).

## 8. Cost Management
* **Missing Implementation:**
  * **Cost Report & Budget Alerts:** No Terraform resources or configurations for cloud spend reports or monthly budget alerts.
  * **Architecture Decision Records (ADRs):** The `docs/adr/` directory and all required ADRs (Node machine type, DB technology, Deployment strategy) are missing.
  * **Calculations & Analysis:** Unit economics metric (cost per 1,000 orders) and committed-use savings analysis are not documented.
* **Partially/Weakly Implemented:** None identified.

## 9. Disaster Recovery
* **Missing Implementation:**
  * **RTO/RPO Targets:** RTO and RPO targets are not defined or justified in documentation.
  * **DNS Failover:** DNS health-check and failover to a static error page (hosted in S3) are not implemented.
* **Partially/Weakly Implemented:**
  * **Kubernetes Manifest Backup:** Velero is not configured, and the existing manual backup file (`k8s-backups/cloudmart-prod-backup.yaml`) is virtually empty.
