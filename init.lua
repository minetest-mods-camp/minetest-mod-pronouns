--[[
Copyright (C) 2023 prestidigitator (as registered on forum.minetest.net)

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
]]


local modname = minetest.get_current_modname()


-- Persistence

local storage = minetest.get_mod_storage()

local settings = nil
do
    local ser = storage:get("settings")
    if ser then
        settings = minetest.parse_json(ser)
        if not settings then
            print("Using default pronouns settings.")
        end
    end
    if not settings then
        settings = {
            max_length       = 6,
            max_total_length = 20,
            restricted       = false,
            preapproved = {
                e    = true, em   = true, eir   = true,
                ey   = true,
                he   = true, him  = true, his   = true,
                she  = true, her  = true,
                they = true, them = true, their = true,
                xe   = true, xem  = true, xyr   = true,
                ze   = true, zem  = true, zir   = true,
            },
        }
    end
end

local player_pronouns = nil
do
    local ser = storage:get("player_pronouns")
    if ser then
        player_pronouns = minetest.parse_json(ser)
        if not player_pronons then
            print("Player pronoun database has been reset.")
        end
    end
    if not player_pronouns then
        player_pronouns = {}
    end
end

local function save_settings()
    local ser, err = minetest.write_json(settings)
    if not ser then error(("Error serializing pronoun settings: %s"):format(err)) end
    storage:set_string("settings", ser)
end

local function save_player_pronouns()
    local ser, err = minetest.write_json(player_pronouns)
    if not ser then error(("Error serializing player pronouns: %s"):format(err)) end
    storage:set_string("player_pronouns", ser)
end


-- Internal Utilities

local function player_to_name(player)
    return type(player) == "string" and player or player:get_player_name()
end

local function unique_list_from_lists_and_sets(...)
    local list, set = {}, {}
    for i = 1, select("#", ...) do
        local list_or_set = select(i, ...)
        if list_or_set[1] then
            for _, v in ipairs(list_or_set) do
                if not set[v] then
                    list[#list+1], set[v] = v, true
                end
            end
        else
            for v in pairs(list_or_set) do
                if not set[v] then
                    list[#list+1], set[v] = v, true
                end
            end
        end
    end
    return list
end

local function set_from_lists_and_sets(...)
    local set = {}
    for i = 1, select("#", ...) do
        local list_or_set = select(i, ...)
        if list_or_set[1] then
            for _, v in ipairs(list_or_set) do set[v] = true end
        else
            for v in pairs(list_or_set) do set[v] = true end
        end
    end
    return set
end

local function lists_equal(a, b)
    if #a ~= #b then return false end
    for i, v in ipairs(a) do
        if b[i] ~= v then return false end
    end
    return true
end

local function sets_equal(a, b)
    for v in pairs(a) do
        if not b[v] then return false end
    end
    for v in pairs(b) do
        if not a[v] then return false end
    end
    return true
end

local function copy_list_or_set(t)
    if t[1] then
        return {unpack(t)}
    else
        local new = {}
        for v in pairs(t) do new[v] = true end
        return new
    end
end

local function trim_space(str)
    local si, ei = str:find("^%s+")
    if si then str = str:sub(ei+1) end

    si = str:find("%s+$")
    if si then str = str:sub(1, si-1) end

    return str
end

local function normalize_space(str)
    return str:gsub("%s+", " ")
end


-- API Namespace

local pronouns = {}
_G[modname] = pronouns


-- Settings

-- Returns a number.
function pronouns.get_max_length()
    return settings.max_length
end

-- max_len is a number or number-formatted string.  Non-positive values mean the length
-- is unrestricted.
function pronouns.set_max_length(max_len)
    max_len = tonumber(max_len)
    max_len = max_len and math.floor(max_len) or 0

    local old = settings.max_length
    if max_len ~= old then
        settings.max_length = max_len
        save_settings()
    end
    return old
end

-- Returns a number.
function pronouns.get_max_total_length()
    return settings.max_length
end

-- max_len is a number or number-formatted string.  Non-positive values mean the length
-- is unrestricted.
function pronouns.set_max_total_length(max_len)
    max_len = tonumber(max_len)
    max_len = max_len and math.floor(max_len) or 0

    local old = settings.max_total_length
    if max_len ~= old then
        settings.max_total_length = max_len
        save_settings()
    end
    return old
end

-- Returns a boolean.
function pronouns.get_restricted()
    return settings.restricted
end

-- bool is used for its truthiness value.
function pronouns.set_restricted(bool)
    local old = not not settings.restricted
    bool      = not not bool
    if bool ~= old then
        settings.restricted = bool
        save_settings()
    end
    return old
end

-- Returns a set (unordered only keys matter) of pronouns.
function pronouns.get_preapproved()
    return copy_list_or_set(settings.preapproved or {})
end

-- pronouns is a list (ordered, positive integer indices, # length operator) or a set
-- (unordered, only keys matter).  The order of a list is ignored.
function pronouns.set_preapproved(pronouns)
    local old, pset = settings.preapproved or {}, set_from_lists_and_sets(pronouns)
    if sets_equal(pset, old) then
        old = copy_list_or_set(old)
    else
        settings.preapproved = pset
        save_settings()
    end
    return old
end

-- pronouns is a list (ordered, positive integer indices, # length operator) or a set
-- (unordered, only keys matter).  The order of a list is ignored.
function pronouns.add_preapproved(pronouns)
    local old  = settings.preapproved or {}
    local pset = set_from_lists_and_sets(old, pronouns)
    if sets_equal(pset, old) then
        old = copy_list_or_set(old)
    else
        settings.preapproved = pset
        save_settings()
    end
    return old
end

-- pronouns is a list (ordered, positive integer indices, # length operator) or a set
-- (unordered, only keys matter).  The order of a list is ignored.
function pronouns.remove_preapproved(pronouns)
    local rset = set_from_lists_and_sets(pronouns)

    local old, pset, changed = settings.preapproved or {}, {}, false
    for p in pairs(old) do
        if rset[p] then
            changed = true
        else
            pset[p] = true
        end
    end
    if changed then
        settings.preapproved = pset
        save_settings()
    else
        old = copy_list_or_set(old)
    end
    return old
end


-- Permissions

minetest.register_privilege(
    "pronouns",
    "Set pronouns on other players, pre-approve pronouns, and bypass pronoun "..
        "restrictions."
)

-- Checks whether actor (player ObjectRef or name string) is allowed to set pronouns on
-- target (player ObjectRef or name string), and whether actor has the pronouns
-- privilege.
--
-- Returns allowed, privileged, err where err is a string if not allowed and the other
-- two values are booleans.
function pronouns.check_privs(actor, target)
    local aname
    if type(actor) == "string" then
        aname, actor = actor, minetest.get_player_by_name(actor)
    else
        aname = actor:get_player_name()
    end
    if not aname or not actor then
        return false, false, "Unknown actor."
    end
    local privileged = minetest.get_player_privs(aname).pronouns

    local tname = player_to_name(target)

    if not player_pronouns[tname] then
        return false, true, (
            "Unknown player '%s' (never connected while pronouns mod active)."
        ):format(tname)
    end

    if privileged then
        return true, true
    end

    if tname ~= aname then
        return false, false,
            "Setting pronouns for other players requires the pronouns privilege."
    end

    return true, false
end

local function _can_add(with_priv, target, pronouns)
    local tname = player_to_name(target)

    local restricted  = settings.restricted
    local preapproved = settings.preapproved
    local approved    = (player_pronouns[tname] or {}).approved or {}

    if with_priv then return true end

    local max_len = settings.max_length
    if max_len and max_len > 0 or restricted then
        pronouns = set_from_lists_and_sets(pronouns)
        for p in pairs(pronouns) do
            if not preapproved[p] and not approved[p] then
                if restricted then
                    return false, (
                        "Using unapproved pronoun '%s' requires the pronouns "..
                        "privilege."
                    ):format(p)
                elseif #p > settings.max_length then
                    return false, (
                        "Pronoun '%s' exceeds maximum length %d."
                    ):format(p, max_len)
                end
            end
        end
    end

    return true
end

local function _can_set(with_priv, target, pronouns)
    local allowed, err = _can_add(with_priv, target, pronouns)
    if not allowed then return false, err end

    if with_priv then return true end

    pronouns = unique_list_from_lists_and_sets(pronouns)
    if #pronouns > 1 then
        local max_total_len = settings.max_total_length
        if max_total_len and max_total_len > 0 then
            local pronouns_tag = table.concat(pronouns, "/")
            if #pronouns_tag > max_total_len then
                return false, (
                    "List of pronouns '%s' exceeds maximum length %d."
                ):format(pronouns_tag, max_total_len)
            end
        end
    end

    return true
end

-- Checks whether actor (player ObjectRef or name string) has permission to set pros
-- (list or set of pronouns) on target (player ObjectRef or name string).
--
-- Returns allowed, err where err is a string if allowed is false, and allowed is a
-- boolean.
function pronouns.can_set(actor, target, pros)
    local tname = player_to_name(target)

    local allowed, privileged, err = pronouns.check_privs(actor, tname)
    if not allowed then return false, err end
    if privileged  then return true       end

    return _can_set(privileged, tname, pros)
end

-- Checks whether actor (player ObjectRef or name string) has permission to add pros
-- (list or set of pronouns) on target (player ObjectRef or name string).
--
-- Returns allowed, err where err is a string if allowed is false, and allowed is a
-- boolean.
function pronouns.can_add(actor, target, pros)
    local tname = player_to_name(target)

    local allowed, privileged, err = pronouns.check_privs(actor, tname)
    if not allowed then return false, err end
    if privileged  then return true       end

    local plist = unique_list_from_lists_and_sets(
        player_pronouns[tname].set or {}, pros
    )
    return _can_set(privileged, tname, plist)
end

-- Checks whether actor (player ObjectRef or name string) has permission to remove pros
-- (list or set of pronouns) on target (player ObjectRef or name string).
--
-- Returns allowed, err where err is a string if allowed is false, and allowed is a
-- boolean.
function pronouns.can_remove(actor, target, pros)
    local allowed, _, err = pronouns.check_privs(actor, target)
    return allowed, err
end


-- Nametag Hooks

local update_player_tag  -- forward decl

local function default_pre_hook(player)
    return player:get_player_name()
end

local function default_post_hook(player, tag)
    return tag
end

local preproc, postproc = default_pre_hook, default_post_hook

local function default_pronouns_handler(player, pronouns_tag)
    local tag = player:get_player_name()
    if preproc then tag = preproc(player) end

    if pronouns_tag and pronouns_tag:len() > 0 then
        tag = ("%s (%s)"):format(tag, pronouns_tag)
    end

    if postproc then tag = postproc(player, tag) end

    local props = player:get_properties()
    if tag ~= props.nametag then
        player:set_properties({nametag = tag})
    end
end

local pronouns_handler = default_pronouns_handler

-- Sets or unsets a preprocessing hook (pre) and a postprocessing hook (post),
-- returning the old values.
--
-- * pre(player) - Returns a nametag for the given player, without any pronouns added.
--   With no hook, the player's name is used.
-- * post(player, tag) - Returns a final nametag for the given player, where the tag
--   parameter is the pronoun-adjusted nametag "<name> (<pronoun1>/<pronoun2>/...)".
--   With no hook, the tag isn't modified.
--
-- These hooks are designed for compatibility with other mods that set players'
-- nametags, and/or that want to filter certain strings if the restricted pronoun
-- whitelist isn't being used.
--
-- Alternately, a whole different pronouns handler function can be set (see
-- pronouns.set_pronouns_handler), in which case it is up to the mod which defines that
-- handler function whether it uses these hooks or ignores them.
function pronouns.set_nametag_hooks(pre, post)
    local old_pre, old_post = preproc, postproc
    preproc, postproc = pre, post
    for _, player in ipairs(minetest.get_connected_players()) do
        update_player_tag(player)
    end
    return old_pre, old_post
end

-- Sets a handler function handlerf(player, pronouns_tag) which is called when a player
-- joins, their pronoun list is changed, or this function is called.  Returns the old
-- handler function.  The pronouns_tag argument will be nil if the player's list of
-- pronouns is empty.
--
-- The default handler uses the pre and post hooks (see pronouns.set_nametag_hooks) to
-- determine the name portion of the nametag (pre hook), construct a
-- "<name> (<pronouns>)" nametag, modify that tag (post hook), and set the nametag by
-- modifying the player ObjectRef properties.
function pronouns.set_pronouns_handler(handlerf)
    local old = pronouns_handler
    if handlerf ~= old then
        pronouns_handler = handlerf
        for _, player in ipairs(minetest.get_connected_players()) do
            update_player_tag(player)
        end
    end
    return old
end


-- Player Pronouns

update_player_tag = function(player)  -- local declared above
    local pname
    if type(player) == "string" then
        player, pname = minetest.get_player_by_name(player), player
    else
        pname = player:get_player_name()
    end
    if not player or not pname then return end

    local ppro, changed = player_pronouns[pname], false
    if not ppro then
        ppro = {}
        player_pronouns[pname] = ppro
        save_player_pronouns()
    end

    local plist = unique_list_from_lists_and_sets(ppro.set or {})

    local hf = pronouns_handler or default_pronouns_handler
    hf(player, #plist > 0 and table.concat(plist, "/") or nil)
end

minetest.register_on_joinplayer(update_player_tag)

-- Returns a (copied) list or set of pronoun strings for the player.
function pronouns.get(player)
    local pname = player_to_name(player)
    if not pname then return nil end

    return copy_list_or_set((player_pronouns[pname] or {}).set or {})
end

-- Returns a (copied) set of approved pronoun strings for the player.
function pronouns.get_approved(player)
    local pname = player_to_name(player)
    if not pname then return nil end

    return copy_list_or_set((player_pronouns[pname] or {}).approved or {})
end

-- Sets the list of a player's pronouns.
--
-- pronouns is a list or set of pronouns.
--
-- approved can be a list or set of approved pronouns for the player, or some other
-- truthy value indicating that pronouns should also be used as the approved set.
--
-- Returns old values for pronouns, approved (the former a list or set, the latter a
-- set).
function pronouns.set(player_name, pronouns, approved)
    local ppro = player_pronouns[player_name]
    if not ppro then
        ppro = {}
        player_pronouns[player_name] = ppro
    end

    local old_pros, pros_changed = ppro.set or {}, false
    if pronouns[1] then
        pronouns = unique_list_from_lists_and_sets(pronouns)
        if old_pros[1] then
            pros_changed = not lists_equal(pronouns, old_pros)
        else
            pros_changed = true
        end
    else
        pronouns = set_from_lists_and_sets(pronouns)
        if old_pros[1] then
            pros_changed = true
        else
            pros_changed = not sets_equal(pronouns, old_pros)
        end
    end
    if pros_changed then
        ppro.set = pronouns
    else
        old_pros = copy_list_or_set(old_pros)
    end

    local old_aset, aset, aset_changed = ppro.approved or {}, {}, false
    if approved then
        if type(approved) == "table" then
            aset = set_from_lists_and_sets(approved)
        else
            aset = set_from_lists_and_sets(pronouns)
        end
        aset_changed = not sets_equal(aset, old_aset)
    end
    if aset_changed then
        ppro.approved = aset
    else
        old_aset = copy_list_or_set(old_aset)
    end

    if pros_changed or aset_changed then
        save_player_pronouns()
    end

    local player = minetest.get_player_by_name(player_name)
    if player then update_player_tag(player) end

    return old_pros, old_aset
end

-- Adds pros (a list or set of pronouns) to the list of a player's pronouns.
--
-- If with_approval is true, pros is also added to the player's list of approved
-- pronouns.
--
-- Returns old values for pronouns, approved (the former a list or set, the latter a
-- set).
function pronouns.add(player_name, pros, with_approval)
    local ppro = player_pronouns[player_name] or {}

    local plist = unique_list_from_lists_and_sets(ppro.set or {}, pros)

    local aset = nil
    if with_approval then
        aset = set_from_lists_and_sets(ppro.approved or {}, pros)
    end

    return pronouns.set(player_name, plist, aset)
end

-- Removes pros (a list or set of pronouns) from the list of a player's pronouns.
--
-- If with_approval is true, pros is also removed from the player's list of approved
-- pronouns.
--
-- Returns old values for pronouns, approved (the former a list or set, the latter a
-- set).
function pronouns.remove(player_name, pros, with_approval)
    local ppro = player_pronouns[player_name] or {}

    local rset = set_from_lists_and_sets(pros)

    local old, new = ppro.set or {}, {}
    if old[1] then
        for _, p in ipairs(old) do
            if not rset[p] then new[#new+1] = p end
        end
    else
        for p in pairs(old) do
            if not rset[p] then new[p] = true end
        end
    end

    local aset = nil
    if with_approval then
        aset = {}
        for p in pairs(ppro.approved or {}) do
            if not rset[p] then aset[p] = true end
        end
    end

    return pronouns.set(player_name, new, aset)
end


-- Commands

-- Parses a list of pronouns from str.  Anything within quotes (") is used as-is
-- (except whitespace is always normalized to a single space).  Pronouns are otherwise
-- separated by whitespace and/or slashes (/).
function pronouns.parse(str)
    local args = {}

    local i, n, arg, in_arg, in_quote = 1, #str, "", false, false
    while i and i <= n do
        if not in_arg then
            local si, ei, c = str:find("([^%s/])", i)
            if not si then
                break
            elseif c == "\"" then
                arg = ""
                i, in_arg, in_quote = ei+1, true, true
            else
                arg = c
                i, in_arg = ei+1, true
            end
        elseif not in_quote then
            local si, ei, c = str:find("([\"%s/])", i)
            if not si then
                args[#args+1] = arg..str:sub(i)
                in_arg = false
                break
            elseif c == "\"" then
                arg = arg..str:sub(i, si-1)
                i, in_quote = ei+1, true
            else
                args[#args+1] = arg..str:sub(i, si-1)
                i, in_arg = ei+1, false
            end
        else
            local si, ei, c, ni, nc = str:find("([\"\\])()(.?)", i)
            if not si then
                args[#args+1] = arg..str:sub(i)
                in_arg = false
                break
            elseif c == "\"" then
                arg = arg..str:sub(i, si-1)
                i, in_quote = ni, false
            else
                arg = arg..str:sub(i, si-1)..nc
                i = ei+1
            end
        end
    end
    if in_arg and arg:len() > 0 then
        args[#args+1] = arg
    end

    local pronouns = {}
    for _, arg in ipairs(args) do
        arg = normalize_space(trim_space(arg))
        if arg:len() > 0 then pronouns[#pronouns+1] = arg end
    end

    return pronouns
end

minetest.register_chatcommand("pronounsconf", {
    params =
        "["..
         "max-length <n> | "..
         "max-total-length <n> | "..
         "restrict <bool> | "..
         "approve [add|remove] <pronouns>"..
        "]",

    description = "Configure pronoun restrictions.",

    privs = {pronouns = true},

    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return true, nil end

        param = trim_space(param)

        local function output()
            local ser, err = minetest.write_json(settings, true)
            if ser then
                return true, ser
            else
                return false, (
                    "-!- Error serializing pronoun settings: %s"
                ):format(err)
            end
        end

        do
            local si, ei = param:find("^max[_-]?length%s+")
            if si then
                pronouns.set_max_length(param:sub(ei+1))
                return output()
            end
        end
        do
            local si, ei = param:find("^max[_-]?total[_-]?length%s+")
            if si then
                pronouns.set_max_total_length(param:sub(ei+1))
                return output()
            end
        end
        do
            local si, ei = param:find("^restricted%s+")
            if not si then
                si, ei = param:find("^restrict%s+")
            end
            if si then
                param = param:sub(ei+1):lower()
                pronouns.set_restricted(
                    ({["1"] = true, ["t"] = true, ["true"] = true})[param] or false
                )
                return output()
            end
        end
        do
            local si, ei, op = param:find("^preapproved?%s+")
            if not si then
                si, ei, op = param:find("^approved?%s+")
            end
            if si then
                param = param:sub(ei+1)

                local setf   = pronouns.set_preapproved
                local si, ei = param:find("^add%s+")
                if si then
                    setf, param = pronouns.add_preapproved, param:sub(ei+1)
                else
                    si, ei = param:find("^remove%s+")
                    if si then
                        setf, param = pronouns.remove_preapproved, param:sub(ei+1)
                    end
                end

                setf(pronouns.parse(param))
                return output()
            end
        end
        do
            if param:len() > 0 then
                return false, "-!- Invalid subcommand"
            end
        end
        return output()
    end,
})

minetest.register_chatcommand("pronouns", {
    params = "[for <player>] [[add|remove] <pronouns>]",

    description = "Set or show your pronouns or those for <player>.",

    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return true, nil end

        param = trim_space(param)

        local target = name
        do
            local si, ei, tname = param:find("^for%s+([^%s]+)%s+")
            if not si then
                si, ei, tname = param:find("^for%s+([^%s]+)$")
            end
            if si then
                target, param = tname, param:sub(ei+1)
            end
        end

        local _, privileged, _ = pronouns.check_privs(player, target)

        local function output()
            local who = target == name and "Your" or target.."'s"
            local plist = unique_list_from_lists_and_sets(pronouns.get(target))
            local pdesc = #plist > 0 and table.concat(plist, "/") or "unspecified"

            local adesc = nil
            if privileged or target == name then
                local alist = unique_list_from_lists_and_sets(
                    pronouns.get_approved(target), settings.preapproved
                )
                if #alist > 0 then adesc = table.concat(alist, "/") end
            end

            local msg = ("%s pronouns are %s"):format(who, pdesc)
            if adesc then
                msg = msg..(" (approved: %s)"):format(adesc)
            end
            return true, msg
        end

        do
            local si, ei = param:find("^add%s+")
            if si then
                local plist  = pronouns.parse(param:sub(ei+1))
                local allowed, err = pronouns.can_add(player, target, plist)
                if not allowed then
                    return false, "-!- "..err
                end
                pronouns.add(target, plist, privileged)
                return output()
            end
        end
        do
            local si, ei = param:find("^remove%s+")
            if si then
                local plist = pronouns.parse(param:sub(ei+1))
                local allowed, err = pronouns.can_remove(player, target, plist)
                if not allowed then
                    return false, "-!- "..err
                end
                pronouns.remove(target, plist, privileged)
                return output()
            end
        end
        do
            if param:len() > 0 then
                local plist = pronouns.parse(param)
                local allowed, err = pronouns.can_set(player, target, plist)
                if not allowed then
                    return false, "-!- "..err
                end
                pronouns.set(target, plist, privileged)
                return output()
            end
        end
        return output()
    end,
})
