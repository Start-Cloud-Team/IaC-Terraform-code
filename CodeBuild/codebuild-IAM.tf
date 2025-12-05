resource "aws_iam_policy" "iac-codebuild-policy" {
  name = "${var.codebuild_name}-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection",
          "s3-object-lambda:*",
          "ssm:Describe*",
          "ssm:Get*",
          "ssm:List*",
          "codebuild:StartBuild",
          "ecr:CreateRepository",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "cloudwatch:GenerateQuery",
          "cloudwatch:GenerateQueryResultsSummary",
          "secretsmanager:GetSecretValue",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "codebuild:BatchGetBuilds",
          "iam:PassRole",
          "ecs:RegisterTaskDefinition",
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentGroup"
        ],
        Resource = "arn:aws:codebuild:${var.region}:${var.account_id}:project/${var.codebuild_name}"
      },
    ]
  })
}

resource "aws_iam_role" "iac-codebuild-role" {
  name = "${var.codebuild_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "iac-codebuild-attach" {
  role       = aws_iam_role.iac-codebuild-role.name
  policy_arn = aws_iam_policy.iac-codebuild-policy.arn
}
