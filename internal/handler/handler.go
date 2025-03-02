package handler

import (
	"context"
	"encoding/json"
	"log"
	"time"
)

// Message はSQSから受信するメッセージの構造体
type Message struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"`
	Data      any       `json:"data"`
	Timestamp time.Time `json:"timestamp"`
}

// MessageHandler はSQSメッセージを処理するハンドラー
type MessageHandler struct {
	// 必要に応じてデータベース接続や他のクライアントを追加
}

// NewMessageHandler は新しいメッセージハンドラーを作成
func NewMessageHandler() *MessageHandler {
	return &MessageHandler{}
}

// HandleMessage はメッセージを処理するメイン関数
func (h *MessageHandler) HandleMessage(ctx context.Context, messageBody string) error {
	// メッセージをパース
	var message Message
	if err := json.Unmarshal([]byte(messageBody), &message); err != nil {
		// JSONとしてパースできない場合は、単純な文字列として処理
		log.Printf("JSON形式ではないメッセージを処理します: %s", messageBody)
		return h.processRawMessage(ctx, messageBody)
	}

	// メッセージタイプに基づいて処理を分岐
	log.Printf("メッセージの処理: ID=%s, Type=%s", message.ID, message.Type)

	switch message.Type {
	case "task":
		return h.processTaskMessage(ctx, message)
	case "notification":
		return h.processNotificationMessage(ctx, message)
	case "data-sync":
		return h.processDataSyncMessage(ctx, message)
	default:
		log.Printf("未知のメッセージタイプです: %s", message.Type)
		return h.processUnknownMessage(ctx, message)
	}
}

// processRawMessage は非JSON形式のメッセージを処理
func (h *MessageHandler) processRawMessage(ctx context.Context, messageBody string) error {
	// ここでプレーンテキストメッセージを処理
	log.Printf("RAWメッセージの処理: %s", messageBody)

	// 実際の処理をここに実装
	// 例: ログに記録するだけ

	return nil
}

// processTaskMessage はタスク関連のメッセージを処理
func (h *MessageHandler) processTaskMessage(ctx context.Context, message Message) error {
	// タスクメッセージの処理ロジックをここに実装
	log.Printf("タスクメッセージを処理: %v", message.Data)

	// 処理時間をシミュレート
	time.Sleep(500 * time.Millisecond)

	return nil
}

// processNotificationMessage は通知関連のメッセージを処理
func (h *MessageHandler) processNotificationMessage(ctx context.Context, message Message) error {
	// 通知メッセージの処理ロジックをここに実装
	log.Printf("通知メッセージを処理: %v", message.Data)

	// 処理時間をシミュレート
	time.Sleep(200 * time.Millisecond)

	return nil
}

// processDataSyncMessage はデータ同期関連のメッセージを処理
func (h *MessageHandler) processDataSyncMessage(ctx context.Context, message Message) error {
	// データ同期メッセージの処理ロジックをここに実装
	log.Printf("データ同期メッセージを処理: %v", message.Data)

	// 処理時間をシミュレート
	time.Sleep(1 * time.Second)

	return nil
}

// processUnknownMessage は未知のタイプのメッセージを処理
func (h *MessageHandler) processUnknownMessage(ctx context.Context, message Message) error {
	// 未知のメッセージタイプの処理
	log.Printf("未知のメッセージを処理: %v", message)

	// 例としてエラーを返さずに処理を続行
	return nil
}
