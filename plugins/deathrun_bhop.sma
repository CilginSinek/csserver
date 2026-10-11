#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <mode_profile>

new bool:gCanDoubleJump[33];
new MapProfileMode:gMapMode;

public plugin_init() {
    register_plugin("Deathrun Auto Bhop", "1.0.0", "csserver");
    register_forward(FM_PlayerPreThink, "bhop_doublejump");
    RegisterHookChain(RG_CBasePlayer_Spawn, "bhop_spawn", true);
}
public plugin_cfg() {
    new map[64]; get_mapname(map, charsmax(map));
    gMapMode = get_map_profile_mode(map);
    if (gMapMode == MAP_PROFILE_DEATHRUN) {
        set_cvar_num("sv_autobunnyhopping", 1);
        set_cvar_num("sv_enablebunnyhopping", 1);
        set_cvar_num("sv_airaccelerate", 100);
    } else if (gMapMode == MAP_PROFILE_JAILBREAK) {
        set_cvar_num("sv_autobunnyhopping", 1);
        set_cvar_num("sv_enablebunnyhopping", 1);
        set_cvar_num("sv_airaccelerate", 100);
    } else {
        set_cvar_num("sv_autobunnyhopping", 0);
        set_cvar_num("sv_enablebunnyhopping", 0);
        set_cvar_num("sv_airaccelerate", 10);
    }
}

public bhop_spawn(id) {
    if (gMapMode == MAP_PROFILE_DEATHRUN && is_user_alive(id)) gCanDoubleJump[id] = true;
}

public bhop_doublejump(id) {
    if (gMapMode != MAP_PROFILE_DEATHRUN || !is_user_alive(id)) return FMRES_IGNORED;
    if (pev(id, pev_flags) & FL_ONGROUND) { gCanDoubleJump[id] = true; return FMRES_IGNORED; }
    new buttons = pev(id, pev_button), oldbuttons = pev(id, pev_oldbuttons);
    if (gCanDoubleJump[id] && (buttons & IN_JUMP) && !(oldbuttons & IN_JUMP)) {
        new Float:velocity[3]; pev(id, pev_velocity, velocity); velocity[2] = 270.0; set_pev(id, pev_velocity, velocity);
        gCanDoubleJump[id] = false;
    }
    return FMRES_IGNORED;
}

