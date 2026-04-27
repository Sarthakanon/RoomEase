package services

import (
	"log"
	"time"

	"github.com/robfig/cron/v3"
	"gorm.io/gorm"
)

// CronService handles scheduled tasks
type CronService struct {
	cron                    *cron.Cron
	recurringExpenseService *RecurringExpenseService
}

// NewCronService creates a new cron service
func NewCronService(db *gorm.DB) *CronService {
	c := cron.New(cron.WithLocation(time.UTC))
	recurringExpenseService := NewRecurringExpenseService(db)
	
	return &CronService{
		cron:                    c,
		recurringExpenseService: recurringExpenseService,
	}
}

// Start starts the cron service
func (s *CronService) Start() error {
	log.Println("Starting cron service...")
	
	// Process recurring expenses every hour
	_, err := s.cron.AddFunc("0 * * * *", func() {
		log.Println("Running recurring expense processing job...")
		if err := s.recurringExpenseService.ProcessRecurringExpenses(); err != nil {
			log.Printf("Error in recurring expense processing: %v", err)
		}
	})
	if err != nil {
		return err
	}
	
	// Cleanup old notifications daily at 2 AM
	_, err = s.cron.AddFunc("0 2 * * *", func() {
		log.Println("Running notification cleanup job...")
		if err := s.recurringExpenseService.CleanupOldNotifications(); err != nil {
			log.Printf("Error in notification cleanup: %v", err)
		}
	})
	if err != nil {
		return err
	}
	
	s.cron.Start()
	log.Println("Cron service started successfully")
	
	return nil
}

// Stop stops the cron service
func (s *CronService) Stop() {
	log.Println("Stopping cron service...")
	s.cron.Stop()
	log.Println("Cron service stopped")
}

// GetNextRuns returns the next run times for all scheduled jobs
func (s *CronService) GetNextRuns() []time.Time {
	entries := s.cron.Entries()
	var nextRuns []time.Time
	
	for _, entry := range entries {
		nextRuns = append(nextRuns, entry.Next)
	}
	
	return nextRuns
}