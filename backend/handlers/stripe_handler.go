package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/stripe/stripe-go/v72"
	"github.com/stripe/stripe-go/v72/paymentintent"
)

// Initialize Stripe with secret key
func init() {
	// Stripe secret key
	stripe.Key = "sk_test_51TU9vSHqZqdKUPbJ6LYC6JrGX2nYo0BW8QsJTNwyBW2F9PpFU68DuDKaKfJzZnPojKFYD5eaiUpDt730jU1hL9iA000P86Axir"
	log.Println("✅ Stripe initialized")
}

// CreateIntentRequest represents the payment intent creation request
type CreateIntentRequest struct {
	Amount      int64  `json:"amount"`       // Amount in smallest currency unit (paisa/cents)
	Currency    string `json:"currency"`     // Currency code (e.g., "inr", "usd")
	ProductID   string `json:"product_id"`   // Product identifier
	ProductName string `json:"product_name"` // Product name
}

// CreateIntentResponse represents the payment intent creation response
type CreateIntentResponse struct {
	ID           string `json:"id"`
	ClientSecret string `json:"client_secret"`
}

// CreatePaymentIntent creates a Stripe payment intent
func CreatePaymentIntent(w http.ResponseWriter, r *http.Request) {
	// Only allow POST requests
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse request body
	var req CreateIntentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ Error decoding request: %v", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate request
	if req.Amount <= 0 {
		http.Error(w, "Amount must be greater than 0", http.StatusBadRequest)
		return
	}
	if req.Currency == "" {
		req.Currency = "inr" // Default to INR
	}

	log.Printf("🔵 Creating payment intent: Amount=%d %s, Product=%s", req.Amount, req.Currency, req.ProductName)

	// Create payment intent parameters
	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(req.Amount),
		Currency: stripe.String(req.Currency),
	}

	// Add metadata
	params.AddMetadata("product_id", req.ProductID)
	params.AddMetadata("product_name", req.ProductName)

	// Create payment intent
	pi, err := paymentintent.New(params)
	if err != nil {
		log.Printf("❌ Error creating payment intent: %v", err)
		http.Error(w, "Failed to create payment intent", http.StatusInternalServerError)
		return
	}

	log.Printf("✅ Payment intent created: %s", pi.ID)

	// Prepare response
	response := CreateIntentResponse{
		ID:           pi.ID,
		ClientSecret: pi.ClientSecret,
	}

	// Send response
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("❌ Error encoding response: %v", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// VerifyPaymentIntent verifies a payment intent (optional, for additional security)
func VerifyPaymentIntent(w http.ResponseWriter, r *http.Request) {
	// Only allow POST requests
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse request body
	var req struct {
		PaymentIntentID string `json:"payment_intent_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Retrieve payment intent from Stripe
	pi, err := paymentintent.Get(req.PaymentIntentID, nil)
	if err != nil {
		log.Printf("❌ Error retrieving payment intent: %v", err)
		http.Error(w, "Failed to verify payment", http.StatusInternalServerError)
		return
	}

	// Check payment status
	response := map[string]interface{}{
		"id":       pi.ID,
		"status":   pi.Status,
		"amount":   pi.Amount,
		"metadata": pi.Metadata,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// VerifySubscriptionPayment verifies Stripe payment and activates subscription
func VerifySubscriptionPayment(w http.ResponseWriter, r *http.Request) {
	// Only allow POST requests
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse request body
	var req struct {
		PaymentIntentID string  `json:"payment_intent_id"`
		PlanID          string  `json:"plan_id"`
		Amount          float64 `json:"amount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ Error decoding request: %v", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	log.Printf("🔵 Verifying subscription payment: PaymentIntent=%s, Plan=%s", req.PaymentIntentID, req.PlanID)

	// Retrieve payment intent from Stripe to verify it was successful
	pi, err := paymentintent.Get(req.PaymentIntentID, nil)
	if err != nil {
		log.Printf("❌ Error retrieving payment intent: %v", err)
		http.Error(w, "Failed to verify payment", http.StatusInternalServerError)
		return
	}

	// Check if payment was successful
	if pi.Status != "succeeded" {
		log.Printf("❌ Payment not successful: status=%s", pi.Status)
		http.Error(w, "Payment not completed", http.StatusBadRequest)
		return
	}

	log.Printf("✅ Payment verified successfully: %s", pi.ID)

	// Return success response
	// Note: Actual subscription activation should be done by the main backend
	// This handler just verifies the payment was successful
	response := map[string]interface{}{
		"success": true,
		"message": "Payment verified successfully",
		"data": map[string]interface{}{
			"payment_intent_id": pi.ID,
			"plan_id":           req.PlanID,
			"amount":            pi.Amount,
			"status":            pi.Status,
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
