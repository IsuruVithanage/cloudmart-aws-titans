# Security Group Justification — CloudMart (Principle of Least Privilege)

## 1. Bastion Host SG (`cloudmart-bastion-sg`)
| Rule | Port | Source | Justification |
|------|------|--------|---------------|
| Inbound SSH | 22 | 0.0.0.0/0 | Admin access for troubleshooting. Restrict to known IP in production. |
| Outbound All | All | 0.0.0.0/0 | Required to reach private resources inside VPC. |

## 2. Load Balancer SG (`cloudmart-alb-sg`)
| Rule | Port | Source | Justification |
|------|------|--------|---------------|
| Inbound HTTP | 80 | 0.0.0.0/0 | Public internet access to frontend. Redirects to HTTPS. |
| Inbound HTTPS | 443 | 0.0.0.0/0 | Secure public internet access to frontend. |
| Outbound All | All | VPC CIDR | Forward traffic only to EKS worker nodes inside VPC. |

## 3. Database SG (`cloudmart-db-sg`)
| Rule | Port | Source | Justification |
|------|------|--------|---------------|
| Inbound PostgreSQL | 5432 | 10.0.11.0/24, 10.0.12.0/24 | Only private app subnets (EKS nodes) can reach RDS. Database is never exposed to public internet. |
| Outbound None | — | — | RDS does not initiate outbound connections. |

## 4. EKS Worker Node SG (managed by EKS module)
| Rule | Port | Source | Justification |
|------|------|--------|---------------|
| Inbound from ALB | 30000-32767 | ALB SG | NodePort range for Kubernetes services. |
| Inbound from control plane | 443, 10250 | EKS control plane | Required for kubelet and API server communication. |
| Outbound All | All | 0.0.0.0/0 | Workers need internet access via NAT for pulling images. |
