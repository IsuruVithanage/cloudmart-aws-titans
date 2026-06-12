resource "aws_ecr_repository" "services" {
for_each = toset(var.service_names)

name                 = "cloudmart/${each.value}"
image_tag_mutability = "MUTABLE"
force_delete        = true

image_scanning_configuration {
scan_on_push = true
}

tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "services" {
for_each   = aws_ecr_repository.services
repository = each.value.name

policy = jsonencode({
rules = [{
rulePriority = 1
description  = "Keep only last 10 images per repository"
selection = {
tagStatus   = "any"
countType   = "imageCountMoreThan"
countNumber = 10
}
action = { type = "expire" }
}]
})
}