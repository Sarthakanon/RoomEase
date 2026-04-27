#!/bin/bash

# RoomEase API Testing Setup Script
# This script helps you quickly set up Bruno API testing environment

echo "🚀 RoomEase API Testing Setup"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Bruno is installed
echo ""
print_info "Checking Bruno installation..."
if command -v bruno &> /dev/null; then
    print_status "Bruno CLI is installed"
else
    print_warning "Bruno CLI not found. Install from: https://www.usebruno.com/"
fi

# Check if Node.js is installed for helper scripts
echo ""
print_info "Checking Node.js installation..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_status "Node.js is installed: $NODE_VERSION"
else
    print_error "Node.js not found. Install from: https://nodejs.org/"
    exit 1
fi

# Install dependencies for helper scripts
echo ""
print_info "Installing helper script dependencies..."
cd "$(dirname "$0")"
if [ -f "package.json" ]; then
    npm install
    if [ $? -eq 0 ]; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
else
    print_error "package.json not found"
    exit 1
fi

# Check backend server connectivity
echo ""
print_info "Checking backend server connectivity..."

# Try local development server
LOCAL_URL="http://192.168.101.9:8080/health"
if curl -s --connect-timeout 5 "$LOCAL_URL" > /dev/null 2>&1; then
    print_status "Local development server is running: $LOCAL_URL"
    BACKEND_AVAILABLE=true
else
    print_warning "Local development server not accessible: $LOCAL_URL"
fi

# Try Docker server
DOCKER_URL="http://localhost:8080/health"
if curl -s --connect-timeout 5 "$DOCKER_URL" > /dev/null 2>&1; then
    print_status "Docker server is running: $DOCKER_URL"
    BACKEND_AVAILABLE=true
else
    print_warning "Docker server not accessible: $DOCKER_URL"
fi

if [ "$BACKEND_AVAILABLE" != true ]; then
    print_error "No backend server is accessible. Please start your backend server first."
    echo ""
    echo "To start local server:"
    echo "  cd backend && go run main.go"
    echo ""
    echo "To start Docker server:"
    echo "  docker-compose up -d"
    exit 1
fi

# Environment selection
echo ""
print_info "Environment Setup"
echo "Which environment would you like to configure?"
echo "1) Local Development (192.168.101.9:8080)"
echo "2) Docker (localhost:8080)"
echo "3) Production Railway"
echo "4) AWS Production"
echo "5) Skip environment setup"

read -p "Enter your choice (1-5): " ENV_CHOICE

case $ENV_CHOICE in
    1)
        ENV_FILE="../environments/Local.bru"
        BASE_URL="http://192.168.101.9:8080"
        ;;
    2)
        ENV_FILE="../environments/Docker.bru"
        BASE_URL="http://localhost:8080"
        ;;
    3)
        ENV_FILE="../environments/Production.bru"
        read -p "Enter your Railway URL (e.g., https://your-app.up.railway.app): " BASE_URL
        ;;
    4)
        ENV_FILE="../environments/AWS.bru"
        read -p "Enter your AWS URL (e.g., https://your-app.amazonaws.com): " BASE_URL
        ;;
    5)
        print_info "Skipping environment setup"
        ENV_FILE=""
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Update environment file if selected
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    print_info "Updating environment file: $ENV_FILE"
    
    # Update base URL in environment file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|baseUrl: .*|baseUrl: $BASE_URL|" "$ENV_FILE"
    else
        # Linux
        sed -i "s|baseUrl: .*|baseUrl: $BASE_URL|" "$ENV_FILE"
    fi
    
    print_status "Environment file updated with base URL: $BASE_URL"
fi

# Firebase token setup
echo ""
print_info "Firebase Token Setup"
echo "Do you want to generate a Firebase token now?"
echo "1) Yes, generate token with helper script"
echo "2) No, I'll set it up manually later"

read -p "Enter your choice (1-2): " TOKEN_CHOICE

case $TOKEN_CHOICE in
    1)
        print_info "Setting up Firebase token..."
        echo ""
        echo "Before generating token, make sure you have a test user in Firebase:"
        echo "1. Go to Firebase Console > Authentication > Users"
        echo "2. Add user with email: test@example.com"
        echo "3. Set password: testpassword123"
        echo ""
        read -p "Press Enter when ready to generate token..."
        
        node get-firebase-token.js
        
        if [ $? -eq 0 ]; then
            print_status "Token generated successfully!"
            print_info "Copy the token above and paste it into your Bruno environment file"
        else
            print_error "Token generation failed. Check the error messages above."
        fi
        ;;
    2)
        print_info "Skipping token generation"
        print_info "Remember to set firebase_token in your environment file manually"
        ;;
    *)
        print_error "Invalid choice"
        ;;
esac

# Final instructions
echo ""
print_status "Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Open Bruno and import the collection from: $(dirname "$0")/.."
echo "2. Select your environment in Bruno"
echo "3. Update firebase_token in environment file if not done already"
echo "4. Run the Login test to verify everything works"
echo ""
echo "Useful files:"
echo "- Environment files: ../environments/"
echo "- Setup guide: ../ENVIRONMENT_SETUP.md"
echo "- Main README: ../README.md"
echo ""
print_status "Happy testing! 🎉"