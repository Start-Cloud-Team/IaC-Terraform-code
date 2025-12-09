####################CodeDeploy app create####################
resource "aws_codedeploy_app" "iac-codedeploy" {
    compute_platform = "ECS"
    name             = "iac-codedeploy"
}

####################CodeDeploy group create####################
resource "aws_codedeploy_deployment_group" "iac-codedeploy-group" {
    app_name               = aws_codedeploy_app.iac-codedeploy.name
    deployment_config_name = "CodeDeployDefault.ECSAllAtOnce" #테스크를 한 번에 교체
    deployment_group_name  = "iac-codedeploy-group" #배포 그룹 설정
    service_role_arn       = aws_iam_role.iac-codedeploy-role.arn

    auto_rollback_configuration {
        enabled = true
        events  = ["DEPLOYMENT_FAILURE"]
    }

    blue_green_deployment_config {
        deployment_ready_option {
            action_on_timeout = "CONTINUE_DEPLOYMENT"
        }

        terminate_blue_instances_on_deployment_success {
            action                           = "TERMINATE"
            termination_wait_time_in_minutes = 5
        }
    }

    deployment_style {
        deployment_option = "WITH_TRAFFIC_CONTROL"
        deployment_type   = "BLUE_GREEN"
    }

    ecs_service {
        cluster_name = var.cluster_name
        service_name = var.cluster_service_name
    }

    load_balancer_info {
        target_group_pair_info {
            prod_traffic_route {
                listener_arns = [var.alb_listener_arn]
            }

            target_group {
                name = var.alb_tg_blue
            }

            target_group {
                name = var.alb_tg_green
            }
        }
    }

}
