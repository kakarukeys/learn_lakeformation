locals {
  # created on UI
  qs_group_arn = "arn:aws:quicksight:ap-southeast-1:572512847063:group/default/test-lf-quicksight-gp"
}

# LF permissions for QuickSight groups

resource "aws_lakeformation_permissions" "qs_group_catalog_lf_perms" {
  principal        = local.qs_group_arn
  permissions      = ["DESCRIBE"]
  catalog_resource = true
}

resource "aws_lakeformation_permissions" "qs_group_db_lf_perms" {
  principal   = local.qs_group_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "qs_group_tbl_lf_perms" {
  principal   = local.qs_group_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.access_all.key
      values = ["true"]
    }
  }
}

resource "aws_lakeformation_permissions" "qs_group_tbl_select_lf_perms" {
  principal   = local.qs_group_arn
  permissions = ["SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

# delegated LF permissions

resource "aws_lakeformation_permissions" "qs_group_natasha_db_lf_perms" {
  principal   = local.qs_group_arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    catalog_id  = "769026163231"

    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}

resource "aws_lakeformation_permissions" "qs_group_natasha_tbl_lf_perms" {
  principal   = local.qs_group_arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    catalog_id  = "769026163231"

    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.confidentiality.key
      values = ["non-sensitive"]
    }
  }
}
