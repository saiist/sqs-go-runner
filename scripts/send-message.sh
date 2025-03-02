#!/bin/bash
set -e

# 引数をチェック
if [ "$#" -ne 1 ]; then
    echo "使用方法: $0 <メッセージタイプ>"
    echo "利用可能なタイプ: task, notification, data-sync"
    exit 1
fi

MESSAGE_TYPE=$1
MESSAGE_ID=$(uuidgen || cat /proc/sys/kernel/random/uuid)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# メッセージタイプに応じたデータを作成
case $MESSAGE_TYPE in
  task)
    DATA='{"taskId":"task-'$RANDOM'","priority":"high","action":"process"}'
    ;;
  notification)
    DATA='{"recipientId":"user-'$RANDOM'","title":"新着情報","body":"メッセージが届きました"}'
    ;;
  data-sync)
    DATA='{"entityType":"product","entityId":"prod-'$RANDOM'","operation":"update"}'
    ;;
  *)
    echo "不明なメッセージタイプ: $MESSAGE_TYPE"
    exit 1
    ;;
esac

# JSONメッセージを構築
MESSAGE_BODY='{
  "id": "'$MESSAGE_ID'",
  "type": "'$MESSAGE_TYPE'",
  "data": '$DATA',
  "timestamp": "'$TIMESTAMP'"
}'

# メッセージを送信
echo "テストメッセージを送信中... タイプ: $MESSAGE_TYPE"
echo "$MESSAGE_BODY"

aws --endpoint-url=http://localhost:4566 \
    sqs send-message \
    --queue-url http://localhost:4566/000000000000/sqs-go-runner-queue \
    --message-body "$MESSAGE_BODY" \
    --region ap-northeast-1

echo "メッセージを送信しました！"