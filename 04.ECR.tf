resource "aws_ecr_repository" "iac-webgoat-ecr" {
  name = "iac-webgoat-ecr"

  force_delete = true
}

