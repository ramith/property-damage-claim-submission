import ballerina/http;
import ballerina/log;
import ballerina/mime;

configurable string contractLookupApiEndpoint = ?;

http:Client contractLookUpAPI = check new (url = contractLookupApiEndpoint);

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

        // make sure that steps are processed in correct order. (don't depend on response to be in the correct order)
        ClaimProcessingStep[] sortedSteps = from var s in contractLookupStatus.route
            order by s.stepNumber ascending
            select s;

        foreach ClaimProcessingStep step in sortedSteps {
            log:printInfo("claim processing step", step = step);

            match step.stepName {
                "ReceiveClaim" => {
                    // Add your logic for the "ReceiveClaim" case here
                    EstimationResponse estimationResponse = check recieveClaim(step.associatedVendor, claimSubmission, fileAttachment);
                    if (estimationResponse.status != "Estimate Generated") {
                        return error("estimation workflow failed");
                    }
                }

                "DamageRepair" => {
                        check damageRepair(step.associatedVendor, claimSubmission);
                }
                _ => {
                    return error("unknown claim processing step");
                }
            }

        }

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

function recieveClaim(string destination, ClaimSubmission claim, FileAttachment attachment) returns EstimationResponse|error {

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
    http:Client esitmationAPI = check new (estimationAPIEndpont);
    EstimationResponse digiFactEstimationResponse = check esitmationAPI->post("", request);
    return digiFactEstimationResponse;

}



function damageRepair(string destination, ClaimSubmission claim) returns error? {
    // Send to fire department
    // Fire department API integration logic

    FireDamageRepairRequest fireDamageRepairRequest = toFireDamageRepairRequest(claim);

    string damageRepairAPI = check findPartnerEndpoint(destination);

    http:Client fireDamageRepairAPI = check new (damageRepairAPI);
    FireDamageRepairResponse fireDamageRepairResponse = check fireDamageRepairAPI->/.post(fireDamageRepairRequest);
    log:printInfo("fire damage repair response", fireDamageRepairResponse = fireDamageRepairResponse);

    if fireDamageRepairResponse.status != "Service Scheduled" {
        return error("unable to schedule fire damage repair service");
    }
    return ();
}
