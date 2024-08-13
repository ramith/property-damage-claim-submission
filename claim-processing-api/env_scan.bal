import ballerina/os;

const string PARTNER_ = "PARTNER_";
map<string> partnerEnvs = scanEnvForEndpoints();

function scanEnvForEndpoints() returns map<string> {
    map<string> envs = os:listEnv();    
    map<string> filtered = map from [string, string] [key, value] in envs.entries()
                        where key.startsWith(PARTNER_)
                        select [key, value];

    return filtered;
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
