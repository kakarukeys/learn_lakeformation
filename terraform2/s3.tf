module "natasha_data_lake" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "natasha-data-lake"

  # attach_policy = true
  # policy                   = data.aws_iam_policy_document.natasha_data_lake_policy.json

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

# data "aws_iam_policy_document" "natasha_data_lake_policy" { # require if sharing catalog without LF
#   statement {
#     effect = "Allow"

#     actions = [
#       "s3:Get*",
#       "s3:List*",
#     ]

#     resources = [
#       module.natasha_data_lake.s3_bucket_arn,
#       "${module.natasha_data_lake.s3_bucket_arn}/*"
#     ]

#     principals {
#       type = "AWS"

#       identifiers = local.catalog_share_principals
#     }
#   }
# }

resource "aws_lakeformation_resource" "natasha_data_lake" {
  arn                   = module.natasha_data_lake.s3_bucket_arn
  role_arn              = module.lf_data_access.iam_role_arn
  hybrid_access_enabled = false
}
