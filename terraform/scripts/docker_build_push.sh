#!/bin/bash
set -e

# 引数を取得
REPOSITORY_URL=$1
IMAGE_TAG=$2
AWS_REGION=$3

# 引数のチェック
if [ -z "$REPOSITORY_URL" ] || [ -z "$IMAGE_TAG" ] || [ -z "$AWS_REGION" ]; then
  echo "使用方法: $0 <repository-url> <image-tag> <aws-region>"
  exit 1
fi

echo "リポジトリURL: $REPOSITORY_URL"
echo "イメージタグ: $IMAGE_TAG"
echo "AWSリージョン: $AWS_REGION"

# プロジェクトのルートディレクトリに移動
cd "$(dirname "$0")/../.."

# AWS ECRにログイン
echo "AWS ECRにログイン中..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $REPOSITORY_URL | cut -d'/' -f1)

# Dockerイメージをビルド
echo "Dockerイメージをビルド中..."
docker build -t $REPOSITORY_URL:$IMAGE_TAG .

# ECRにイメージをプッシュ
echo "ECRにイメージをプッシュ中..."
docker push $REPOSITORY_URL:$IMAGE_TAG

echo "ビルドとプッシュが完了しました: $REPOSITORY_URL:$IMAGE_TAG"