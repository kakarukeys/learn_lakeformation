# Glue role

data "aws_iam_policy_document" "glue_role_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${module.natasha_glue_artifacts.s3_bucket_arn}/*",
      "arn:aws:s3:::*/metadata/*" # Iceberg metadata
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "lakeformation:GetDataAccess",
      "s3:PutObject",    # sometimes spark calls S3 API to create objects
      "s3:DeleteObject", # sometimes spark calls S3 API to delete objects
    ]

    resources = ["*"]
  }
}

module "glue_role_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.54.1"

  name        = "glue_role_policy"
  description = "glue service role policy"
  policy      = data.aws_iam_policy_document.glue_role_policy_document.json
}

module "glue_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.54.1"

  create_role       = true
  role_name         = "glue_role"
  role_description  = "service role for Glue to run jobs"
  role_requires_mfa = false

  trusted_role_services = [
    "glue.amazonaws.com",
  ]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole",
    module.glue_role_policy.arn,
  ]
}

resource "aws_lakeformation_permissions" "glue_role_catalog_lf_perms" {
  principal        = module.glue_role.iam_role_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "glue_role_db_lf_perms" {
  principal   = module.glue_role.iam_role_arn
  permissions = ["DESCRIBE", "CREATE_TABLE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "glue_role_tbl_lf_perms" {
  principal   = module.glue_role.iam_role_arn
  permissions = ["ALL"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "glue_role_data_loc_lf_perms" {
  principal   = module.glue_role.iam_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.natasha_data_lake.arn
  }
}

# Glue databases and LF tagging

resource "aws_glue_catalog_database" "default" {
  name        = "default"
  description = "DO NOT REMOVE, USED BY SPARK"
}

resource "aws_lakeformation_resource_lf_tags" "default_db_lf_tags" {
  database {
    name = aws_glue_catalog_database.default.name
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.access_all.key
    value = "true"
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.confidentiality.key
    value = "non-sensitive"
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.data_domain_general.key
    value = "true"
  }
}

resource "aws_glue_catalog_database" "my_product" {
  name         = "my_product"
  description  = "my product db"
  location_uri = "s3://${module.natasha_data_lake.s3_bucket_id}/product/"
}

resource "aws_lakeformation_resource_lf_tags" "my_product_db_lf_tags" {
  database {
    name = aws_glue_catalog_database.my_product.name
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.access_all.key
    value = "true"
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.confidentiality.key
    value = "non-sensitive"
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.data_domain_tech.key
    value = "true"
  }
}

# Glue resource policy (for traditional glue catalog sharing)

# data "aws_iam_policy_document" "glue_resource_policy_document" {
#   statement {
#     actions = [
#       "glue:GetDatabase",
#       "glue:GetDatabases",
#     ]

#     resources = concat([
#       "arn:aws:glue:ap-southeast-1:${local.account_id}:catalog",
#       ], [
#       for db in local.catalog_share_dbs : db.arn
#     ])

#     principals {
#       type        = "AWS"
#       identifiers = local.catalog_share_principals
#     }
#   }

#   statement {
#     actions = [
#       "glue:GetTable",
#       "glue:GetTables",
#       "glue:GetTableVersion",
#       "glue:GetTableVersions",
#       "glue:SearchTables",
#     ]

#     resources = concat([
#       "arn:aws:glue:ap-southeast-1:${local.account_id}:catalog",
#       ], [
#       for db in local.catalog_share_dbs : db.arn
#       ], [
#       for db in local.catalog_share_dbs : "arn:aws:glue:${var.region}:${local.account_id}:table/${db.name}/*"
#     ])

#     principals {
#       type        = "AWS"
#       identifiers = local.catalog_share_principals
#     }
#   }

#   # required if mixing traditional glue catalog sharing with RAM data sharing
#   # statement {
#   #   actions = ["glue:ShareResource"]

#   #   resources = [
#   #     "arn:aws:glue:${var.region}:${local.account_id}:table/*/*",
#   #     "arn:aws:glue:${var.region}:${local.account_id}:database/*",
#   #     "arn:aws:glue:${var.region}:${local.account_id}:catalog",
#   #   ]

#   #   principals {
#   #     type        = "Service"
#   #     identifiers = ["ram.amazonaws.com"]
#   #   }
#   # }
# }

# resource "aws_glue_resource_policy" "glue_resource_policy" {
#   policy        = data.aws_iam_policy_document.glue_resource_policy_document.json
#   enable_hybrid = "FALSE" # set to TRUE if also using RAM to share other stuff
# }

# Glue jobs

module "natasha_glue_artifacts" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "natasha-glue-artifacts"

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

resource "aws_s3_object" "etl_py" {
  bucket = module.natasha_glue_artifacts.s3_bucket_id

  key          = "etl.py"
  source       = "./etl.py"
  content_type = "text/plain"
  etag         = filemd5("./etl.py")
}

resource "aws_glue_job" "example_etl" {
  name = "example_etl"

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 4

  role_arn = module.glue_role.iam_role_arn

  command {
    script_location = "s3://${module.natasha_glue_artifacts.s3_bucket_id}/etl.py"
    name            = "glueetl"
    python_version  = "3"
  }

  default_arguments = {
    # "--enable-glue-datacatalog": "true" # no need if you enable FGAC
    # for glue 5.0 working on Iceberg tables, see https://aws.amazon.com/blogs/big-data/enforce-fine-grained-access-control-on-data-lake-tables-using-aws-glue-5-0-integrated-with-aws-lake-formation/
    "--enable-lakeformation-fine-grained-access" : "true",
    "--datalake-formats" : "iceberg",
  }
}

# ----

resource "aws_s3_object" "etl_g4_py" {
  bucket = module.natasha_glue_artifacts.s3_bucket_id

  key          = "etl_g4.py"
  source       = "./etl_g4.py"
  content_type = "text/plain"
  etag         = filemd5("./etl_g4.py")
}

resource "aws_glue_job" "example_etl_g4" {
  name = "example_etl_g4"

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  role_arn = module.glue_role.iam_role_arn

  command {
    script_location = "s3://${module.natasha_glue_artifacts.s3_bucket_id}/etl_g4.py"
    name            = "glueetl"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-glue-datacatalog": "true" # no need if you enable FGAC
    # for glue 5.0 working on Iceberg tables, see https://aws.amazon.com/blogs/big-data/enforce-fine-grained-access-control-on-data-lake-tables-using-aws-glue-5-0-integrated-with-aws-lake-formation/
    # "--enable-lakeformation-fine-grained-access" : "true",
    "--datalake-formats" : "iceberg",
  }
}
