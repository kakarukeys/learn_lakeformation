provider "aws" {
  region     = var.region
  access_key = ""
  secret_key = ""
}

# terraform plan -var-file=envs/dev.tfvars -out plan.out
