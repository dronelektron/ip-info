#include <sourcemod>
#include <cURL>
#include <morecolors>

#define PREFIX_COLORED "{orange}[IP info] {default}"

#define TEMPLATE_IP_COUNTRY "https://ipapi.co/%s/country_name"
#define TEMPLATE_IP_CITY "https://ipapi.co/%s/city"

#define SUFFIX_COUNTRY "_country"
#define SUFFIX_CITY "_city"

#define CACHE_EXT ".txt"

#define IP_MAX_LENGTH 24
#define REQUEST_MAX_LENGTH 256
#define BUFFER_MAX_SIZE 1024

public Plugin myinfo = {
    name = "IP info",
    author = "Dron-elektron",
    description = "Displays info about IP address such as country and city",
    version = "0.1.1",
    url = ""
}

enum IpState {
    IpState_Country,
    IpState_City
}

static int g_curlOption[][2] = {
    {_:CURLOPT_NOSIGNAL, 1},
    {_:CURLOPT_NOPROGRESS, 1},
    {_:CURLOPT_TIMEOUT, 30},
    {_:CURLOPT_CONNECTTIMEOUT, 60},
    {_:CURLOPT_VERBOSE, 0}
}

static char g_ip[MAXPLAYERS + 1][IP_MAX_LENGTH];
static Handle g_countryFile[MAXPLAYERS + 1] = {null, ...};
static Handle g_cityFile[MAXPLAYERS + 1] = {null, ...};
static IpState g_state[MAXPLAYERS + 1];

static ConVar g_workingDirectory = null;
static ConVar g_certificateName = null;
static ConVar g_cacheDirectory = null;

public void OnPluginStart() {
    g_workingDirectory = CreateConVar("sm_ipinfo_working_directory", "ipinfo", "Working directory of the plugin");
    g_certificateName = CreateConVar("sm_ipinfo_certificate_name", "cacert.pem", "Name of the SSL certificate");
    g_cacheDirectory = CreateConVar("sm_ipinfo_cache_directory", "cache", "Cache directory for country and city");

    LoadTranslations("ip-info.phrases");
}

public void OnClientConnected(int client) {
    if (IsFakeClient(client)) {
        return;
    }

    GetIp(client);

    if (IsCacheAvailable(client)) {
        LogMessage("Cache is found for the player \"%L\" (%s)", client, g_ip[client]);
        DisplayIpInfo(client);
    } else {
        LogMessage("Cache is not found for the player \"%L\" (%s)", client, g_ip[client]);
        GetCountry(client);
    }
}

void GetIp(int client) {
    char ip[IP_MAX_LENGTH];

    GetClientIP(client, ip, sizeof(ip));
    strcopy(g_ip[client], IP_MAX_LENGTH, ip);
}

Handle CreateTempFile(int client, const char[] suffix) {
    char tempFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, suffix, tempFilePath, sizeof(tempFilePath));

    return curl_OpenFile(tempFilePath, "w");
}

void GetCountry(int client) {
    g_state[client] = IpState_Country;
    g_countryFile[client] = CreateTempFile(client, SUFFIX_COUNTRY);

    GetInfo(client, TEMPLATE_IP_COUNTRY);
}

void GetCity(int client) {
    g_state[client] = IpState_City;
    g_cityFile[client] = CreateTempFile(client, SUFFIX_CITY);

    GetInfo(client, TEMPLATE_IP_CITY);
}

void GetInfo(int client, const char[] template) {
    Handle curl = curl_easy_init();
    char certificatePath[PLATFORM_MAX_PATH];
    char requestUrl[REQUEST_MAX_LENGTH];

    GetCertPath(certificatePath, sizeof(certificatePath));
    Format(requestUrl, sizeof(requestUrl), template, g_ip[client]);
    SetDefaultOpt(curl);

    if (StrEqual(template, TEMPLATE_IP_COUNTRY)) {
        curl_easy_setopt_handle(curl, CURLOPT_WRITEDATA, g_countryFile[client]);
    } else {
        curl_easy_setopt_handle(curl, CURLOPT_WRITEDATA, g_cityFile[client]);
    }

    curl_easy_setopt_string(curl, CURLOPT_CAINFO, certificatePath);
    curl_easy_setopt_string(curl, CURLOPT_URL, requestUrl);
    curl_easy_perform_thread(curl, OnComplete, client);
}

void SetDefaultOpt(Handle curl) {
    curl_easy_setopt_int_array(curl, g_curlOption, sizeof(g_curlOption));
}

void OnComplete(Handle curl, CURLcode code, int client) {
    CloseHandle(curl);

    switch (g_state[client]) {
        case IpState_Country: {
            CloseHandle(g_countryFile[client]);

            if (code != CURLE_OK) {
                char errorMsg[BUFFER_MAX_SIZE];
                char countryFilePath[PLATFORM_MAX_PATH];

                curl_easy_strerror(code, errorMsg, sizeof(errorMsg));

                LogError("Country name is not received for the player \"%L\" (%s): [code: %d] %s", client, g_ip[client], code, errorMsg);
                CPrintToChatAll("%s%t", PREFIX_COLORED, "Country name is not received", client);
                GetCachePath(client, SUFFIX_COUNTRY, countryFilePath, sizeof(countryFilePath));
                DeleteFile(countryFilePath);
            } else {
                LogMessage("Country name is received for the player \"%L\" (%s)", client, g_ip[client]);
                GetCity(client);
            }
        }

        case IpState_City: {
            CloseHandle(g_cityFile[client]);

            if (code != CURLE_OK) {
                char errorMsg[BUFFER_MAX_SIZE];
                char cityFilePath[PLATFORM_MAX_PATH];

                curl_easy_strerror(code, errorMsg, sizeof(errorMsg));

                LogError("City name is not received for the player \"%L\" (%s): [code: %d] %s", client, g_ip[client], code, errorMsg);
                CPrintToChatAll("%s%t", PREFIX_COLORED, "City name is not received", client);
                GetCachePath(client, SUFFIX_CITY, cityFilePath, sizeof(cityFilePath));
                DeleteFile(cityFilePath);
            } else {
                LogMessage("City name is received for the player \"%L\" (%s)", client, g_ip[client]);
                DisplayIpInfo(client);
            }
        }
    }
}

void DisplayIpInfo(int client) {
    char countryName[BUFFER_MAX_SIZE];
    char cityName[BUFFER_MAX_SIZE];

    ReadStringFromCache(client, SUFFIX_COUNTRY, countryName, sizeof(countryName));
    ReadStringFromCache(client, SUFFIX_CITY, cityName, sizeof(cityName));

    CPrintToChatAll("%s%t", PREFIX_COLORED, "Player connected", client, countryName, cityName);
    LogMessage("Player \"%L\" connected from %s, %s (%s)", client, countryName, cityName, g_ip[client]);
}

void ReadStringFromCache(int client, const char[] suffix, char[] buffer, int maxBufferSize) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, suffix, cacheFilePath, sizeof(cacheFilePath));

    File cacheFile = OpenFile(cacheFilePath, "r");

    cacheFile.ReadString(buffer, maxBufferSize, -1);
    CloseHandle(cacheFile);
}

void GetCertPath(char[] path, int maxPathLength) {
    char workDir[PLATFORM_MAX_PATH];
    char certName[PLATFORM_MAX_PATH];

    g_workingDirectory.GetString(workDir, sizeof(workDir));
    g_certificateName.GetString(certName, sizeof(certName));

    Format(path, maxPathLength, "%s/%s", workDir, certName);
}

void GetCachePath(int client, const char[] suffix, char[] path, int maxPathLength) {
    char workDir[PLATFORM_MAX_PATH];
    char cacheDir[PLATFORM_MAX_PATH];

    g_workingDirectory.GetString(workDir, sizeof(workDir));
    g_cacheDirectory.GetString(cacheDir, sizeof(cacheDir));

    Format(path, maxPathLength, "%s/%s/%s%s%s", workDir, cacheDir, g_ip[client], suffix, CACHE_EXT);
}

bool IsCacheAvailable(int client) {
    char countryNameFilePath[PLATFORM_MAX_PATH];
    char cityNameFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, SUFFIX_COUNTRY, countryNameFilePath, sizeof(countryNameFilePath));
    GetCachePath(client, SUFFIX_CITY, cityNameFilePath, sizeof(cityNameFilePath));

    return FileExists(countryNameFilePath) && FileExists(cityNameFilePath);
}
