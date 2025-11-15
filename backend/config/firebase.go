package config

import (
	"context"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

var (
	FirebaseApp  *firebase.App
	FirebaseAuth *auth.Client
)

// InitFirebase initializes Firebase Admin SDK
func InitFirebase(serviceAccountPath string) error {
	ctx := context.Background()

	// Initialize Firebase app with service account
	opt := option.WithCredentialsFile(serviceAccountPath)
	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		return err
	}

	// Get Auth client
	authClient, err := app.Auth(ctx)
	if err != nil {
		return err
	}

	FirebaseApp = app
	FirebaseAuth = authClient

	log.Println("✅ Firebase Admin SDK initialized successfully")
	return nil
}
