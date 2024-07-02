import ballerina/http;
import ballerina/log;

# A service representing a network-accessible API
# bound to port `9090`.
service /partner on httpListener {

    resource function post register(string payload) returns http:Created {
        log:printInfo("Received a request to register a new partner");
        log:printInfo("Payload: ", p = payload);

        return http:CREATED;
    }
}

