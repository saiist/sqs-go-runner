package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"sqs-go-runner/internal/config"
	"sqs-go-runner/internal/consumer"
)

func main() {
	// 設定を読み込み
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("設定の読み込みに失敗しました: %v", err)
	}

	// コンテキストの作成 (シグナルハンドリング用)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// ヘルスチェック用のHTTPサーバーを起動
	go startHealthCheckServer()

	// シグナルチャネルを設定
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)

	// SQSコンシューマーの作成と開始
	consumer := consumer.NewSQSConsumer(cfg)
	go func() {
		// シグナルを受け取るまで待機
		sig := <-signalChan
		log.Printf("シグナルを受信しました: %v", sig)
		cancel() // コンテキストをキャンセルしてコンシューマーに停止を通知
	}()

	// SQSメッセージの受信を開始
	log.Printf("SQS コンシューマーを開始します。キューURL: %s", cfg.QueueURL)
	if err := consumer.Start(ctx); err != nil {
		log.Fatalf("コンシューマー実行中にエラーが発生しました: %v", err)
	}

	log.Println("SQS コンシューマーが正常に終了しました")
}

// ヘルスチェック用のHTTPサーバーを起動
func startHealthCheckServer() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	log.Println("ヘルスチェックサーバーを :8080 で起動")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatalf("ヘルスチェックサーバーの起動に失敗: %v", err)
	}
}
