output "region" {
  description = "AWS region"
  value       = var.region
}

output "iova_admin_password" {
  value     = module.iova_admin.iam_user_login_profile_password
  sensitive = true
}

output "iova_tf_workload_identity_access_key" {
  value = module.iova_tf_workload_identity.iam_access_key_id
}

output "iova_tf_workload_identity_secret_key" {
  value     = module.iova_tf_workload_identity.iam_access_key_secret
  sensitive = true
}

output "iova_data_lake_admin_password" {
  value     = module.iova_data_lake_admin.iam_user_login_profile_password
  sensitive = true
}

output "iova_lf_admin_password" {
  value     = module.iova_lf_admin.iam_user_login_profile_password
  sensitive = true
}

output "iova_lf_readonly_admin_password" {
  value     = module.iova_lf_readonly_admin.iam_user_login_profile_password
  sensitive = true
}

output "iova_data_engr_password" {
  value     = module.iova_data_engr.iam_user_login_profile_password
  sensitive = true
}

output "iova_pii_classifier_access_key" {
  value = module.iova_pii_classifier.iam_access_key_id
}

output "iova_pii_classifier_secret_key" {
  value     = module.iova_pii_classifier.iam_access_key_secret
  sensitive = true
}

output "iova_data_mngr_password" {
  value     = module.iova_data_mngr.iam_user_login_profile_password
  sensitive = true
}

output "iova_hr_mngr_password" {
  value     = module.iova_hr_mngr.iam_user_login_profile_password
  sensitive = true
}

output "iova_sales_mngr_password" {
  value     = module.iova_sales_mngr.iam_user_login_profile_password
  sensitive = true
}

output "iova_tech_outsourcing_mngr_password" {
  value     = module.iova_tech_outsourcing_mngr.iam_user_login_profile_password
  sensitive = true
}
