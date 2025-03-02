# SQS Go Runner Makefile

# デフォルトのAWSリージョン
AWS_REGION = ap-northeast-1

# LocalStack設定
LOCALSTACK_URL = http://localhost:4566
QUEUE_URL = $(LOCALSTACK_URL)/000000000000/sqs-go-runner-queue

# 色の定義
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

# ヘルプメッセージ表示
.PHONY: help
help:
	@echo "$(BLUE)SQS Go Runner$(NC) - AWS SQSコンシューマーアプリケーション"
	@echo ""
	@echo "$(YELLOW)開発コマンド:$(NC)"
	@echo "  $(GREEN)make dev-up$(NC)        - 開発環境を起動 (LocalStack + アプリケーション)"
	@echo "  $(GREEN)make dev-down$(NC)      - 開発環境を停止"
	@echo "  $(GREEN)make logs$(NC)          - アプリケーションのログを表示"
	@echo "  $(GREEN)make send-task$(NC)     - タスクタイプのテストメッセージを送信"
	@echo "  $(GREEN)make send-notification$(NC) - 通知タイプのテストメッセージを送信"
	@echo "  $(GREEN)make send-data-sync$(NC) - データ同期タイプのテストメッセージを送信"
	@echo ""
	@echo "$(YELLOW)ビルドコマンド:$(NC)"
	@echo "  $(GREEN)make build$(NC)         - アプリケーションをローカルでビルド"
	@echo "  $(GREEN)make docker-build$(NC)  - Dockerイメージをビルド"
	@echo ""
	@echo "$(YELLOW)テストコマンド:$(NC)"
	@echo "  $(GREEN)make test$(NC)          - 単体テストを実行"
	@echo "  $(GREEN)make lint$(NC)          - コードの静的解析を実行"
	@echo ""
	@echo "$(YELLOW)Terraform コマンド:$(NC)"
	@echo "  $(GREEN)make tf-init$(NC)       - Terraformを初期化"
	@echo "  $(GREEN)make tf-plan$(NC)       - デプロイ計画を表示"
	@echo "  $(GREEN)make tf-apply$(NC)      - AWSリソースをデプロイ"
	@echo "  $(GREEN)make tf-destroy$(NC)    - AWSリソースを削除"
	@echo "  $(GREEN)make tf-fmt$(NC)        - Terraformファイルをフォーマット"
	@echo ""
	@echo "$(YELLOW)ユーティリティ:$(NC)"
	@echo "  $(GREEN)make clean$(NC)         - ビルド成果物を削除"
	@echo "  $(GREEN)make check-queue$(NC)   - SQSキューの状態を確認"

# 開発環境を起動
.PHONY: dev-up
dev-up:
	@echo "$(GREEN)開発環境を起動しています...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)LocalStackとアプリケーションを起動しました$(NC)"
	@echo "アプリケーションのログを表示するには: $(BLUE)make logs$(NC)"

# 開発環境を停止
.PHONY: dev-down
dev-down:
	@echo "$(GREEN)開発環境を停止しています...$(NC)"
	@docker-compose down
	@echo "$(GREEN)開発環境を停止しました$(NC)"

# アプリケーションのログを表示
.PHONY: logs
logs:
	@docker-compose logs -f app

# テストメッセージの送信 (タスク)
.PHONY: send-task
send-task:
	@echo "$(GREEN)タスクメッセージを送信しています...$(NC)"
	@./scripts/send-message.sh task

# テストメッセージの送信 (通知)
.PHONY: send-notification
send-notification:
	@echo "$(GREEN)通知メッセージを送信しています...$(NC)"
	@./scripts/send-message.sh notification

# テストメッセージの送信 (データ同期)
.PHONY: send-data-sync
send-data-sync:
	@echo "$(GREEN)データ同期メッセージを送信しています...$(NC)"
	@./scripts/send-message.sh data-sync

# アプリケーションをローカルでビルド
.PHONY: build
build:
	@echo "$(GREEN)アプリケーションをビルドしています...$(NC)"
	@go build -o bin/app .
	@echo "$(GREEN)ビルド完了: bin/app$(NC)"

# Dockerイメージをビルド
.PHONY: docker-build
docker-build:
	@echo "$(GREEN)Dockerイメージをビルドしています...$(NC)"
	@docker build -t sqs-go-runner:latest .
	@echo "$(GREEN)Dockerイメージのビルド完了: sqs-go-runner:latest$(NC)"

# テストを実行
.PHONY: test
test:
	@echo "$(GREEN)テストを実行しています...$(NC)"
	@go test -v ./...

# コードの静的解析を実行
.PHONY: lint
lint:
	@echo "$(GREEN)静的解析を実行しています...$(NC)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "$(RED)golangci-lintがインストールされていません。$(NC)"; \
		echo "インストール方法: https://golangci-lint.run/usage/install/"; \
	fi

# ビルド成果物を削除
.PHONY: clean
clean:
	@echo "$(GREEN)ビルド成果物を削除しています...$(NC)"
	@rm -rf bin/
	@echo "$(GREEN)削除完了$(NC)"

# SQSキューの状態を確認
.PHONY: check-queue
check-queue:
	@echo "$(GREEN)SQSキューの状態を確認しています...$(NC)"
	@aws --endpoint-url=$(LOCALSTACK_URL) sqs get-queue-attributes \
		--queue-url $(QUEUE_URL) \
		--attribute-names ApproximateNumberOfMessages \
		--region $(AWS_REGION)

# Terraformを初期化
.PHONY: tf-init
tf-init:
	@echo "$(GREEN)Terraformを初期化しています...$(NC)"
	@cd terraform && terraform init

# デプロイ計画を表示
.PHONY: tf-plan
tf-plan:
	@echo "$(GREEN)デプロイ計画を表示しています...$(NC)"
	@cd terraform && terraform plan

# AWSリソースをデプロイ
.PHONY: tf-apply
tf-apply:
	@echo "$(GREEN)AWSリソースをデプロイしています...$(NC)"
	@cd terraform && terraform apply

# AWSリソースを削除
.PHONY: tf-destroy
tf-destroy:
	@echo "$(GREEN)AWSリソースを削除しています...$(NC)"
	@cd terraform && terraform destroy

# Terraformファイルをフォーマット
.PHONY: tf-fmt
tf-fmt:
	@echo "$(GREEN)Terraformファイルをフォーマットしています...$(NC)"
	@cd terraform && terraform fmt