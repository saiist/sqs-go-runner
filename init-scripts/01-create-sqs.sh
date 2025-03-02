#!/bin/bash
set -e

echo "SQSキューを作成中..."

# デッドレターキューを作成
aws --endpoint-url=http://localhost:4566 \
    sqs create-queue \
    --queue-name sqs-go-runner-dlq \
    --region ap-northeast-1

# デッドレターキューのARNを取得
DLQ_URL=$(aws --endpoint-url=http://localhost:4566 \
    sqs get-queue-url \
    --queue-name sqs-go-runner-dlq \
    --region ap-northeast-1 \
    --query 'QueueUrl' \
    --output text)

DLQ_ARN=$(aws --endpoint-url=http://localhost:4566 \
    sqs get-queue-attributes \
    --queue-url $DLQ_URL \
    --attribute-names QueueArn \
    --region ap-northeast-1 \
    --query 'Attributes.QueueArn' \
    --output text)

# メインキューを作成 (デッドレターキュー設定付き)
aws --endpoint-url=http://localhost:4566 \
    sqs create-queue \
    --queue-name sqs-go-runner-queue \
    --attributes '{
        "DelaySeconds": "0",
        "MaximumMessageSize": "262144",
        "MessageRetentionPeriod": "1209600",
        "ReceiveMessageWaitTimeSeconds": "20",
        "VisibilityTimeout": "60",
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"'$DLQ_ARN'\",\"maxReceiveCount\":\"5\"}"
    }' \
    --region ap-northeast-1

echo "SQSキューの作成完了!"

# キューの情報を表示
echo "利用可能なSQSキュー:"
aws --endpoint-url=http://localhost:4566 sqs list-queues --region ap-northeast-1