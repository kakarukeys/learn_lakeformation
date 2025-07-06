module "iova_admin" {
  # for manual IAM operations
  # use this user to create TF workload identity
  # use this user to remove IAMAllowedPrincipals group
  # has no LF permissions, but can use S3 API to manipulate files
  # see https://docs.aws.amazon.com/lake-formation/latest/dg/access-control-underlying-data.html
  # The Lake Formation permissions model doesn't prevent access to Amazon S3 locations through the Amazon S3 API or console
  # if you have access to them through IAM or Amazon S3 policies. You can attach IAM policies to principals to block this access.
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_admin"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

module "iova_tf_workload_identity" { # for Terraform
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_tf_workload_identity"

  create_iam_access_key         = true
  create_iam_user_login_profile = false

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess", # it is also added to data lake admin by itself
  ]
}

# to handle rare cases where user imports tables created by glue role into TF
# data lake admins implicit perms do not include some perms such as DROP
resource "aws_lakeformation_permissions" "iova_tf_workload_identity_tbl_lf_perms" {
  principal = module.iova_tf_workload_identity.iam_user_arn

  permissions = [
    "ALL",
    "ALTER",
    "DELETE",
    "DESCRIBE",
    "DROP",
    "INSERT",
    "SELECT",
  ]

  permissions_with_grant_option = [
    "ALL",
    "ALTER",
    "DELETE",
    "DESCRIBE",
    "DROP",
    "INSERT",
    "SELECT",
  ]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

module "iova_data_lake_admin" {
  # for testing only
  # although this role is made data lake administrator and has implicit LF perms, it cannot do anything without IAM permissions
  # it cannot change data lake settings
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_data_lake_admin"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true
}

module "iova_lf_admin" {
  # for manual Lake Formation administration
  # use this user to remove any configs related to IAMAllowedPrincipals group
  # use this user to remove any legacy glue db setting "Default permissions for newly created tables"
  # it cannot change data lake settings because of AWSLakeFormationDataAdmin policy, use TF to change settings instead
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_lf_admin"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin",
    "arn:aws:iam::aws:policy/AWSLakeFormationCrossAccountManager",
    "arn:aws:iam::aws:policy/AWSResourceAccessManagerResourceShareParticipantAccess",
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonRedshiftReadOnlyAccess", # need its reshift:DescribeDataSharesForConsumer
  ]
}

data "aws_iam_policy_document" "iova_lf_readonly_admin_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "cloudtrail:DescribeTrails",
      "cloudtrail:LookupEvents",
      "glue:BatchGet*",
      "glue:Get*",
      "glue:List*",
      "glue:Search*",
      "lakeformation:Describe*",
      "lakeformation:Get*",
      "lakeformation:List*",
      "lakeformation:Search*",
      "organizations:DescribeAccount",
      "organizations:DescribeOrganization",
      "organizations:ListAccountsForParent",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:ListRoots",
      "ram:Get*",
      "ram:List*",
      "redshift:DescribeDataSharesForConsumer",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "sso:ListInstances",
    ]

    resources = ["*"]
  }
}

module "iova_lf_readonly_admin_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.54.1"

  name        = "iova_lf_readonly_admin_policy"
  description = "Lake Formation read-only admin policy"
  policy      = data.aws_iam_policy_document.iova_lf_readonly_admin_policy_document.json
}

module "iova_lf_readonly_admin" {
  # for checking and auditing of Lake Formation settings and permissions
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_lf_readonly_admin"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
    module.iova_lf_readonly_admin_policy.arn,
  ]
}

data "aws_iam_policy_document" "iova_data_engr_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = [
      module.iova_glue_artifacts.s3_bucket_arn,
      "${module.iova_glue_artifacts.s3_bucket_arn}/*",

      # external s3 buckets (not managed by LF)
      # "arn:aws:s3:::natasha-data-lake",
      # "arn:aws:s3:::natasha-data-lake/*",
    ]
  }
}

module "iova_data_engr_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.54.1"

  name        = "iova_data_engr_policy"
  description = "data engineer policy"
  policy      = data.aws_iam_policy_document.iova_data_engr_policy_document.json
}

module "iova_data_engr" {
  # for data engineering work
  # can query data with Athena
  # lack s3 permissions to call s3 API to get / update / delete objects in data lake bucket
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_data_engr"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess", # provides lakeformation:GetDataAccess
    module.iova_data_engr_policy.arn,
  ]
}

resource "aws_lakeformation_permissions" "iova_data_engr_catalog_lf_perms" {
  principal        = module.iova_data_engr.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "iova_data_engr_db_lf_perms" {
  principal   = module.iova_data_engr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_engr_tbl_lf_perms" {
  principal   = module.iova_data_engr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_engr_tbl_select_lf_perms" {
  principal   = module.iova_data_engr.iam_user_arn
  permissions = ["SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

data "aws_iam_policy_document" "iova_pii_classifier_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "lakeformation:GetResourceLFTags",
      "lakeformation:AddLFTagsToResource",
    ]

    resources = ["*"]
  }
}

module "iova_pii_classifier_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.54.1"

  name        = "iova_pii_classifier_policy"
  description = "PII classifier policy"
  policy      = data.aws_iam_policy_document.iova_pii_classifier_policy_document.json
}

module "iova_pii_classifier" {
  # for pii classification
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_pii_classifier"

  create_iam_access_key         = true
  create_iam_user_login_profile = false

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonBedrockReadOnly",
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess", # provides lakeformation:GetDataAccess
    module.iova_pii_classifier_policy.arn,
  ]
}

resource "aws_lakeformation_permissions" "iova_pii_classifier_lf_tag_lf_perms" {
  principal   = module.iova_pii_classifier.iam_user_arn
  permissions = ["DESCRIBE", "ASSOCIATE"]

  lf_tag {
    key    = aws_lakeformation_lf_tag.confidentiality.key
    values = ["non-sensitive", "sensitive", "confidential"]
  }
}

resource "aws_lakeformation_permissions" "iova_pii_classifier_catalog_lf_perms" {
  principal        = module.iova_pii_classifier.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "iova_pii_classifier_db_lf_perms" {
  principal   = module.iova_pii_classifier.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_pii_classifier_tbl_lf_perms" {
  principal = module.iova_pii_classifier.iam_user_arn

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

module "iova_data_mngr" {
  # example role
  # can query data with Athena
  # lack s3 permissions to call s3 API to get / update / delete objects in data lake bucket
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_data_mngr"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess", # provides lakeformation:GetDataAccess
  ]
}

resource "aws_lakeformation_permissions" "iova_data_mngr_catalog_lf_perms" {
  principal        = module.iova_data_mngr.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "iova_data_mngr_db_lf_perms" {
  principal   = module.iova_data_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_mngr_tbl_lf_perms" {
  principal   = module.iova_data_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_mngr_tbl_select_lf_perms" {
  principal   = module.iova_data_mngr.iam_user_arn
  permissions = ["SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }
  }
}

module "iova_hr_mngr" {
  # example role
  # can query data with Athena
  # lack s3 permissions to call s3 API to get / update / delete objects in data lake bucket
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_hr_mngr"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess", # provides lakeformation:GetDataAccess
  ]
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_catalog_lf_perms" {
  principal        = module.iova_hr_mngr.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_db_lf_perms1" {
  principal   = module.iova_hr_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_tbl_lf_perms1" {
  principal   = module.iova_hr_mngr.iam_user_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_db_lf_perms2" {
  principal   = module.iova_hr_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_hr.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_tbl_lf_perms2" {
  principal   = module.iova_hr_mngr.iam_user_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_hr.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_db_lf_perms3" {
  principal   = module.iova_hr_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_sales.key
      values = ["true"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_tbl_lf_perms3" {
  principal   = module.iova_hr_mngr.iam_user_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_sales.key
      values = ["true"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }
  }
}

module "iova_sales_mngr" {
  # example role
  # can query data with Athena
  # lack s3 permissions to call s3 API to get / update / delete objects in data lake bucket
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_sales_mngr"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess", # provides lakeformation:GetDataAccess
  ]
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_catalog_lf_perms" {
  principal        = module.iova_sales_mngr.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_db_lf_perms1" {
  principal   = module.iova_sales_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_tbl_lf_perms1" {
  principal   = module.iova_sales_mngr.iam_user_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_db_lf_perms2" {
  principal   = module.iova_sales_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_sales.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_tbl_lf_perms2" {
  principal   = module.iova_sales_mngr.iam_user_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_sales.key
      values = ["true"]
    }
  }
}

module "iova_tech_outsourcing_mngr" {
  # example role
  # can query data with Athena
  # lack s3 permissions to call s3 API to get / update / delete objects in data lake bucket
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "iova_tech_outsourcing_mngr"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess", # provides lakeformation:GetDataAccess
  ]
}

resource "aws_lakeformation_permissions" "iova_tech_outsourcing_mngr_catalog_lf_perms" {
  principal        = module.iova_tech_outsourcing_mngr.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "iova_tech_outsourcing_mngr_db_lf_perms2" {
  principal   = module.iova_tech_outsourcing_mngr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_tech_outsourcing_mngr_tbl_lf_perms2" {
  principal   = module.iova_tech_outsourcing_mngr.iam_user_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}
