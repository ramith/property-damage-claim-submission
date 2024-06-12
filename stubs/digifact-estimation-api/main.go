package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Claim represents the structure of the claim data.
type Claim struct {
	ClaimReference    string          `json:"claimReference"`
	CustomerReference string          `json:"customerReference"`
	CustomerProfile   CustomerProfile `json:"customerProfile"`
	PolicyID          int             `json:"policyID"`
	LossDetails       LossDetails     `json:"lossDetails"`
}

// CustomerProfile represents the customer's profile.
type CustomerProfile struct {
	ID string `json:"id"`
}

// LossDetails represents the details of the loss.
type LossDetails struct {
	DateOfLoss    string `json:"dateOfLoss"`
	TypeOfLoss    string `json:"typeOfLoss"`
	EstimatedLoss string `json:"estimatedLoss"`
	Attachments   string `json:"attachments"`
}

func main() {
	r := gin.Default()
	//r.Use(LogRequestBody());
	r.POST("/estimate", estimateHandler)
	r.Run(":8082")
}

// estimateHandler handles the /estimate endpoint.
func estimateHandler(c *gin.Context) {
	// Parse the form, including file upload
	file, handler, err := c.Request.FormFile("attachments")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File upload error"})
		return
	}
	defer file.Close()

	fileSize, err := file.Seek(0, io.SeekEnd)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to determine file size"})
		return
	}

	// Reset file pointer
	_, err = file.Seek(0, io.SeekStart)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to reset file pointer"})
		return
	}

	// Extract and parse the JSON payload from the form field
	claimJson := c.PostForm("claim")
	var claim Claim
	if err := json.Unmarshal([]byte(claimJson), &claim); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Print everything in a single log line
	log.Printf("File uploaded: %s, File size: %d bytes, Claim Data: %+v", handler.Filename, fileSize, claim)

	c.JSON(http.StatusOK, gin.H{
		"status":                 "Estimate Generated",
		"estimatedRepairCost":    "$4500",
		"vendorAssigned":         "DigiFact",
		"expectedCompletionDate": "2024-06-20T00:00:00Z",
	})
}

// Middleware to log request body
func LogRequestBody() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Read the Body content
		bodyBytes, err := io.ReadAll(c.Request.Body)
		if err != nil {
			log.Println("Error reading body:", err)
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}

		// Restore the io.ReadCloser to its original state
		c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

		// Log the request body
		log.Println("Received JSON payload:", string(bodyBytes))

		// Pass on to the next-in-chain
		c.Next()
	}
}
