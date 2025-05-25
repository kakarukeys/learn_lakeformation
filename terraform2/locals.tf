locals {
  account_id = data.aws_caller_identity.current.account_id

  catalog_share_principals = [
    "arn:aws:iam::572512847063:root",
  ]

  catalog_share_dbs = [
    aws_glue_catalog_database.my_product
  ]
}
