void Command_Create() {
    RegConsoleCmd("sm_ipinfo", Command_IpInfo);
}

public Action Command_IpInfo(int client, int args) {
    Menu_IpInfo(client);

    return Plugin_Handled;
}
