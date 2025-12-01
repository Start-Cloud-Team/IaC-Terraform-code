resource "aws_iam_role" "iac-codebuild-role" {
  name = "iac-webgoat-codebuild-role"

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

resource "aws_iam_policy" "iac-webgoat-codebuild-policy" {
    name = "iac-webgoat-codebuild-policy"
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
                    "codebuild:StartBuild",
                    "codebuild:BatchGetBuilds",
                    "ecr:CreateRepository",
                    "iam:PassRole",
                    "ecs:RegisterTaskDefinition",
                    "codedeploy:CreateDeployment",
                    "codedeploy:GetDeployment",
                    "codedeploy:GetDeploymentGroup"
                ],
                Resource = "*"
            },
        ]
    })
}

resource "aws_iam_role_policy_attachment" "iac-webgoat-codebuild-attach" {
  role       = aws_iam_role.iac-codebuild-role.name
  policy_arn = aws_iam_policy.iac-webgoat-codebuild-policy.arn
}

resource "aws_codebuild_project" "iac-webgoat-codebuild"{
    name = "iac-webgoat-codebuild"
    service_role = aws_iam_role.iac-codebuild-role.arn

    artifacts {
        type = "NO_ARTIFACTS"
    }

    environment {
        image        = "aws/codebuild/standard:7.0" 
        type         = "LINUX_CONTAINER" 
        compute_type = "BUILD_GENERAL1_SMALL"
    }

    source {
        type     = "GITHUB"
        location = "https://github.com/Start-Cloud-Team/WebGoat"
        buildspec = <<-EOF
        version: 0.2
        env:
            variables:
                IMAGE_REPO_NAME: "iac-webgoat-ecr"
                IMAGE_TAG: "latest"
                ACCOUNT_ID: "329984431650"
                AWS_DEFAULT_REGION: "ap-northeast-2"
                TZ: "America/Boise"
                WEBGOAT_HOST: "www.webgoat.local"
                WEBWOLF_HOST: "www.webwolf.local"
                EXCLUDE_CATEGORIES: "CLIENT_SIDE,GENERAL,CHALLENGE"
                EXCLUDE_LESSONS: "SqlInjectionAdvanced,SqlInjectionMitigations"

            parameter-store:
                SONAR_TOKEN: /devops/sonarcloud/token

        phases:
            install:
                runtime-versions:
                    java: corretto21
                commands:
                    - echo "=== INSTALL PHASE ==="
                    - java -version
                    - echo "=== INSTALL SONAR SCANNER ==="
                    - wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip
                    - unzip -q sonar-scanner-cli-6.2.1.4610-linux-x64.zip
                    - echo "=== LOGIN TO ECR ==="
                    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

            pre_build:
                commands:
                    - echo "=== BUILD JAVA PROJECT ==="
                    - mvn clean compile -DskipTests -Dmaven.compiler.release=21
                    - echo "=== SONARCLOUD SCAN ==="
                    - ./sonar-scanner-6.2.1.4610-linux-x64/bin/sonar-scanner -Dsonar.projectKey=Start-Cloud-Team_WebGoat -Dsonar.organization=start-cloud-team -Dsonar.sources=src/main/java -Dsonar.java.binaries=target/classes -Dsonar.branch.name=main -Dsonar.host.url=https://sonarcloud.io -Dsonar.token=$SONAR_TOKEN || echo "SonarCloud scan failed, continuing..."
                    - echo "=== PULL WEBGOAT IMAGE ==="
                    - docker pull webgoat/webgoat:latest

            build:
                commands:
                    - echo "=== TAG IMAGE FOR ECR ==="
                    - docker tag webgoat/webgoat:latest $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG

            post_build:
                commands:
                    - echo "=== PUSH IMAGE TO ECR ==="
                    - docker push $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
                    - echo "=== CREATE imageDetail.json ==="
                    - |
                        cat <<EOS > imageDetail.json
                        [
                        {
                        "name": "WebGoat-container",
                        "imageUri": "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG"
                        }
                        ]
                        EOS
                    - echo "=== CREATE taskdef.json ==="
                    - |
                        cat <<EOS > taskdef.json
                        {
                        "family": "WebGoat-tasks",
                        "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
                        "taskRoleArn": "arn:aws:iam::329984431650:role/ecsTaskRoleForExec",
                        "networkMode": "awsvpc",
                        "requiresCompatibilities": ["FARGATE"],
                        "cpu": "256",
                        "memory": "2048",
                        "enableExecuteCommand": true,
                        "containerDefinitions": [
                            {
                            "name": "WebGoat-container",
                            "image": "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG",
                            "essential": true,
                            "environment": [
                                {"name": "TZ", "value": "$TZ"},
                                {"name": "WEBGOAT_HOST", "value": "$WEBGOAT_HOST"},
                                {"name": "WEBWOLF_HOST", "value": "$WEBWOLF_HOST"},
                                {"name": "EXCLUDE_CATEGORIES", "value": "$EXCLUDE_CATEGORIES"},
                                {"name": "EXCLUDE_LESSONS", "value": "$EXCLUDE_LESSONS"}
                            ],
                            "portMappings": [
                                {
                                "containerPort": 8080,
                                "protocol": "tcp"
                                }
                            ]
                            }
                        ]
                        }
                        EOS
                    - echo "=== CREATE appspec.yml ==="
                    - |
                        cat <<EOS > appspec.yml
                        version: 0.0
                        Resources:
                            - TargetService:
                                Type: AWS::ECS::Service
                                Properties:
                                    TaskDefinition: "<TASK_DEFINITION>"
                                    LoadBalancerInfo:
                                        ContainerName: "WebGoat-container"
                                        ContainerPort: 8080
                        EOS

        artifacts:
            files:
                - imageDetail.json
                - taskdef.json
                - appspec.yml

        EOF
        }
}
