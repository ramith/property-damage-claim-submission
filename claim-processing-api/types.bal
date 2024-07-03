
import ballerina/http;

listener http:Listener httpListener =  check new http:Listener(9090);


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
    ClaimProcessingStep[] route;
};

type ClaimProcessingStep record {
    int stepNumber;
    string stepName;
    string associatedVendor;
    string vendorEndpoint;
};

type EstimationRequest record {
    int policyID;
    string claimReference;
    string customerReference;
    CustomerProfile customerProfile;
    LossDetails lossDetails;
};

type EstimationResponse record {
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

type FileAttachment record {
    string fileName;
    byte[] content;
    string contentType;
};

# Converts a claim submission into a fire damage repair request.
#
# This function takes a claim submission as input and converts it into a format 
# suitable for a fire damage repair request. The resulting object will contain 
# all necessary details required by the repair service provider.
#
# + claimSubmission - The claim submission details including claim reference, customer reference,
# customer profile, policy ID, and loss details.
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
# customer profile, policy ID, and loss details.
#
# + returns - A `EstimationRequest` object containing the formatted details for the DigiFact estimation request.
# Returns an error if the conversion process encounters any issues.
function toDigiFactEstimationRequest(ClaimSubmission claimSubmission) returns EstimationRequest|error => {
    policyID: check int:fromString(claimSubmission.policyID),
    claimReference: claimSubmission.claimReference,
    customerReference: claimSubmission.customerReference,
    customerProfile: claimSubmission.customerProfile,
    lossDetails: claimSubmission.lossDetails
};
