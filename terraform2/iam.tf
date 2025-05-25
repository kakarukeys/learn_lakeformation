module "natasha_admin" {
  # for manual IAM operations
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "natasha_admin"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

module "natasha_tf_workload_identity" { # for Terraform
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "natasha_tf_workload_identity"

  create_iam_access_key         = true
  create_iam_user_login_profile = false

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]
}

module "natasha_lf_admin" {
  # for manual Lake Formation administration
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "natasha_lf_admin"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin",
    "arn:aws:iam::aws:policy/AWSLakeFormationCrossAccountManager",
    "arn:aws:iam::aws:policy/AWSResourceAccessManagerResourceShareParticipantAccess",
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonRedshiftReadOnlyAccess",
  ]
}

data "aws_iam_policy_document" "natasha_data_engr_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = [
      module.natasha_glue_artifacts.s3_bucket_arn,
      "${module.natasha_glue_artifacts.s3_bucket_arn}/*",
    ]
  }
}

module "natasha_data_engr_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.54.1"

  name        = "natasha_data_engr_policy"
  description = "data engineer policy"
  policy      = data.aws_iam_policy_document.natasha_data_engr_policy_document.json
}

module "natasha_data_engr" {
  # for data engineering work
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.54.1"

  name = "natasha_data_engr"

  create_iam_access_key         = false
  create_iam_user_login_profile = true

  password_reset_required = false
  force_destroy           = true

  policy_arns = [
    "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess",
    # "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", # need this to read data, when no Lake Formation set up
    module.natasha_data_engr_policy.arn,
  ]
}

resource "aws_lakeformation_permissions" "natasha_data_engr_catalog_lf_perms" {
  principal        = module.natasha_data_engr.iam_user_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "natasha_data_engr_db_lf_perms" {
  principal   = module.natasha_data_engr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "natasha_data_engr_tbl_lf_perms" {
  principal   = module.natasha_data_engr.iam_user_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "natasha_data_engr_tbl_select_lf_perms" {
  principal   = module.natasha_data_engr.iam_user_arn
  permissions = ["SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}
