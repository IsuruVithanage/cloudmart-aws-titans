# ============================================================
# DynamoDB Seeding Job - Runs once using local AWS CLI
# ============================================================

resource "local_file" "seed_data" {
  filename = "${path.module}/seed.json"
  content = jsonencode({
    "cloudmart-products" = [
      {
        PutRequest = {
          Item = {
            id          = { S = "prod-001" }
            name        = { S = "Wireless Bluetooth Headphones" }
            description = { S = "Premium noise-cancelling headphones" }
            price       = { N = "79.99" }
            category    = { S = "electronics" }
            stock       = { N = "150" }
            imageUrl    = { S = "/images/headphones.jpg" }
          }
        }
      },
      {
        PutRequest = {
          Item = {
            id          = { S = "prod-002" }
            name        = { S = "Organic Ceylon Tea (100 bags)" }
            description = { S = "Premium hand-picked Ceylon tea" }
            price       = { N = "12.99" }
            category    = { S = "food" }
            stock       = { N = "500" }
            imageUrl    = { S = "/images/ceylon-tea.jpg" }
          }
        }
      },
      {
        PutRequest = {
          Item = {
            id          = { S = "prod-003" }
            name        = { S = "USB-C Laptop Stand" }
            description = { S = "Adjustable aluminium stand" }
            price       = { N = "49.99" }
            category    = { S = "electronics" }
            stock       = { N = "75" }
            imageUrl    = { S = "/images/laptop-stand.jpg" }
          }
        }
      },
      {
        PutRequest = {
          Item = {
            id          = { S = "prod-004" }
            name        = { S = "Handloom Cotton Sarong" }
            description = { S = "Traditional Sri Lankan handloom sarong" }
            price       = { N = "24.99" }
            category    = { S = "clothing" }
            stock       = { N = "200" }
            imageUrl    = { S = "/images/sarong.jpg" }
          }
        }
      },
      {
        PutRequest = {
          Item = {
            id          = { S = "prod-005" }
            name        = { S = "Mechanical Keyboard (TKL)" }
            description = { S = "Cherry MX Brown switches" }
            price       = { N = "89.99" }
            category    = { S = "electronics" }
            stock       = { N = "60" }
            imageUrl    = { S = "/images/keyboard.jpg" }
          }
        }
      },
      {
        PutRequest = {
          Item = {
            id          = { S = "prod-006" }
            name        = { S = "Cold Pressed Coconut Oil (500ml)" }
            description = { S = "Virgin coconut oil from Sri Lanka" }
            price       = { N = "8.99" }
            category    = { S = "food" }
            stock       = { N = "300" }
            imageUrl    = { S = "/images/coconut-oil.jpg" }
          }
        }
      }
    ]
  })
}

resource "null_resource" "dynamodb_seeder" {
  depends_on = [
    module.data_services,
    local_file.seed_data
  ]

  provisioner "local-exec" {
    command = "aws dynamodb batch-write-item --request-items file://${local_file.seed_data.filename} --region ap-south-1"
  }
}