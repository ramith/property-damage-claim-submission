package main

import (
	"bytes"
	"io"
	"log"
	"net/http"
	"os"

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
	r.Use(LogRequestBody());

	r.POST("/upload", func(c *gin.Context) {
		// Parse the form, including file upload
		file, handler, err := c.Request.FormFile("file")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "File upload error"})
			return
		}

		// Save the file
		out, err := os.Create(handler.Filename)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to save file"})
			return
		}
		defer out.Close()

		_, err = io.Copy(out, file)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to read file"})
			return
		}

		// Retrieve JSON data from form field
		estimateID := c.PostForm("estimateId")
		data := c.PostForm("data")

		// Print the uploaded file name and form data for debugging
		log.Printf("File uploaded: %s\n", handler.Filename)
		log.Printf("Form Data: estimateId=%s, data=%s\n", estimateID, data)

		c.JSON(http.StatusOK, gin.H{
			"status":                 "Estimate Generated",
			"estimatedRepairCost":    "$4500",
			"vendorAssigned":         "DigiFact",
			"expectedCompletionDate": "2024-06-20T00:00:00Z",
		})
	})

	r.POST("/estimate", func(c *gin.Context) {
		var claim Claim

		// Bind the JSON payload to the Claim struct.
		if err := c.ShouldBindJSON(&claim); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"status":                  "Estimate Generated",
			"estimatedRepairCost":     "$4500",
			"vendorAssigned":          "DigiFact",
			"expectedCompletionDate": "2024-06-20T00:00:00Z",
		})
	})

	r.Run(":8082")
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
