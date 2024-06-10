package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
    r := gin.Default()

    r.POST("/lookup", func(c *gin.Context) {

        var payload map[string]interface{}

        // Bind the JSON payload to the map.
        if err := c.ShouldBindJSON(&payload); err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
            return
        }

        // Convert the payload map to JSON for logging
        payloadJSON, err := json.MarshalIndent(payload, "", "  ")
        if err != nil {
            log.Println("Error converting payload to JSON:", err)
        } else {
            log.Println("Received JSON payload:", string(payloadJSON))
        }

        c.JSON(http.StatusOK, gin.H{
            "status":   "Success",
            "message":  "Routing information retrieved.",
            "routeTo":  "DigiFact",
        })
    })

    r.Run(":8081")
}

