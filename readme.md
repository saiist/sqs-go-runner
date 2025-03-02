# SQS Go Runner

![Go](https://img.shields.io/badge/Go-1.22-blue)
![AWS](https://img.shields.io/badge/AWS-SQS%20|%20AppRunner%20|%20ECR-orange)
![Status](https://img.shields.io/badge/Status-Active-green)

## 概要

`sqs-go-runner` は AWS SQS (Simple Queue Service) からメッセージを受信して処理するGoアプリケーションです。AWS App Runnerでデプロイされ、メッセージを非同期で確実に処理します。

## アーキテクチャ

![アーキテクチャ図](docs/architecture.svg)

### 主要コンポーネント

- **Go Application**: SQSからメッセージを受信・処理するサービス
- **Amazon SQS**: 処理するメッセージを保存するキュー
- **AWS App Runner**: Goアプリケーションを実行する管理サービス
- **Amazon ECR**: Dockerイメージを保存するコンテナレジストリ

### 処理フロー

1. 外部システムがSQSキューにメッセージを送信
2. Go アプリケーションがSQSからメッセージを受信（ロングポーリング方式）
3. 受信したメッセージをgoroutineで並列処理
4. 正常に処理されたメッセージはキューから削除
5. 処理に5回失敗したメッセージはデッドレターキューに移動

## 開発環境のセットアップ

### 前提条件

- Go 1.22以上
- Docker および Docker Compose
- AWS CLI
- Make
- Terraform (本番環境デプロイ用)

### ローカル開発環境の起動

LocalStackを使用して、AWSサービスをローカルでエミュレートします：

```bash
# 開発環境を起動
make dev-up

# テストメッセージの送信
make send-task
make send-notification
make send-data-sync

# ログを確認
make logs

# 開発環境を停止
make dev-down
```

## プロジェクト構造

```
sqs-go-runner/
├── Dockerfile                 # アプリケーションのコンテナイメージ定義
├── Makefile                   # 開発用コマンド
├── README.md                  # プロジェクト説明（本ファイル）
├── docker-compose.yml         # ローカル開発環境の定義
├── go.mod                     # Goの依存関係管理
├── go.sum                     # Goのパッケージバージョン管理
├── init-scripts/              # LocalStack初期化スクリプト
│   └── 01-create-sqs.sh       # SQSキューの作成
├── internal/                  # 内部パッケージ
│   ├── config/                # 設定管理
│   ├── consumer/              # SQSコンシューマーロジック
│   └── handler/               # メッセージ処理ロジック
├── main.go                    # アプリケーションのエントリーポイント
├── scripts/                   # ユーティリティスクリプト
│   └── send-message.sh        # テストメッセージ送信
└── terraform/                 # インフラ定義
    ├── main.tf                # Terraformのメイン設定
    ├── scripts/               # Terraformヘルパースクリプト
    └── terraform.tfvars.example  # 環境変数サンプル
```

## デプロイ方法

### 開発環境でのテスト

```bash
# 開発環境を起動
make dev-up

# テストメッセージを送信してアプリケーションをテスト
make send-task
```

### 本番環境へのデプロイ

Terraformを使用してAWSにデプロイします：

```bash
# Terraform変数ファイルを作成
cd terraform
cp terraform.tfvars.example terraform.tfvars
# 必要に応じて変数を編集

# Terraformを初期化
make tf-init

# デプロイ計画を確認
make tf-plan

# デプロイを実行
make tf-apply
```

## メッセージタイプ

アプリケーションは以下のタイプのメッセージを処理できます：

1. **task** - バックグラウンドタスク処理用
   ```json
   {
     "id": "msg-123",
     "type": "task",
     "data": {
       "taskId": "task-456",
       "priority": "high",
       "action": "process"
     },
     "timestamp": "2023-01-01T12:00:00Z"
   }
   ```

2. **notification** - 通知メッセージ
   ```json
   {
     "id": "msg-456",
     "type": "notification",
     "data": {
       "recipientId": "user-789",
       "title": "新着情報",
       "body": "メッセージが届きました"
     },
     "timestamp": "2023-01-01T12:00:00Z"
   }
   ```

3. **data-sync** - データ同期
   ```json
   {
     "id": "msg-789",
     "type": "data-sync",
     "data": {
       "entityType": "product",
       "entityId": "prod-123",
       "operation": "update"
     },
     "timestamp": "2023-01-01T12:00:00Z"
   }
   ```

## デプロイ構成

このアプリケーションは、AWS App Runnerでパブリックモードで実行されます。これは主に次の理由によります：

1. **シンプルな設定**: VPC設定が不要で、すぐにデプロイできます
2. **ヘルスチェックアクセス**: App Runner内蔵のヘルスチェックが正常に機能します
3. **監視とデバッグ**: パブリックエンドポイントにより、サービスの状態確認が容易になります

### セキュリティに関する注意点

App Runnerサービスはパブリックにアクセス可能ですが、このアプリケーションは主にSQSキューからメッセージを受信する役割に特化しているため、セキュリティリスクは限定的です：

- アプリケーションは基本的に入力処理のみを行い、外部からのリクエストに対して最小限の応答（ヘルスチェック）のみを返します
- 外部からのHTTPリクエストはヘルスチェックエンドポイント (`/`) のみが対応します
- サービスを実装する際には、追加のエンドポイントを作成しないよう注意が必要です

より厳格なセキュリティが必要な場合は、VPC設定を追加してプライベート構成に変更することも可能です。その場合、次の点に注意してください：

```bash
# プライベート構成に変更する場合のTerraform変更点
# 1. main.tfにVPC関連の変数を追加（vpc_id, private_subnet_ids）
# 2. App Runner設定にネットワーク構成を追加
# 3. VPCコネクタとセキュリティグループを作成
```

### SQSメッセージの送信方法

SQSキューには、以下の方法でメッセージを送信できます：

1. **AWS SDKを使用**: アプリケーションからAWS SDKを使用してSQSにメッセージを送信
2. **AWSコンソール**: AWS管理コンソールからテストメッセージを送信
3. **AWS CLI**: AWS CLIを使用してコマンドラインからメッセージを送信

```bash
# AWS CLIでメッセージを送信する例
aws sqs send-message \
  --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/sqs-go-runner-queue \
  --message-body '{"id":"msg-123","type":"task","data":{"taskId":"task-456"},"timestamp":"2023-01-01T12:00:00Z"}'
```
