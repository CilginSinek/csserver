#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <mode_profile>

native account_is_ready(id);
new bool:gEnabled, gT, gLastT, gLastCount;

public plugin_precache() {
    new map[64]; get_mapname(map, charsmax(map));
    gEnabled = (get_map_profile_mode(map) == MAP_PROFILE_DEATHRUN);
    if (gEnabled) register_forward(FM_Spawn, "entity_spawn_pre", false);
}
public entity_spawn_pre(ent) {
    if (!pev_valid(ent)) return FMRES_IGNORED;
    new classname[48]; pev(ent, pev_classname, classname, charsmax(classname));
    if (equal(classname, "func_bomb_target") || equal(classname, "info_bomb_target") ||
        equal(classname, "hostage_entity") || equal(classname, "func_hostage_rescue") ||
        equal(classname, "info_hostage_rescue") || equal(classname, "func_vip_safetyzone") ||
        equal(classname, "info_vip_start") || equal(classname, "func_escapezone") || equal(classname, "func_buyzone")) {
        engfunc(EngFunc_RemoveEntity, ent); return FMRES_SUPERCEDE;
    }
    return FMRES_IGNORED;
}
public plugin_init() {
    register_plugin("Deathrun Manager", "1.0.0", "csserver");
    if (!gEnabled) return;
    RegisterHookChain(RG_CSGameRules_RestartRound, "restart_pre", false);
    RegisterHookChain(RG_CSGameRules_CheckWinConditions, "win_pre", false);
    RegisterHookChain(RG_CBasePlayer_Spawn, "spawn_post", true);
    register_clcmd("jointeam", "team_command"); register_clcmd("chooseteam", "team_command");
    register_clcmd("joinclass", "team_command");
    register_clcmd("buy", "team_command"); register_clcmd("buyequip", "team_command");
    register_clcmd("cl_autobuy", "team_command"); register_clcmd("cl_rebuy", "team_command");
    set_task(1.0, "waiting_tick", 901, _, _, "b");
}
public plugin_cfg() {
    if (!gEnabled) return;
    set_cvar_num("mp_autoteambalance", 0); set_cvar_num("mp_limitteams", 0);
    set_cvar_num("mp_freezetime", 0); set_cvar_num("mp_give_player_c4", 0);
}
stock ready_players(players[32]) {
    new count;
    for (new id = 1; id <= MaxClients; id++)
        if (is_user_connected(id) && !is_user_hltv(id) && account_is_ready(id)) players[count++] = id;
    return count;
}
public account_verified(id) {
    if (!gEnabled) return;
    rg_join_team(id, TEAM_CT);
    rg_set_user_team(id, TEAM_CT, MODEL_CT_GIGN, true, false);
    set_member(id, m_iModelName, MODEL_CT_GIGN);
    set_member(id, m_iJoiningState, GETINTOGAME);
    set_member(id, m_iMenu, Menu_OFF);
    client_print(id, print_chat, "[Deathrun] Takimlar otomatik secilir. Bhop icin ZIPLAMA tusunu basili tutun.");
}
public team_command(id) {
    if (gEnabled) return PLUGIN_HANDLED;
    return PLUGIN_CONTINUE;
}
public restart_pre() {
    new players[32], count = ready_players(players);
    gT = 0;
    if (count >= 2) {
        for (new i = 0; i < count; i++) if (players[i] > gLastT) { gT = players[i]; break; }
        if (!gT) gT = players[0];
        gLastT = gT;
    }
    for (new i = 0; i < count; i++) {
        new id = players[i];
        rg_set_user_team(id, id == gT ? TEAM_TERRORIST : TEAM_CT, id == gT ? MODEL_T_LEET : MODEL_CT_GIGN, true, false);
        set_member(id, m_iModelName, id == gT ? MODEL_T_LEET : MODEL_CT_GIGN);
        if (get_member(id, m_iJoiningState) != JOINED) set_member(id, m_iJoiningState, GETINTOGAME);
    }
    if (gT) {
        new nick[32]; get_user_name(gT, nick, charsmax(nick));
        client_print(0, print_chat, "[Deathrun] Tuzak yoneticisi: %s", nick);
    }
    return HC_CONTINUE;
}
public win_pre() {
    new players[32];
    if (ready_players(players) < 2) return HC_SUPERCEDE;
    return HC_CONTINUE;
}
public spawn_post(id) {
    if (!is_user_alive(id) || !account_is_ready(id)) return;
    rg_remove_all_items(id); rg_give_item(id, "weapon_knife");
    set_member(id, m_iAccount, 0);
}
public waiting_tick() {
    new players[32], count = ready_players(players);
    if (count >= 2 && gLastCount < 2) set_cvar_num("sv_restart", 1);
    if (count < 2) {
        gT = 0;
        for (new i = 0; i < count; i++) {
            new id = players[i];
            if (get_member(id, m_iTeam) != TEAM_CT) rg_set_user_team(id, TEAM_CT, MODEL_CT_GIGN, true, false);
            if (!is_user_alive(id) && get_member(id, m_iJoiningState) == JOINED) rg_round_respawn(id);
        }
        if (count && gLastCount != count) client_print(0, print_chat, "[Deathrun] Ikinci oyuncu bekleniyor; serbest antrenman.");
    }
    gLastCount = count;
}
public client_disconnected(id) {
    if (!gEnabled || id != gT) return;
    gT = 0;
    new players[32];
    if (ready_players(players) >= 2) rg_round_end(1.0, WINSTATUS_CTS, ROUND_CTS_WIN);
}

