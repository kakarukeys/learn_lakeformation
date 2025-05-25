# Glue role

data "aws_iam_policy_document" "glue_role_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${module.iova_glue_artifacts.s3_bucket_arn}/*",
      "arn:aws:s3:::*/metadata/*" # Iceberg metadata
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "lakeformation:AddLFTagsToResource",
      "lakeformation:GetDataAccess",
      "lakeformation:GetResourceLFTags",
      "s3:PutObject",    # sometimes spark calls S3 API to create objects, see https://docs.aws.amazon.com/glue/latest/dg/security-lf-enable.html#security-lf-enable-open-table-format-support
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

resource "aws_lakeformation_permissions" "glue_role_lf_tag_lf_perms" {
  principal   = module.glue_role.iam_role_arn
  permissions = ["DESCRIBE", "ASSOCIATE"]

  lf_tag {
    key    = aws_lakeformation_lf_tag.confidentiality.key
    values = ["non-sensitive", "sensitive", "confidential"]
  }
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
  principal = module.glue_role.iam_role_arn

  # required for column LF tagging
  # undocumented
  permissions                   = ["ALL"]
  permissions_with_grant_option = ["ALL"]

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
    arn = aws_lakeformation_resource.iova_data_lake.arn
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

resource "aws_glue_catalog_database" "my_sales" {
  name         = "my_sales"
  description  = "my sales db"
  location_uri = "s3://${module.iova_data_lake.s3_bucket_id}/sales/"
}

resource "aws_lakeformation_resource_lf_tags" "my_sales_db_lf_tags" {
  database {
    name = aws_glue_catalog_database.my_sales.name
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
    key   = aws_lakeformation_lf_tag.data_domain_sales.key
    value = "true"
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.data_domain_hr.key
    value = "true"
  }
}

resource "aws_glue_catalog_database" "my_store" {
  name         = "my_store"
  description  = "my store db"
  location_uri = "s3://${module.iova_data_lake.s3_bucket_id}/store/"
}

resource "aws_lakeformation_resource_lf_tags" "my_store_db_lf_tags" {
  database {
    name = aws_glue_catalog_database.my_store.name
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
    key   = aws_lakeformation_lf_tag.data_domain_sales.key
    value = "true"
  }
}

resource "aws_glue_catalog_database" "success_factor" {
  name         = "success_factor"
  description  = "HR system db"
  location_uri = "s3://${module.iova_data_lake.s3_bucket_id}/success_factor/"
}

resource "aws_lakeformation_resource_lf_tags" "success_factor_db_lf_tags" {
  database {
    name = aws_glue_catalog_database.success_factor.name
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
    key   = aws_lakeformation_lf_tag.data_domain_hr.key
    value = "true"
  }
}

# Resource links and LF tagging

resource "aws_glue_catalog_database" "my_product" {
  name = "my_product"

  target_database {
    catalog_id    = "769026163231"
    database_name = "my_product"
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_lakeformation_resource_lf_tags" "my_product_db_lf_tags" { # resource links do not inherit tags from source
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

# Glue jobs

module "iova_glue_artifacts" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "iova-glue-artifacts"

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
  bucket = module.iova_glue_artifacts.s3_bucket_id

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
    script_location = "s3://${module.iova_glue_artifacts.s3_bucket_id}/etl.py"
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
