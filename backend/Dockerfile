# Use official Go image
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o main .

# Final stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

# Copy the binary and service account
COPY --from=builder /app/main .
COPY --from=builder /app/serviceAccount.json .

EXPOSE 8080
CMD ["./main"]