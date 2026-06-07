package logging

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/golang/glog"
)

type LogLevel string

const (
	Info  LogLevel = "Info"
	Warn  LogLevel = "Warn"
	Error LogLevel = "Error"
)

type LogEntry struct {
	LogLevel string `json:"logLevel"`
	Time     string `json:"time"`
	OrgID    string `json:"orgid"`
	API      string `json:"api,omitempty"`
	Function string `json:"functionName,omitempty"`
	User     string `json:"user"`
	Content  string `json:"content"`
}

// SetGlogInitial initializes glog with proper file logging (original version)
func SetGlogInitial() error {
	// Create log directory if it doesn't exist
	logDir := "./logs" // Use relative path instead of /logging
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %v", err)
	}

	// Set glog flags before parsing
	flag.Set("log_dir", logDir)
	flag.Set("logtostderr", "false")     // Don't log to stderr, use files
	flag.Set("alsologtostderr", "true")  // Also log to stderr for debugging
	flag.Set("stderrthreshold", "ERROR") // Only errors go to stderr
	flag.Set("v", "2")                   // Set verbosity level

	// Parse flags if not already parsed
	if !flag.Parsed() {
		flag.Parse()
	}

	// Log initialization message
	glog.Info("Logging system initialized with file output")
	return nil
}

// SetGlogInitialWithCleanup initializes glog with file logging and automatic cleanup
func SetGlogInitialWithCleanup() error {
	logDir := "./logs"
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %v", err)
	}

	// Enhanced glog configuration for better file management
	flag.Set("log_dir", logDir)
	flag.Set("logtostderr", "false")     // Don't log to stderr, use files
	flag.Set("alsologtostderr", "true")  // Also log to stderr for debugging
	flag.Set("stderrthreshold", "ERROR") // Only errors go to stderr
	flag.Set("v", "2")                   // Set verbosity level

	// These settings help with file management
	flag.Set("log_backtrace_at", "") // Disable backtrace
	flag.Set("max_log_size", "5")    // Max log file size in MB (smaller files)

	if !flag.Parsed() {
		flag.Parse()
	}

	go StartDailyRotationRoutine()

	// Start cleanup routine (delete glog files older than 30 days)
	StartGlogCleanupRoutine(logDir, 30)

	glog.Info("Glog system initialized with file output and automatic cleanup")
	return nil
}

// Daily rotation routine that restarts glog at midnight
func StartDailyRotationRoutine() {
	for {
		now := time.Now()
		// Calculate time until next midnight
		tomorrow := now.Add(24 * time.Hour)
		midnight := time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(), 0, 0, 0, 0, tomorrow.Location())
		timeUntilMidnight := midnight.Sub(now)

		// Wait until midnight
		time.Sleep(timeUntilMidnight)

		// Flush current logs
		glog.Flush()

		// Create new directory for the new day
		newDay := time.Now().Format("2006-01-02")
		newLogDir := filepath.Join("./logs", newDay)
		os.MkdirAll(newLogDir, 0755)

		// Update log directory (requires restart of application for glog)
		flag.Set("log_dir", newLogDir)

		glog.Info("Rotated to new daily log directory:", newLogDir)
	}
}

// CleanupOldGlogFiles removes glog files older than the specified number of days
// glog creates files like: programname.hostname.username.log.INFO.20250610-143022.12345
func CleanupOldGlogFiles(logDir string, maxAge int) error {
	cutoffTime := time.Now().AddDate(0, 0, -maxAge)

	err := filepath.Walk(logDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip directories
		if info.IsDir() {
			return nil
		}

		fileName := info.Name()

		// Check if it's a glog file by pattern
		// glog files contain .log. and level suffixes
		isGlogFile := strings.Contains(fileName, ".log.") &&
			(strings.Contains(fileName, ".INFO.") ||
				strings.Contains(fileName, ".WARNING.") ||
				strings.Contains(fileName, ".ERROR.") ||
				strings.Contains(fileName, ".FATAL."))

		if isGlogFile {
			// Extract date from glog filename
			// Format: programname.hostname.username.log.LEVEL.YYYYMMDD-HHMMSS.PID
			parts := strings.Split(fileName, ".")
			var dateStr string
			for i, part := range parts {
				if (part == "INFO" || part == "WARNING" || part == "ERROR" || part == "FATAL") && i+1 < len(parts) {
					dateTimeStr := parts[i+1]
					if len(dateTimeStr) >= 8 {
						dateStr = dateTimeStr[:8] // Extract YYYYMMDD
					}
					break
				}
			}

			// Parse the date from filename if available
			if dateStr != "" {
				if fileDate, err := time.Parse("20060102", dateStr); err == nil {
					if fileDate.Before(cutoffTime) {
						fmt.Printf("Deleting old glog file: %s (date: %s)\n", path, fileDate.Format("2006-01-02"))
						if err := os.Remove(path); err != nil {
							fmt.Printf("Error deleting %s: %v\n", path, err)
						}
					}
					return nil
				}
			}

			// Fallback to modification time if date parsing fails
			if info.ModTime().Before(cutoffTime) {
				fmt.Printf("Deleting old glog file: %s (modified: %s)\n", path, info.ModTime().Format("2006-01-02"))
				if err := os.Remove(path); err != nil {
					fmt.Printf("Error deleting %s: %v\n", path, err)
				}
			}
		}

		return nil
	})

	return err
}

func StartGlogCleanupRoutine(logDir string, maxAge int) {
	go func() {
		ticker := time.NewTicker(24 * time.Hour) // Run daily at startup time
		defer ticker.Stop()

		// Run cleanup immediately on startup
		if err := CleanupOldGlogFiles(logDir, maxAge); err != nil {
			fmt.Printf("Error during initial glog cleanup: %v\n", err)
		}

		// Use range instead of for-select when listening to single channel
		for range ticker.C {
			if err := CleanupOldGlogFiles(logDir, maxAge); err != nil {
				fmt.Printf("Error during glog cleanup: %v\n", err)
			}
		}
	}()
}

// ScheduleDailyFlush encourages glog to create new files daily
// This helps simulate daily rotation by flushing logs at specific times
func ScheduleDailyFlush() {
	go func() {
		now := time.Now()
		// Calculate time until next midnight
		nextMidnight := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())
		initialDelay := nextMidnight.Sub(now)

		// Wait until midnight, then flush daily
		time.Sleep(initialDelay)

		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()

		for {
			FlushLogs()
			glog.Info("Daily log flush completed")
			<-ticker.C
		}
	}()
}

// CleanupGlogManual provides manual cleanup option
func CleanupGlogManual(logDir string, maxAge int) error {
	return CleanupOldGlogFiles(logDir, maxAge)
}

// LogAPI logs API-level activity using glog (writes to files)
func LogAPI(level LogLevel, orgID, api, user, content string) {
	logTime := time.Now().Format("2006-01-02 15:04:05") // More readable format
	logEntry := LogEntry{
		LogLevel: string(level),
		Time:     logTime,
		OrgID:    orgID,
		API:      api,
		User:     user,
		Content:  content,
	}

	jsonData, err := json.Marshal(logEntry)
	if err != nil {
		glog.Errorf("Log serialization error: %v", err)
		return
	}

	// Use glog for all logging - this will write to files
	logMessage := string(jsonData)

	switch level {
	case Info:
		glog.Info("API_LOG: ", logMessage)
	case Warn:
		glog.Warning("API_LOG: ", logMessage)
	case Error:
		glog.Error("API_LOG: ", logMessage)
	}
}

// LogFunction logs function-level activity using glog
func LogFunction(level LogLevel, orgID, functionName, user, content string) {
	logTime := time.Now().Format("2006-01-02 15:04:05")
	logEntry := LogEntry{
		LogLevel: string(level),
		Time:     logTime,
		OrgID:    orgID,
		Function: functionName,
		User:     user,
		Content:  content,
	}

	jsonData, err := json.Marshal(logEntry)
	if err != nil {
		glog.Errorf("Log serialization error: %v", err)
		return
	}

	logMessage := string(jsonData)

	switch level {
	case Info:
		glog.Info("FUNC_LOG: ", logMessage)
	case Warn:
		glog.Warning("FUNC_LOG: ", logMessage)
	case Error:
		glog.Error("FUNC_LOG: ", logMessage)
	}
}

// LogToFile writes to a specific custom log file (alternative approach)
func LogToFile(entry LogEntry, logFilePath string) error {
	// Ensure directory exists
	dir := filepath.Dir(logFilePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	file, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	logTime := time.Now().Format("2006-01-02 15:04:05")
	entry.Time = logTime

	data, err := json.Marshal(entry)
	if err != nil {
		return err
	}

	_, err = file.Write(append(data, '\n'))
	return err
}

// FlushLogs ensures all glog buffers are flushed to disk
func FlushLogs() {
	glog.Flush()
}
