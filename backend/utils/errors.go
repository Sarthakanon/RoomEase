package utils

import (
	"fmt"
	"log"
)

// ErrorCode represents application error codes
type ErrorCode string

const (
	ErrCodeInvalidRequest     ErrorCode = "INVALID_REQUEST"
	ErrCodeUnauthorized       ErrorCode = "UNAUTHORIZED"
	ErrCodeNotFound           ErrorCode = "NOT_FOUND"
	ErrCodeInternalServer     ErrorCode = "INTERNAL_SERVER_ERROR"
	ErrCodeInvalidToken       ErrorCode = "INVALID_TOKEN"
	ErrCodeSessionExpired     ErrorCode = "SESSION_EXPIRED"
	ErrCodeValidationFailed   ErrorCode = "VALIDATION_FAILED"
	ErrCodeDatabaseError      ErrorCode = "DATABASE_ERROR"
)

// AppError represents an application error
type AppError struct {
	Code    ErrorCode
	Message string
	Err     error
}

// Error implements the error interface
func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

// NewAppError creates a new application error
func NewAppError(code ErrorCode, message string, err error) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
		Err:     err,
	}
}

// LogError logs an error with context
func LogError(context string, err error) {
	if appErr, ok := err.(*AppError); ok {
		log.Printf("ERROR [%s] %s: %s", context, appErr.Code, redactSensitiveData(appErr.Message))
	} else {
		log.Printf("ERROR [%s]: %s", context, redactSensitiveData(err.Error()))
	}
}

// redactSensitiveData removes sensitive information from log messages
func redactSensitiveData(message string) string {
	// Simple redaction - in production, use more sophisticated methods
	// This is a placeholder for demonstration
	return message
}
