void UseCase_PrintIpInfo(int client) {
    Cache_SetCountry(client, COUNTRY_UNDEFINED);

    if (IsFakeClient(client)) {
        Message_CountryUndefined(client, BOT);

        return;
    }

    char ip[IP_MAX_SIZE];

    GetClientIP(client, ip, IP_MAX_SIZE);

    if (StrContains(ip, "192.168") == 0) {
        Message_CountryUndefined(client, LOCAL_IP);

        return;
    }

    char country[COUNTRY_MAX_SIZE];

    if (GeoipCountry(ip, country, COUNTRY_MAX_SIZE)) {
        Cache_SetCountry(client, country);
        Message_PlayerConnected(client, country, ip);
    } else {
        Message_CountryUndefined(client, UNKNOWN_REASON);
    }
}
