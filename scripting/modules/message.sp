void Message_PlayerConnected(int client, const char[] country, const char[] ip) {
    PrintToChatAll(COLOR_DEFAULT ... "%t%t", PREFIX_COLORED, "Player connected", client, country);
    LogMessage("\"%L\" connected from '%s' (%s)", client, country, ip);
}

void Message_CountryUndefined(int client, const char[] reason) {
    PrintToChatAll(COLOR_DEFAULT ... "%t%t", PREFIX_COLORED, "Country undefined", client, reason);
    LogMessage("Failed to determine country for player \"%L\" (%s)", client, reason);
}
