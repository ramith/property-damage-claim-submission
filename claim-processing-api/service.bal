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

    # Receives a claim submission and routes it to the appropriate system.
    #
    # This function handles the submission of a claim, validates the incoming data,
    # and routes it to the designated system based on the provided information.
    #
    # + claim - The claim submission details including claim reference, customer reference,
    #           customer profile, policy ID, and loss details.
    # + request - The HTTP request received, containing the claim submission payload.
    # 
    # + returns - An error message if validation fails or routing encounters an issue.
    #             A success message if the claim is successfully routed.
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

# Routes the claim submission to the DigiFact system.
#
# + claim - The claim submission details including claim reference, customer reference,
#           customer profile, policy ID, and loss details.
#
# + returns - An error if there is an issue during the routing process. Otherwise, returns nothing.
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

# Requests repair services for fire damage based on the claim submission.
#
# This function processes a claim submission specifically for fire damage repairs. 
# It prepares and sends the necessary information to the repair service provider.
#
# + claim - The claim submission details including claim reference, customer reference,
#           customer profile, policy ID, and loss details.
#
# + returns - An error? if there is an issue during the repair request process. Otherwise, returns nothing.
function requestFireDamageRepair(ClaimSubmission claim) returns error? {
    // Send to fire department
    // Fire department API integration logic

    FireDamageRepairRequest fireDamageRepairRequest = toFireDamageRepairRequest(claim);

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

# Converts a claim submission into a fire damage repair request.
#
# This function takes a claim submission as input and converts it into a format 
# suitable for a fire damage repair request. The resulting object will contain 
# all necessary details required by the repair service provider.
#
# + claimSubmission - The claim submission details including claim reference, customer reference,
#                     customer profile, policy ID, and loss details.
#
# + returns - A `FireDamageRepairRequest` object containing the formatted details for the fire damage repair request.
function toFireDamageRepairRequest(ClaimSubmission claimSubmission) returns FireDamageRepairRequest => {
    claimReference: claimSubmission.claimReference,
    customerReference: claimSubmission.customerReference,
    propertyDetails: claimSubmission.propertyDetails,
    typeOfServiceRequested: claimSubmission.lossDetails.typeOfLoss,
    dateOfServiceRequested: claimSubmission.lossDetails.dateOfLoss
};


# Converts a claim submission into a DigiFact estimation request.
#
# This function takes a claim submission as input and converts it into a format 
# suitable for a DigiFact estimation request. The resulting object will contain 
# all necessary details required by DigiFact for processing the estimation.
#
# + claimSubmission - The claim submission details including claim reference, customer reference,
#                     customer profile, policy ID, and loss details.
#
# + returns - A `DigiFactEstimationRequest` object containing the formatted details for the DigiFact estimation request.
#             Returns an error if the conversion process encounters any issues.
function toDigiFactEstimationRequest(ClaimSubmission claimSubmission) returns DigiFactEstimationRequest|error => {
    policyID: check int:fromString(claimSubmission.policyID),
    claimReference: claimSubmission.claimReference,
    customerReference: claimSubmission.customerReference,
    customerProfile: claimSubmission.customerProfile,
    lossDetails: claimSubmission.lossDetails
};