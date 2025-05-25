resource "aws_lakeformation_data_lake_settings" "iova_data_lake_settings" {
  admins = [
    module.iova_tf_workload_identity.iam_user_arn,
    module.iova_data_lake_admin.iam_user_arn,
    module.iova_lf_admin.iam_user_arn,
  ]

  read_only_admins = [
    module.iova_lf_readonly_admin.iam_user_arn,
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
      "${module.iova_data_lake.s3_bucket_arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [
      module.iova_data_lake.s3_bucket_arn,
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

resource "aws_lakeformation_lf_tag" "data_domain_sales" {
  key    = "sales"
  values = ["true"]
}

resource "aws_lakeformation_lf_tag" "data_domain_hr" {
  key    = "hr"
  values = ["true"]
}

# resource shares (makes TF planning slow, the best is to auto-accept using organization setting)

# resource "aws_ram_resource_share_accepter" "accept_nathasha_share1" {
#   share_arn = "arn:aws:ram:ap-southeast-1:769026163231:resource-share/acb7deb1-6170-49c0-ad6d-48f3b174782d"
# }

# resource "aws_ram_resource_share_accepter" "accept_nathasha_share2" {
#   share_arn = "arn:aws:ram:ap-southeast-1:769026163231:resource-share/7edf8c63-839c-41d2-bc16-53100188b105"
# }
