#include <sourcemod>
#include <geoip>

#include "morecolors"

#pragma semicolon 1
#pragma newdecls required

#include "ii/cache"
#include "ii/menu"
#include "ii/message"

#include "modules/cache.sp"
#include "modules/console-command.sp"
#include "modules/menu.sp"
#include "modules/message.sp"
#include "modules/use-case.sp"

public Plugin myinfo = {
    name = "IP info",
    author = "Dron-elektron",
    description = "Displays info about IP address such as country",
    version = "1.0.3",
    url = "https://github.com/dronelektron/ip-info"
};

public void OnPluginStart() {
    Command_Create();
    LoadTranslations("ip-info.phrases");
}

public void OnClientConnected(int client) {
    UseCase_PrintIpInfo(client);
}
