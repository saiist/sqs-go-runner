FROM golang:1.22-alpine AS builder

WORKDIR /app

# 依存関係をコピーしてダウンロード
COPY go.mod go.sum* ./
RUN go mod download

# ソースコードをコピー
COPY . .

# アプリケーションをビルド
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

# 最終イメージを作成
FROM alpine:latest

# 必要なCA証明書をインストール
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# ビルダーからバイナリをコピー
COPY --from=builder /app/app .

# ポートを公開
EXPOSE 8080

# アプリケーションを実行
CMD ["./app"]