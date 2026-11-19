# Multi-stage Dockerfile for AB Learning Go API
FROM golang:1.22-alpine AS builder

WORKDIR /src

RUN apk add --no-cache git build-base ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

WORKDIR /src/cmd/api
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /app/ab-api

FROM alpine:3.18

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=builder /app/ab-api /usr/local/bin/ab-api
COPY --from=builder /src/db/migrations /app/db/migrations

ENV PORT=8080
ENV MIGRATIONS_DIR=/app/db/migrations

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/ab-api"]