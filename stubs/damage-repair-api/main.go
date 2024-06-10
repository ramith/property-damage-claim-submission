package main

import (
    "github.com/gin-gonic/gin"
    "net/http"
)

type Location struct {
    Latitude  float64 `json:"latitude" binding:"required"`
    Longitude float64 `json:"longitude" binding:"required"`
}

type PropertyDetails struct {
    Reference string   `json:"reference" binding:"required"`
    Address   string   `json:"address" binding:"required"`
    Type      string   `json:"type" binding:"required"`
    Location  Location `json:"location" binding:"required"`
}

type RepairRequest struct {
    ClaimReference          string          `json:"claimReference" binding:"required"`
    CustomerReference       string          `json:"customerReference" binding:"required"`
    PropertyDetails         PropertyDetails `json:"propertyDetails" binding:"required"`
    TypeOfServiceRequested  string          `json:"typeOfServiceRequested" binding:"required"`
    DateOfServiceRequested  string          `json:"dateOfServiceRequested" binding:"required"`
}

type RepairResponse struct {
    Status          string `json:"status"`
    ServiceDate     string `json:"serviceDate"`
    ServiceProvider string `json:"serviceProvider"`
}

func main() {
    r := gin.Default()

    r.POST("/repair", func(c *gin.Context) {
        var request RepairRequest
        if err := c.ShouldBindJSON(&request); err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
            return
        }

        response := RepairResponse{
            Status:          "Service Scheduled",
            ServiceDate:     "2024-06-15",
            ServiceProvider: "FirstOnSite",
        }

        c.JSON(http.StatusOK, response)
    })

    r.Run(":8083")
}
