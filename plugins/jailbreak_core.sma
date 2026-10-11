#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <reapi>
#include <hamsandwich>
#include <fun>
#include <cstrike>
#include <mode_profile>

#define ACCESS_WARDEN ADMIN_LEVEL_B
native account_is_ready(id);
new bool:gJailbreak, gWarden, bool:gCellsOpen, bool:gTeamsAssigned, bool:gTsustumOpen;
new bool:gAssigned[33], gJumpsRemaining[33], bool:gBonusJump[33], bool:gPaintHeld[33], bool:gPaintHasPoint[33];
new Float:gPaintLastPoint[33][3], Float:gPaintNextAt[33];
new Float:gRocketNextAt[33];
new bool:gCtGod[33];
new gCash[33], bool:gCashReady[33], bool:gShopGive[33], gTransferTarget[33];
new gCashStart, gCashKill, gCashHeadshot, gCashDeath, gCashMaximum;
new gPriceHe, gPriceFlash, gPriceGlock, gPriceUsp, gPriceTmp;
new gPriceHp, gPriceSpeed, gPriceJump, gPriceInvisible, gPriceBlackout, gPriceRevive;
new gPaintSprite, gPaintLife;
new gJbMenusEnabled;

public plugin_precache() { gPaintSprite = precache_model("sprites/laserbeam.spr"); }
public plugin_init() {
    register_plugin("Jailbreak Core", "1.0.0", "csserver");
    register_clcmd("say /komutcu", "cmd_warden");
    register_clcmd("say /hucreac", "cmd_cells");
    register_clcmd("say /lr", "cmd_lr");
    register_clcmd("say /ctmenu", "cmd_ct_menu");
    register_clcmd("say_team /ctmenu", "cmd_ct_menu");
    register_clcmd("say /menuler", "cmd_ct_menu");
    register_clcmd("say_team /menuler", "cmd_ct_menu");
    register_clcmd("say /hucre", "cmd_cells");
    register_clcmd("say_team /hucre", "cmd_cells");
    register_clcmd("say /revmenu", "cmd_revmenu");
    register_clcmd("say_team /revmenu", "cmd_revmenu");
    register_clcmd("say /god", "cmd_ctgod");
    register_clcmd("say_team /god", "cmd_ctgod");
    register_clcmd("say /godmode", "cmd_ctgod");
    register_clcmd("say_team /godmode", "cmd_ctgod");
    register_clcmd("say /tsustum", "cmd_tsustum");
    register_clcmd("say_team /tsustum", "cmd_tsustum");
    register_clcmd("say /jbmenu", "cmd_jbmenu");
    register_clcmd("say_team /jbmenu", "cmd_jbmenu");
    register_clcmd("nightvision", "cmd_jbmenu");
    register_clcmd("say /mg", "cmd_transfer_menu");
    register_clcmd("say_team /mg", "cmd_transfer_menu");
    register_clcmd("say /tl", "cmd_transfer_menu");
    register_clcmd("say_team /tl", "cmd_transfer_menu");
    register_clcmd("say /rocket", "cmd_rocket");
    register_clcmd("say_team /rocket", "cmd_rocket");
    register_clcmd("say /ct", "cmd_chat_ct");
    register_clcmd("say_team /ct", "cmd_chat_ct");
    register_clcmd("say /t", "cmd_chat_t");
    register_clcmd("say_team /t", "cmd_chat_t");
    register_clcmd("say_team /komutcu", "cmd_warden");
    register_clcmd("say_team /hucreac", "cmd_cells");
    register_clcmd("say_team /lr", "cmd_lr");
    register_concmd("amx_komutcu", "cmd_admin_warden", ADMIN_LEVEL_B, "<oyuncu>");
    register_concmd("amx_rev", "cmd_rev", ADMIN_LEVEL_C, "[oyuncu|@all]");
    register_concmd("amx_team", "cmd_admin_team", ACCESS_WARDEN, "<oyuncu> <T|CT|SPEC>");
    register_clcmd("jointeam", "block_team_change");
    register_clcmd("chooseteam", "block_team_change");
    register_clcmd("joinclass", "block_team_change");
    register_clcmd("buy", "block_buy");
    register_clcmd("buyequip", "block_buy");
    register_clcmd("cl_autobuy", "block_buy");
    register_clcmd("cl_rebuy", "block_buy");
    register_clcmd("+paint", "paint_start"); register_clcmd("-paint", "paint_stop");
    register_clcmd("+boya", "paint_start"); register_clcmd("-boya", "paint_stop");
    register_clcmd("+kalem", "paint_start"); register_clcmd("-kalem", "paint_stop");
    register_forward(FM_PlayerPreThink, "double_jump_prethink");
    register_forward(FM_PlayerPreThink, "paint_prethink");
    RegisterHam(Ham_AddPlayerItem, "player", "block_t_weapons", false);
    RegisterHookChain(RG_CBasePlayer_Spawn, "on_player_spawn", true);
    RegisterHookChain(RG_CSGameRules_RestartRound, "on_round_restart", true);
    bind_pcvar_num(create_cvar("paint_marker_life_time", "25"), gPaintLife);
    bind_pcvar_num(create_cvar("jb_cash_start", "7"), gCashStart);
    gJbMenusEnabled = create_cvar("jb_menus_enabled", "1");
    bind_pcvar_num(create_cvar("jb_cash_kill", "3"), gCashKill);
    bind_pcvar_num(create_cvar("jb_cash_headshot", "2"), gCashHeadshot);
    bind_pcvar_num(create_cvar("jb_cash_death", "2"), gCashDeath);
    bind_pcvar_num(create_cvar("jb_cash_max", "1000000"), gCashMaximum);
    bind_pcvar_num(create_cvar("jb_price_he", "15"), gPriceHe);
    bind_pcvar_num(create_cvar("jb_price_flash", "10"), gPriceFlash);
    bind_pcvar_num(create_cvar("jb_price_glock", "35"), gPriceGlock);
    bind_pcvar_num(create_cvar("jb_price_usp", "40"), gPriceUsp);
    bind_pcvar_num(create_cvar("jb_price_tmp", "45"), gPriceTmp);
    bind_pcvar_num(create_cvar("jb_price_hp", "15"), gPriceHp);
    bind_pcvar_num(create_cvar("jb_price_speed", "20"), gPriceSpeed);
    bind_pcvar_num(create_cvar("jb_price_jump", "25"), gPriceJump);
    bind_pcvar_num(create_cvar("jb_price_invisible", "30"), gPriceInvisible);
    bind_pcvar_num(create_cvar("jb_price_blackout", "30"), gPriceBlackout);
    bind_pcvar_num(create_cvar("jb_price_revive", "30"), gPriceRevive);
    RegisterHam(Ham_Killed, "player", "on_player_killed", true);
}

public plugin_cfg() {
    new map[64]; get_mapname(map, charsmax(map));
    gJailbreak = (get_map_profile_mode(map) == MAP_PROFILE_JAILBREAK);
    gWarden = 0; gCellsOpen = false; gTeamsAssigned = false; gTsustumOpen = false;
    arrayset(gAssigned, false, sizeof gAssigned);
    arrayset(gJumpsRemaining, 0, sizeof gJumpsRemaining);
    arrayset(gBonusJump, false, sizeof gBonusJump);
    arrayset(gPaintHeld, false, sizeof gPaintHeld);
    arrayset(gPaintHasPoint, false, sizeof gPaintHasPoint);
    if (gJailbreak) {
        new players[32], count; get_players(players, count, "ch");
        for (new i; i < count; i++) if (account_is_ready(players[i])) account_verified(players[i]);
        set_task(2.0, "assign_teams");
        client_print(0, print_chat, "[Jailbreak] Takimlar otomatik secilir. Komutcu: /komutcu. Hucre: /hucreac. Admin rev: /rev.");
    }
}

public on_round_restart() { if (gJailbreak) { gWarden = 0; gCellsOpen = false; gTsustumOpen = false; } }

public assign_teams() {
    if (!gJailbreak) return;
    new players[32], count; get_players(players, count, "ch");
    new ready[32], readyCount;
    for (new i; i < count; i++) if (account_is_ready(players[i])) ready[readyCount++] = players[i];
    if (!readyCount) return;

    if (!gTeamsAssigned) {
        for (new i; i < readyCount; i++) {
            // Jailbreak servers keep every ordinary joiner in T. Admins use amx_team for explicit assignments.
            set_jail_team(ready[i], TEAM_TERRORIST);
        }
        gTeamsAssigned = true;
        set_task(0.5, "jail_map_spawn");
        return;
    }
    for (new i; i < readyCount; i++) {
        new id = ready[i];
        if (!gAssigned[id]) set_jail_team(id, TEAM_TERRORIST);
    }
}

public account_verified(id) {
    if (gJailbreak && !gCashReady[id]) {
        gCash[id] = gCashStart;
        gCashReady[id] = true;
        show_cash(id);
    }
    if (gJailbreak) set_task(0.5, "assign_teams");
}

public client_putinserver(id) {
    gCashReady[id] = false;
    gCash[id] = 0;
    gTransferTarget[id] = 0;
}

public on_player_killed(victim, attacker, shouldgib) {
    if (!gJailbreak || !is_user_connected(victim) || !gCashReady[victim]) return HAM_IGNORED;
    add_cash(victim, gCashDeath);
    if (attacker >= 1 && attacker <= 32 && attacker != victim && is_user_connected(attacker) &&
        gCashReady[attacker] && get_member(attacker, m_iTeam) != get_member(victim, m_iTeam) &&
        (get_member(attacker, m_iTeam) == TEAM_TERRORIST || get_member(attacker, m_iTeam) == TEAM_CT) &&
        (get_member(victim, m_iTeam) == TEAM_TERRORIST || get_member(victim, m_iTeam) == TEAM_CT)) {
        add_cash(attacker, gCashKill);
        if (get_member(victim, m_bHeadshotKilled)) add_cash(attacker, gCashHeadshot);
    }
    return HAM_IGNORED;
}

stock add_cash(id, amount) {
    if (!is_user_connected(id) || amount <= 0) return;
    gCash[id] = min(gCashMaximum, gCash[id] + amount);
    show_cash(id);
}

stock show_cash(id) {
    if (is_user_connected(id)) client_print(id, print_chat, "[JB] TL bakiyen: %d", gCash[id]);
}

stock bool:spend_cash(id, amount) {
    if (!gCashReady[id] || amount < 0 || gCash[id] < amount) {
        client_print(id, print_chat, "[JB] Yeterli TL yok. Bakiye: %d", gCash[id]);
        return false;
    }
    gCash[id] -= amount;
    return true;
}

stock set_jail_team(id, TeamName:team) {
    if (!is_user_connected(id) || !account_is_ready(id)) return;
    rg_set_user_team(id, team, team == TEAM_CT ? MODEL_CT_GIGN : MODEL_T_LEET, true, true);
    set_member(id, m_iModelName, team == TEAM_CT ? MODEL_CT_GIGN : MODEL_T_LEET);
    set_member(id, m_iJoiningState, GETINTOGAME);
    set_member(id, m_iMenu, Menu_OFF);
    gAssigned[id] = true;
    gJumpsRemaining[id] = 1;
}

public jail_map_spawn() {
    if (!gJailbreak || !gTeamsAssigned) return;
    new players[32], count; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        new id = players[i];
        if (!account_is_ready(id)) continue;
        if (is_user_alive(id)) user_kill(id, 1);
        set_task(0.2, "respawn_player", id);
    }
}

public respawn_player(id) {
    if (gJailbreak && is_user_connected(id) && account_is_ready(id) && !is_user_alive(id)) rg_round_respawn(id);
}

public cmd_warden(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT) {
        client_print(id, print_chat, "[Jailbreak] Yalnizca hayattaki CT komutcu olabilir."); return PLUGIN_HANDLED;
    }
    if (gWarden && is_user_connected(gWarden)) {
        client_print(id, print_chat, "[Jailbreak] Zaten bir komutcu var."); return PLUGIN_HANDLED;
    }
    gWarden = id; new name[32]; get_user_name(id, name, charsmax(name));
    client_print(0, print_chat, "[Jailbreak] Komutcu: %s", name);
    return PLUGIN_HANDLED;
}

public cmd_admin_warden(id, level, cid) {
    if (!cmd_access(id, level, cid, 2) || !gJailbreak) return PLUGIN_HANDLED;
    new arg[32]; read_argv(1, arg, charsmax(arg));
    new target = cmd_target(id, arg, CMDTARGET_ALLOW_SELF | CMDTARGET_ONLY_ALIVE);
    if (!target || get_member(target, m_iTeam) != TEAM_CT) return PLUGIN_HANDLED;
    gWarden = target;
    new name[32]; get_user_name(target, name, charsmax(name)); client_print(0, print_chat, "[Jailbreak] Admin komutcu atadi: %s", name);
    return PLUGIN_HANDLED;
}

public cmd_cells(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (id != gWarden && !(get_user_flags(id) & ACCESS_WARDEN)) {
        client_print(id, print_chat, "[Jailbreak] Hucreleri yalnizca komutcu acabilir."); return PLUGIN_HANDLED;
    }
    if (gCellsOpen) return PLUGIN_HANDLED;
    new ent, body, opened;
    get_user_aiming(id, ent, body, 4096);
    if (pev_valid(ent)) {
        new classname[32]; pev(ent, pev_classname, classname, charsmax(classname));
        if (equal(classname, "func_button") || equal(classname, "func_rot_button") ||
            equal(classname, "func_door") || equal(classname, "func_door_rotating")) {
            force_use(id, ent); opened = 1;
        }
    }
    if (opened) {
        gCellsOpen = true;
        client_print(0, print_chat, "[Jailbreak] Komutcu baktigi kapi/butonu kullandi.");
    } else client_print(id, print_chat, "[Jailbreak] Hucre butonuna/kapisina bakip /hucreac yazin.");
    return PLUGIN_HANDLED;
}

public cmd_lr(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!is_user_alive(id) || get_member(id, m_iTeam) != TEAM_TERRORIST) return PLUGIN_HANDLED;
    new players[32], count, alive; get_players(players, count, "ah");
    for (new i; i < count; i++) if (get_member(players[i], m_iTeam) == TEAM_TERRORIST) alive++;
    if (alive != 1) { client_print(id, print_chat, "[Jailbreak] LR yalnizca son hayattaki mahkuma acik."); return PLUGIN_HANDLED; }
    new menu = menu_create("Son istek - rakip sec", "lr_select");
    for (new i; i < count; i++) if (get_member(players[i], m_iTeam) == TEAM_CT) {
        new name[32], info[8]; num_to_str(players[i], info, charsmax(info)); get_user_name(players[i], name, charsmax(name));
        menu_additem(menu, name, info);
    }
    menu_display(id, menu); return PLUGIN_HANDLED;
}

public lr_select(id, menu, item) {
    if (item >= 0) {
        new info[8], access, callback, target; menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback); target = str_to_num(info);
        if (is_user_alive(id) && is_user_alive(target)) {
            rg_remove_all_items(id); rg_remove_all_items(target); rg_give_item(id, "weapon_knife"); rg_give_item(target, "weapon_knife");
            client_print(0, print_chat, "[Jailbreak] LR bicak duellosu basladi.");
        }
    }
    menu_destroy(menu); return PLUGIN_HANDLED;
}

public block_team_change(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (is_user_connected(id) && account_is_ready(id) && get_member(id, m_iTeam) != TEAM_TERRORIST) {
        set_task(0.1, "force_terrorist", id);
    }
    client_print(id, print_center, "Takim secimi kapali; Jailbreak'te herkes T baslar. CT icin /ctmenu.");
    return PLUGIN_HANDLED;
}

public force_terrorist(id) {
    if (gJailbreak && is_user_connected(id) && account_is_ready(id) && get_member(id, m_iTeam) != TEAM_TERRORIST)
        set_jail_team(id, TEAM_TERRORIST);
}

public cmd_ctmenu(id) {
    return cmd_teamctmenu(id);
}

public cmd_teamctmenu(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!(get_user_flags(id) & ACCESS_WARDEN)) {
        client_print(id, print_chat, "[Jailbreak] CT atama menusunu yalnizca yetkili kullanabilir.");
        return PLUGIN_HANDLED;
    }
    new menu = menu_create("Jailbreak - CT atama", "ctmenu_select");
    new players[32], count; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        new target = players[i];
        if (!account_is_ready(target) || get_member(target, m_iTeam) == TEAM_CT) continue;
        new name[32], info[8]; get_user_name(target, name, charsmax(name)); num_to_str(target, info, charsmax(info));
        menu_additem(menu, name, info);
    }
    if (menu_items(menu) == 0) {
        menu_destroy(menu); client_print(id, print_chat, "[Jailbreak] CT'ye atanabilecek oyuncu yok.");
        return PLUGIN_HANDLED;
    }
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public cmd_ct_menu(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!get_pcvar_num(gJbMenusEnabled)) {
        client_print(id, print_chat, "[CTMenu] Yonetici bu menuyu gecici olarak kapatti.");
        return PLUGIN_HANDLED;
    }
    if (!is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT) {
        client_print(id, print_chat, "[CTMenu] Bu menu yalnizca hayattaki korumalara aciktir.");
        return PLUGIN_HANDLED;
    }
    new menu = menu_create("Koruma Menusu", "ct_action_select");
    menu_additem(menu, "Komutcu ol", "1");
    menu_additem(menu, "Hucreleri ac", "2");
    menu_additem(menu, "Olmus mahkumu dirilt", "3");
    menu_additem(menu, "Godmode ac/kapat (komutcu)", "4");
    menu_additem(menu, "Roket menusu (yetkili)", "5");
    menu_additem(menu, "T'sustum oyununu ac/kapat (yetkili)", "6");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public ct_action_select(id, menu, item) {
    if (item >= 0 && gJailbreak && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_CT) {
        switch (item) {
            case 0: cmd_warden(id);
            case 1: cmd_cells(id);
            case 2: cmd_revmenu(id);
            case 3: cmd_ctgod(id);
            case 4: cmd_rocket(id);
            case 5: cmd_tsustum(id);
        }
    }
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public cmd_revmenu(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (get_member(id, m_iTeam) != TEAM_CT || (id != gWarden && !(get_user_flags(id) & ACCESS_WARDEN))) {
        client_print(id, print_chat, "[Jailbreak] Diriltme menusunu komutcu veya yetkili kullanabilir.");
        return PLUGIN_HANDLED;
    }
    new menu = menu_create("Mahkum dirilt", "revmenu_select");
    new players[32], count; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        new target = players[i];
        if (is_user_alive(target) || get_member(target, m_iTeam) != TEAM_TERRORIST || !account_is_ready(target)) continue;
        new name[32], info[8]; get_user_name(target, name, charsmax(name)); num_to_str(target, info, charsmax(info));
        menu_additem(menu, name, info);
    }
    if (!menu_items(menu)) { menu_destroy(menu); client_print(id, print_chat, "[Jailbreak] Diriltilecek olu mahkum yok."); return PLUGIN_HANDLED; }
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public revmenu_select(id, menu, item) {
    if (item >= 0 && gJailbreak && get_member(id, m_iTeam) == TEAM_CT && (id == gWarden || (get_user_flags(id) & ACCESS_WARDEN))) {
        new info[8], access, callback, target; menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback); target = str_to_num(info);
        if (is_user_connected(target) && !is_user_alive(target) && get_member(target, m_iTeam) == TEAM_TERRORIST && account_is_ready(target)) {
            rg_round_respawn(target);
            client_print(0, print_chat, "[Jailbreak] Bir mahkum komutcu tarafindan diriltildi.");
        }
    }
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public cmd_ctgod(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT || (id != gWarden && !(get_user_flags(id) & ACCESS_WARDEN))) {
        client_print(id, print_chat, "[Jailbreak] Godmode yalnizca komutcu veya yetkili CT icin acik.");
        return PLUGIN_HANDLED;
    }
    gCtGod[id] = !gCtGod[id];
    set_user_godmode(id, gCtGod[id]);
    client_print(id, print_chat, "[Jailbreak] Godmode %s.", gCtGod[id] ? "acildi" : "kapatildi");
    return PLUGIN_HANDLED;
}

public cmd_tsustum(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (get_member(id, m_iTeam) == TEAM_TERRORIST) {
        if (!gTsustumOpen) { client_print(id, print_chat, "[T'sustum] Su anda adaylik oyunu acik degil."); return PLUGIN_HANDLED; }
        if (!account_is_ready(id) || !is_user_connected(id)) return PLUGIN_HANDLED;
        gTsustumOpen = false;
        set_jail_team(id, TEAM_CT);
        if (is_user_alive(id)) user_kill(id, 1);
        set_task(0.2, "respawn_player", id);
        new name[32]; get_user_name(id, name, charsmax(name));
        client_print(0, print_chat, "[T'sustum] %s oyunu kazandi ve yetkili tarafindan CT'ye alindi.", name);
        return PLUGIN_HANDLED;
    }
    if (get_member(id, m_iTeam) != TEAM_CT || (id != gWarden && !(get_user_flags(id) & ACCESS_WARDEN))) {
        client_print(id, print_chat, "[T'sustum] Oyunu yalnizca komutcu veya yetkili CT acabilir.");
        return PLUGIN_HANDLED;
    }
    gTsustumOpen = !gTsustumOpen;
    client_print(0, print_chat, "[T'sustum] CT adayi oyunu %s. Katilmak icin /tsustum yazin.", gTsustumOpen ? "basladi" : "kapatildi");
    return PLUGIN_HANDLED;
}

public cmd_jbmenu(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!get_pcvar_num(gJbMenusEnabled)) {
        client_print(id, print_chat, "[JBMenu] Yonetici bu menuleri gecici olarak kapatti.");
        return PLUGIN_HANDLED;
    }
    if (!is_user_alive(id) || get_member(id, m_iTeam) != TEAM_TERRORIST || !gCashReady[id]) {
        client_print(id, print_chat, "[JBMenu] Mahkum menusu yalnizca hayattaki ve girisi dogrulanmis T oyuncularina aciktir.");
        return PLUGIN_HANDLED;
    }
    new title[96], menu;
    formatex(title, charsmax(title), "Mahkum JBMenu - %d TL", gCash[id]);
    menu = menu_create(title, "jbmenu_select");
    menu_additem(menu, "Emanet / Cephane", "1");
    menu_additem(menu, "Isyan yetenekleri", "2");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public jbmenu_select(id, menu, item) {
    if (item >= 0 && gJailbreak && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_TERRORIST && gCashReady[id]) {
        switch (item) {
            case 0: open_equipment_menu(id);
            case 1: open_rebel_menu(id);
        }
    }
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

stock open_equipment_menu(id) {
    new menu = menu_create("Emanet / Cephane", "equipment_select");
    new item[64];
    formatex(item, charsmax(item), "HE bombasi - %d TL", gPriceHe); menu_additem(menu, item, "1");
    formatex(item, charsmax(item), "Flash bombasi - %d TL", gPriceFlash); menu_additem(menu, item, "2");
    formatex(item, charsmax(item), "Glock18 - %d TL", gPriceGlock); menu_additem(menu, item, "3");
    formatex(item, charsmax(item), "USP - %d TL", gPriceUsp); menu_additem(menu, item, "4");
    formatex(item, charsmax(item), "TMP - %d TL", gPriceTmp); menu_additem(menu, item, "5");
    menu_display(id, menu);
}

stock open_rebel_menu(id) {
    new menu = menu_create("Isyan yetenekleri", "rebel_select");
    new item[64];
    formatex(item, charsmax(item), "+100 can (en cok 200) - %d TL", gPriceHp); menu_additem(menu, item, "1");
    formatex(item, charsmax(item), "5 saniye hiz - %d TL", gPriceSpeed); menu_additem(menu, item, "2");
    formatex(item, charsmax(item), "Bu can icin ekstra cift zipla - %d TL", gPriceJump); menu_additem(menu, item, "3");
    formatex(item, charsmax(item), "5 saniye gorunmezlik - %d TL", gPriceInvisible); menu_additem(menu, item, "4");
    formatex(item, charsmax(item), "CT'lerin ekranini 5 saniye karart - %d TL", gPriceBlackout); menu_additem(menu, item, "5");
    formatex(item, charsmax(item), "Olmus mahkum arkadasi dirilt - %d TL", gPriceRevive); menu_additem(menu, item, "6");
    menu_display(id, menu);
}

stock bool:can_buy(id, price) {
    if (!gJailbreak || !is_user_alive(id) || get_member(id, m_iTeam) != TEAM_TERRORIST || !gCashReady[id]) {
        client_print(id, print_chat, "[JBMenu] Bu alisveris yalnizca hayattaki mahkumlara aciktir.");
        return false;
    }
    new aliveT = alive_terrorists();
    if (aliveT <= 1) {
        client_print(id, print_chat, "[JBMenu] Son mahkumken LR kurallarini bozacak alisveris yapamazsin.");
        return false;
    }
    return spend_cash(id, price);
}

stock alive_terrorists() {
    new players[32], count, alive; get_players(players, count, "ah");
    for (new i; i < count; i++) if (get_member(players[i], m_iTeam) == TEAM_TERRORIST) alive++;
    return alive;
}

public equipment_select(id, menu, item) {
    if (item >= 0 && gJailbreak && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_TERRORIST) {
        new weapon[24], price, ammo = 1;
        switch (item) {
            case 0: { copy(weapon, charsmax(weapon), "weapon_hegrenade"); price = gPriceHe; }
            case 1: { copy(weapon, charsmax(weapon), "weapon_flashbang"); price = gPriceFlash; }
            case 2: { copy(weapon, charsmax(weapon), "weapon_glock18"); price = gPriceGlock; ammo = 20; }
            case 3: { copy(weapon, charsmax(weapon), "weapon_usp"); price = gPriceUsp; ammo = 12; }
            case 4: { copy(weapon, charsmax(weapon), "weapon_tmp"); price = gPriceTmp; ammo = 30; }
        }
        if (can_buy(id, price)) {
            gShopGive[id] = true;
            new entity = rg_give_item(id, weapon);
            gShopGive[id] = false;
            if (entity > 0 && ammo > 1) cs_set_user_bpammo(id, get_weaponid(weapon), ammo);
            client_print(id, print_chat, "[JBMenu] %s satin alindi. Bakiye: %d TL", weapon, gCash[id]);
        }
    }
    menu_destroy(menu); return PLUGIN_HANDLED;
}

public rebel_select(id, menu, item) {
    if (item < 0 || !gJailbreak || !is_user_alive(id) || get_member(id, m_iTeam) != TEAM_TERRORIST) {
        menu_destroy(menu); return PLUGIN_HANDLED;
    }
    new price;
    switch (item) {
        case 0: price = gPriceHp;
        case 1: price = gPriceSpeed;
        case 2: price = gPriceJump;
        case 3: price = gPriceInvisible;
        case 4: price = gPriceBlackout;
        case 5: price = gPriceRevive;
    }
    if (item == 5 && (alive_terrorists() <= 1 || !has_revive_target())) {
        client_print(id, print_chat, "[JBMenu] Son mahkumken veya uygun hedef yokken diriltme satin alinamaz.");
        menu_destroy(menu); return PLUGIN_HANDLED;
    }
    if (can_buy(id, price)) {
        switch (item) {
            case 0: {
                new Float:hp = get_entvar(id, var_health);
                set_entvar(id, var_health, floatmin(200.0, hp + 100.0));
            }
            case 1: {
                remove_task(id + 6000);
                set_user_maxspeed(id, 350.0);
                set_task(5.0, "reset_rebel_speed", id + 6000);
            }
            case 2: {
                gBonusJump[id] = true;
                if (!(pev(id, pev_flags) & FL_ONGROUND)) gJumpsRemaining[id]++;
            }
            case 3: {
                remove_task(id + 7000);
                set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0);
                set_task(5.0, "reset_rebel_visibility", id + 7000);
            }
            case 4: blackout_cts();
            case 5: open_revive_target_menu(id);
        }
        client_print(id, print_chat, "[JBMenu] Yetenek kullanildi. Bakiye: %d TL", gCash[id]);
    }
    menu_destroy(menu); return PLUGIN_HANDLED;
}

public reset_rebel_speed(taskid) {
    new id = taskid - 6000;
    if (is_user_alive(id)) rg_reset_maxspeed(id);
}

public reset_rebel_visibility(taskid) {
    new id = taskid - 7000;
    if (is_user_connected(id)) set_user_rendering(id);
}

stock blackout_cts() {
    new players[32], count; get_players(players, count, "ah");
    new fade = get_user_msgid("ScreenFade");
    for (new i; i < count; i++) {
        new target = players[i];
        if (get_member(target, m_iTeam) != TEAM_CT) continue;
        message_begin(MSG_ONE_UNRELIABLE, fade, _, target);
        write_short(1 << 12); write_short(1 << 12); write_short(0);
        write_byte(0); write_byte(0); write_byte(0); write_byte(255); message_end();
        set_task(5.0, "clear_ct_blackout", target + 8000);
    }
}

public clear_ct_blackout(taskid) {
    new id = taskid - 8000;
    if (!is_user_connected(id)) return;
    new fade = get_user_msgid("ScreenFade");
    message_begin(MSG_ONE_UNRELIABLE, fade, _, id);
    write_short(1); write_short(1); write_short(1 << 0);
    write_byte(0); write_byte(0); write_byte(0); write_byte(0); message_end();
}

stock open_revive_target_menu(id) {
    if (alive_terrorists() <= 1) { client_print(id, print_chat, "[JBMenu] Son mahkumken oyuncu diriltilemez."); return; }
    new menu = menu_create("Diriltilecek mahkum arkadas", "rebel_revive_select");
    new players[32], count; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        new target = players[i];
        if (is_user_alive(target) || get_member(target, m_iTeam) != TEAM_TERRORIST || !account_is_ready(target)) continue;
        new name[32], info[8]; get_user_name(target, name, charsmax(name)); num_to_str(target, info, charsmax(info)); menu_additem(menu, name, info);
    }
    if (!menu_items(menu)) { menu_destroy(menu); client_print(id, print_chat, "[JBMenu] Diriltilecek olu mahkum yok."); return; }
    menu_display(id, menu);
}

stock bool:has_revive_target() {
    new players[32], count; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        new target = players[i];
        if (!is_user_alive(target) && get_member(target, m_iTeam) == TEAM_TERRORIST && account_is_ready(target)) return true;
    }
    return false;
}

public rebel_revive_select(id, menu, item) {
    if (item >= 0 && gJailbreak && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_TERRORIST && alive_terrorists() > 1) {
        new info[8], access, callback, target;
        menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback); target = str_to_num(info);
        if (is_user_connected(target) && !is_user_alive(target) && get_member(target, m_iTeam) == TEAM_TERRORIST && account_is_ready(target)) {
            rg_round_respawn(target);
            client_print(0, print_chat, "[JBMenu] Bir mahkum arkadasini diriltti.");
        }
    }
    menu_destroy(menu); return PLUGIN_HANDLED;
}

public cmd_transfer_menu(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT) {
        client_print(id, print_chat, "[JB] TL yalnizca hayattaki CT oyuncular tarafindan verilebilir.");
        return PLUGIN_HANDLED;
    }
    new menu = menu_create("Mahkuma TL ver", "transfer_target_select");
    new players[32], count; get_players(players, count, "ah");
    for (new i; i < count; i++) {
        new target = players[i];
        if (get_member(target, m_iTeam) != TEAM_TERRORIST || !gCashReady[target]) continue;
        new name[48], info[8]; get_user_name(target, name, charsmax(name)); num_to_str(target, info, charsmax(info));
        format(name, charsmax(name), "%s - %d TL", name, gCash[target]); menu_additem(menu, name, info);
    }
    if (!menu_items(menu)) { menu_destroy(menu); client_print(id, print_chat, "[JB] TL verilecek hayatta mahkum yok."); return PLUGIN_HANDLED; }
    menu_display(id, menu); return PLUGIN_HANDLED;
}

public transfer_target_select(id, menu, item) {
    if (item >= 0 && gJailbreak && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_CT) {
        new info[8], access, callback; menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
        gTransferTarget[id] = str_to_num(info);
        new transfer = menu_create("Verilecek miktar", "transfer_amount_select");
        menu_additem(transfer, "10 TL", "10"); menu_additem(transfer, "25 TL", "25"); menu_additem(transfer, "50 TL", "50");
        menu_display(id, transfer);
    }
    menu_destroy(menu); return PLUGIN_HANDLED;
}

public transfer_amount_select(id, menu, item) {
    if (item >= 0 && gJailbreak && is_user_alive(id) && get_member(id, m_iTeam) == TEAM_CT) {
        new info[8], access, callback; menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
        new target = gTransferTarget[id], amount = str_to_num(info);
        if (is_user_alive(target) && get_member(target, m_iTeam) == TEAM_TERRORIST && gCashReady[target]) {
            if (!spend_cash(id, amount)) { gTransferTarget[id] = 0; menu_destroy(menu); return PLUGIN_HANDLED; }
            add_cash(target, amount);
            new name[32]; get_user_name(target, name, charsmax(name)); client_print(id, print_chat, "[JB] %s oyuncusuna %d TL verildi.", name, amount);
        } else client_print(id, print_chat, "[JB] Secilen mahkum artik oyunda degil.");
    }
    gTransferTarget[id] = 0;
    menu_destroy(menu); return PLUGIN_HANDLED;
}

public cmd_rocket(id) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!(get_user_flags(id) & ACCESS_WARDEN)) {
        client_print(id, print_chat, "[Jailbreak] Roket icin yetkili olmalisin.");
        return PLUGIN_HANDLED;
    }
    new menu = menu_create("Roket - mahkum sec", "rocket_select");
    new players[32], count; get_players(players, count, "ah");
    for (new i; i < count; i++) {
        new target = players[i];
        if (get_member(target, m_iTeam) != TEAM_TERRORIST) continue;
        new name[32], info[8]; get_user_name(target, name, charsmax(name)); num_to_str(target, info, charsmax(info));
        menu_additem(menu, name, info);
    }
    if (menu_items(menu) == 0) { menu_destroy(menu); client_print(id, print_chat, "[Jailbreak] Roket atacak hayatta mahkum yok."); return PLUGIN_HANDLED; }
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public rocket_select(id, menu, item) {
    if (item >= 0 && gJailbreak && (get_user_flags(id) & ACCESS_WARDEN)) {
        new Float:now = get_gametime();
        if (now < gRocketNextAt[id]) { client_print(id, print_chat, "[Jailbreak] Roket icin bekleyin."); menu_destroy(menu); return PLUGIN_HANDLED; }
        new info[8], access, callback, target; menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback); target = str_to_num(info);
        if (is_user_alive(target) && get_member(target, m_iTeam) == TEAM_TERRORIST) {
            new Float:velocity[3]; pev(target, pev_velocity, velocity); velocity[2] = 900.0; set_pev(target, pev_velocity, velocity);
            gRocketNextAt[id] = now + 2.0;
            new name[32]; get_user_name(target, name, charsmax(name)); client_print(0, print_chat, "[Jailbreak] %s rokete bindirildi!", name);
        }
    }
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

stock revive_terrorists(id) {
    if (!(get_user_flags(id) & ACCESS_WARDEN)) return;
    new players[32], count, revived; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        new target = players[i];
        if (account_is_ready(target) && !is_user_alive(target) && get_member(target, m_iTeam) == TEAM_TERRORIST) {
            rg_round_respawn(target); revived++;
        }
    }
    client_print(id, print_chat, "[Jailbreak] Diriltilen mahkum: %d", revived);
}

public ctmenu_select(id, menu, item) {
    if (item >= 0 && gJailbreak && (get_user_flags(id) & ACCESS_WARDEN)) {
        new info[8], access, callback, target;
        menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
        target = str_to_num(info);
        if (is_user_connected(target) && account_is_ready(target)) {
            set_jail_team(target, TEAM_CT);
            if (is_user_alive(target)) user_kill(target, 1);
            set_task(0.2, "respawn_player", target);
            new name[32]; get_user_name(target, name, charsmax(name));
            client_print(0, print_chat, "[Jailbreak] %s yetkili tarafindan CT'ye atandi.", name);
        }
    }
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public cmd_chat_ct(id) { return cmd_chat_team(id, TEAM_CT); }
public cmd_chat_t(id) { return cmd_chat_team(id, TEAM_TERRORIST); }

stock cmd_chat_team(id, TeamName:team) {
    if (!gJailbreak) return PLUGIN_CONTINUE;
    if (!(get_user_flags(id) & ACCESS_WARDEN)) {
        client_print(id, print_chat, "[Jailbreak] Takim atama yetkin yok.");
        return PLUGIN_HANDLED;
    }
    new arg[32]; read_args(arg, charsmax(arg)); remove_quotes(arg); trim(arg);
    if (!arg[0]) {
        if (!account_is_ready(id)) return PLUGIN_HANDLED;
        set_jail_team(id, team);
        if (is_user_alive(id)) user_kill(id, 1);
        set_task(0.2, "respawn_player", id);
        return PLUGIN_HANDLED;
    }
    new target = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (target && account_is_ready(target)) {
        set_jail_team(target, team);
        if (is_user_alive(target)) user_kill(target, 1);
        set_task(0.2, "respawn_player", target);
    }
    return PLUGIN_HANDLED;
}

public cmd_jbteam(id, level, cid) {
    if (!cmd_access(id, level, cid, 3) || !gJailbreak) return PLUGIN_HANDLED;
    new targetArg[32], teamArg[8]; read_argv(1, targetArg, charsmax(targetArg)); read_argv(2, teamArg, charsmax(teamArg));
    new target = cmd_target(id, targetArg, CMDTARGET_ALLOW_SELF);
    if (target && account_is_ready(target) && (equali(teamArg, "ct") || equali(teamArg, "t"))) {
        new TeamName:team = equali(teamArg, "ct") ? TEAM_CT : TEAM_TERRORIST;
        set_jail_team(target, team);
        if (is_user_alive(target)) user_kill(target, 1);
        set_task(0.2, "respawn_player", target);
    }
    return PLUGIN_HANDLED;
}

public cmd_admin_team(id, level, cid) {
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED;
    if (!gJailbreak) {
        console_print(id, "[AMXX] amx_team yalniz Jailbreak haritasinda kullanilir.");
        return PLUGIN_HANDLED;
    }
    new targetArg[32], teamArg[16];
    read_argv(1, targetArg, charsmax(targetArg));
    read_argv(2, teamArg, charsmax(teamArg));
    new target = cmd_target(id, targetArg, CMDTARGET_ALLOW_SELF);
    if (!target || !account_is_ready(target)) return PLUGIN_HANDLED;

    if (equali(teamArg, "t") || equali(teamArg, "terrorist")) {
        set_jail_team(target, TEAM_TERRORIST);
    } else if (equali(teamArg, "ct") || equali(teamArg, "counter")) {
        set_jail_team(target, TEAM_CT);
    } else if (equali(teamArg, "spec") || equali(teamArg, "spectator")) {
        rg_set_user_team(target, TEAM_SPECTATOR, MODEL_UNASSIGNED, true, true);
        gAssigned[target] = true;
        gJumpsRemaining[target] = 0;
        if (is_user_alive(target)) user_kill(target, 1);
    } else {
        console_print(id, "Kullanim: amx_team <oyuncu> <T|CT|SPEC>");
        return PLUGIN_HANDLED;
    }

    if (teamArg[0] && !equali(teamArg, "spec") && !equali(teamArg, "spectator")) {
        if (is_user_alive(target)) user_kill(target, 1);
        set_task(0.2, "respawn_player", target);
    }
    new name[32]; get_user_name(target, name, charsmax(name));
    console_print(id, "[Jailbreak] %s takimina atandi: %s", teamArg, name);
    return PLUGIN_HANDLED;
}

public cmd_assign_ct(id, level, cid) {
    if (!cmd_access(id, level, cid, 2) || !gJailbreak) return PLUGIN_HANDLED;
    new arg[32]; read_argv(1, arg, charsmax(arg));
    new target = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (target && account_is_ready(target)) {
        set_jail_team(target, TEAM_CT);
        if (is_user_alive(target)) user_kill(target, 1);
        set_task(0.2, "respawn_player", target);
    }
    return PLUGIN_HANDLED;
}

public block_buy(id) {
    if (gJailbreak && get_member(id, m_iTeam) == TEAM_TERRORIST) {
        client_print(id, print_center, "Mahkumlar silah satin alamaz.");
        return PLUGIN_HANDLED;
    }
    return gJailbreak ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public block_t_weapons(id, item) {
    if (gShopGive[id]) return HAM_IGNORED;
    if (!gJailbreak || !is_user_connected(id) || get_member(id, m_iTeam) != TEAM_TERRORIST || !pev_valid(item)) return HAM_IGNORED;
    new classname[32]; pev(item, pev_classname, classname, charsmax(classname));
    if (equal(classname, "weapon_knife")) return HAM_IGNORED;
    return HAM_SUPERCEDE;
}

public on_player_spawn(id) {
    if (id < 1 || id > MaxClients || !is_user_connected(id)) return;
    gCtGod[id] = false;
    set_user_godmode(id, 0);
    set_user_rendering(id);
    if (!gJailbreak || !is_user_alive(id) || !account_is_ready(id)) return;
    gJumpsRemaining[id] = 1;
    gBonusJump[id] = false;
    if (get_member(id, m_iTeam) == TEAM_TERRORIST) {
        rg_remove_all_items(id);
        rg_give_item(id, "weapon_knife");
    }
}

public double_jump_prethink(id) {
    if (!gJailbreak || !is_user_alive(id) || !account_is_ready(id)) return FMRES_IGNORED;
    if (pev(id, pev_flags) & FL_ONGROUND) {
        gJumpsRemaining[id] = 1 + (gBonusJump[id] ? 1 : 0);
        return FMRES_IGNORED;
    }
    new buttons = pev(id, pev_button), oldbuttons = pev(id, pev_oldbuttons);
    if (gJumpsRemaining[id] > 0 && (buttons & IN_JUMP) && !(oldbuttons & IN_JUMP)) {
        new Float:velocity[3]; pev(id, pev_velocity, velocity);
        velocity[2] = 270.0;
        set_pev(id, pev_velocity, velocity);
        gJumpsRemaining[id]--;
    }
    return FMRES_IGNORED;
}

public paint_start(id) {
    if (!gJailbreak || !is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT || !account_is_ready(id)) {
        client_print(id, print_chat, "[Paint] Jailbreak'te yalnizca hayattaki CT oyuncular kullanabilir.");
        return PLUGIN_HANDLED;
    }
    gPaintHeld[id] = true;
    gPaintHasPoint[id] = false;
    return PLUGIN_HANDLED;
}

public paint_stop(id) {
    gPaintHeld[id] = false;
    gPaintHasPoint[id] = false;
    return PLUGIN_HANDLED;
}

public paint_prethink(id) {
    if (!gPaintHeld[id] || !gJailbreak || !is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT) {
        gPaintHasPoint[id] = false;
        return FMRES_IGNORED;
    }
    new Float:now = get_gametime();
    if (now < gPaintNextAt[id]) return FMRES_IGNORED;
    gPaintNextAt[id] = now + 0.08;
    new point[3]; get_user_origin(id, point, 3);
    new Float:current[3]; current[0] = float(point[0]); current[1] = float(point[1]); current[2] = float(point[2]);
    if (gPaintHasPoint[id]) {
        new Float:dx = current[0] - gPaintLastPoint[id][0];
        new Float:dy = current[1] - gPaintLastPoint[id][1];
        new Float:dz = current[2] - gPaintLastPoint[id][2];
        if ((dx * dx + dy * dy + dz * dz) > 100.0) {
            message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
            write_byte(TE_BEAMPOINTS);
            write_coord(floatround(gPaintLastPoint[id][0])); write_coord(floatround(gPaintLastPoint[id][1])); write_coord(floatround(gPaintLastPoint[id][2]));
            write_coord(point[0]); write_coord(point[1]); write_coord(point[2]);
            write_short(gPaintSprite); write_byte(0); write_byte(0); write_byte(clamp(gPaintLife * 10, 1, 255));
            write_byte(6); write_byte(0); write_byte(55); write_byte(155); write_byte(255); write_byte(220); write_byte(0);
            message_end();
        }
    }
    gPaintLastPoint[id][0] = current[0]; gPaintLastPoint[id][1] = current[1]; gPaintLastPoint[id][2] = current[2];
    gPaintHasPoint[id] = true;
    return FMRES_IGNORED;
}

public cmd_rev(id, level, cid) {
    if (!cmd_access(id, level, cid, 1) || !gJailbreak) return PLUGIN_HANDLED;
    new targetArg[32]; read_argv(1, targetArg, charsmax(targetArg));
    new revived;
    if (!targetArg[0] || equali(targetArg, "@all")) {
        new players[32], count; get_players(players, count, "ch");
        for (new i; i < count; i++) {
            new target = players[i];
            if (account_is_ready(target) && !is_user_alive(target)) { rg_round_respawn(target); revived++; }
        }
    } else {
        new target = cmd_target(id, targetArg, CMDTARGET_ALLOW_SELF);
        if (target && account_is_ready(target) && !is_user_alive(target)) { rg_round_respawn(target); revived = 1; }
    }
    if (id) console_print(id, "[Jailbreak] Revive edilen oyuncu sayisi: %d", revived);
    return PLUGIN_HANDLED;
}

public client_disconnected(id) {
    if (id == gWarden) gWarden = 0;
    gAssigned[id] = false; gJumpsRemaining[id] = 0; gBonusJump[id] = false; gPaintHeld[id] = false; gPaintHasPoint[id] = false; gCtGod[id] = false;
    gCash[id] = 0; gCashReady[id] = false; gShopGive[id] = false; gTransferTarget[id] = 0;
}

