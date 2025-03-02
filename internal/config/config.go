package config

import (
	"errors"
	"os"
	"strconv"
)

// Config はアプリケーションの設定を保持する構造体
type Config struct {
	QueueURL          string
	Region            string
	MaxMessages       int64
	WaitTimeSeconds   int64
	VisibilityTimeout int64
	EndpointURL       string // LocalStack用カスタムエンドポイント
}

// Load は環境変数から設定を読み込む
func Load() (*Config, error) {
	queueURL := os.Getenv("SQS_QUEUE_URL")
	if queueURL == "" {
		return nil, errors.New("SQS_QUEUE_URL環境変数が設定されていません")
	}

	region := os.Getenv("SQS_REGION")
	if region == "" {
		region = "ap-northeast-1" // デフォルト値を設定
	}

	// ポーリング待機時間（デフォルト: 20秒）
	waitTime := int64(20)
	if waitTimeStr := os.Getenv("POLLING_WAIT_TIME"); waitTimeStr != "" {
		if parsedWaitTime, err := strconv.ParseInt(waitTimeStr, 10, 64); err == nil {
			waitTime = parsedWaitTime
		}
	}

	// 一度に取得するメッセージ数（デフォルト: 10件）
	maxMessages := int64(10)
	if maxMsgStr := os.Getenv("MAX_MESSAGES"); maxMsgStr != "" {
		if parsedMaxMsg, err := strconv.ParseInt(maxMsgStr, 10, 64); err == nil {
			maxMessages = parsedMaxMsg
		}
	}

	// 可視性タイムアウト（デフォルト: 30秒）
	visibilityTimeout := int64(30)
	if visibilityStr := os.Getenv("VISIBILITY_TIMEOUT"); visibilityStr != "" {
		if parsedVisibility, err := strconv.ParseInt(visibilityStr, 10, 64); err == nil {
			visibilityTimeout = parsedVisibility
		}
	}

	// LocalStack用のカスタムエンドポイント
	endpointURL := os.Getenv("AWS_ENDPOINT_URL")

	return &Config{
		QueueURL:          queueURL,
		Region:            region,
		MaxMessages:       maxMessages,
		WaitTimeSeconds:   waitTime,
		VisibilityTimeout: visibilityTimeout,
		EndpointURL:       endpointURL,
	}, nil
}
