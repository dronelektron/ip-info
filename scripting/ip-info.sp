#include <sourcemod>
#include <cURL>
#include <morecolors>
#include <json>

#define PREFIX_COLORED "{orange}[IP info] "

#define CACHE_EXT ".txt"
#define IP_MAX_LENGTH 32
#define REQUEST_MAX_LENGTH 256
#define API_KEY_MAX_LENGTH 64
#define BUFFER_MAX_SIZE 1024

public Plugin myinfo = {
    name = "IP info",
    author = "Dron-elektron",
    description = "Displays info about IP address such as country and city",
    version = "0.3.0",
    url = ""
}

static int g_curlOption[][2] = {
    {_:CURLOPT_NOSIGNAL, 1},
    {_:CURLOPT_NOPROGRESS, 1},
    {_:CURLOPT_TIMEOUT, 30},
    {_:CURLOPT_CONNECTTIMEOUT, 60},
    {_:CURLOPT_VERBOSE, 0}
}

static char g_ip[MAXPLAYERS + 1][IP_MAX_LENGTH];
static Handle g_cacheFile[MAXPLAYERS + 1] = {null, ...};

static ConVar g_workingDirectory = null;
static ConVar g_apiKey = null;

public void OnPluginStart() {
    g_workingDirectory = CreateConVar("sm_ipinfo_working_directory", "ipinfo", "Working directory of the plugin");
    g_apiKey = CreateConVar("sm_ipinfo_api_key", "", "API key for the service");

    LoadTranslations("ip-info.phrases");
    AutoExecConfig(true, "ip-info");
}

public void OnClientConnected(int client) {
    if (IsFakeClient(client)) {
        return;
    }

    GetIp(client);

    if (IsCacheAvailable(client)) {
        LogMessage("Cache is found for player \"%L\" (%s)", client, g_ip[client]);
        DisplayIpInfo(client);
    } else {
        LogMessage("Cache is not found for player \"%L\" (%s)", client, g_ip[client]);
        GetIpInfo(client);
    }
}

void GetIp(int client) {
    char ip[IP_MAX_LENGTH];

    GetClientIP(client, ip, sizeof(ip));
    strcopy(g_ip[client], IP_MAX_LENGTH, ip);
}

Handle CreateCacheFile(int client) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, cacheFilePath, sizeof(cacheFilePath));

    return curl_OpenFile(cacheFilePath, "w");
}

void GetIpInfo(int client) {
    Handle curl = curl_easy_init();
    char requestUrl[REQUEST_MAX_LENGTH];
    char apiKey[API_KEY_MAX_LENGTH];

    g_apiKey.GetString(apiKey, sizeof(apiKey));
    g_cacheFile[client] = CreateCacheFile(client);

    FormatRequest(g_ip[client], apiKey, requestUrl, sizeof(requestUrl));

    curl_easy_setopt_int_array(curl, g_curlOption, sizeof(g_curlOption));
    curl_easy_setopt_handle(curl, CURLOPT_WRITEDATA, g_cacheFile[client]);
    curl_easy_setopt_string(curl, CURLOPT_URL, requestUrl);
    curl_easy_perform_thread(curl, OnComplete, client);
}

void OnComplete(Handle curl, CURLcode code, int client) {
    CloseHandle(curl);
    CloseHandle(g_cacheFile[client]);

    if (code != CURLE_OK) {
        char errorMessage[BUFFER_MAX_SIZE];

        curl_easy_strerror(code, errorMessage, sizeof(errorMessage));

        DisplayError(client, errorMessage);
    } else {
        DisplayIpInfo(client);
    }
}

void DisplayError(int client, const char[] message) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    LogError("Data was not received for player \"%L\" (%s): %s", client, g_ip[client], message);
    CPrintToChatAll("%s%t", PREFIX_COLORED, "Data was not received", client);
    GetCachePath(client, cacheFilePath, sizeof(cacheFilePath));
    DeleteFile(cacheFilePath);
}

void DisplayIpInfo(int client) {
    char ipInfo[BUFFER_MAX_SIZE];
    char errorMessage[BUFFER_MAX_SIZE];

    ReadStringFromCache(client, ipInfo, sizeof(ipInfo));

    JSON_Object obj = json_decode(ipInfo);

    GetErrorMessage(obj, errorMessage, sizeof(errorMessage));

    if (StrEqual(errorMessage, "")) {
        char countryFieldName[BUFFER_MAX_SIZE];
        char cityFiledName[BUFFER_MAX_SIZE];
        char country[BUFFER_MAX_SIZE];
        char city[BUFFER_MAX_SIZE];

        GetJsonCountryFieldName(countryFieldName, sizeof(countryFieldName));
        GetJsonCityFieldName(cityFiledName, sizeof(cityFiledName));

        obj.GetString(countryFieldName, country, sizeof(country));
        obj.GetString(cityFiledName, city, sizeof(city));

        CPrintToChatAll("%s%t", PREFIX_COLORED, "Player connected", client, country, city);
        LogMessage("Player \"%L\" connected from %s, %s (%s)", client, country, city, g_ip[client]);
    } else {
        DisplayError(client, errorMessage);
    }

    json_cleanup_and_delete(obj);
}

void ReadStringFromCache(int client, char[] buffer, int maxBufferSize) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, cacheFilePath, sizeof(cacheFilePath));

    File cacheFile = OpenFile(cacheFilePath, "r");

    cacheFile.ReadString(buffer, maxBufferSize, -1);
    CloseHandle(cacheFile);
}

void GetCachePath(int client, char[] path, int maxPathLength) {
    char workDir[PLATFORM_MAX_PATH];
    char cacheDir[PLATFORM_MAX_PATH];

    g_workingDirectory.GetString(workDir, sizeof(workDir));

    GetCacheDirectoryName(cacheDir, sizeof(cacheDir));
    Format(path, maxPathLength, "%s/%s/%s%s", workDir, cacheDir, g_ip[client], CACHE_EXT);
}

bool IsCacheAvailable(int client) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, cacheFilePath, sizeof(cacheFilePath));

    return FileExists(cacheFilePath);
}

// ==== Service ====

#define SERVICE_NAME "ipapi.com"
#define REQUEST_TEMPLATE "http://api.ipapi.com/api/%s?access_key=%s&fields=%s,%s"

#define JSON_FIELD_COUNTRY "country_name"
#define JSON_FIELD_CITY "city"
#define JSON_FIELD_ERROR "error"
#define JSON_FIELD_ERROR_INFO "info"

void FormatRequest(const char[] ip, const char[] apiKey, char[] request, int requestMaxSize) {
    Format(request, requestMaxSize, REQUEST_TEMPLATE, ip, apiKey, JSON_FIELD_COUNTRY, JSON_FIELD_CITY);
}

void GetCacheDirectoryName(char[] cacheDirectoryName, int cacheDirectoryNameMaxSize) {
    strcopy(cacheDirectoryName, cacheDirectoryNameMaxSize, SERVICE_NAME);
}

void GetJsonCountryFieldName(char[] country, int countryMaxSize) {
    strcopy(country, countryMaxSize, JSON_FIELD_COUNTRY);
}

void GetJsonCityFieldName(char[] city, int cityMaxSize) {
    strcopy(city, cityMaxSize, JSON_FIELD_CITY);
}

void GetErrorMessage(JSON_Object obj, char[] errorMessage, int errorMessageMaxSize) {
    JSON_Object errorObj = obj.GetObject(JSON_FIELD_ERROR);

    if (errorObj == null) {
        strcopy(errorMessage, errorMessageMaxSize, "");
    } else {
        errorObj.GetString(JSON_FIELD_ERROR_INFO, errorMessage, errorMessageMaxSize);
    }
}
