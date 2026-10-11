#include <amxmodx>
#include <amxmisc>

enum _:BanRecord { Subject[64], Expires, IsIP }
new Array:gBans, gFile[256];

public plugin_natives() {
    register_library("persistent_bans");
    register_native("persistent_ban_store", "store_native");
    register_native("persistent_ban_remove", "remove_native");
}
public plugin_init() {
    register_plugin("Persistent AMX Bans", "1.0.0", "csserver");
    gBans = ArrayCreate(BanRecord);
    get_datadir(gFile, charsmax(gFile)); add(gFile, charsmax(gFile), "/persistent_bans.txt");
    new file = fopen(gFile, "rt");
    if (file) {
        new line[128], subject[64], expires[32], ip[4], record[BanRecord];
        while (!feof(file)) {
            fgets(file, line, charsmax(line));
            if (parse(line, subject, charsmax(subject), expires, charsmax(expires), ip, charsmax(ip)) != 3) continue;
            copy(record[Subject], 63, subject); record[Expires] = str_to_num(expires); record[IsIP] = str_to_num(ip);
            if (record[Expires] && record[Expires] <= get_systime()) continue;
            ArrayPushArray(gBans, record);
        }
        fclose(file);
    }
}
public plugin_cfg() {
    // Run after server.cfg so stock ban files cannot overwrite the remaining duration.
    set_task(1.0, "restore_bans");
}
public restore_bans() {
    new record[BanRecord];
    for (new i = 0; i < ArraySize(gBans); i++) {
        ArrayGetArray(gBans, i, record);
        if (!record[Subject][0]) continue;
        if (record[Expires] && record[Expires] <= get_systime()) continue;
        new Float:minutes = record[Expires] ? float(record[Expires] - get_systime()) / 60.0 : 0.0;
        if (record[IsIP]) server_cmd("addip %.4f ^"%s^"", minutes, record[Subject]);
        else server_cmd("banid %.4f ^"%s^"", minutes, record[Subject]);
    }
    server_exec(); save_bans();
}
stock find_record(const subject[], bool:ip) {
    new record[BanRecord];
    for (new i = 0; i < ArraySize(gBans); i++) {
        ArrayGetArray(gBans, i, record);
        if (equal(record[Subject], subject) && bool:record[IsIP] == ip) return i;
    }
    return -1;
}
public store_native(plugin, params) {
    new subject[64], record[BanRecord]; get_string(1, subject, charsmax(subject));
    if (!subject[0] || contain(subject, "^"") != -1 || contain(subject, ";") != -1 || contain(subject, "^n") != -1) return 0;
    new minutes = get_param(2), bool:ip = bool:get_param(3);
    copy(record[Subject], 63, subject); record[IsIP] = _:ip;
    record[Expires] = minutes > 0 ? get_systime() + min(minutes, 1000000) * 60 : 0;
    new index = find_record(subject, ip);
    if (index < 0) ArrayPushArray(gBans, record); else ArraySetArray(gBans, index, record);
    return save_bans();
}
public remove_native(plugin, params) {
    new subject[64]; get_string(1, subject, charsmax(subject));
    new index = find_record(subject, bool:get_param(2));
    if (index >= 0) ArrayDeleteItem(gBans, index);
    return save_bans();
}
stock save_bans() {
    new tmp[260]; formatex(tmp, charsmax(tmp), "%s.tmp", gFile);
    new file = fopen(tmp, "wt");
    if (!file) { log_amx("Cannot write persistent ban file"); return 0; }
    new record[BanRecord];
    for (new i = 0; i < ArraySize(gBans); i++) {
        ArrayGetArray(gBans, i, record);
        if (record[Subject][0] && (!record[Expires] || record[Expires] > get_systime()))
            fprintf(file, "^"%s^" %d %d^n", record[Subject], record[Expires], record[IsIP]);
    }
    fclose(file);
    return rename_file(tmp, gFile, 1);
}
public plugin_end() { ArrayDestroy(gBans); }
