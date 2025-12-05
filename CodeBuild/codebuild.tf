####################CodeBuild 생성####################
resource "aws_codebuild_project" "iac-codebuild"{
    name = var.codebuild_name
    service_role = aws_iam_role.iac-codebuild-role.arn
    
    artifacts {
        type = "NO_ARTIFACTS"
    }

    environment {
        image        = "aws/codebuild/standard:6.0" 
        type         = "LINUX_CONTAINER" 
        compute_type = "BUILD_GENERAL1_SMALL"
    }

    source {
        type     = "GITHUB"
        location = var.git_url
        buildspec = <<-EOF
        version: 0.2
        env:
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
                    - echo "=== INSTALL SNYK CLI ==="
                    - curl -Lo snyk https://static.snyk.io/cli/$IMAGE_TAG/snyk-linux
                    - chmod +x snyk
                    - mv snyk /usr/local/bin/snyk
                    - echo "=== LOGIN TO ECR ==="
                    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

            pre_build:
                commands:
                    - echo "=== BUILD JAVA PROJECT ==="
                    - mvn clean compile -DskipTests -Dmaven.compiler.release=21 || true
                    - echo "=== SONARCLOUD SCAN ==="
                    - ./sonar-scanner-6.2.1.4610-linux-x64/bin/sonar-scanner -Dsonar.projectKey=Start-Cloud-Team_WebGoat -Dsonar.organization=start-cloud-team -Dsonar.sources=src/main/java -Dsonar.java.binaries=target/classes -Dsonar.branch.name=main -Dsonar.host.url=https://sonarcloud.io -Dsonar.token=$SONAR_TOKEN || true
                    - echo "=== SNYK AUTH ==="
                    - snyk auth $SNYK_TOKEN || true
                    - echo "=== RUN SNYK SCA TEST (Non-blocking) ==="
                    - snyk test --all-projects --json-file-output=snyk-sca-results.json || true
                    - test -f snyk-sca-results.json || echo '{"error":"Snyk SCA scan failed"}' > snyk-sca-results.json
                    - snyk monitor --project-name=bWAPP-SCA || true
                    - echo "=== PULL WEBGOAT IMAGE ==="
                    - docker pull webgoat/webgoat:$IMAGE_TAG || true

            build:
                commands:
                    - echo "=== TAG IMAGE FOR ECR ==="
                    - docker tag webgoat/webgoat:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
                    - echo "=== RUN SNYK CONTAINER TEST (Non-blocking) ==="
                    - snyk container test $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG --json-file-output=snyk-container-results.json || true
                    - test -f snyk-container-results.json || echo '{"error":"Snyk Container scan failed"}' > snyk-container-results.json
                    - snyk container monitor $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG --project-name=bWAPP-Container || echo "Snyk monitor upload failed"

            post_build:
                commands:
                    - echo "=== PUSH IMAGE TO ECR ==="
                    - docker push $ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG
                    - echo "=== FETCH SONARCLOUD RESULTS ==="
                    - TIMESTAMP=$(date +%Y%m%d-%H%M%S)
                    - |
                        curl -u $SONAR_TOKEN: "https://sonarcloud.io/api/issues/search?componentKeys=Start-Cloud-Team_WebGoat&resolved=false" \
                        -o sonarcloud-issues.json || echo '{"error":"Failed to fetch issues"}' > sonarcloud-issues.json
                    - |
                        curl -u $SONAR_TOKEN: "https://sonarcloud.io/api/measures/component?component=Start-Cloud-Team_WebGoat&metricKeys=bugs,vulnerabilities,code_smells,coverage,security_hotspots" \
                        -o sonarcloud-metrics.json || echo '{"error":"Failed to fetch metrics"}' > sonarcloud-metrics.json
                    - echo "=== UPLOAD SECURITY RESULTS TO S3 ==="
                    - test -f snyk-sca-results.json && aws s3 cp snyk-sca-results.json s3://$S3_BUCKET/snyk/sca-$TIMESTAMP.json || echo "Snyk SCA results file not found"
                    - test -f snyk-container-results.json && aws s3 cp snyk-container-results.json s3://$S3_BUCKET/snyk/container-$TIMESTAMP.json || echo "Snyk Container results file not found"
                    - test -f sonarcloud-issues.json && aws s3 cp sonarcloud-issues.json s3://$S3_BUCKET/sonarqube/issues-$TIMESTAMP.json || echo "SonarCloud issues file not found"
                    - test -f sonarcloud-metrics.json && aws s3 cp sonarcloud-metrics.json s3://$S3_BUCKET/sonarqube/metrics-$TIMESTAMP.json || echo "SonarCloud metrics file not found"
                    - echo "Security scan results uploaded to S3 bucket $S3_BUCKET"
                    - echo "=== CREATE imageDetail.json ==="
                    - >
                        printf '[{"name":"Bwapp-container","imageUri":"%s"}]'
                        "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG"
                        > imageDetail.json
                    - echo "=== CREATE taskdef.json ==="
                    - >
                        printf '{"family":"Bwapp-tasks","executionRoleArn":"arn:aws:iam::%s:role/ecsTaskExecutionRole","taskRoleArn":"arn:aws:iam::$ACCOUNT_ID:role/escTaskRoleForExec","networkMode":"awsvpc","requiresCompatibilities":["FARGATE"],"cpu":"256","memory":"2048","enableExecuteCommand":true,"containerDefinitions":[{"name":"Bwapp-container","image":"%s","essential":true,"environment":[{"name":"TZ","value":"%s"},{"name":"WEBGOAT_HOST","value":"%s"},{"name":"WEBWOLF_HOST","value":"%s"},{"name":"EXCLUDE_CATEGORIES","value":"%s"},{"name":"EXCLUDE_LESSONS","value":"%s"}],"portMappings":[{"containerPort":8080,"protocol":"tcp"}]}]}'
                        "$ACCOUNT_ID"
                        "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG"
                        "$TZ" "$WEBGOAT_HOST" "$WEBWOLF_HOST" "$EXCLUDE_CATEGORIES" "$EXCLUDE_LESSONS"
                        > taskdef.json
                    - echo "=== CREATE appspec.yml ==="
                    - >
                        printf 'version: 0.0\nResources:\n  - TargetService:\n      Type: AWS::ECS::Service\n      Properties:\n        TaskDefinition: "<TASK_DEFINITION>"\n        LoadBalancerInfo:\n          ContainerName: "Bwapp-container"\n          ContainerPort: 8080'
                        > appspec.yml

        artifacts:
            files:
                - imageDetail.json
                - taskdef.json
                - appspec.yml
        EOF
    }
}
