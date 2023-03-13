Pronouns Minetest Mod
=====================

This Minetest mod allows player to set displayed and queryable pronouns for themselves.
Pronouns appear parenthesized after the player's name in their in-world hovering
nametag.

Copyright and Licensing
-----------------------

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

Features
--------

* The mod persists server settings and player pronouns in mod storage.
* The order of a player's pronouns is preserved.
* There is a maximum length on each pronoun (e.g. "them").
* There is a maximum length of the combined pronoun string (e.g. "he/him/they/them").
* Pronouns can be limited to a restricted whitelist, for servers concerned about
  unrestricted chat and/or nametags.
* All of the above restrictions can be circumvented by moderators.
* The API allows overriding behavior, automation, and compatibility with other mods.

Basic Use
---------

To set your pronouns, use the command:

    /pronouns <pronouns>

where `<pronouns>` is a list of pornouns separated by spaces and/or slashes (/).

To add or remove pronouns to your existing list, use the commands:

    /pronouns add <pronouns>
    /pronouns remove <pronouns>

To see what pronouns you have set (and which are preapproved so they can be used
despite length restrictions or a restricted whitelist), use the command:

    /pronouns

To get the pronouns of someone else (like if you're only interacting with them in chat
and can't see their nametag), use the command:

    /pronouns for <player>

where `<player>` is the player's name.

Moderation
----------

A "moderator" for this mod is anyone with the "pronouns" privilege.  They may change
the configuration and set pronouns for other players.  Any pronoun a moderator
sets/adds for another player is remembered, and that player may make use of it when
changing their own pronouns (for example, if there is a length limit of 2 and the
"them" pronoun has not been preapproved, a moderator may add it to the list of a
player's pronouns, and the player may thereafter use it themself, even if they
temporarily remove it from their pronoun list).

To view and change the mod's settings, use the command:

    /pronounsconf

Each setting may be changed using an appropriate subcommand:

    /pronounsconf max-length <number>
    /pronounsconf max-total-length <number>
    /pronounsconf restrict (true|false)
    /pronounsconf approve <pronouns>
    /pronounsconf approve add <pronouns>
    /pronounsconf approve remove <pronouns>

See also (`/help pronounsconf`).

To set the pronouns for another player, use the commands:

    /pronouns for <player> <pronouns>
    /pronouns for <player> add <pronouns>
    /pronouns for <player> remove <pronouns>

This allows setting the pronouns of both online and offline players.  However, the
player must have logged into the server at some point while the pronouns mod was
installed/active, so that the mod knows the name represents a real player.

API
---

All API functions are available under the namespace `pronouns` (note that if the name
of the mod has been changed in `mod.conf`, this namespace will change too, so replace
`pronouns.…` below as appropriate in that case).

Many of the API functions have a "documentation comment" above them in the Lua source
code, so check there for more information.

### Settings

These are the API equivalent of the settings commands.

    pronouns.get_max_length()
    pronouns.set_max_length(max_len)
    pronouns.get_max_total_length()
    pronouns.set_max_total_length(max_len)
    pronouns.get_restricted()
    pronouns.set_restricted(bool)
    pronouns.get_preapproved()
    pronouns.set_preapproved(pronouns)
    pronouns.add_preapproved(pronouns)
    pronouns.remove_preapproved(pronouns)

### Permissions

These allow another mod to check whether an operation by one player on another is
allowed according to the semantics defined by this mod (including privilege checks,
length limits, and whitelist restrictions).  None of these checks are done by the API
functions which actually do the setting; cooperation between mods is assumed, so it is
presumed that if another mod "bypasses" the checks by failing to call these methods,
there is a good reason for it.

    pronouns.check_privs(actor, target)
    pronouns.can_set(actor, target, pros)
    pronouns.can_add(actor, target, pros)
    pronouns.can_remove(actor, target, pros)

### Nametag Hooks

This API function allows other mods to set "hooks" that will be called by this mod when
setting a player's nametag (this is done when the player logs in, their pronouns are
changed while they are logged in, or this function is called).

    pronouns.set_nametag_hooks(pre, post)

This is for both compatibility with other mods that set players' nametags, and for more
versatile filtering when desired.  For example, if a server's moderation team were
concerned about the pronoun sequence "she/it" being set for some reason, another mod
could use the post hook to post-process the whole `<name> (<pronouns>)` nametag string
to search for and somehow modify or remove that sequence.

The function returns the old pair of hooks, so the calling mod can call them in a
"chain of responsibility" type pattern when and if appropriate.  Note that using `nil`
for either hook will remove any existing one, so your mod may want to test the return
values and set the old hook back in place if it doesn't have one to install itself.

The whole mechanism of handling pronouns for logged in players can also be replaced by
setting a pronoun handler function using:

    pronouns.set_pronoun_handler(handlerf)

which allows another mod to replace or augment the use of the hooks and setting of the
player nametag property entirely.

### Player Pronouns

These are the API equivalents of the `/pronouns` commands.

    pronouns.get(player)
    pronouns.get_approved(player)
    pronouns.set(player_name, pronouns, approved)
    pronouns.add(player_name, pros, with_approval)
    pronouns.remove(player_name, pros, with_approval)
