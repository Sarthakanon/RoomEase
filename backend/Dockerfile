# Use official Go image
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o main .

# Final stage - minimal image
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

# Copy the binary and required files
COPY --from=builder /app/main .
COPY --from=builder /app/serviceAccount.json ./serviceAccount.json

# Expose port (Railway will override this)
EXPOSE 8080

# Run the application
CMD ["./main"]