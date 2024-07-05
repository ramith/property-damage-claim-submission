package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

// RequestPayload represents the structure of the incoming JSON payload.
type RequestPayload struct {
	ClaimReference    string `json:"claimReference"`
	CustomerReference string `json:"customerReference"`
	PolicyID          int    `json:"policyID"`
}

// ClaimProcessingStep represents each step in the routing information.
type ClaimProcessingStep struct {
	StepNumber       int    `json:"stepNumber"`
	StepName         string `json:"stepName"`
	AssociatedVendor string `json:"associatedVendor"`
	VendorEndpoint   string `json:"vendorEndpoint"`
}

// ResponsePayload represents the structure of the outgoing JSON response.
type ResponsePayload struct {
	Status  string                `json:"status"`
	Message string                `json:"message"`
	Route   []ClaimProcessingStep `json:"route"`
}

func main() {
	r := gin.Default()

	r.POST("/lookup", func(c *gin.Context) {
		var requestPayload RequestPayload
		// Bind the JSON payload to the struct.
		if err := c.ShouldBindJSON(&requestPayload); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Log the received payload
		log.Printf("Received payload: %+v", requestPayload)

		// Create the response struct with example data.
		responsePayload := ResponsePayload{
			Status:  "Success",
			Message: "Routing information retrieved.",
			Route: []ClaimProcessingStep{
				{
					StepNumber:       1,
					StepName:         "ReceiveClaim",
					AssociatedVendor: "DigiFact",
					VendorEndpoint:   "https://api.vendora.com/receive-claim",
				},
				{
					StepNumber:       2,
					StepName:         "DamageRepair",
					AssociatedVendor: "FirstOnSite",
					VendorEndpoint:   "https://api.vendorb.com/validate-claim",
				},
			},
		}

		// Send the response as JSON.
		c.JSON(http.StatusOK, responsePayload)

	})

	r.Run(":8081")
}
