import ballerina/http;
import ballerina/log;
import ballerina/mime;

configurable string contractLookupApiEndpoint = ?;
configurable string estimationApiEndpoint = ?;
configurable string firedamageRepairApiEndpoint = ?;

http:Client contractLookUpAPI = check new (url = contractLookupApiEndpoint);
http:Client fireDamageRepairAPI = check new (url = firedamageRepairApiEndpoint);

# A service representing a network-accessible API
# bound to port `9090`.
service /claim on httpListener {

    resource function post submit(http:Request req) returns string|error {
        mime:Entity[] bodyParts = check req.getBodyParts();

        ClaimSubmission claimSubmission = {claimType: "", claimReference: "", policyID: "", customerContact: {email: "", phone: ""}, lossDetails: {dateOfLoss: "", typeOfLoss: "", estimatedLoss: "", attachments: ""}, customerProfile: {id: "", name: "", address: ""}, propertyDetails: {reference: "", address: "", 'type: "", location: {latitude: 0, longitude: 0}}, customerReference: "", dateSubmitted: ""};
        FileAttachment fileAttachment = {fileName: "", content: [], contentType: ""};

        foreach mime:Entity item in bodyParts {
            string contentType = item.getContentType();
            if contentType == mime:APPLICATION_JSON {
                json claimDataJson = check item.getJson();
                claimSubmission = check claimDataJson.cloneWithType(ClaimSubmission);
            } else if item.getContentDisposition().fileName != "" {
                // Handle the file part
                mime:ContentDisposition contentDisposition = item.getContentDisposition();
                fileAttachment.fileName = contentDisposition.fileName;
                fileAttachment.content = check item.getByteArray();
                fileAttachment.contentType = item.getContentType();
            }
        }

        log:printInfo("recieved claim submission with attachments",
                        claim = claimSubmission, fileName = fileAttachment.fileName, fileSize = fileAttachment.content.length());

        ContractLookupResponse contractLookupStatus = check contractLookup(claimSubmission);

        if contractLookupStatus.status != "Success" {
            return error("contract lookup failed - unable to find a contract");
        }

        EstimationResponse estimationResponse = check routeForEstimation(contractLookupStatus.routeTo, claimSubmission, fileAttachment);

        if (estimationResponse.status != "Estimate Generated") {
            return error("estimation workflow failed");
        }

        check routeToDamageRepair(claimSubmission);

        return "claim submitted successfully";
    }
}

function contractLookup(ClaimSubmission claim) returns ContractLookupResponse|error {
    log:printInfo("contract look up ", claim = claim);

    ContractLookupRequest contractLookupRequest = {
        claimReference: claim.claimReference,
        customerReference: claim.customerReference,
        policyID: check int:fromString(claim.policyID)
    };

    ContractLookupResponse contractLookUpStatus = check contractLookUpAPI->/lookup.post(contractLookupRequest);
    log:printInfo("contract lookup status", contractLookUpStatus = contractLookUpStatus);

    return contractLookUpStatus;
}

function routeForEstimation(string destination, ClaimSubmission claim, FileAttachment attachment) returns EstimationResponse|error {

    EstimationRequest digiFactEstimationRequest = {
        policyID: check int:fromString(claim.policyID),
        claimReference: claim.claimReference,
        customerReference: claim.customerReference,
        customerProfile: claim.customerProfile,
        lossDetails: claim.lossDetails
    };
    mime:Entity jsonPart = new;
    jsonPart.setBody(digiFactEstimationRequest.toJson());
    check jsonPart.setContentType(mime:APPLICATION_JSON);

    mime:ContentDisposition jsonContentDisposition = new;
    jsonContentDisposition.name = "claim";
    jsonContentDisposition.disposition = "form-data";
    jsonPart.setContentDisposition(jsonContentDisposition);

    mime:Entity filePart = new;
    filePart.setByteArray(attachment.content, attachment.contentType);
    check filePart.setContentType(attachment.contentType);

    mime:ContentDisposition fileContentDisposition = new;
    fileContentDisposition.name = "attachments";
    fileContentDisposition.disposition = "form-data";
    fileContentDisposition.fileName = attachment.fileName;
    filePart.setContentDisposition(fileContentDisposition);

    mime:Entity[] bodyParts = [jsonPart, filePart];

    // Send the multipart request
    http:Request request = new;
    request.setBodyParts(bodyParts, contentType = mime:MULTIPART_FORM_DATA);
    string estimationAPIEndpont = check findPartnerEndpoint(destination);
    http:Client esitmationAPI = check new (<string>estimationAPIEndpont);
    EstimationResponse digiFactEstimationResponse = check esitmationAPI->post("", request);
    return digiFactEstimationResponse;

}

function routeToDamageRepair(ClaimSubmission claim) returns error? {
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

    FireDamageRepairRequest fireDamageRepairRequest = toFireDamageRepairRequest(claim);

    FireDamageRepairResponse fireDamageRepairResponse = check fireDamageRepairAPI->/repair.post(fireDamageRepairRequest);
    log:printInfo("fire damage repair response", fireDamageRepairResponse = fireDamageRepairResponse);

    if fireDamageRepairResponse.status != "Service Scheduled" {
        return error("unable to schedule fire damage repair service");
    }
    return ();
}
