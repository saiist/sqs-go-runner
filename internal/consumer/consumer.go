package consumer

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"sqs-go-runner/internal/config"
	"sqs-go-runner/internal/handler"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
)

// SQSConsumer はSQSからメッセージを受信するコンシューマー
type SQSConsumer struct {
	client            *sqs.Client
	queueURL          string
	maxMessages       int32
	waitTimeSeconds   int32
	visibilityTimeout int32
	handler           *handler.MessageHandler
}

// NewSQSConsumer は新しいSQSコンシューマーを作成
func NewSQSConsumer(cfg *config.Config) *SQSConsumer {
	// AWS設定のオプションを準備
	opts := []func(*awsconfig.LoadOptions) error{
		awsconfig.WithRegion(cfg.Region),
	}

	// LocalStack用カスタムエンドポイントがあれば追加
	if cfg.EndpointURL != "" {
		customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
			return aws.Endpoint{
				PartitionID:   "aws",
				URL:           cfg.EndpointURL,
				SigningRegion: cfg.Region,
			}, nil
		})
		opts = append(opts, awsconfig.WithEndpointResolverWithOptions(customResolver))
		log.Printf("カスタムAWSエンドポイントを使用: %s", cfg.EndpointURL)
	}

	// AWS設定を読み込み
	awsCfg, err := awsconfig.LoadDefaultConfig(context.TODO(), opts...)
	if err != nil {
		log.Fatalf("AWS設定の読み込みに失敗しました: %v", err)
	}

	// SQSクライアントを作成
	client := sqs.NewFromConfig(awsCfg)

	// メッセージハンドラーを作成
	msgHandler := handler.NewMessageHandler()

	return &SQSConsumer{
		client:            client,
		queueURL:          cfg.QueueURL,
		maxMessages:       int32(cfg.MaxMessages),
		waitTimeSeconds:   int32(cfg.WaitTimeSeconds),
		visibilityTimeout: int32(cfg.VisibilityTimeout),
		handler:           msgHandler,
	}
}

// Start はメッセージの受信を開始
func (c *SQSConsumer) Start(ctx context.Context) error {
	// コンテキストのキャンセルを監視
	for {
		select {
		case <-ctx.Done():
			log.Println("コンテキストがキャンセルされました。コンシューマーを停止します")
			return nil
		default:
			// メッセージを受信して処理
			if err := c.receiveAndProcessMessages(ctx); err != nil {
				log.Printf("メッセージ処理中にエラーが発生しました: %v", err)
				// エラー発生時は少し待機してリトライ
				time.Sleep(5 * time.Second)
			}
		}
	}
}

// receiveAndProcessMessages はメッセージを受信して処理
func (c *SQSConsumer) receiveAndProcessMessages(ctx context.Context) error {
	// メッセージ受信リクエストの作成
	receiveParams := &sqs.ReceiveMessageInput{
		QueueUrl:              aws.String(c.queueURL),
		MaxNumberOfMessages:   c.maxMessages,
		WaitTimeSeconds:       c.waitTimeSeconds,
		VisibilityTimeout:     c.visibilityTimeout,
		AttributeNames:        []types.QueueAttributeName{"All"},
		MessageAttributeNames: []string{"All"},
	}

	// メッセージを受信
	resp, err := c.client.ReceiveMessage(ctx, receiveParams)
	if err != nil {
		return fmt.Errorf("メッセージ受信に失敗しました: %w", err)
	}

	// 受信したメッセージがない場合はここで終了
	if len(resp.Messages) == 0 {
		return nil
	}

	log.Printf("%d 件のメッセージを受信しました", len(resp.Messages))

	// 並列処理のためのWaitGroup
	var wg sync.WaitGroup

	// 各メッセージを並列処理
	for _, msg := range resp.Messages {
		wg.Add(1)
		go func(message types.Message) {
			defer wg.Done()

			// メッセージを処理
			err := c.processMessage(ctx, message)
			if err != nil {
				log.Printf("メッセージ処理に失敗しました: %v", err)
				return
			}

			// 正常に処理できたメッセージを削除
			if err := c.deleteMessage(ctx, message); err != nil {
				log.Printf("メッセージ削除に失敗しました: %v", err)
			}
		}(msg)
	}

	// すべての処理が完了するのを待機
	wg.Wait()
	return nil
}

// processMessage は個々のメッセージを処理
func (c *SQSConsumer) processMessage(ctx context.Context, message types.Message) error {
	messageID := *message.MessageId
	messageBody := *message.Body

	log.Printf("メッセージの処理を開始: %s", messageID)

	// メッセージハンドラーを使用して処理
	if err := c.handler.HandleMessage(ctx, messageBody); err != nil {
		return fmt.Errorf("メッセージID %s の処理に失敗: %w", messageID, err)
	}

	log.Printf("メッセージの処理が完了: %s", messageID)
	return nil
}

// deleteMessage はSQSキューからメッセージを削除
func (c *SQSConsumer) deleteMessage(ctx context.Context, message types.Message) error {
	deleteParams := &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(c.queueURL),
		ReceiptHandle: message.ReceiptHandle,
	}

	_, err := c.client.DeleteMessage(ctx, deleteParams)
	if err != nil {
		return fmt.Errorf("メッセージ削除に失敗: %w", err)
	}

	log.Printf("メッセージを削除しました: %s", *message.MessageId)
	return nil
}
