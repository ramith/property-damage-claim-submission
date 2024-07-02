import ballerina/log;
import ballerina/os;

const string PARTNER_ = "PARTNER_";
map<string> partnerEnvs = scanEnvForEndpoints();

function scanEnvForEndpoints() returns map<string> {
    map<string> envs = os:listEnv();
    map<string> result = envs.filter(function(string key) returns boolean {

        if (key.startsWith(PARTNER_)) {
            log:printInfo("Partner Endpoint", key = key, value = envs[key]);
            return true;
        }
        return false;
    });
    return result;
}

function findPartnerEndpoint(string partnerName) returns string|error {
    string endpointKey = PARTNER_ + partnerName.trim().toUpperAscii();
    string? ep = partnerEnvs[endpointKey];
    if ep is () {
        return error("partner endpoint not found for " + partnerName);
    } else {
        return ep;
    }
}
