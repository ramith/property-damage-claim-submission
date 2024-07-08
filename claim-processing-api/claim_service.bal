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
        FileAttachment? fileAttachment = ();

        foreach mime:Entity item in bodyParts {
            string contentType = item.getContentType();
            mime:ContentDisposition contentDisposition = item.getContentDisposition();
            log:printInfo("processing content type", contentType = contentType, contentDisposition = contentDisposition.disposition,
                                                                fileName = contentDisposition.fileName, name = contentDisposition.name);

            if contentType == mime:APPLICATION_JSON {
                log:printInfo("found claim submission json");
                json claimDataJson = check item.getJson();
                claimSubmission = check claimDataJson.cloneWithType(ClaimSubmission);
            } else if item.getContentDisposition().fileName != "" {
                // Handle the file part

                fileAttachment = {
                    fileName: contentDisposition.fileName,
                    content: check item.getByteArray(),
                    contentType: contentType
                };
            } else {
                log:printWarn("unknown content type", contentType = contentType);

                string|error content = item.getText();
                if content is string {
                    log:printWarn("unknown content in text form", content = content);
                } else {
                    log:printError("unable to parse the content as a text", content);
                    return error("unable to parse the content as a text");
                }
            }
        }

        if (fileAttachment is ()) {
            log:printWarn("no attachments found in the claim submission");
        } else {
            log:printInfo("recieved claim submission with attachments",
                            claim = claimSubmission, fileName = fileAttachment.fileName, fileSize = fileAttachment.content.length());
        }

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
                    EstimationResponse|error estimationResponse = recieveClaim(step.associatedVendor, claimSubmission, fileAttachment);
                    if estimationResponse is error {
                        log:printError("workflow step - estimation failed", estimationResponse);
                        return estimationResponse;
                    }

                    if (estimationResponse.status != "Estimate Generated") {
                        return error("estimation workflow failed - unexpected status");
                    }
                }

                "DamageRepair" => {
                    error? outcome = damageRepair(step.associatedVendor, claimSubmission);
                    if outcome is error {
                        log:printError("workflow step - damage repair failed", outcome);
                        return outcome;
                    }

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

    ContractLookupRequest contractLookupRequest = {
        claimReference: claim.claimReference,
        customerReference: claim.customerReference,
        policyID: check int:fromString(claim.policyID)
    };

    ContractLookupResponse contractLookUpStatus = check contractLookUpAPI->/lookup.post(contractLookupRequest);
    log:printInfo("contract lookup status", contractLookUpStatus = contractLookUpStatus);

    return contractLookUpStatus;
}

function recieveClaim(string destination, ClaimSubmission claim, FileAttachment? attachment) returns EstimationResponse|error {

    mime:Entity[] bodyParts = [];

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

    bodyParts.push(jsonPart);

    if !(attachment is ()) {
        mime:Entity filePart = new;
        filePart.setByteArray(attachment.content, attachment.contentType);
        check filePart.setContentType(attachment.contentType);

        mime:ContentDisposition fileContentDisposition = new;
        fileContentDisposition.name = "attachments";
        fileContentDisposition.disposition = "form-data";
        fileContentDisposition.fileName = attachment.fileName;
        filePart.setContentDisposition(fileContentDisposition);
        bodyParts.push(filePart);
    } else {
        log:printWarn("no attachments found, not sending attachments to the estimation API");
    }

    // Send the multipart request
    http:Request request = new;
    request.setBodyParts(bodyParts, contentType = mime:MULTIPART_FORM_DATA);
    string estimationAPIEndpont = check findPartnerEndpoint(destination);
    log:printInfo("sending claim to estimation API", endpoint = estimationAPIEndpont, claim = digiFactEstimationRequest);
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
    FireDamageRepairResponse|error fireDamageRepairResponse = fireDamageRepairAPI->post("", fireDamageRepairRequest);
    if fireDamageRepairResponse is error {
        log:printError("error while calling fire damage repair service", fireDamageRepairResponse);
    } else {
        log:printInfo("fire damage repair response", fireDamageRepairResponse = fireDamageRepairResponse);

        if fireDamageRepairResponse.status != "Service Scheduled" {
            return error("unable to schedule fire damage repair service");
        }
    }

    return ();
}
