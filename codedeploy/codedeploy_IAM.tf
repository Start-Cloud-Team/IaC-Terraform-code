####################CodeDeploy Policy create####################
resource "aws_iam_policy" "iac-codedeploy-policy" {
    name = "iac-codedeploy-policy"
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
        {
            "Sid": "AllowCodeDeployAccessAllS3Artifacts",
            "Effect": "Allow",
            "Action": [
            "s3:GetObject",
			"s3:GetObjectVersion",
            "s3:ListBucket"
            ],
        "Resource": "*"
        },
        {
            "Action": [
                "ecs:DescribeServices",
                "ecs:CreateTaskSet",
                "ecs:UpdateServicePrimaryTaskSet",
                "ecs:DeleteTaskSet",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:ModifyRule",
                "lambda:InvokeFunction",
                "cloudwatch:DescribeAlarms",
                "sns:Publish",
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "iam:PassRole"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "ecs-tasks.amazonaws.com"
                    ]
                }
            }
        }
    ]
    })
}

####################CodeDeploy Role create####################
resource "aws_iam_role" "iac-codedeploy-role" {
    name = "iac-codedeploy-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Effect = "Allow",
            Principal = {
                Service = "codedeploy.amazonaws.com"
            },
            Action = "sts:AssumeRole"
        }]
    })
}

####################CodeDeploy Role and Policy attach####################
resource "aws_iam_role_policy_attachment" "iac-codedeploy-attach" {
    role       = aws_iam_role.iac-codedeploy-role.name
    policy_arn = aws_iam_policy.iac-codedeploy-policy.arn

}
