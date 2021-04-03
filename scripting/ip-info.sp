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

#define NO_ERROR_MESSAGE ""
#define NO_IP_INFO ""
#define NO_ITEM_INFO ""

#define TARGET_ALL 0

public Plugin myinfo = {
    name = "IP info",
    author = "Dron-elektron",
    description = "Displays info about IP address such as country and city",
    version = "0.4.0",
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
static char g_country[MAXPLAYERS + 1][BUFFER_MAX_SIZE];
static char g_city[MAXPLAYERS + 1][BUFFER_MAX_SIZE];
static Handle g_cacheFile[MAXPLAYERS + 1] = {null, ...};

static ConVar g_workingDirectory = null;

public void OnPluginStart() {
    g_workingDirectory = CreateConVar("sm_ipinfo_working_directory", "ipinfo", "Working directory of the plugin");

    RegConsoleCmd("sm_ipinfo", Command_IpInfo);
    LoadTranslations("common.phrases");
    LoadTranslations("ip-info.phrases");
    AutoExecConfig(true, "ip-info");
}

public void OnClientConnected(int client) {
    ClearIpInfoForMenu(client);

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

public Action Command_IpInfo(int client, int args) {
    if (args == 0) {
        CreateIpInfoMenu(client, TARGET_ALL);
    } else {
        char arg[BUFFER_MAX_SIZE];

        GetCmdArg(1, arg, sizeof(arg));

        int target = FindTarget(client, arg);

        if (target > 0) {
            CreateIpInfoMenu(client, target);
        }
    }

    return Plugin_Handled;
}

public int Handler_IpInfoMenu(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void CreateIpInfoMenu(int client, int target) {
    Menu menu = new Menu(Handler_IpInfoMenu);

    menu.SetTitle("IP info");

    AddIpInfoItemsToMenu(menu, target);

    menu.Display(client, 20);
}

void AddIpInfoItemsToMenu(Menu menu, int target) {
    char item[BUFFER_MAX_SIZE];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            continue;
        }

        if (target != TARGET_ALL && i != target) {
            continue;
        }

        if (StrEqual(g_country[i], NO_IP_INFO)) {
            Format(item, sizeof(item), "%T", "Menu item no ip info", i, i, "Undefined");
        } else {
            Format(item, sizeof(item), "%T", "Menu item ip info", i, i, g_country[i], g_city[i]);
        }

        menu.AddItem(NO_ITEM_INFO, item);
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

    g_cacheFile[client] = CreateCacheFile(client);

    FormatRequest(g_ip[client], requestUrl, sizeof(requestUrl));

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

    if (StrEqual(errorMessage, NO_ERROR_MESSAGE)) {
        char countryFieldName[BUFFER_MAX_SIZE];
        char cityFiledName[BUFFER_MAX_SIZE];
        char country[BUFFER_MAX_SIZE];
        char city[BUFFER_MAX_SIZE];

        GetJsonCountryFieldName(countryFieldName, sizeof(countryFieldName));
        GetJsonCityFieldName(cityFiledName, sizeof(cityFiledName));

        obj.GetString(countryFieldName, country, sizeof(country));
        obj.GetString(cityFiledName, city, sizeof(city));

        CPrintToChatAll("%s%t", PREFIX_COLORED, "Player connected", client, country, city);
        SaveIpInfoForMenu(client, country, city);
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

void ClearIpInfoForMenu(int client) {
    strcopy(g_country[client], BUFFER_MAX_SIZE, NO_IP_INFO);
    strcopy(g_city[client], BUFFER_MAX_SIZE, NO_IP_INFO);
}

void SaveIpInfoForMenu(int client, const char[] country, const char[] city) {
    strcopy(g_country[client], BUFFER_MAX_SIZE, country);
    strcopy(g_city[client], BUFFER_MAX_SIZE, city);
}

// TODO: Menu

// ==== Service ====

#define SERVICE_NAME "ipwhois.io"
#define REQUEST_TEMPLATE "http://ipwhois.app/json/%s?objects=%s,%s"

#define JSON_FIELD_COUNTRY "country"
#define JSON_FIELD_CITY "city"
#define JSON_FIELD_ERROR_MESSAGE "message"

void FormatRequest(const char[] ip, char[] request, int requestMaxSize) {
    Format(request, requestMaxSize, REQUEST_TEMPLATE, ip, JSON_FIELD_COUNTRY, JSON_FIELD_CITY);
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
    JSON_Object errorObj = obj.GetObject(JSON_FIELD_ERROR_MESSAGE);

    if (errorObj == null) {
        strcopy(errorMessage, errorMessageMaxSize, NO_ERROR_MESSAGE);
    } else {
        obj.GetString(JSON_FIELD_ERROR_MESSAGE, errorMessage, errorMessageMaxSize);
    }
}
