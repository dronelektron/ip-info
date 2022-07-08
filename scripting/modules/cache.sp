static char g_countries[MAXPLAYERS + 1][COUNTRY_MAX_SIZE];

void Cache_GetCountry(int client, char[] country) {
    strcopy(country, COUNTRY_MAX_SIZE, g_countries[client]);
}

void Cache_SetCountry(int client, const char[] country) {
    strcopy(g_countries[client], COUNTRY_MAX_SIZE, country);
}
