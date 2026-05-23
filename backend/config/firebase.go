package config

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"

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

	// Prefer full service-account JSON from env for cloud deploys.
	credentialsJSON := os.Getenv("FIREBASE_CREDENTIALS_JSON")
	if credentialsJSON != "" {
		opt := option.WithCredentialsJSON([]byte(credentialsJSON))
		app, err := firebase.NewApp(ctx, nil, opt)
		if err != nil {
			return err
		}
		authClient, err := app.Auth(ctx)
		if err != nil {
			return err
		}
		FirebaseApp = app
		FirebaseAuth = authClient
		log.Println("✅ Firebase Admin SDK initialized successfully (env json)")
		return nil
	}

	// Fallback: build credentials JSON from individual env vars.
	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	clientEmail := os.Getenv("FIREBASE_CLIENT_EMAIL")
	privateKey := os.Getenv("FIREBASE_PRIVATE_KEY")
	privateKeyID := os.Getenv("FIREBASE_PRIVATE_KEY_ID")
	clientID := os.Getenv("FIREBASE_CLIENT_ID")

	if projectID != "" && clientEmail != "" && privateKey != "" {
		privateKey = strings.ReplaceAll(privateKey, "\\n", "\n")
		creds := map[string]string{
			"type":                        "service_account",
			"project_id":                  projectID,
			"private_key_id":              privateKeyID,
			"private_key":                 privateKey,
			"client_email":                clientEmail,
			"client_id":                   clientID,
			"auth_uri":                    "https://accounts.google.com/o/oauth2/auth",
			"token_uri":                   "https://oauth2.googleapis.com/token",
			"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
			"client_x509_cert_url":        "https://www.googleapis.com/robot/v1/metadata/x509/" + clientEmail,
		}
		raw, err := json.Marshal(creds)
		if err != nil {
			return err
		}
		opt := option.WithCredentialsJSON(raw)
		app, err := firebase.NewApp(ctx, nil, opt)
		if err != nil {
			return err
		}
		authClient, err := app.Auth(ctx)
		if err != nil {
			return err
		}
		FirebaseApp = app
		FirebaseAuth = authClient
		log.Println("✅ Firebase Admin SDK initialized successfully (env fields)")
		return nil
	}

	// Final fallback: local file-based credentials.
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
