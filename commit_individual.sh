#!/bin/bash

# Script to commit each file individually with descriptive messages

echo "Starting individual commits..."

# Modified files
git add .gitignore
git commit -m "chore: update .gitignore to exclude compiled binaries and ML artifacts"

git add backend/cmd/main.go
git commit -m "feat(backend): update main.go with new configurations"

git add backend/go.mod
git commit -m "chore(backend): update go.mod dependencies"

git add backend/go.sum
git commit -m "chore(backend): update go.sum checksums"

git add backend/handlers/expense_test.go
git commit -m "test(backend): update expense handler tests"

git add backend/internal/auth/handler.go
git commit -m "feat(backend): update auth handler implementation"

git add backend/internal/auth/repository.go
git commit -m "feat(backend): update auth repository layer"

git add backend/internal/auth/service.go
git commit -m "feat(backend): update auth service logic"

git add backend/internal/config/config.go
git commit -m "feat(backend): update configuration management"

git add backend/internal/models/user.go
git commit -m "feat(backend): update user model structure"

git add backend/main.go
git commit -m "feat(backend): update main entry point"

git add backend/models/roomspace_test.go
git commit -m "test(backend): update roomspace model tests"

git add backend/services/postgres.go
git commit -m "feat(backend): update PostgreSQL service implementation"

git add backend/services/roomspace_test.go
git commit -m "test(backend): update roomspace service tests"

git add lib/core/widgets/mobile_scaffold.dart
git commit -m "feat(frontend): update mobile scaffold widget"

git add lib/features/home/mobile_dashboard.dart
git commit -m "feat(frontend): update mobile dashboard with new features"

git add lib/main.dart
git commit -m "feat(frontend): update main app configuration"

git add lib/services/ocr_service.dart
git commit -m "feat(frontend): update OCR service implementation"

git add pubspec.lock
git commit -m "chore(frontend): update pubspec.lock dependencies"

git add pubspec.yaml
git commit -m "chore(frontend): update pubspec.yaml with new packages"

# New analytics files - Backend
git add backend/handlers/analytics_handler.go
git commit -m "feat(backend): add analytics handler for spending insights"

git add backend/handlers/analytics_handler_test.go
git commit -m "test(backend): add analytics handler tests"

git add backend/models/analytics.go
git commit -m "feat(backend): add analytics models and structures"

git add backend/models/analytics_test.go
git commit -m "test(backend): add analytics model tests"

git add backend/pkg/database/migrations/010_create_analytics_tables.sql
git commit -m "feat(backend): add analytics database migration"

git add backend/pkg/database/migrations/README.md
git commit -m "docs(backend): add migrations README documentation"

git add backend/pkg/database/migrations/verify_analytics_schema.sh
git commit -m "chore(backend): add analytics schema verification script"

git add backend/services/analytics_service.go
git commit -m "feat(backend): add analytics service implementation"

git add backend/services/analytics_service_test.go
git commit -m "test(backend): add analytics service tests"

git add backend/services/verify_roomspace_analytics.go
git commit -m "feat(backend): add roomspace analytics verification"

# New analytics files - Frontend
git add lib/features/analytics/
git commit -m "feat(frontend): add analytics feature module with UI components"

git add lib/models/analytics_models.dart
git commit -m "feat(frontend): add analytics data models"

git add lib/services/analytics_service.dart
git commit -m "feat(frontend): add analytics service for API integration"

# ML Pipeline
git add ml_pipeline/
git commit -m "feat(ml): add machine learning pipeline for spending predictions and analytics"

echo ""
echo "✅ All files committed individually!"
echo ""
echo "Summary:"
git log --oneline -35
