data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  azs = length(var.availability_zones) == 2 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  ami = var.ami_id != "" ? var.ami_id : nonsensitive(data.aws_ssm_parameter.al2023[0].value)

  common_tags = merge(var.extra_tags, {
    Project    = var.project_name
    Assignment = "3"
    ManagedBy  = "Terraform"
  })

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    repository_url      = var.repository_url
    repository_branch   = var.repository_branch
    release_ref         = var.release_ref
    deployment_revision = var.deployment_revision
    bootstrap_script    = file("${path.module}/../scripts/user-data.sh")
  })
}
