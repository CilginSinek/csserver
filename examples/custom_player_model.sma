#include <amxmodx>
#include <reapi>

new const PLAYER_MODEL[] = "runner";

public plugin_precache() {
    precache_model("models/player/runner/runner.mdl");
    // Modeliniz ayri bir runnerT.mdl kullaniyorsa onu da precache_model ile ekleyin.
}
public plugin_init() {
    register_plugin("Example CT Model", "1.0.0", "csserver");
    RegisterHookChain(RG_CBasePlayer_Spawn, "spawn_post", true);
}
public spawn_post(id) {
    if (is_user_alive(id) && get_member(id, m_iTeam) == TEAM_CT)
        rg_set_user_model(id, PLAYER_MODEL, true);
}
