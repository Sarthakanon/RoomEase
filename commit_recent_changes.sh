#!/bin/bash

# Script to commit recent changes individually with descriptive messages

echo "Starting individual commits for recent changes..."

# Analytics screen padding fixes
git add lib/features/analytics/presentation/analytics_page.dart
git commit -m "fix(analytics): improve button padding and spacing in analytics screen"

# Recommendations card overflow fix
git add lib/features/analytics/widgets/recommendations_card.dart
git commit -m "fix(analytics): fix overflow in recommendations feedback buttons"

# Settings screen - roomspace switching improvements
git add lib/features/settings/presentation/settings_screen.dart
git commit -m "feat(settings): add dropdown for roomspace switching and improve UX"

# Home dashboard - remove roomspace switcher
git add lib/features/home/mobile_dashboard.dart
git commit -m "refactor(home): remove roomspace switcher from dashboard and improve expense loading"

# Roomspace details screen - add switcher and fix active roomspace
git add lib/features/roomspace/presentation/roomspace_details_screen.dart
git commit -m "feat(roomspace): add roomspace switcher and fix active roomspace detection"

# Roomspace provider - add debug logging
git add lib/providers/roomspace_provider.dart
git commit -m "feat(provider): add comprehensive debug logging for roomspace operations"

# Roomspace data model - fix JSON parsing
git add lib/models/roomspace_data.dart
git commit -m "fix(models): fix RoomspaceData JSON parsing to handle API response structure"

# API service - fix getRecentExpenses endpoint
git add lib/services/api_service.dart
git commit -m "fix(api): correct getRecentExpenses endpoint to use proper roomspace API"

# Personal expense dialog - fix text overflow
git add lib/features/home/widgets/personal_expense_dialog.dart
git commit -m "fix(ui): shorten dialog title to prevent overflow in personal expense dialog"

# Technical documentation
git add docs/TECHNICAL_ANALYSIS.md
git commit -m "docs: add comprehensive technical analysis for professionalism report"

echo ""
echo "✅ All recent changes committed individually!"
echo ""
echo "Summary of commits:"
git log --oneline -10

echo ""
echo "To push all commits to remote, run:"
echo "git push origin main"
