#include <sourcemod>
#include <cURL>
#include <morecolors>
#include <json>

#define PREFIX_COLORED "{orange}[IP info] "

#define TEMPLATE_REQUEST "http://api.ipapi.com/api/%s?access_key=%s"

#define FIELD_COUNTRY_NAME "country_name"
#define FIELD_CITY_NAME "city"
#define FIELD_ERROR "error"
#define FIELD_ERROR_CODE "code"
#define FIELD_ERROR_INFO "info"

#define CACHE_EXT ".txt"

#define IP_MAX_LENGTH 24
#define REQUEST_MAX_LENGTH 256
#define API_KEY_MAX_LENGTH 33
#define BUFFER_MAX_SIZE 1024

public Plugin myinfo = {
    name = "IP info",
    author = "Dron-elektron",
    description = "Displays info about IP address such as country and city",
    version = "0.2.0",
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
static ConVar g_cacheDirectory = null;
static ConVar g_apiKey = null;

public void OnPluginStart() {
    g_workingDirectory = CreateConVar("sm_ipinfo_working_directory", "ipinfo", "Working directory of the plugin");
    g_cacheDirectory = CreateConVar("sm_ipinfo_cache_directory", "cache", "Cache directory for country and city");
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

    Format(requestUrl, sizeof(requestUrl), TEMPLATE_REQUEST, g_ip[client], apiKey);

    curl_easy_setopt_int_array(curl, g_curlOption, sizeof(g_curlOption));
    curl_easy_setopt_handle(curl, CURLOPT_WRITEDATA, g_cacheFile[client]);
    curl_easy_setopt_string(curl, CURLOPT_URL, requestUrl);
    curl_easy_perform_thread(curl, OnComplete, client);
}

void OnComplete(Handle curl, CURLcode code, int client) {
    CloseHandle(curl);
    CloseHandle(g_cacheFile[client]);

    if (code != CURLE_OK) {
        int errorCode = view_as<int>(code);
        char errorMessage[BUFFER_MAX_SIZE];

        curl_easy_strerror(code, errorMessage, sizeof(errorMessage));

        DisplayError(client, errorCode, errorMessage);
    } else {
        DisplayIpInfo(client);
    }
}

void DisplayError(int client, int code, const char[] message) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    LogError("Data was not received for player \"%L\" (%s): [code: %d] %s", client, g_ip[client], code, message);
    CPrintToChatAll("%s%t", PREFIX_COLORED, "Data was not received", client);
    GetCachePath(client, cacheFilePath, sizeof(cacheFilePath));
    DeleteFile(cacheFilePath);
}

void DisplayIpInfo(int client) {
    char ipInfo[BUFFER_MAX_SIZE];

    ReadStringFromCache(client, ipInfo, sizeof(ipInfo));

    JSON_Object obj = json_decode(ipInfo);
    JSON_Object errorObj = obj.GetObject(FIELD_ERROR);

    if (errorObj != null) {
        int errorCode = errorObj.GetInt(FIELD_ERROR_CODE);
        char errorInfo[BUFFER_MAX_SIZE];

        errorObj.GetString(FIELD_ERROR_INFO, errorInfo, sizeof(errorInfo));

        DisplayError(client, errorCode, errorInfo);
    } else {
        char countryName[BUFFER_MAX_SIZE];
        char cityName[BUFFER_MAX_SIZE];

        obj.GetString(FIELD_COUNTRY_NAME, countryName, sizeof(countryName));
        obj.GetString(FIELD_CITY_NAME, cityName, sizeof(cityName));

        CPrintToChatAll("%s%t", PREFIX_COLORED, "Player connected", client, countryName, cityName);
        LogMessage("Player \"%L\" connected from %s, %s (%s)", client, countryName, cityName, g_ip[client]);
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
    g_cacheDirectory.GetString(cacheDir, sizeof(cacheDir));

    Format(path, maxPathLength, "%s/%s/%s%s", workDir, cacheDir, g_ip[client], CACHE_EXT);
}

bool IsCacheAvailable(int client) {
    char cacheFilePath[PLATFORM_MAX_PATH];

    GetCachePath(client, cacheFilePath, sizeof(cacheFilePath));

    return FileExists(cacheFilePath);
}
