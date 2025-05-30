resource "aws_lakeformation_data_lake_settings" "natasha_data_lake_settings" {
  admins = [
    module.natasha_tf_workload_identity.iam_user_arn,
    module.natasha_lf_admin.iam_user_arn,
  ]

  allow_external_data_filtering         = false
  allow_full_table_external_data_access = false

  parameters = {
    CROSS_ACCOUNT_VERSION = "3"
    SET_CONTEXT           = "TRUE"
  }
}

# custom role for Lake Formation data access (replacing service-linked role)

data "aws_iam_policy_document" "lf_data_access_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = [
      "${module.natasha_data_lake.s3_bucket_arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [
      module.natasha_data_lake.s3_bucket_arn,
    ]
  }

  statement { # from LakeFormationDataAccessServiceRolePolicy
    effect = "Allow"

    actions = [
      "s3:ListAllMyBuckets",
    ]

    resources = [
      "arn:aws:s3:::*"
    ]
  }
}

module "lf_data_access_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.54.1"

  name        = "lf_data_access_policy"
  description = "lf_data_access service role policy"
  policy      = data.aws_iam_policy_document.lf_data_access_policy_document.json
}

module "lf_data_access" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.54.1"

  create_role       = true
  role_name         = "lf_data_access"
  role_description  = "service role for lake formation data access"
  role_requires_mfa = false

  trusted_role_services = [
    "lakeformation.amazonaws.com",
  ]

  custom_role_policy_arns = [
    module.lf_data_access_policy.arn,
  ]
}

# LF tags

resource "aws_lakeformation_lf_tag" "access_all" { # this tag should be only granted to users / roles who need to access ALL data
  key    = "access_all"
  values = ["true"]
}

resource "aws_lakeformation_lf_tag" "confidentiality" {
  key    = "confidentiality"
  values = ["non-sensitive", "sensitive", "confidential"]
}

resource "aws_lakeformation_lf_tag" "data_domain_general" {
  key    = "general"
  values = ["true"]
}

resource "aws_lakeformation_lf_tag" "data_domain_tech" {
  key    = "tech"
  values = ["true"]
}

# cross-account grants

resource "aws_lakeformation_permissions" "iova_lf_tag_confidentiality_lf_perms" {
  principal   = "572512847063"
  permissions = ["DESCRIBE"]

  lf_tag {
    key    = aws_lakeformation_lf_tag.confidentiality.key
    values = ["non-sensitive", "sensitive"]
  }
}

resource "aws_lakeformation_permissions" "iova_lf_tag_data_domain_general_lf_perms" {
  principal   = "572512847063"
  permissions = ["DESCRIBE"]

  lf_tag {
    key    = aws_lakeformation_lf_tag.data_domain_general.key
    values = ["true"]
  }
}

resource "aws_lakeformation_permissions" "iova_lf_tag_data_domain_tech_lf_perms" {
  principal   = "572512847063"
  permissions = ["DESCRIBE"]

  lf_tag {
    key    = aws_lakeformation_lf_tag.data_domain_tech.key
    values = ["true"]
  }
}

# grant to account the maximum scope for management
# for decentralised management, use permissions_with_grant_option and let the receiver account do the granting
resource "aws_lakeformation_permissions" "iova_db_lf_perms" {
  principal   = "572512847063"
  permissions = ["DESCRIBE"]
  permissions_with_grant_option = ["DESCRIBE"]  # for quick sight groups, which are not supported by cross-account grants

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_tbl_lf_perms" {
  principal   = "572512847063"
  permissions = ["DESCRIBE", "SELECT"]
  permissions_with_grant_option = ["DESCRIBE", "SELECT"]  # for quick sight groups, which are not supported by cross-account grants

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

# grant to individual roles the right scope
# for centralised management, grant perms to individual roles here, instead of delegating to receiver accounts
resource "aws_lakeformation_permissions" "iova_glue_role_db_lf_perms" {
  principal   = "arn:aws:iam::572512847063:role/glue_role"
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_glue_role_tbl_lf_perms" {
  principal   = "arn:aws:iam::572512847063:role/glue_role"
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_engr_db_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_data_engr"
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_engr_tbl_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_data_engr"
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_mngr_db_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_data_mngr"
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_data_mngr_tbl_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_data_mngr"
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_db_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_hr_mngr"
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_hr_mngr_tbl_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_hr_mngr"
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_db_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_sales_mngr"
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_sales_mngr_tbl_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_sales_mngr"
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive", "sensitive"]
    }

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_tech_outsourcing_mngr_db_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_tech_outsourcing_mngr"
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "iova_tech_outsourcing_mngr_tbl_lf_perms" {
  principal   = "arn:aws:iam::572512847063:user/iova_tech_outsourcing_mngr"
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.data_domain_tech.key
      values = ["true"]
    }
  }
}
