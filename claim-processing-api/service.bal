import ballerina/http;
import ballerina/log;

configurable string contractLookupApiEndpoint = ?;
configurable string digiFactApiEndpoint = ?;
configurable string firedamageRepairApiEndpoint = ?;

http:Client contractLookUpAPI = check new (url = contractLookupApiEndpoint);
http:Client digifactAPI = check new (url = digiFactApiEndpoint);
http:Client fireDamageRepairAPI = check new (url = firedamageRepairApiEndpoint);

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function post submit(ClaimSubmission claim, http:Request request) returns error|string {
        // Add your logic here

        log:printInfo("recieved claim submission", claim = claim);

        ContractLookupRequest contractLookupRequest = {
            claimReference: claim.claimReference,
            customerReference: claim.customerReference,
            policyID: check int:fromString(claim.policyID)
        };

        ContractLookupResponse contractLookUpStatus = check contractLookUpAPI->/lookup.post(contractLookupRequest);
        log:printInfo("contract lookup status", contractLookUpStatus = contractLookUpStatus);

        if (contractLookUpStatus.status != "Success") {
            return error("contract lookup failed");
        }

        match contractLookUpStatus.routeTo {
            "DigiFact" => {
                check routeToDigiFact(claim);
            }
            // more system to route
            _ => {
                return error("unable to find a system to route");
            }
            // Route to default
        }

        return "claim submitted successfully";
    }
}

function routeToDigiFact(ClaimSubmission claim) returns error? {

    DigiFactEstimationRequest digiFactEstimationRequest = {
        policyID: check int:fromString(claim.policyID),
        claimReference: claim.claimReference,
        customerReference: claim.customerReference,
        customerProfile: claim.customerProfile,
        lossDetails: claim.lossDetails
    };
    DigiFactEstimationResponse digiFactEstimationResponse = check digifactAPI->/estimate.post(digiFactEstimationRequest);
    log:printInfo("DigiFact estimation response", digiFactEstimationResponse = digiFactEstimationResponse);

    if (digiFactEstimationResponse.status != "Estimate Generated") {
        return error("DigiFact estimation failed");
    }

    match claim.lossDetails.typeOfLoss {
        "Fire Damage" => {
            check requestFireDamageRepair(claim);
        }

        // more system to integrate based on the type of loss
        _ => {
            return error("unable to find a matching damage repair system to route");
        }
        // Route to default
    }

}

function requestFireDamageRepair(ClaimSubmission claim) returns error? {
    // Send to fire department
    // Fire department API integration logic
    FireDamageRepairRequest fireDamageRepairRequest = {
        claimReference: claim.claimReference,
        customerReference: claim.customerReference,
        propertyDetails: claim.propertyDetails,
        typeOfServiceRequested: claim.lossDetails.typeOfLoss,
        dateOfServiceRequested: claim.lossDetails.dateOfLoss
    };

    FireDamageRepairResponse fireDamageRepairResponse = check fireDamageRepairAPI->/repair.post(fireDamageRepairRequest);
    log:printInfo("fire damage repair response", fireDamageRepairResponse = fireDamageRepairResponse);

    if fireDamageRepairResponse.status != "Service Scheduled" {
        return error("unable to schedule fire damage repair service");
    }
    return ();
}

type CustomerProfile record {
    string id;
    string name;
    string address;
};

type CustomerContact record {
    string email;
    string phone;
};

type Location record {
    decimal latitude;
    decimal longitude;
};

type PropertyDetails record {
    string reference;
    string address;
    string 'type;
    Location location;
};

type LossDetails record {
    string dateOfLoss;
    string typeOfLoss;
    string estimatedLoss;
    string attachments;
};

type ClaimSubmission record {
    string claimReference;
    string dateSubmitted;
    string customerReference;
    string policyID;
    CustomerProfile customerProfile;
    CustomerContact customerContact;
    string claimType;
    PropertyDetails propertyDetails;
    LossDetails lossDetails;
};

type ContractLookupRequest record {
    string claimReference;
    string customerReference;
    int policyID;
};

type ContractLookupResponse record {
    string status;
    string message;
    string routeTo;
};

type DigiFactEstimationRequest record {
    int policyID;
    string claimReference;
    string customerReference;
    CustomerProfile customerProfile;
    LossDetails lossDetails;
};

type DigiFactEstimationResponse record {
    string status;
    string estimatedRepairCost;
    string vendorAssigned;
    string expectedCompletionDate;
};

type FireDamageRepairRequest record {
    string claimReference;
    string customerReference;
    PropertyDetails propertyDetails;
    string typeOfServiceRequested;
    string dateOfServiceRequested;
};

type FireDamageRepairResponse record {
    string status;
    string serviceDate;
    string serviceProvider;
};
