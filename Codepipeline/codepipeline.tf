####################GitHub connection create####################
resource "aws_codestarconnections_connection" "iac-github-connection" {
  name          = "iac-github-connection"
  provider_type = "GitHub"

  tags = {
    "codestar:connectionType" = "GitHub"
    "codestar:triggerOnPush"  = "true"
  }
}

####################CodePipeline create####################
resource "aws_codepipeline" "iac-codepipeline" {
  name     = "iac-codepipeline"
  role_arn = aws_iam_role.iac-codepipeline-role.arn

  artifact_store {
    location = var.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.iac-github-connection.arn
        FullRepositoryId = "Start-Cloud-Team/WebGoat"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      version          = "1"
      configuration = {
        ProjectName = "iac-codebuild"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["BuildArtifact"]
      version         = "1"

      configuration = {
        ApplicationName                = "iac-codedeploy"
        DeploymentGroupName            = "iac-codedeploy-group"
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "BuildArtifact"
        AppSpecTemplatePath            = "appspec.yml"
      }
    }
  }

  stage {
    name = "Webgoat-dast-tool"
      action {
        name             = "SCAN"
        category         = "Test"
        owner            = "AWS"
        provider         = "CodeBuild"
        input_artifacts  = ["SourceArtifact"]
        version          = "1"

        configuration = {
          ProjectName = "iac-Webgoat-Dast_tool"
        }
    }
  }

}
