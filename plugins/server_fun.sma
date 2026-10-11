#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fun>
#include <reapi>
#include <hamsandwich>
#include <mode_profile>

#define ACCESS_HOOK ADMIN_LEVEL_H
#define ACCESS_PARACHUTE ADMIN_LEVEL_A
#define TASK_SNOW 45810

new bool:gRedbull[33], Float:gOldGravity[33];
new bool:gHookEnabled[33], bool:gHookHeld[33], Float:gHookDrawAt[33];
new bool:gParachute[33];
new bool:gParachuteMode;
new gParachuteEnt[33];
new Float:gParachuteOpenAt[33];
new bool:gSnowEnabled;
new gOldInfiniteGrenades;
new gSnowSprite, gHookSprite;
new gMaxSpeed, gMaxHealth, gHealPerSecond, gSnowInterval, gSnowCount;
new Float:gHookSpeed;
new Float:gSnowNextThrow[33];
new Float:gRedbullGravity, Float:gParachuteFallSpeed;
new gSnowEnabledCvar, gHookEnabledCvar, gParachuteEnabledCvar;

public plugin_precache() {
    // Built-in GoldSrc snow sprite; no client-side model download is required.
    gSnowSprite = precache_model("sprites/snow.spr");
    precache_model("models/snowwars/v090/weapons/w_snowball.mdl");
    gHookSprite = precache_model("sprites/laserbeam.spr");
    precache_model("models/parachute.mdl");
}

public plugin_init() {
    register_plugin("CS Server Fun", "1.0.0", "csserver");
    register_clcmd("say /redbull", "cmd_redbull");
    register_clcmd("say_team /redbull", "cmd_redbull");
    register_clcmd("say /hook", "cmd_hook");
    register_clcmd("say_team /hook", "cmd_hook");
    register_clcmd("+hook", "cmd_hook_start");
    register_clcmd("-hook", "cmd_hook_stop");
    register_clcmd("+rope", "cmd_hook_start");
    register_clcmd("-rope", "cmd_hook_stop");
    register_clcmd("+grap", "cmd_hook_start");
    register_clcmd("-grap", "cmd_hook_stop");
    register_clcmd("say /para", "cmd_parachute");
    register_clcmd("say_team /para", "cmd_parachute");
    register_clcmd("say /parasut", "cmd_parachute");
    register_clcmd("say_team /parasut", "cmd_parachute");
    register_clcmd("say /parachute", "cmd_parachute");
    register_concmd("amx_parasut", "cmd_admin_parachute", ACCESS_PARACHUTE, "<oyuncu> <0|1>");
    register_concmd("amx_snow", "cmd_snow", ADMIN_LEVEL_C, "<0|1> kar savasini ac/kapat");
    register_concmd("amx_noclip", "cmd_noclip", ADMIN_LEVEL_C, "<oyuncu> noclip ac/kapat");
    register_forward(FM_PlayerPreThink, "on_prethink");
    register_forward(FM_SetModel, "replace_he_with_snowball", true);
    RegisterHam(Ham_TakeDamage, "player", "on_take_damage", false);
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "on_reset_speed", false);
    RegisterHookChain(RG_CBasePlayer_Killed, "on_killed", true);
    RegisterHookChain(RG_CBasePlayer_ThrowGrenade, "on_throw_grenade", false);
    bind_pcvar_num(create_cvar("redbull_maxspeed", "700"), gMaxSpeed);
    bind_pcvar_float(create_cvar("redbull_gravity", "0.5"), gRedbullGravity);
    bind_pcvar_num(create_cvar("redbull_maxcan", "250"), gMaxHealth);
    bind_pcvar_num(create_cvar("redbull_heal", "1"), gHealPerSecond);
    create_cvar("sv_redbull", "1");
    gHookEnabledCvar = create_cvar("sv_hook_enabled", "1");
    gSnowEnabledCvar = create_cvar("sv_snow_enabled", "0");
    gParachuteEnabledCvar = create_cvar("sv_parachute_enabled", "1");
    bind_pcvar_float(create_cvar("parachute_fallspeed", "100.0"), gParachuteFallSpeed);
    bind_pcvar_float(create_cvar("hook_speed", "800.0"), gHookSpeed);
    bind_pcvar_num(create_cvar("snow_interval", "6"), gSnowInterval);
    bind_pcvar_num(create_cvar("snow_count", "4"), gSnowCount);
}

public replace_he_with_snowball(entity, const model[]) {
    if (!gSnowEnabled || !pev_valid(entity) || !equal(model, "models/w_hegrenade.mdl")) return FMRES_IGNORED;
    new classname[16]; pev(entity, pev_classname, classname, charsmax(classname));
    if (!equal(classname, "grenade")) return FMRES_IGNORED;
    engfunc(EngFunc_SetModel, entity, "models/snowwars/v090/weapons/w_snowball.mdl");
    return FMRES_IGNORED;
}

public plugin_cfg() {
    new map[64]; get_mapname(map, charsmax(map));
    new MapProfileMode:profile = get_map_profile_mode(map);
    if (profile == MAP_PROFILE_JAILBREAK) {
        server_cmd("exec addons/amxmodx/configs/jailbreak.cfg");
        gParachuteMode = true;
        set_mode_parachutes(true);
    } else if (profile == MAP_PROFILE_DEATHRUN) {
        server_cmd("exec addons/amxmodx/configs/deathrun.cfg");
        gParachuteMode = true;
        set_mode_parachutes(true);
    } else {
        server_cmd("exec addons/amxmodx/configs/vanilla.cfg");
        gParachuteMode = false;
        set_mode_parachutes(false);
    }
    set_pcvar_num(gParachuteEnabledCvar, gParachuteMode);
    gSnowEnabled = get_pcvar_num(gSnowEnabledCvar) != 0;
    server_exec();
}

public client_putinserver(id) {
    gParachute[id] = gParachuteMode;
}

stock set_mode_parachutes(bool:enabled) {
    new players[32], count; get_players(players, count, "ch");
    for (new i; i < count; i++) {
        gParachute[players[i]] = enabled;
        remove_parachute_entity(players[i]);
    }
}

public client_disconnected(id) {
    remove_task(id + 1000);
    remove_parachute_entity(id);
    gRedbull[id] = false; gHookEnabled[id] = false; gHookHeld[id] = false; gParachute[id] = false;
    gSnowNextThrow[id] = 0.0;
}

public on_throw_grenade(id, grenade, Float:source[3], Float:velocity[3], Float:time, event) {
    if (!gSnowEnabled || !is_user_connected(id)) return HC_CONTINUE;
    new Float:now = get_gametime();
    if (now < gSnowNextThrow[id]) {
        client_print(id, print_center, "Kar topu icin atis araligi: 1.5 saniye.");
        return HC_SUPERCEDE;
    }
    gSnowNextThrow[id] = now + 1.5;
    return HC_CONTINUE;
}

public cmd_redbull(id) {
    if (!is_user_alive(id)) return PLUGIN_HANDLED;
    if (!get_cvar_num("sv_redbull")) {
        if (gRedbull[id]) restore_redbull(id);
        client_print(id, print_chat, "[RedBull] Su anda kapali.");
        return PLUGIN_HANDLED;
    }
    gRedbull[id] = !gRedbull[id];
    if (gRedbull[id]) {
        gOldGravity[id] = get_entvar(id, var_gravity);
        set_entvar(id, var_gravity, gRedbullGravity);
        set_entvar(id, var_maxspeed, float(gMaxSpeed));
        if (!task_exists(id + 1000)) set_task(1.0, "redbull_regen", id + 1000, _, _, "b");
        client_print(id, print_chat, "[RedBull] Aktif; saniyede %d can yeniler (ust sinir %d). Kapatmak icin /redbull yaz.", gHealPerSecond, gMaxHealth);
    } else {
        restore_redbull(id);
        client_print(id, print_chat, "[RedBull] Kapandi.");
    }
    return PLUGIN_HANDLED;
}

public on_reset_speed(id) {
    if (is_user_connected(id) && gRedbull[id] && !get_cvar_num("sv_redbull")) {
        restore_redbull(id);
        return HC_CONTINUE;
    }
    if (is_user_connected(id) && gRedbull[id]) {
        set_entvar(id, var_maxspeed, float(gMaxSpeed));
        set_entvar(id, var_gravity, gRedbullGravity);
        return HC_SUPERCEDE;
    }
    return HC_CONTINUE;
}

public on_killed(id) {
    if (gRedbull[id]) restore_redbull(id);
    gHookHeld[id] = false;
    remove_parachute_entity(id);
}

stock restore_redbull(id) {
    gRedbull[id] = false;
    remove_task(id + 1000);
    if (!is_user_connected(id)) return;
    set_entvar(id, var_gravity, gOldGravity[id] > 0.0 ? gOldGravity[id] : 1.0);
    rg_reset_maxspeed(id);
}

public redbull_regen(taskid) {
    new id = taskid - 1000;
    if (!get_cvar_num("sv_redbull")) { restore_redbull(id); return; }
    if (!is_user_alive(id) || !gRedbull[id]) return;
    new Float:health = get_entvar(id, var_health);
    if (health < float(gMaxHealth)) set_entvar(id, var_health, floatmin(float(gMaxHealth), health + float(gHealPerSecond)));
}

public cmd_hook(id) {
    if (!(get_user_flags(id) & ACCESS_HOOK)) {
        client_print(id, print_chat, "[Hook] Bu komut admin yetkisi gerektirir.");
        return PLUGIN_HANDLED;
    }
    if (!get_pcvar_num(gHookEnabledCvar)) {
        client_print(id, print_chat, "[Hook] Yonetici tarafindan gecici olarak kapatildi.");
        return PLUGIN_HANDLED;
    }
    gHookEnabled[id] = !gHookEnabled[id];
    gHookHeld[id] = false;
    client_print(id, print_chat, "[Hook] %s", gHookEnabled[id] ? "Acik. Konsolda bind f +hook yazin (birakinca -hook otomatik gonderilir). +rope ve +grap da desteklenir." : "Kapali.");
    return PLUGIN_HANDLED;
}

public cmd_hook_start(id) {
    if (!get_pcvar_num(gHookEnabledCvar)) {
        client_print(id, print_chat, "[Hook] Yonetici tarafindan gecici olarak kapatildi.");
        return PLUGIN_HANDLED;
    }
    if (gHookEnabled[id] && is_user_alive(id)) gHookHeld[id] = true;
    return PLUGIN_HANDLED;
}

public cmd_hook_stop(id) { gHookHeld[id] = false; return PLUGIN_HANDLED; }

public cmd_parachute(id) {
    if (!get_pcvar_num(gParachuteEnabledCvar)) {
        client_print(id, print_chat, "[Parasut] Yonetici tarafindan gecici olarak kapatildi.");
        return PLUGIN_HANDLED;
    }
    gParachute[id] = !gParachute[id];
    client_print(id, print_chat, "[Parasut] %s. Dusarken E tusunu basili tut.", gParachute[id] ? "Acik" : "Kapali");
    return PLUGIN_HANDLED;
}

public cmd_admin_parachute(id, level, cid) {
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED;
    new targetArg[32], valueArg[8];
    read_argv(1, targetArg, charsmax(targetArg)); read_argv(2, valueArg, charsmax(valueArg));
    new target = cmd_target(id, targetArg, CMDTARGET_ALLOW_SELF);
    if (!target) return PLUGIN_HANDLED;
    gParachute[target] = bool:(str_to_num(valueArg) != 0);
    new name[32]; get_user_name(target, name, charsmax(name));
    console_print(id, "[AMXX] Parasut %s: %s", gParachute[target] ? "acik" : "kapali", name);
    return PLUGIN_HANDLED;
}

public cmd_noclip(id, level, cid) {
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED;
    new arg[32]; read_argv(1, arg, charsmax(arg));
    new target = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (!target) return PLUGIN_HANDLED;
    new enabled = !get_user_noclip(target);
    set_user_noclip(target, enabled);
    new name[32]; get_user_name(target, name, charsmax(name));
    console_print(id, "[AMXX] Noclip %s: %s", enabled ? "acildi" : "kapandi", name);
    return PLUGIN_HANDLED;
}

public on_prethink(id) {
    if (!is_user_alive(id)) return FMRES_IGNORED;
    new bool:deploying = get_pcvar_num(gParachuteEnabledCvar) && gParachute[id] && (pev(id, pev_button) & IN_USE) != 0;
    if (deploying) {
        new Float:velocity[3]; pev(id, pev_velocity, velocity);
        if (velocity[2] < 0.0) {
            if (!pev(id, pev_groundentity)) {
                ensure_parachute_entity(id);
                update_parachute_animation(id);
                if (velocity[2] < -gParachuteFallSpeed) {
                    velocity[2] = -gParachuteFallSpeed;
                    set_pev(id, pev_velocity, velocity);
                }
            } else {
                remove_parachute_entity(id);
            }
        } else {
            remove_parachute_entity(id);
        }
    } else remove_parachute_entity(id);
    if (!get_pcvar_num(gHookEnabledCvar) || !gHookEnabled[id] || !gHookHeld[id]) {
        gHookHeld[id] = false;
        return FMRES_IGNORED;
    }
    new Float:start[3], Float:view[3], Float:aim[3], Float:velocity[3];
    pev(id, pev_origin, start); pev(id, pev_view_ofs, view);
    start[0] += view[0]; start[1] += view[1]; start[2] += view[2];
    velocity_by_aim(id, 8192, aim);
    for (new i = 0; i < 3; i++) aim[i] += start[i];
    new trace = create_tr2(); engfunc(EngFunc_TraceLine, start, aim, DONT_IGNORE_MONSTERS, id, trace);
    new Float:end[3]; get_tr2(trace, TR_EndPos, end); free_tr2(trace);
    if (get_gametime() >= gHookDrawAt[id]) {
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
        write_byte(TE_BEAMPOINTS);
        write_coord(floatround(start[0])); write_coord(floatround(start[1])); write_coord(floatround(start[2]));
        write_coord(floatround(end[0])); write_coord(floatround(end[1])); write_coord(floatround(end[2]));
        write_short(gHookSprite); write_byte(0); write_byte(0); write_byte(2); write_byte(5); write_byte(0);
        write_byte(210); write_byte(230); write_byte(255); write_byte(220); write_byte(0);
        message_end();
        gHookDrawAt[id] = get_gametime() + 0.08;
    }
    velocity[0] = end[0] - start[0]; velocity[1] = end[1] - start[1]; velocity[2] = end[2] - start[2];
    new Float:length = floatsqroot(velocity[0] * velocity[0] + velocity[1] * velocity[1] + velocity[2] * velocity[2]);
    if (length > 0.0) {
        new Float:scale = floatmin(gHookSpeed, 2000.0) / length;
        if (scale > 1.0) scale = 1.0;
        velocity[0] *= scale; velocity[1] *= scale; velocity[2] *= scale;
    }
    set_pev(id, pev_velocity, velocity);
    return FMRES_IGNORED;
}

stock ensure_parachute_entity(id) {
    if (gParachuteEnt[id] > 0 && pev_valid(gParachuteEnt[id])) return;
    new ent = create_entity("info_target");
    if (!ent) return;
    gParachuteEnt[id] = ent;
    set_pev(ent, pev_classname, "player_parachute");
    set_pev(ent, pev_aiment, id);
    set_pev(ent, pev_owner, id);
    set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(ent, pev_solid, SOLID_NOT);
    engfunc(EngFunc_SetModel, ent, "models/parachute.mdl");
    // Start with the canopy deployment animation; it switches to idle once open.
    set_pev(ent, pev_sequence, 0);
    set_pev(ent, pev_frame, 0.0);
    set_pev(ent, pev_framerate, 1.0);
    set_pev(ent, pev_animtime, get_gametime());
    gParachuteOpenAt[id] = get_gametime() + 2.5;
}

stock update_parachute_animation(id) {
    new ent = gParachuteEnt[id];
    if (ent > 0 && pev_valid(ent) && pev(ent, pev_sequence) == 0 && get_gametime() >= gParachuteOpenAt[id]) {
        set_pev(ent, pev_sequence, 1);
        set_pev(ent, pev_frame, 0.0);
        set_pev(ent, pev_animtime, get_gametime());
    }
}

stock remove_parachute_entity(id) {
    if (gParachuteEnt[id] > 0 && pev_valid(gParachuteEnt[id])) engfunc(EngFunc_RemoveEntity, gParachuteEnt[id]);
    gParachuteEnt[id] = 0;
}

public cmd_snow(id, level, cid) {
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED;
    new arg[8]; read_argv(1, arg, charsmax(arg));
    gSnowEnabled = (str_to_num(arg) != 0);
    set_pcvar_num(gSnowEnabledCvar, gSnowEnabled);
    if (gSnowEnabled) {
        gOldInfiniteGrenades = get_cvar_num("mp_infinite_grenades");
        if (!task_exists(TASK_SNOW)) set_task(floatmax(1.0, float(gSnowInterval)), "snow_tick", TASK_SNOW, _, _, "b");
        // Infinite grenades plus rapid throws can flood entity creation and
        // network temp entities. Keep the user's current ammo policy intact.
        client_print(0, print_chat, "[Kar Savasi] Etkinlik acildi. HE bombalari kar topudur; kisi basi 1.5 sn atis siniri var.");
    } else {
        remove_task(TASK_SNOW); server_cmd("mp_infinite_grenades %d", gOldInfiniteGrenades); server_exec();
        client_print(0, print_chat, "[Kar Savasi] Etkinlik kapatildi.");
    }
    return PLUGIN_HANDLED;
}

public on_take_damage(victim, inflictor, attacker, Float:damage, damagebits) {
    if (!gSnowEnabled || !is_user_alive(victim) || !pev_valid(inflictor)) return HAM_IGNORED;
    new classname[16]; pev(inflictor, pev_classname, classname, charsmax(classname));
    if (!equal(classname, "grenade")) return HAM_IGNORED;
    // Snowballs chill instead of dealing lethal HE damage; thaw after two seconds.
    set_pev(victim, pev_flags, pev(victim, pev_flags) | FL_FROZEN);
    set_task(2.0, "thaw_player", victim + 47000);
    SetHamParamFloat(4, 0.0);
    return HAM_SUPERCEDE;
}

public thaw_player(taskid) {
    new id = taskid - 47000;
    if (is_user_connected(id)) set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
}

public snow_tick() {
    if (!gSnowEnabled) return;
    new players[32], count; get_players(players, count, "a");
    for (new n = 0; n < count; n++) {
        new Float:origin[3]; pev(players[n], pev_origin, origin);
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
        write_byte(TE_SPRITETRAIL); write_coord(floatround(origin[0] - 700.0));
        write_coord(floatround(origin[1] - 700.0)); write_coord(floatround(origin[2] + 600.0));
        write_coord(floatround(origin[0] + 700.0)); write_coord(floatround(origin[1] + 700.0));
        write_coord(floatround(origin[2] - 100.0)); write_short(gSnowSprite);
        write_byte(clamp(gSnowCount, 1, 8)); write_byte(20); write_byte(2); write_byte(20); write_byte(20);
        message_end();
    }
}
