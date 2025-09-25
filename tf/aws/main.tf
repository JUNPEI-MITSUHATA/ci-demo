resource "aws_s3_bucket" "demo" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Project = "ci-demo"
    Managed = "terraform"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}

