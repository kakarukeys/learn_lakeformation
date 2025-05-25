module "iova_athena" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "aws-athena-query-results-iova"

  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
  force_destroy            = true
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_athena_data_catalog" "natasha" {  # glue catalog sharing without resource link
  name        = "natasha"
  description = "Natasha Athena data catalog"
  type        = "GLUE"

  parameters = {
    "catalog-id" = "769026163231"
  }
}
