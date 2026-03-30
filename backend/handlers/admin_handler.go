package handlers

import (
	"net/http"
	"roomease/backend/config"
	"roomease/backend/models"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// AdminHandler handles admin-related requests
type AdminHandler struct{}

// NewAdminHandler creates a new admin handler
func NewAdminHandler() *AdminHandler {
	return &AdminHandler{}
}

// GetSystemStats returns system statistics
// GET /api/admin/stats
func (h *AdminHandler) GetSystemStats(c *gin.Context) {
	ctx := c.Request.Context()
	
	// Count total users
	var totalUsers int64
	if err := config.DB.WithContext(ctx).Model(&models.User{}).Count(&totalUsers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to count users: " + err.Error(),
		})
		return
	}

	// Count total roomspaces
	var totalRoomspaces int64
	if err := config.DB.WithContext(ctx).Model(&models.Roomspace{}).Count(&totalRoomspaces).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to count roomspaces: " + err.Error(),
		})
		return
	}

	// Count total expenses
	var totalExpenses int64
	if err := config.DB.WithContext(ctx).Model(&models.Expense{}).Count(&totalExpenses).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to count expenses: " + err.Error(),
		})
		return
	}

	// Count banned users
	var bannedUsers int64
	if err := config.DB.WithContext(ctx).Model(&models.User{}).Where("is_banned = ?", true).Count(&bannedUsers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to count banned users: " + err.Error(),
		})
		return
	}

	// Calculate total expense amount
	var totalExpenseAmount float64
	if err := config.DB.WithContext(ctx).Model(&models.Expense{}).Select("COALESCE(SUM(amount), 0)").Scan(&totalExpenseAmount).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to calculate total expense amount: " + err.Error(),
		})
		return
	}

	stats := map[string]interface{}{
		"total_users":         totalUsers,
		"total_roomspaces":    totalRoomspaces,
		"total_expenses":      totalExpenses,
		"total_expense_amount": totalExpenseAmount,
		"banned_users":        bannedUsers,
		"last_updated":        time.Now(),
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    stats,
	})
}

// GetAllUsers returns all users with pagination
// GET /api/admin/users
func (h *AdminHandler) GetAllUsers(c *gin.Context) {
	// Parse pagination parameters
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	search := c.Query("search")

	offset := (page - 1) * limit

	// Build query
	query := config.DB.Model(&models.User{})
	
	if search != "" {
		query = query.Where("name ILIKE ? OR email ILIKE ?", "%"+search+"%", "%"+search+"%")
	}

	// Get total count
	var total int64
	query.Count(&total)

	// Get users
	var users []models.User
	result := query.
		Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&users)

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch users",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    users,
		"pagination": gin.H{
			"page":  page,
			"limit": limit,
			"total": total,
		},
	})
}

// BanUser bans a user
// POST /api/admin/users/:userId/ban
func (h *AdminHandler) BanUser(c *gin.Context) {
	userId := c.Param("userId")

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Find user
	var user models.User
	result := config.DB.Where("firebase_uid = ?", userId).First(&user)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "User not found",
		})
		return
	}

	// Update user ban status
	result = config.DB.Model(&user).Updates(map[string]interface{}{
		"is_banned":   true,
		"ban_reason":  req.Reason,
		"banned_at":   time.Now(),
		"updated_at":  time.Now(),
	})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to ban user",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "User banned successfully",
	})
}

// UnbanUser unbans a user
// POST /api/admin/users/:userId/unban
func (h *AdminHandler) UnbanUser(c *gin.Context) {
	userId := c.Param("userId")

	// Find user
	var user models.User
	result := config.DB.Where("firebase_uid = ?", userId).First(&user)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "User not found",
		})
		return
	}

	// Update user ban status
	result = config.DB.Model(&user).Updates(map[string]interface{}{
		"is_banned":   false,
		"ban_reason":  nil,
		"banned_at":   nil,
		"updated_at":  time.Now(),
	})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to unban user",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "User unbanned successfully",
	})
}

// CheckUserBanStatus checks if a user is banned
// GET /api/admin/users/:userId/ban-status
func (h *AdminHandler) CheckUserBanStatus(c *gin.Context) {
	userId := c.Param("userId")

	// Add timeout context for database operations
	ctx := c.Request.Context()
	
	var user models.User
	result := config.DB.WithContext(ctx).Where("firebase_uid = ?", userId).First(&user)
	if result.Error != nil {
		// Log the specific error for debugging
		if result.Error.Error() == "record not found" {
			c.JSON(http.StatusNotFound, gin.H{
				"success": false,
				"error":   "User not found",
			})
		} else {
			// Database connection or other error
			c.JSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"error":   "Database error: " + result.Error.Error(),
			})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"is_banned":  user.IsBanned,
		"ban_reason": user.BanReason,
		"banned_at":  user.BannedAt,
	})
}

// GetUserDetails returns detailed user information
// GET /api/admin/users/:userId
func (h *AdminHandler) GetUserDetails(c *gin.Context) {
	userId := c.Param("userId")

	var user models.User
	result := config.DB.Where("firebase_uid = ?", userId).First(&user)
	if result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "User not found",
		})
		return
	}

	// Get user's roomspaces count
	var roomspaceCount int64
	config.DB.Model(&models.RoomspaceMember{}).
		Where("user_id = ? AND is_active = ?", userId, true).
		Count(&roomspaceCount)

	// Get user's expenses count
	var expenseCount int64
	config.DB.Model(&models.Expense{}).
		Where("paid_by = ?", userId).
		Count(&expenseCount)

	userDetails := map[string]interface{}{
		"user":            user,
		"roomspace_count": roomspaceCount,
		"expense_count":   expenseCount,
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    userDetails,
	})
}