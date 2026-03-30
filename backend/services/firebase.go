package services

import (
	"context"
	"errors"
	"roomease/backend/config"
)

// FirebaseUser represents the user information extracted from Firebase token
type FirebaseUser struct {
	UID   string
	Email string
	Name  string
}

// VerifyToken verifies a Firebase ID token and returns user information
func VerifyToken(idToken string) (*FirebaseUser, error) {
	ctx := context.Background()

	// Verify the ID token
	token, err := config.FirebaseAuth.VerifyIDToken(ctx, idToken)
	if err != nil {
		return nil, errors.New("invalid or expired token")
	}

	// Extract user information
	user := &FirebaseUser{
		UID:   token.UID,
		Email: token.Claims["email"].(string),
	}

	// Try to get display name from claims
	if name, ok := token.Claims["name"].(string); ok && name != "" {
		user.Name = name
	} else {
		user.Name = user.Email // Fallback to email
	}

	return user, nil
}
