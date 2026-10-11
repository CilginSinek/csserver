#if defined _mode_profile_included
    #endinput
#endif
#define _mode_profile_included

enum MapProfileMode {
    MAP_PROFILE_VANILLA = 0,
    MAP_PROFILE_DEATHRUN,
    MAP_PROFILE_JAILBREAK
}

stock MapProfileMode:get_map_profile_mode(const map[]) {
    if (equali(map, "jail_", 5) || equali(map, "jb_", 3) || map_in_profile(map, "jail_maps.ini"))
        return MAP_PROFILE_JAILBREAK;
    if (equali(map, "deathrun_", 9) || map_in_profile(map, "deathrun_maps.ini"))
        return MAP_PROFILE_DEATHRUN;
    return MAP_PROFILE_VANILLA;
}

stock bool:map_in_profile(const map[], const profile[]) {
    new path[192], line[96];
    get_configsdir(path, charsmax(path));
    add(path, charsmax(path), "/");
    add(path, charsmax(path), profile);
    new file = fopen(path, "rt");
    if (!file) return false;
    new found;
    while (!feof(file)) {
        fgets(file, line, charsmax(line));
        trim(line);
        if (line[0] && line[0] != ';' && equali(line, map)) { found = 1; break; }
    }
    fclose(file);
    return bool:(found != 0);
}
