resource "random_id" "products_bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "products" {
  bucket = local.products_bucket_name

  # This environment is torn down and rebuilt routinely; product images are seed
  # data that can always be regenerated.
  force_destroy = true

  tags = {
    Name    = local.products_bucket_name
    Service = "catalog"
  }
}

resource "aws_s3_bucket_ownership_controls" "products" {
  bucket = aws_s3_bucket.products.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "products" {
  bucket = aws_s3_bucket.products.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "products" {
  count = var.products_bucket_public_block ? 1 : 0

  bucket = aws_s3_bucket.products.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "products" {
  count = var.products_bucket_lifecycle_enabled ? 1 : 0

  bucket = aws_s3_bucket.products.id

  rule {
    id     = "expire-noncurrent-media"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.products_bucket_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.products]
}
