provider "aws" {
  region = var.region
}

# 変数定義
variable "app_name" {
  description = "アプリケーション名"
  type        = string
}

variable "image_tag" {
  description = "デプロイするイメージのタグ"
  type        = string
}

variable "region" {
  description = "AWSリージョン"
  type        = string
}

variable "environment" {
  description = "環境（dev/stg/prod）"
  type        = string
  default     = "production"
}

locals {
  tags = {
    Name        = var.app_name
    Environment = var.environment
  }
}

# ECRリポジトリの作成
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# ECRリポジトリポリシー
resource "aws_ecr_repository_policy" "app_policy" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowPullFromAppRunner",
        Effect = "Allow",
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# SQSキューの作成
resource "aws_sqs_queue" "message_queue" {
  name                       = "${var.app_name}-queue"
  delay_seconds              = 0
  max_message_size           = 262144  # 256 KB
  message_retention_seconds  = 1209600 # 14日間
  receive_wait_time_seconds  = 20      # ロングポーリング(20秒)
  visibility_timeout_seconds = 60      # 処理タイムアウト(60秒)

  # デッドレターキューの設定
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 5 # 5回処理失敗したらDLQへ
  })

  tags = local.tags
}

# デッドレターキュー
resource "aws_sqs_queue" "dead_letter_queue" {
  name                      = "${var.app_name}-dlq"
  message_retention_seconds = 1209600 # 14日間

  tags = local.tags
}

# App Runner用IAMロール
resource "aws_iam_role" "apprunner_access_role" {
  name = "${var.app_name}-apprunner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "build.apprunner.amazonaws.com",
            "tasks.apprunner.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = local.tags
}

# ECRアクセス用のポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# SQSアクセス権限ポリシー
resource "aws_iam_policy" "sqs_access_policy" {
  name        = "${var.app_name}-sqs-access-policy"
  description = "Policy to allow SQS access for App Runner service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueues",
          "sqs:ChangeMessageVisibility"
        ]
        Effect = "Allow"
        Resource = [
          aws_sqs_queue.message_queue.arn,
          aws_sqs_queue.dead_letter_queue.arn
        ]
      }
    ]
  })

  tags = local.tags
}

# IAMロールにSQSポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "sqs_policy_attachment" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = aws_iam_policy.sqs_access_policy.arn
}

# CloudWatch Logsへのアクセス権限
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Dockerイメージのビルドとプッシュ用のnullリソース
resource "null_resource" "docker_push" {
  depends_on = [aws_ecr_repository.app]

  triggers = {
    ecr_repository_url = aws_ecr_repository.app.repository_url
    dockerfile_hash    = filemd5("${path.root}/../Dockerfile")
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/docker_build_push.sh ${aws_ecr_repository.app.repository_url} ${var.image_tag} ${var.region}"
  }
}

# App Runnerサービスの作成（パブリックモード）
resource "aws_apprunner_service" "app" {
  service_name = var.app_name
  depends_on   = [aws_ecr_repository_policy.app_policy, null_resource.docker_push]

  source_configuration {
    auto_deployments_enabled = true

    image_repository {
      image_configuration {
        port = "8080"
        runtime_environment_variables = {
          SQS_QUEUE_URL      = aws_sqs_queue.message_queue.url
          SQS_REGION         = var.region
          POLLING_WAIT_TIME  = "20"
          MAX_MESSAGES       = "10"
          VISIBILITY_TIMEOUT = "30"
        }
      }
      image_identifier      = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_access_role.arn
    }
  }

  instance_configuration {
    cpu               = "1 vCPU"
    memory            = "2 GB"
    instance_role_arn = aws_iam_role.apprunner_access_role.arn
  }

  tags = local.tags
}

# 出力
output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECRリポジトリURL"
}

output "app_runner_service_url" {
  value       = aws_apprunner_service.app.service_url
  description = "App Runner Service URL"
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.message_queue.url
  description = "SQSキューのURL"
}

output "dead_letter_queue_url" {
  value       = aws_sqs_queue.dead_letter_queue.url
  description = "デッドレターキューのURL"
}

output "deployment_instructions" {
  value       = <<-EOT
    App Runner サービスのセットアップが完了しました。
    
    サービスURL: ${aws_apprunner_service.app.service_url}
    SQSキューURL: ${aws_sqs_queue.message_queue.url}
    
    GitHub Actionsによる自動デプロイを設定するには：
    1. GitHub リポジトリにSecrets を追加:
       - AWS_ACCESS_KEY_ID
       - AWS_SECRET_ACCESS_KEY
    2. .github/workflows/deploy.yml ファイルを追加
    
    自動デプロイは ECR への新しいイメージのプッシュで自動的に開始されます（auto_deployments_enabled = true）

    ※App Runnerはパブリックモードで実行されます（インターネットからアクセス可能）
  EOT
  description = "デプロイ手順"
}