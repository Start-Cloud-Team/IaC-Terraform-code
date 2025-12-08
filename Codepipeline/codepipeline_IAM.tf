resource "aws_iam_policy" "iac-codepipeline-policy" {
  name = "iac-codepipeline-policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [ 
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject", 
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::iac-codepipeline-s3-bucket",   
          "arn:aws:s3:::iac-codepipeline-s3-bucket/*"
        ]
      },
      {
        "Sid": "AllowCodeBuildForWebgoat",
        "Effect": "Allow",
        "Action": [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ],
        "Resource": [
          "arn:aws:codebuild:${var.region}:${var.account_id}:project/iac-Webgoat-Dast_tool",
          "arn:aws:codebuild:${var.region}:${var.account_id}:project/iac-codebuild"
        ]
      },
      {
        "Sid": "AllowCodeConnectionsUse",
        "Effect": "Allow",
        "Action": [
          "codeconnections:UseConnection",
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:ListConnections"
        ],
        "Resource": [
          "arn:aws:codestar-connections:${var.region}:${var.account_id}:connection/*",
          "arn:aws:codeconnections:${var.region}:${var.account_id}:connection/*"
        ]
      },
      {
        "Sid": "AllowCodeDeployDeploymentActions",
        "Action": [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment"
        ],
        "Resource": [
          "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentgroup:iac-codedeploy/iac-codedeploy-group"
        ],
        "Effect": "Allow"
      },
      {
        "Sid": "AllowCodeDeployApplicationActions",
        "Action": [
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ],
        "Resource": [
          "arn:aws:codedeploy:*:${var.account_id}:application:iac-codedeploy"
        ],
        "Effect": "Allow"
      },
      {
        "Sid": "AllowCodeDeployDeploymentConfigAccess",
        "Action": [
          "codedeploy:GetDeploymentConfig"
        ],
        "Resource": [
          "arn:aws:codedeploy:*:${var.account_id}:deploymentconfig:*"
        ],
        "Effect": "Allow"
      },
      {
        "Sid": "AllowECSRegisterTaskDefinition",
        "Action": [
          "ecs:RegisterTaskDefinition"
        ],
        "Resource": [
          "*"
        ],
        "Effect": "Allow"
      },
      {
        "Sid": "AllowPassRoleToECSWithCondition",
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": [
          "arn:aws:iam::${var.account_id}:role/iac-task-role",
          "arn:aws:iam::${var.account_id}:role/iac-task-execution-role"
        ],
        "Condition": {
          "StringEquals": {
            "iam:PassedToService": [
              "ecs.amazonaws.com",
              "ecs-tasks.amazonaws.com"
            ]
          }
        }
      },
      {
        "Sid": "AllowWebgoatCodeDeployApplicationActions",
        "Effect": "Allow",
        "Action": [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:Get*",
          "codedeploy:List*"
        ],
        "Resource": "*"
      },
      {
        "Sid": "AllowGetRole",
        "Effect": "Allow",
        "Action": [
          "iam:GetRole"
        ],
        "Resource": "*"
      },
      {
        "Sid": "AllowECSServiceUpdate",
        "Effect": "Allow",
        "Action": [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeClusters"
        ],
        "Resource": "*"
      },
      {
        "Sid": "AllowPassRoleForCodeDeploy",
        "Effect": "Allow",
        "Action": [
          "iam:PassRole"
        ],
        "Resource": "arn:aws:iam::${var.account_id}:role/iac-codedeploy-role",
        "Condition": {
          "StringEquals": {
            "iam:PassedToService": "codedeploy.amazonaws.com"
          }
        }
      },
      {
        "Sid": "AllowALBOperationsForCodeDeploy",
        "Effect": "Allow",
        "Action": [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "elasticloadbalancing:Describe*"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role" "iac-codepipeline-role" {
  name = "iac-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "iac-codepipeline-policy-attach" {
  role       = aws_iam_role.iac-codepipeline-role.name
  policy_arn = aws_iam_policy.iac-codepipeline-policy.arn

}
