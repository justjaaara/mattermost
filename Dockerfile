FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY server/go.mod server/go.sum ./
RUN go mod download

COPY server/ .
RUN make build

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/bin/mattermost .
EXPOSE 8065
CMD ["./mattermost"]
