do
-- Will leave the group if be added
local function run(msg, matches)
local bot_id = 12029465
   -- like local bot_id = 1234567
    if matches[1] == 'leave' and is_sudo(msg) then
       chat_del_user("chat#id"..msg.to.id, 'user#id'..bot_id, ok_cb, false)
    elseif msg.action.type == "chat_add_user" and msg.action.user.id == tonumber(bot_id) and not is_sudo(msg) then
       send_large_msg("chat#id"..msg.to.id, 'kose nanat n/n bokone nanatam n/n nabinam azin gohi bokhori n/n madafucker n/n  this is not one of my groups.', ok_cb, false)
       chat_del_user("chat#id"..msg.to.id, 'user#id'..bot_id, ok_cb, false)
    end
end
 
return {
  patterns = {
    "^[!/](leave)$",
    "^!!tgservice (.+)$",
  },
  run = run
}
end
