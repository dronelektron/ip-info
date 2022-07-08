void Menu_IpInfo(int client) {
    Menu menu = new Menu(MenuHandler_IpInfo);

    menu.SetTitle("IP info");

    Menu_AddIpInfoItems(menu);

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_IpInfo(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void Menu_AddIpInfoItems(Menu menu) {
    char item[ITEM_MAX_SIZE];
    char country[COUNTRY_MAX_SIZE];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i)) {
            continue;
        }

        Cache_GetCountry(i, country);

        if (StrEqual(country, COUNTRY_UNDEFINED)) {
            Format(item, sizeof(item), "%T", "Menu item no ip info", i, i);
        } else {
            Format(item, sizeof(item), "%T", "Menu item ip info", i, i, country);
        }

        menu.AddItem("", item, ITEMDRAW_DISABLED);
    }
}
