output "region" {
  description = "AWS region"
  value       = var.region
}

output "natasha_admin_password" {
  value     = module.natasha_admin.iam_user_login_profile_password
  sensitive = true
}

output "natasha_tf_workload_identity_access_key" {
  value = module.natasha_tf_workload_identity.iam_access_key_id
}

output "natasha_tf_workload_identity_secret_key" {
  value     = module.natasha_tf_workload_identity.iam_access_key_secret
  sensitive = true
}

output "natasha_lf_admin_password" {
  value     = module.natasha_lf_admin.iam_user_login_profile_password
  sensitive = true
}

output "natasha_data_engr_password" {
  value     = module.natasha_data_engr.iam_user_login_profile_password
  sensitive = true
}
