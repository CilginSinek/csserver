#include <amxmodx>
#include <amxmisc>

#define ACCESS_SETTINGS ADMIN_LEVEL_C

new gRedbull, gHook, gSnow, gParachute, gJailMenus;

public plugin_init() {
    register_plugin("Admin Feature Settings", "1.0.0", "csserver");
    register_clcmd("say /ayarlar", "cmd_settings");
    register_clcmd("say_team /ayarlar", "cmd_settings");
    register_clcmd("amx_adminsettings", "cmd_settings");
    gRedbull = get_cvar_pointer("sv_redbull");
    gHook = get_cvar_pointer("sv_hook_enabled");
    gSnow = get_cvar_pointer("sv_snow_enabled");
    gParachute = get_cvar_pointer("sv_parachute_enabled");
    gJailMenus = get_cvar_pointer("jb_menus_enabled");
}

public cmd_settings(id) {
    if (!(get_user_flags(id) & ACCESS_SETTINGS)) {
        client_print(id, print_chat, "[Ayarlar] Bu menu yalniz yoneticiye aciktir.");
        return PLUGIN_HANDLED;
    }
    show_settings(id);
    return PLUGIN_HANDLED;
}

stock show_settings(id) {
    new menu = menu_create("Sunucu Ozellikleri", "settings_select");
    new item[64];
    new status[16];
    get_status(gRedbull, status, charsmax(status)); formatex(item, charsmax(item), "RedBull: %s", status); menu_additem(menu, item, "1");
    get_status(gHook, status, charsmax(status)); formatex(item, charsmax(item), "Hook: %s", status); menu_additem(menu, item, "2");
    get_status(gSnow, status, charsmax(status)); formatex(item, charsmax(item), "Kar etkinligi: %s", status); menu_additem(menu, item, "3");
    get_status(gParachute, status, charsmax(status)); formatex(item, charsmax(item), "Parasut: %s", status); menu_additem(menu, item, "4");
    get_status(gJailMenus, status, charsmax(status)); formatex(item, charsmax(item), "Jailbreak menuleri: %s", status); menu_additem(menu, item, "5");
    menu_setprop(menu, MPROP_EXITNAME, "Kapat");
    menu_display(id, menu);
}

stock get_status(cvar, output[], length) {
    if (!cvar) copy(output, length, "Yuklenmedi");
    else copy(output, length, get_pcvar_num(cvar) ? "Acik" : "Kapali");
}

public settings_select(id, menu, item) {
    if (item < 0) { menu_destroy(menu); return PLUGIN_HANDLED; }
    if (!(get_user_flags(id) & ACCESS_SETTINGS)) { menu_destroy(menu); return PLUGIN_HANDLED; }

    new cvar, key = item + 1;
    switch (key) {
        case 1: cvar = gRedbull;
        case 2: cvar = gHook;
        case 3: {
            new enabled;
            if (_:gSnow != 0) enabled = !get_pcvar_num(gSnow);
            client_cmd(id, "amx_snow %d", enabled);
            menu_destroy(menu);
            set_task(0.2, "reopen_settings", id);
            return PLUGIN_HANDLED;
        }
        case 4: cvar = gParachute;
        case 5: cvar = gJailMenus;
    }
    if (cvar) {
        new enabled = !get_pcvar_num(cvar);
        set_pcvar_num(cvar, enabled);
        client_print(id, print_chat, "[Ayarlar] Ozellik %s.", enabled ? "acildi" : "kapatildi");
    } else {
        client_print(id, print_chat, "[Ayarlar] Eklenti/cvar henuz yuklu degil.");
    }
    menu_destroy(menu);
    show_settings(id);
    return PLUGIN_HANDLED;
}

public reopen_settings(id) {
    if (is_user_connected(id) && (get_user_flags(id) & ACCESS_SETTINGS)) show_settings(id);
}
