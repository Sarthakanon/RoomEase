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

# Copy only the binary
COPY --from=builder /app/main .

# Create a dummy serviceAccount.json (will be overridden by env vars)
RUN echo '{}' > serviceAccount.json

# Expose port
EXPOSE 8080

# Run the application
CMD ["./main"]