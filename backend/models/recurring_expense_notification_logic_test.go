package models

import (
	"testing"
	"time"
)

func TestRecurringTemplate_ShouldSendNotification_OnConfiguredReminderDayOnly(t *testing.T) {
	loc := time.UTC
	createdAt := time.Date(2026, 5, 24, 12, 0, 0, 0, loc)
	template := RecurringExpenseTemplate{
		CreatedAt: createdAt,
		IsActive:  true,
		RecurringConfig: RecurringConfig{
			IsRecurring:            true,
			Interval:               IntervalWeekly,
			NotifyBeforeCreation:   true,
			NotificationDaysBefore: 1,
		},
	}

	// Weekly from May 24 means next scheduled is May 31.
	reminderDay := time.Date(2026, 5, 30, 9, 0, 0, 0, loc)
	dueDay := time.Date(2026, 5, 31, 9, 0, 0, 0, loc)
	tooEarly := time.Date(2026, 5, 29, 9, 0, 0, 0, loc)

	if !template.ShouldSendNotification(reminderDay) {
		t.Fatalf("expected reminder to be sent on configured reminder day")
	}
	if template.ShouldSendNotification(dueDay) {
		t.Fatalf("did not expect reminder on due day")
	}
	if template.ShouldSendNotification(tooEarly) {
		t.Fatalf("did not expect reminder before reminder window")
	}
}

