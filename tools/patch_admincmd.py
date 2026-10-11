"""Keep upstream AMXX commands and license; add persistence at validated ban sites."""
from common import ROOT


def patched_source():
    text = (ROOT / 'downloads/amxx_base/addons/amxmodx/scripting/admincmd.sma').read_text()
    text = text.replace('#include <amxmisc>', '#include <amxmisc>\n'
                        'native persistent_ban_store(const subject[], minutes, bool:ip);\n'
                        'native persistent_ban_remove(const subject[], bool:ip);\n')
    replacements = {
        'server_cmd("removeip ^"%s^";writeip", arg)': 'persistent_ban_remove(arg, true);\n\t\tserver_cmd("removeip ^"%s^";writeip", arg)',
        'server_cmd("removeid %s;writeid", arg)': 'persistent_ban_remove(arg, false);\n\t\tserver_cmd("removeid %s;writeid", arg)',
        'server_cmd("addip ^"%s^" ^"%s^";wait;writeip", minutes, arg)': 'persistent_ban_store(arg, str_to_num(minutes), true);\n\t\tserver_cmd("addip ^"%s^" ^"%s^";wait;writeip", minutes, arg)',
        'server_cmd("banid ^"%s^" %s;wait;writeid", minutes, arg)': 'persistent_ban_store(arg, str_to_num(minutes), false);\n\t\tserver_cmd("banid ^"%s^" %s;wait;writeid", minutes, arg)',
        'TrieSetString(g_tempBans, authid2, authid); //': 'persistent_ban_store(authid2, nNum, false);\n\tTrieSetString(g_tempBans, authid2, authid); //',
        'get_user_ip(player, address, charsmax(address), 1)': 'get_user_ip(player, address, charsmax(address), 1)\n\tpersistent_ban_store(address, nNum, true);',
    }
    for before, after in replacements.items():
        if text.count(before) != 1:
            raise RuntimeError('Upstream admincmd changed; review persistence patch before compiling.')
        text = text.replace(before, after)
    map_validation = '''stock bool:map_has_missing_wads(const map[])
{
    new path[192], line[192], listed[64];
    get_configsdir(path, charsmax(path));
    add(path, charsmax(path), "/maps_blocked.ini");
    new file = fopen(path, "rt");
    if (!file)
        return false;
    new bool:found;
    while (!feof(file))
    {
        fgets(file, line, charsmax(line));
        trim(line);
        if (!line[0] || line[0] == ';')
            continue;
        parse(line, listed, charsmax(listed));
        if (equali(listed, map))
        {
            found = true;
            break;
        }
    }
    fclose(file);
    return found;
}

'''
    if text.count('public cmdMap(id, level, cid)') != 1:
        raise RuntimeError('Upstream admincmd map command changed; review map safety patch.')
    text = text.replace('public cmdMap(id, level, cid)', map_validation + 'public cmdMap(id, level, cid)')
    before = 'if (!is_map_valid(arg) || contain(arg, "..") != -1)'
    after = '''if (map_has_missing_wads(arg))
	{
		console_print(id, "[AMXX] Map blocked: missing WAD resources. Check maps_blocked.ini.")
		return PLUGIN_HANDLED
	}

	if (!is_map_valid(arg) || contain(arg, "..") != -1)'''
    if text.count(before) != 1:
        raise RuntimeError('Upstream admincmd map validation changed; review map safety patch.')
    text = text.replace(before, after)
    return text


def patched_menu():
    text = (ROOT / 'downloads/amxx_base/addons/amxmodx/scripting/plmenu.sma').read_text()
    text = text.replace('#include <amxmisc>', '#include <amxmisc>\nnative persistent_ban_store(const subject[], minutes, bool:ip);')
    replacements = {
        'server_cmd("addip %d %s;writeip", banTime, ipa);': 'persistent_ban_store(ipa, banTime, true);\n\t\t\t\tserver_cmd("addip %d %s;writeip", banTime, ipa);',
        'server_cmd("banid %d #%d kick;writeid", banTime, userid2);': 'persistent_ban_store(authid2, banTime, false);\n\t\t\t\tserver_cmd("banid %d #%d kick;writeid", banTime, userid2);',
    }
    for before, after in replacements.items():
        if text.count(before) != 1:
            raise RuntimeError('Upstream plmenu changed; review persistence patch.')
        text = text.replace(before, after)
    return text


def patched_votes():
    text = (ROOT / 'downloads/amxx_base/addons/amxmodx/scripting/adminvote.sma').read_text()
    text = text.replace('#include <amxmisc>', '#include <amxmisc>\nnative persistent_ban_store(const subject[], minutes, bool:ip);')
    before = 'public delayedExec(cmd[])\n\tserver_cmd("%s", cmd)'
    after = '''public delayedExec(cmd[])
{
    new operation[16], minutes[16], subject[64];
    parse(cmd, operation, charsmax(operation), minutes, charsmax(minutes), subject, charsmax(subject));
    if (equal(operation, "banid") || equal(operation, "addip"))
        persistent_ban_store(subject, floatround(str_to_float(minutes)), equal(operation, "addip") ? true : false);
    server_cmd("%s", cmd);
}'''
    if text.count(before) != 1:
        raise RuntimeError('Upstream adminvote changed; review persistence patch.')
    return text.replace(before, after)
