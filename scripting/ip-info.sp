#include <sourcemod>
#include <geoip>

#include "ip-info/cache"
#include "ip-info/menu"
#include "ip-info/message"

#include "modules/cache.sp"
#include "modules/console-command.sp"
#include "modules/menu.sp"
#include "modules/message.sp"
#include "modules/use-case.sp"

public Plugin myinfo = {
    name = "IP info",
    author = "Dron-elektron",
    description = "Displays info about IP address such as country",
    version = "1.0.4",
    url = "https://github.com/dronelektron/ip-info"
};

public void OnPluginStart() {
    Command_Create();
    LoadTranslations("ip-info.phrases");
}

public void OnClientPostAdminCheck(int client) {
    UseCase_PrintIpInfo(client);
}
