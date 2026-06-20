# CloudMart — IS 4630 Group Assignment
## Team: Team Titans

## Cloud Provider
Amazon Web Services (AWS) — Region: ap-south-1 (Mumbai)

## Team Members & Contributions
| Member            | Responsibility                                              |
|-------------------|-------------------------------------------------------------|
| Isuru Vithanage   | Infrastructure Foundation (Terraform, VPC, EKS, Networking) |
| Kavith Rashintha  | Kubernetes Deployments & Observability                      |
| Ashan Salinda     | Containerisation & Security                                 |
| Ushan Priyashanka | CI/CD Pipeline & Cost Management                            |
| Savith Abeyrathne | Disaster Recovery                                           |

## Architecture Summary
- **VPC**: 10.0.0.0/16 across ap-south-1a and ap-south-1b
- **Three-tier subnets**: Public (ALB), Private (EKS nodes), Database (RDS)
- **EKS**: Kubernetes 1.30, 2x t3.small nodes
- **ECR**: 5 repositories (one per microservice)
- **Namespaces**: cloudmart-prod, cloudmart-staging

## Deployment Instructions
```bash
# 1. Configure AWS CLI
aws configure

# 2. Deploy infrastructure
cd infra/
terraform init
terraform apply

# 3. Connect kubectl
aws eks update-kubeconfig --name cloudmart-eks --region ap-south-1

# 4. Verify
kubectl get nodes
kubectl get namespaces
```