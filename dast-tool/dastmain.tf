# 1. SSM Parameter Store
resource "aws_ssm_parameter" "hawk_api_key" {
  name  = "/hawk/api_key"
  type  = "SecureString"
  value = var.hawk_api_key
  overwrite = true
}

resource "aws_ssm_parameter" "docker_id" {
  name  = "/hawk/docker_id"
  type  = "String"
  value = var.docker_hub_id
  overwrite = true
}

resource "aws_ssm_parameter" "docker_pw" {
  name  = "/hawk/docker_pw"
  type  = "SecureString"
  value = var.docker_hub_token
  overwrite = true
}

# 2. S3 Bucket for Logs 
resource "aws_s3_bucket" "dast_logs" {
  bucket = var.s3_log_bucket_name
  force_destroy = true # 실습용이라 삭제 가능하게 함 (운영에선 false 추천)
}

# 3. IAM Role & Policy 
resource "aws_iam_role" "codebuild_role" {
  name = "hawk-dast-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "hawk-dast-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs 권한
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "*"
      },
      # S3 로그 저장 권한 + 아티팩트(소스) 읽기 권한
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketLocation"],
        Resource = [
          aws_s3_bucket.dast_logs.arn,
          "${aws_s3_bucket.dast_logs.arn}/*",
          "arn:aws:s3:::*" # ★ 중요: 파이프라인 아티팩트 버킷이 무엇이든 읽을 수 있게 허용
        ]
      },
      # SSM 파라미터 읽기 + KMS 복호화 권한 
      {
        Effect = "Allow",
        Action = ["ssm:GetParameters", "ssm:GetParameter", "kms:Decrypt"],
        Resource = [
          "arn:aws:ssm:*:*:parameter/hawk/*",
          "arn:aws:kms:*:*:key/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["ec2:CreateNetworkInterface", "ec2:Describe*", "ec2:DeleteNetworkInterface"],
        Resource = "*"
      }
    ]
  })
}


# 4. CodeBuild Project 
resource "aws_codebuild_project" "dast_scanner" {
  name          = "iac-Webgoat-Dast_tool"
  description   = "StackHawk DAST Scanner via SSM"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild_role.arn

  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2

env:
  parameter-store:
    HAWK_API_KEY: "/hawk/api_key"   # SSM 파라미터 이름에 맞춰 수정
    TARGET_URL: "/hawk/target_url"

phases:
  install:
    commands:
      - echo "Using StackHawk HawkScan image as build environment."
      - hawk version

  pre_build:
    commands:
      - echo "Checking stackhawk.yml..."
      - ls -al
      - test -f stackhawk.yml || (echo '❌ stackhawk.yml not found in project root' && exit 1)

  build:
    commands:
      - echo "Fetching Target URL from SSM Parameter Store..."
      - test -n "$TARGET_URL" || (echo 'TARGET_URL is empty' && exit 1)
      - sed -i "s|REPLACE_ME_URL|$TARGET_URL|g" stackhawk.yml
      - echo "URL Injection Complete."
      - export API_KEY="$HAWK_API_KEY"
      - echo "Preparing environment variables for HawkScan..."
      - export _JAVA_OPTIONS="-Xms1g -Xmx4g"
      
      - echo "📂 Copying config into /hawk ..."
      - mkdir -p /hawk
      - cp stackhawk.yml /hawk/stackhawk.yml

      - echo " Starting HawkScan..."
      - cd /hawk
      - hawk scan stackhawk.yml
EOF
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "stackhawk/hawkscan:latest"
    type            = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
    s3_logs {
      status              = "ENABLED"
      location            = "${aws_s3_bucket.dast_logs.id}/build-logs"
      encryption_disabled = true
    }
  }
}
