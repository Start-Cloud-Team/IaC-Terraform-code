variable "codebuild_name" {
  type        = string
  default     = "iac-codebuild"
  description = "codebuild name"
}

variable "git_url"{
  type = string
  default = "https://github.com/Start-Cloud-Team/WebGoat"
  description = "github repo url"
}

variable "region"{
  type = string
  default = "ap-northeast-2"
  description = "region"

}
