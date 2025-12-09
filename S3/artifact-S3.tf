####################S3 bucket create####################
resource "aws_s3_bucket" "iac-codepipeline-s3-bucket" {
    bucket = "iac-codepipeline-s3-bucket"
    force_destroy = true
    tags = {
        Name = "iac-codepipeline-s3-bucket"
    }
}

####################S3 bucket versioning####################
resource "aws_s3_bucket_versioning" "iac-codepipeline-s3-bucket-versioning" {
    bucket = aws_s3_bucket.iac-codepipeline-s3-bucket.id
    
    versioning_configuration {
        status = "Enabled"
    }
}
