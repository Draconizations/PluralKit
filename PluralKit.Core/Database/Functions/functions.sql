﻿create function message_context(account_id bigint, guild_id bigint, channel_id bigint)
    returns table (
        system_id int,
        log_channel bigint,
        in_blacklist bool,
        in_log_blacklist bool,
        log_cleanup_enabled bool,
        proxy_enabled bool,
        autoproxy_mode int,
        autoproxy_member int,
        last_message bigint,
        last_message_member int,
        last_switch int,
        last_switch_members int[],
        last_switch_timestamp timestamp,
        system_tag text,
        system_avatar text
    )
as $$
    with
        system as (select systems.* from accounts inner join systems on systems.id = accounts.system where accounts.uid = account_id),
        guild as (select * from servers where id = guild_id),
        last_message as (select * from messages where messages.guild = guild_id and messages.sender = account_id order by mid desc limit 1)
    select
        system.id as system_id,
        guild.log_channel,
        (channel_id = any(guild.blacklist)) as in_blacklist,
        (channel_id = any(guild.log_blacklist)) as in_log_blacklist,
        guild.log_cleanup_enabled,
        coalesce(system_guild.proxy_enabled, true) as proxy_enabled,
        coalesce(system_guild.autoproxy_mode, 1) as autoproxy_mode,
        system_guild.autoproxy_member,
        last_message.mid as last_message,
        last_message.member as last_message_member,
        system_last_switch.switch as last_switch,
        system_last_switch.members as last_switch_members,
        system_last_switch.timestamp as last_switch_timestamp,
        system.tag as system_tag,
        system.avatar_url as system_avatar
    from system
        full join guild on true
        left join last_message on true
        
        left join system_last_switch on system_last_switch.system = system.id
        left join system_guild on system_guild.system = system.id and system_guild.guild = guild_id
$$ language sql stable rows 1;


-- Fetches info about proxying related to a given account/guild
-- Returns one row per member in system, should be used in conjuction with `message_context` too
create function proxy_members(account_id bigint, guild_id bigint)
    returns table (
        id int,
        proxy_tags proxy_tag[],
        keep_proxy bool,
        
        server_name text,
        display_name text,
        name text,
        
        server_avatar text,
        avatar text
    )
as $$
    select
        -- Basic data
        members.id as id,
        members.proxy_tags as proxy_tags,
        members.keep_proxy as keep_proxy,
    
        -- Name info
        member_guild.display_name as server_name,
        members.display_name as display_name,
        members.name as name,
        
        -- Avatar info
        member_guild.avatar_url as server_avatar,
        members.avatar_url as avatar
    from accounts
        inner join systems on systems.id = accounts.system
        inner join members on members.system = systems.id
        left join member_guild on member_guild.member = members.id and member_guild.guild = guild_id
    where accounts.uid = account_id
$$ language sql stable rows 10;


create function generate_hid() returns text as $$
    select string_agg(substr('abcdefghijklmnopqrstuvwxyz', ceil(random() * 26)::integer, 1), '') from generate_series(1, 5)
$$ language sql volatile;


create function find_free_system_hid() returns text as $$
declare new_hid text;
begin
    loop
        new_hid := generate_hid();
        if not exists (select 1 from systems where hid = new_hid) then return new_hid; end if;
    end loop;
end
$$ language plpgsql volatile;


create function find_free_member_hid() returns text as $$
declare new_hid text;
begin
    loop
        new_hid := generate_hid();
        if not exists (select 1 from members where hid = new_hid) then return new_hid; end if;
    end loop;
end
$$ language plpgsql volatile;