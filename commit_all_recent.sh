#!/bin/bash

# Script to commit all recent changes individually with descriptive messages

echo "Starting individual commits for all recent changes..."

# Core widget updates
git add lib/core/widgets/roomspace_switcher.dart
git commit -m "feat(widgets): add roomspace switcher widget for multi-roomspace support"

# Analytics feature - presentation layer
git add lib/features/analytics/presentation/analytics_page.dart
git commit -m "fix(analytics): improve button padding, add personal expenses support, and fix UI spacing"

# Analytics feature - widgets
git add lib/features/analytics/widgets/spending_trends_chart.dart
git commit -m "feat(analytics): add spending trends chart widget with time range selection"

git add lib/features/analytics/widgets/category_breakdown_chart.dart
git commit -m "feat(analytics): add category breakdown pie chart widget"

git add lib/features/analytics/widgets/recommendations_card.dart
git commit -m "fix(analytics): fix overflow in recommendations card and improve feedback UI"

git add lib/features/analytics/widgets/anomaly_alert_card.dart
git commit -m "feat(analytics): add anomaly detection alert card widget"

git add lib/features/analytics/widgets/predictions_card.dart
git commit -m "feat(analytics): add spending predictions card widget"

git add lib/features/analytics/widgets/skeleton_loader.dart
git commit -m "feat(analytics): add skeleton loader widgets for loading states"

# Expense feature updates
git add lib/features/expenses/presentation/expense_list_screen.dart
git commit -m "feat(expenses): add active roomspace support and improve expense filtering"

git add lib/features/expenses/presentation/expense_screen.dart
git commit -m "refactor(expenses): update expense screen to use active roomspace from provider"

git add lib/features/expenses/presentation/expense_details_screen.dart
git commit -m "feat(expenses): update expense details screen with improved UI"

git add lib/features/expenses/presentation/personal_expenses_screen.dart
git commit -m "feat(expenses): add personal expenses screen separate from shared expenses"

git add lib/features/expenses/presentation/personal_expense_details_screen.dart
git commit -m "feat(expenses): add personal expense details screen"

# Home feature updates
git add lib/features/home/mobile_dashboard.dart
git commit -m "refactor(home): remove roomspace switcher, fix expense loading, add debug logging"

git add lib/features/home/widgets/add_expense_dialog.dart
git commit -m "feat(home): update add expense dialog with improved validation"

git add lib/features/home/widgets/personal_expense_dialog.dart
git commit -m "fix(home): shorten dialog title to prevent overflow in personal expense dialog"

# Roomspace feature updates
git add lib/features/roomspace/presentation/roomspace_details_screen.dart
git commit -m "feat(roomspace): add roomspace switcher and fix active roomspace detection"

git add lib/features/roomspace/presentation/roomspace_router.dart
git commit -m "feat(roomspace): add roomspace router for navigation"

git add lib/features/roomspace/presentation/roomspace_selection_screen.dart
git commit -m "feat(roomspace): add roomspace selection screen for initial setup"

git add lib/features/roomspace/presentation/create_roomspace_screen.dart
git commit -m "feat(roomspace): add create roomspace screen"

git add lib/features/roomspace/presentation/join_roomspace_screen.dart
git commit -m "feat(roomspace): add join roomspace screen with invite code"

# Settings feature updates
git add lib/features/settings/presentation/settings_screen.dart
git commit -m "feat(settings): add dropdown for roomspace switching and improve UX"

git add lib/features/settings/presentation/payment_notification_settings_screen.dart
git commit -m "feat(settings): add payment notification settings screen"

# Notifications feature
git add lib/features/notifications/presentation/notification_screen.dart
git commit -m "feat(notifications): add notification screen for expense and join request alerts"

git add lib/features/notifications/presentation/payment_history_screen.dart
git commit -m "feat(notifications): add payment history screen"

# Profile feature
git add lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(profile): add user profile screen"

# Auth feature updates
git add lib/features/auth/presentation/login_screen.dart
git commit -m "feat(auth): update login screen to load roomspaces after authentication"

git add lib/features/auth/presentation/signup_screen.dart
git commit -m "feat(auth): update signup screen with improved validation"

git add lib/features/auth/presentation/splash_screen.dart
git commit -m "feat(auth): update splash screen to load roomspaces on app start"

git add lib/features/auth/presentation/forgot_password_screen.dart
git commit -m "feat(auth): add forgot password screen"

git add lib/features/auth/controllers/auth_controller.dart
git commit -m "feat(auth): update auth controller with backend integration"

# Models
git add lib/models/roomspace_data.dart
git commit -m "fix(models): fix RoomspaceData JSON parsing to handle API response structure"

git add lib/models/analytics_models.dart
git commit -m "feat(models): add analytics data models for ML predictions and insights"

git add lib/models/expense_models.dart
git commit -m "feat(models): update expense models with split types and roomspace support"

# Providers
git add lib/providers/roomspace_provider.dart
git commit -m "feat(provider): add comprehensive debug logging and improve error handling"

# Services
git add lib/services/api_service.dart
git commit -m "fix(api): correct getRecentExpenses endpoint and improve error handling"

git add lib/services/analytics_service.dart
git commit -m "feat(services): add analytics service for ML predictions and insights"

git add lib/services/expense_service.dart
git commit -m "feat(services): add expense service with roomspace support"

git add lib/services/firebase_auth_service.dart
git commit -m "feat(services): update Firebase auth service"

git add lib/services/auth_state_service.dart
git commit -m "feat(services): add auth state persistence service"

git add lib/services/payment_notification_service.dart
git commit -m "feat(services): add payment notification service for SMS detection"

# Core widgets
git add lib/core/widgets/mobile_scaffold.dart
git commit -m "feat(widgets): update mobile scaffold with bottom navigation"

git add lib/core/widgets/skeleton_loader.dart
git commit -m "feat(widgets): add skeleton loader widgets for loading states"

# Main app
git add lib/main.dart
git commit -m "feat(app): update main app with roomspace provider and new routes"

# Documentation
git add docs/TECHNICAL_ANALYSIS.md
git commit -m "docs: add comprehensive technical analysis for professionalism report"

git add README.md
git commit -m "docs: update README with project information" 2>/dev/null || echo "README.md not modified, skipping..."

# Specs
git add .kiro/specs/multiple-roomspace-support/spec.md
git commit -m "docs(specs): add multiple roomspace support specification" 2>/dev/null || echo "spec.md not modified, skipping..."

git add .kiro/specs/multiple-roomspace-support/tasks.md
git commit -m "docs(specs): add multiple roomspace support tasks" 2>/dev/null || echo "tasks.md not modified, skipping..."

echo ""
echo "✅ All changes committed individually!"
echo ""
echo "Summary of recent commits:"
git log --oneline -20

echo ""
echo "To push all commits to remote, run:"
echo "git push origin main"
