output "vpc_id"              { value = module.vpc.vpc_id }
output "public_subnets"      { value = module.vpc.public_subnets }
output "private_subnets"     { value = module.vpc.private_subnets }
output "database_subnets"    { value = module.vpc.database_subnets }
output "bastion_sg_id"       { value = aws_security_group.bastion.id }
output "load_balancer_sg_id" { value = aws_security_group.load_balancer.id }
output "database_sg_id"      { value = aws_security_group.database.id }