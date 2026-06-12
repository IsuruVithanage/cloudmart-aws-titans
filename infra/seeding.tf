# ============================================================
# DynamoDB Seeding Job - Runs once after product-service is ready
# ============================================================

resource "kubernetes_job" "dynamodb_seeder" {
  metadata {
    name      = "dynamodb-seeder"
    namespace = "cloudmart-prod"
  }

  spec {
    template {
      metadata {
        name = "dynamodb-seeder"
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "seeder"
          image = "python:3.12-slim"

          command = ["/bin/sh", "-c"]
          args = [<<EOF
            pip install boto3 && python - <<'PYCODE'
import boto3
from decimal import Decimal
import os
import time

print("Starting DynamoDB seeding...")

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('cloudmart-products')

products = [
    {"id": "prod-001", "name": "Wireless Bluetooth Headphones", "description": "Premium noise-cancelling headphones", "price": Decimal("79.99"), "category": "electronics", "stock": 150, "imageUrl": "/images/headphones.jpg"},
    {"id": "prod-002", "name": "Organic Ceylon Tea (100 bags)", "description": "Premium hand-picked Ceylon tea", "price": Decimal("12.99"), "category": "food", "stock": 500, "imageUrl": "/images/ceylon-tea.jpg"},
    {"id": "prod-003", "name": "USB-C Laptop Stand", "description": "Adjustable aluminium stand", "price": Decimal("49.99"), "category": "electronics", "stock": 75, "imageUrl": "/images/laptop-stand.jpg"},
    {"id": "prod-004", "name": "Handloom Cotton Sarong", "description": "Traditional Sri Lankan handloom sarong", "price": Decimal("24.99"), "category": "clothing", "stock": 200, "imageUrl": "/images/sarong.jpg"},
    {"id": "prod-005", "name": "Mechanical Keyboard (TKL)", "description": "Cherry MX Brown switches", "price": Decimal("89.99"), "category": "electronics", "stock": 60, "imageUrl": "/images/keyboard.jpg"},
    {"id": "prod-006", "name": "Cold Pressed Coconut Oil (500ml)", "description": "Virgin coconut oil from Sri Lanka", "price": Decimal("8.99"), "category": "food", "stock": 300, "imageUrl": "/images/coconut-oil.jpg"},
]

for product in products:
    table.put_item(Item=product)
    print(f"✅ Inserted: {product['name']}")

print("🎉 DynamoDB seeding completed successfully!")
PYCODE
          EOF
          ]

          env {
            name  = "AWS_REGION"
            value = "ap-south-1"
          }
        }

        service_account_name = "product-service-sa"   # Reuse product service role (has DynamoDB access)
      }
    }

    backoff_limit = 2
  }

  depends_on = [helm_release.aws_load_balancer_controller]  # Wait for cluster to be ready
}