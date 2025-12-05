output "role_arn" {
  value = aws_iam_role.iac-codebuild-role.arn
}

output "policy_arn" {
  value = aws_iam_policy.iac-codebuild-policy.arn
}
