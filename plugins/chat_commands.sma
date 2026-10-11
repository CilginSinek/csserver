#include <amxmodx>
#include <amxmisc>

public plugin_init() {
    register_plugin("Slash Admin Commands", "1.0.0", "csserver");
    register_clcmd("say", "route_chat");
    register_clcmd("say_team", "route_chat");
}

public route_chat(id) {
    new text[192], command[32], arg1[64], arg2[32], arg3[96];
    read_args(text, charsmax(text)); remove_quotes(text); trim(text);
    if (text[0] != '/') return PLUGIN_CONTINUE;
    parse(text, command, charsmax(command), arg1, charsmax(arg1), arg2, charsmax(arg2), arg3, charsmax(arg3));
    new shortCommand[32]; copy(shortCommand, charsmax(shortCommand), command[1]);

    if (equali(shortCommand, "map") || equali(shortCommand, "amx_map")) {
        if (!arg1[0]) { client_print(id, print_chat, "Kullanim: /map <harita>"); return PLUGIN_HANDLED; }
        if (map_is_blocked(arg1)) { client_print(id, print_chat, "Harita kullanima kapali; eksik WAD kaynaklarini maps_blocked.ini dosyasindan kontrol edin."); return PLUGIN_HANDLED; }
        if (!is_map_valid(arg1)) { client_print(id, print_chat, "Bilinmeyen harita: %s", arg1); return PLUGIN_HANDLED; }
        client_cmd(id, "amx_map ^"%s^"", arg1); return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "mapmenu") || equali(shortCommand, "haritamenu")) {
        client_cmd(id, "amx_mapmenu"); return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "kick")) {
        if (!arg1[0]) { client_print(id, print_chat, "Kullanim: /kick <oyuncu> [sebep]"); return PLUGIN_HANDLED; }
        client_cmd(id, "amx_kick ^"%s^" ^"%s^"", arg1, arg2); return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "ban")) {
        if (!arg1[0] || !arg2[0]) { client_print(id, print_chat, "Kullanim: /ban <oyuncu> <dakika> [sebep]"); return PLUGIN_HANDLED; }
        client_cmd(id, "amx_ban ^"%s^" ^"%s^" ^"%s^"", arg1, arg2, arg3); return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "slay") || equali(shortCommand, "slap") || equali(shortCommand, "noclip")) {
        if (!arg1[0]) { client_print(id, print_chat, "Oyuncu nicki gerekli."); return PLUGIN_HANDLED; }
        if (equali(shortCommand, "slay")) client_cmd(id, "amx_slay ^"%s^"", arg1);
        else if (equali(shortCommand, "slap")) client_cmd(id, "amx_slap ^"%s^" %d", arg1, arg2[0] ? str_to_num(arg2) : 0);
        else client_cmd(id, "amx_noclip ^"%s^"", arg1);
        return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "snow")) {
        if (!arg1[0]) { client_print(id, print_chat, "Kullanim: /snow <1|0>"); return PLUGIN_HANDLED; }
        client_cmd(id, "amx_snow %d", str_to_num(arg1)); return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "rev") || equali(shortCommand, "revive")) {
        client_cmd(id, "amx_rev ^"%s^"", arg1[0] ? arg1 : "@all");
        return PLUGIN_HANDLED;
    }
    if (equali(shortCommand, "parasut")) {
        if (!arg1[0]) client_cmd(id, "say /para");
        else if (arg2[0]) client_cmd(id, "amx_parasut ^"%s^" %d", arg1, str_to_num(arg2));
        else { client_print(id, print_chat, "Kullanim: /parasut [oyuncu] <0|1>"); return PLUGIN_HANDLED; }
        return PLUGIN_HANDLED;
    }
    // Allow /team, /mapmenu, /say, etc. to resolve to their AMXX amx_* command.
    // Explicit aliases above keep custom argument handling for common commands.
    if (containi(shortCommand, "amx_") == 0 || equali(shortCommand, "team")) {
        for (new i = 1; text[i]; i++) {
            if ((text[i] >= 'a' && text[i] <= 'z') || (text[i] >= 'A' && text[i] <= 'Z') ||
                (text[i] >= '0' && text[i] <= '9') || text[i] == '_' || text[i] == ' ' ||
                text[i] == '^"' || text[i] == '-' || text[i] == '.' || text[i] == ':') continue;
            client_print(id, print_chat, "Komutta desteklenmeyen karakter var.");
            return PLUGIN_HANDLED;
        }
        new routed[192], tail[160];
        if (containi(shortCommand, "amx_") == 0) {
            copy(routed, charsmax(routed), text[1]);
        } else {
            copy(tail, charsmax(tail), text[strlen(command)]);
            formatex(routed, charsmax(routed), "amx_team%s", tail);
        }
        client_cmd(id, "%s", routed);
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

stock map_is_blocked(const map[]) {
    new path[192], line[192], listed[64];
    get_configsdir(path, charsmax(path)); add(path, charsmax(path), "/maps_blocked.ini");
    new file = fopen(path, "rt");
    if (!file) return false;
    new found;
    while (!feof(file)) {
        fgets(file, line, charsmax(line)); trim(line);
        if (!line[0] || line[0] == ';') continue;
        parse(line, listed, charsmax(listed));
        if (equali(listed, map)) { found = 1; break; }
    }
    fclose(file);
    return found;
}
