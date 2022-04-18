# Sets up an S3 bucket to store public web content, with a security policy which allows
# access from cloudfront
#
# Additionally sets up an IAM user which is able to upload to the bucket

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  acl    = var.acl
}

resource "aws_cloudfront_origin_access_identity" "identity" {
  comment = "S3 content for ${var.bucket_name}"
}

data "aws_iam_policy_document" "policy" {
  dynamic "statement" {
    # conditionally add a statement to deny access to the var.blocked_paths
    #
    # We really want to say if length(var.blocked_paths) > 0
    # But instead we map to an array of arrays, and filter out any empty arrays, then apply for_each
    # This has the effect of generating exactly 0 or 1 dynamic block
    for_each = [for set in [[for path in var.blocked_paths : "${aws_s3_bucket.bucket.arn}${path}"]] : set if length(set) > 0]
    content {
      actions   = ["s3:GetObject"]
      resources = toset(statement.value)
      effect    = "Deny"

      principals {
        type        = "AWS"
        identifiers = [aws_cloudfront_origin_access_identity.identity.iam_arn]
      }
    }
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.identity.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_control" {
  bucket = var.bucket_name

  block_public_acls       = var.acl == "private" ? true : false
  block_public_policy     = var.acl == "private" ? true : false
  ignore_public_acls      = var.acl == "private" ? true : false
  restrict_public_buckets = var.acl == "private" ? true : false
}

resource "aws_s3_bucket_policy" "grant_cloudfront_access_to_bucket" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.policy.json
}
