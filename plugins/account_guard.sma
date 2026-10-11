#include <amxmodx>
#include <amxmisc>
#include <sockets>
#include <reapi>

#define MAX_CLIENTS 32
#define MANAGE_ACCESS ADMIN_RCON

enum { Q_NONE, Q_AUTH, Q_MANAGE }
new gSocket[33], gKind[33], gSent[33], gLength[33];
new gRequest[33][768], gResponse[33][128], gSession[33][64];
new Float:gDeadline[33], Float:gLastAuth[33];
new bool:gReady[33], gNick[33][32], gPasswordField[65];
new gToken[65], gPort, gEpoch[33], gNonce, gForward;
new gAction[33], gTarget[33][32];

public plugin_natives() {
    register_library("account_guard");
    register_native("account_is_ready", "native_ready");
}
public native_ready(plugin, params) {
    new id = get_param(1);
    return (id >= 1 && id <= MAX_CLIENTS && gReady[id]);
}
public plugin_init() {
    register_plugin("Nick Account Guard", "1.0.0", "csserver");
    register_clcmd("say", "chat_command");
    register_clcmd("say_team", "chat_command");
    register_clcmd("account_nick", "input_nick");
    register_clcmd("account_password", "input_password");
    register_clcmd("jointeam", "block_pending");
    register_clcmd("chooseteam", "block_pending");
    RegisterHookChain(RG_CBasePlayer_JoiningThink, "joining_pre", false);
    RegisterHookChain(RG_CBasePlayer_Spawn, "spawn_pre", false);
    gForward = CreateMultiForward("account_verified", ET_IGNORE, FP_CELL);
    get_localinfo("account_token", gToken, charsmax(gToken));
    new text[16]; get_localinfo("account_port", text, charsmax(text));
    gPort = str_to_num(text);
    // Startup creates a fresh epoch, preventing slot reuse across map changes.
    get_localinfo("account_epoch", gPasswordField, charsmax(gPasswordField));
    formatex(text, charsmax(text), "%d", random_num(100000, 999999));
    add(gPasswordField, charsmax(gPasswordField), text);
    if (strlen(gToken) != 64 || gPort < 1024)
        set_fail_state("Missing private account localinfo configuration; startup script required.");
    set_task(0.05, "poll_requests", 900, _, _, "b");
}
public client_putinserver(id) {
    gReady[id] = false;
    remove_user_flags(id); set_user_flags(id, ADMIN_USER);
    gEpoch[id] = ++gNonce;
    formatex(gSession[id], charsmax(gSession[]), "%s-%d-%d", gPasswordField, id, gEpoch[id]);
    get_user_name(id, gNick[id], charsmax(gNick[]));
    begin_auth(id);
}
public client_connect(id) {
    gReady[id] = false;
    remove_user_flags(id); set_user_flags(id, ADMIN_USER);
}
public client_disconnected(id) {
    release_player(id);
}
stock release_player(id) {
    close_query(id);
    if (gSession[id][0]) {
        new err, sock = socket_open("127.0.0.1", gPort, SOCKET_TCP, err, SOCK_NON_BLOCKING);
        if (sock > 0) {
            if (socket_is_writable(sock, 0)) {
                new packet[160]; formatex(packet, charsmax(packet), "%s|RELEASE|%s^n", gToken, gSession[id]);
                socket_send(sock, packet, strlen(packet));
            }
            socket_close(sock);
        }
    }
    gReady[id] = false; gSession[id][0] = 0; gAction[id] = 0; gTarget[id][0] = 0;
}
public plugin_end() {
    for (new id = 1; id <= MAX_CLIENTS; id++) release_player(id);
    DestroyForward(gForward);
}
public block_pending(id) { return gReady[id] ? PLUGIN_CONTINUE : PLUGIN_HANDLED; }
public joining_pre(id) { if (!gReady[id]) return HC_SUPERCEDE; return HC_CONTINUE; }
public spawn_pre(id) { if (!gReady[id]) return HC_SUPERCEDE; return HC_CONTINUE; }

stock hex_encode(const source[], dest[], size) {
    new offset;
    for (new i = 0; source[i] && offset + 2 <= size; i++)
        offset += formatex(dest[offset], size - offset, "%02x", source[i] & 255);
    dest[offset] = 0;
}
stock close_query(id) {
    if (gSocket[id] > 0) socket_close(gSocket[id]);
    gSocket[id] = 0; gKind[id] = Q_NONE;
    arrayset(gRequest[id], 0, sizeof gRequest[]); gResponse[id][0] = 0;
}
stock queue_query(id, kind, const packet[]) {
    if (gKind[id] != Q_NONE) return false;
    new error;
    gSocket[id] = socket_open("127.0.0.1", gPort, SOCKET_TCP, error, SOCK_NON_BLOCKING);
    if (gSocket[id] <= 0) { reject(id, "Hesap servisi kullanilamiyor. Daha sonra deneyin."); return false; }
    copy(gRequest[id], charsmax(gRequest[]), packet);
    gKind[id] = kind; gSent[id] = 0; gLength[id] = 0;
    gResponse[id][0] = 0; gDeadline[id] = get_gametime() + 3.0;
    return true;
}
stock begin_auth(id) {
    new nick[32], password[128], hn[65], hp[257], ip[48], packet[768];
    get_user_name(id, nick, charsmax(nick));
    get_user_info(id, "_pw", password, charsmax(password));
    get_user_ip(id, ip, charsmax(ip), 1);
    hex_encode(nick, hn, charsmax(hn)); hex_encode(password, hp, charsmax(hp));
    formatex(packet, charsmax(packet), "%s|AUTH|%s|%s|%s|%s^n", gToken, gSession[id], ip, hn, hp);
    queue_query(id, Q_AUTH, packet);
    arrayset(password, 0, sizeof password); arrayset(hp, 0, sizeof hp); arrayset(packet, 0, sizeof packet);
}
public client_infochanged(id) {
    if (!is_user_connected(id) || !gSession[id][0]) return;
    new nick[32]; get_user_info(id, "name", nick, charsmax(nick));
    if (!equal(nick, gNick[id])) {
        // Do not allow any live rename: reconnect with the desired name and password.
        set_user_info(id, "name", gNick[id]);
        client_print(id, print_chat, "[Hesap] Nick degistirmek icin yeni nick ile yeniden baglanin.");
    }
}
public poll_requests() {
    new Float:now = get_gametime();
    for (new id = 1; id <= MAX_CLIENTS; id++) {
        if (!is_user_connected(id) || !gSession[id][0]) continue;
        if (gKind[id] == Q_NONE) {
            if (now - gLastAuth[id] >= 5.0) begin_auth(id);
            continue;
        }
        if (now > gDeadline[id]) { reject(id, "Hesap servisi yanit vermedi. Daha sonra deneyin."); continue; }
        new length = strlen(gRequest[id]);
        if (gSent[id] < length && socket_is_writable(gSocket[id], 0)) {
            new sent = socket_send(gSocket[id], gRequest[id][gSent[id]], length - gSent[id]);
            if (sent < 0) { reject(id, "Hesap servisi baglanti hatasi."); continue; }
            gSent[id] += sent;
            if (gSent[id] == length) {
                // Clear the password-bearing outbound packet as soon as it is sent.
                arrayset(gRequest[id], 0, sizeof gRequest[]);
                gSent[id] = 0;
            }
        }
        if (!socket_is_readable(gSocket[id], 0)) continue;
        new chunk[128], got = socket_recv(gSocket[id], chunk, charsmax(chunk));
        if (got <= 0 || gLength[id] + got >= charsmax(gResponse[])) {
            reject(id, "Hesap servisi gecersiz yanit verdi."); continue;
        }
        add(gResponse[id], charsmax(gResponse[]), chunk); gLength[id] += got;
        if (contain(gResponse[id], "^n") == -1) continue;
        new kind = gKind[id], answer[128]; copy(answer, charsmax(answer), gResponse[id]); trim(answer);
        close_query(id);
        if (kind == Q_AUTH) {
            if (equal(answer, "OK|GUEST|0") || equal(answer, "OK|ACCOUNT|", 11)) {
                new flags = equal(answer, "OK|GUEST|0") ? 0 : str_to_num(answer[11]);
                new bool:first = !gReady[id];
                remove_user_flags(id); set_user_flags(id, flags ? flags : ADMIN_USER);
                gReady[id] = true; gLastAuth[id] = now;
                if (first) {
                    client_print(id, print_chat, "[Hesap] %s", equal(answer, "OK|GUEST|0") ? "Misafir olarak baglandiniz." : "Nick ve sifre dogrulandi.");
                    new ret; ExecuteForward(gForward, ret, id);
                }
            } else if (equal(answer, "ERR|ALREADY_CONNECTED")) reject(id, "Bu kayitli hesap zaten sunucuda.");
            else if (equal(answer, "ERR|RATE_LIMIT")) reject(id, "Cok fazla sifre denemesi. 60 saniye bekleyin.");
            else reject(id, "Kayitli nick: baglanmadan once setinfo _pw sifreniz yazin.");
        } else {
            gAction[id] = 0;
            if (equal(answer, "OK|SAVED|0")) client_print(id, print_chat, "[Hesap] Islem tamamlandi.");
            else if (equal(answer, "ERR|EXISTS")) client_print(id, print_chat, "[Hesap] Bu nick zaten kayitli.");
            else if (equal(answer, "ERR|NOT_FOUND")) client_print(id, print_chat, "[Hesap] Bu nick icin kayit bulunamadi.");
            else if (equal(answer, "ERR|FOUNDER_PROTECTED")) client_print(id, print_chat, "[Hesap] Kurucu kaydi kaldirilamaz.");
            else if (equal(answer, "ERR|FORBIDDEN")) client_print(id, print_chat, "[Hesap] Islem yetkiniz yok; yeniden baglanin.");
            else if (equal(answer, "ERR|INVALID")) client_print(id, print_chat, "[Hesap] Nick veya sifre gecersiz. Sifre 8-63 bayt olmali.");
            else client_print(id, print_chat, "[Hesap] Islem tamamlanamadi; tekrar deneyin.");
        }
    }
}
stock reject(id, const reason[]) {
    close_query(id); gReady[id] = false;
    remove_user_flags(id); set_user_flags(id, ADMIN_USER);
    server_cmd("kick #%d ^"%s^"", get_user_userid(id), reason);
    server_exec();
}
public chat_command(id) {
    new text[64]; read_args(text, charsmax(text)); remove_quotes(text); trim(text);
    if (!equal(text, "/kayit") && !equal(text, "/kayıt")) return PLUGIN_CONTINUE;
    if (!gReady[id] || !(get_user_flags(id) & MANAGE_ACCESS)) {
        client_print(id, print_chat, "[Hesap] Bu komut yalnizca hesap yoneticileri icindir."); return PLUGIN_HANDLED;
    }
    new menu = menu_create("Hesap yonetimi", "menu_handler");
    menu_additem(menu, "Nick kaydet", "1", MANAGE_ACCESS);
    menu_additem(menu, "Sifre sifirla", "2", MANAGE_ACCESS);
    menu_additem(menu, "Kaydi kaldir", "3", MANAGE_ACCESS);
    menu_display(id, menu); return PLUGIN_HANDLED;
}
public menu_handler(id, menu, item) {
    if (item == MENU_EXIT || !gReady[id] || !(get_user_flags(id) & MANAGE_ACCESS)) { menu_destroy(menu); return; }
    new info[8], access, callback; menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
    gAction[id] = str_to_num(info); gTarget[id][0] = 0;
    menu_destroy(menu); client_cmd(id, "messagemode account_nick");
}
public input_nick(id) {
    if (!gReady[id] || !(get_user_flags(id) & MANAGE_ACCESS) || !gAction[id]) return PLUGIN_HANDLED;
    new nick[128]; read_args(nick, charsmax(nick)); remove_quotes(nick); trim(nick);
    if (!nick[0] || strlen(nick) > 31) { client_print(id, print_chat, "[Hesap] Nick 1..31 bayt olmali."); return PLUGIN_HANDLED; }
    copy(gTarget[id], charsmax(gTarget[]), nick);
    if (gAction[id] == 3) {
        new menu = menu_create("Kayit kaldirilsin mi?", "delete_confirm");
        menu_additem(menu, nick, "yes", MANAGE_ACCESS); menu_display(id, menu);
    } else client_cmd(id, "messagemode account_password");
    return PLUGIN_HANDLED;
}
public delete_confirm(id, menu, item) {
    if (item != MENU_EXIT && gAction[id] == 3) manage_request(id, "");
    menu_destroy(menu);
}
public input_password(id) {
    new password[128]; read_args(password, charsmax(password)); remove_quotes(password);
    if (gAction[id] == 1 || gAction[id] == 2) manage_request(id, password);
    arrayset(password, 0, sizeof password); return PLUGIN_HANDLED;
}
stock manage_request(id, const password[]) {
    if (!gReady[id] || !(get_user_flags(id) & MANAGE_ACCESS) || !gTarget[id][0]) return;
    if (gKind[id] != Q_NONE) { client_print(id, print_chat, "[Hesap] Dogrulama suruyor; islemi yeniden deneyin."); return; }
    new hn[65], hp[257], packet[768], operation[16];
    hex_encode(gTarget[id], hn, charsmax(hn)); hex_encode(password, hp, charsmax(hp));
    copy(operation, charsmax(operation), gAction[id] == 1 ? "REGISTER" : gAction[id] == 2 ? "RESET" : "DELETE");
    formatex(packet, charsmax(packet), "%s|%s|%s|%s|%s^n", gToken, operation, gSession[id], hn, hp);
    queue_query(id, Q_MANAGE, packet);
    arrayset(packet, 0, sizeof packet); arrayset(hp, 0, sizeof hp);
}
