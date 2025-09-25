variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "bucket_name" {
  type        = string
  description = "Unique S3 bucket name"
}

variable "force_destroy" {
  type    = bool
  default = true
}

