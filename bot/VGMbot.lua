package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  -- vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "stats",
    "anti_spam",
    "owners",
    "arabic_lock",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "echo1",
    "echo",
    "calculator",
    "autoleave1",
    "autoleave",
    "antilink",
    "anti_spam",
    "anti-link",
    "Welcome",
    "MemberManager",
    "Spammer",
    "floodcontrol",
    "linkpv",
    "locksticker",
    "translate",
    "time",
    "tagall",
    "plugins"
    },
    sudo_users = {122835592,159887854,0,tonumber(our_id)},--Sudo users
    disabled_channels = {},
    realm = {},--Realms Id
    moderation = {data = 'data/moderation.json'},
    about_text = [[The King Manager

EN
Manager Your Groups
Admin Of Bot
@alireza_PT [ Developer& manager]

FA
مدیر گروه های شما
ادمین 
@alireza_PT [سازنده ومدیر]
]],
    help_text = [[
Commands list :
(لیست دستورات)

!kick [username|id]🚷
You can also do it by reply👤
(اخراج{آیدی}از گروه) 🔹قابل استفاده با ریپلی🔹

!ban [ username|id]⬇️
You can also do it by reply👤
(بن{آیدی فرد}مورد نظر) 🔹قابل استفاده با ریپلی🔹

!unban [id]⬆️
You can also do it by reply👤
(خارج کردن از بن{آیدی فرد}مورد نظر) 🔹قابل استفاده با ریپلی🔹

!banall @UserName or (user_id)🚫
you Can do it By Replay 👤
(بن کردن فرد مورد نظر از تمامی گروه ها) 🔹قابل استفاده با ریپلی🔹

!unbanall 🆔User_Id🆔
(خارج کردن فرد مورد نظر از بن آل)

!who🤔
Members list
(لیست افراد و اطلاعات آن ها)

!modlist🗒
Moderators list
(لیست مدیران گروه)

!promote [username]🔵
Promote someone
(ارتقا مقام{آیدی فرد}مورد نظر به مدیریت گروه)

!demote [username]🔴
Demote someone
(سلب مقام{آیدی فرد}مورد نظر از مدیریت گروه)

!kickme👋🏼
Will kick user
(اخراح کردن من از گروه)

!about📃
Group description
(درباره گروه)

!setphoto✔️
Set and locks group photo
(تنظیم عکس)

!setname [name]✔️
Set group name
(تنظیم اسم)

!rules❌
Group rules
(قوانین)

!id🆔
return group id or user id
(آیدی فرد مورد نظر)

!help📄
(راهنما برای استفاده از دستورات)

!lock [member|name|bots]🔒
Locks [member|name|arabic|bots]
(قفل کردن{ورود به گروه-نام گروه-ربات ها}در گروه)

!unlock [member|name|photo|bots]🔓
Unlocks [member|name|photo|arabic|bots]
(باز کردن{ورود به گروه-نام گروه-عکس گروه-عربی-ربات ها}در گروه)

!set rules <text>✏️
Set <text> as rules
(تنظیم قوانین{متن}مورد نظر)

!set about <text>📌
Set <text> as about
(تنظیم درباره{متن}مورد نظر)

!settings⚙
Returns group settings
(تنظیمات گروه)

!newlink🖋
create/revoke your group link
(دریافت لینک جدید برای گروه)

!link🗞
returns group link
(لینک گروه)

!linkpv : 🔐
To give the invitation Link of group in Bots PV.
(هنگام استفاده ربات لینک گروه را به pv ارسال میکند)

!echo <text>🗣
(با استفاده از این دستور هر چه را که بخواهید ربات تکرار میکند)

!invite [ @username ]✋🏻
(دعوت کردن [آیدی فرد مورد نظر] به گروه)

!plugins😏
(برای نمایش لیست پلاگین های موجود) 🔹قابلیت فعال و غیر فعال سازی🔹

!time [local]🕗
(نشان دادن ساعت و تاریخ فعلی مکان مورد نظر)

!calc <number> [+ × ÷ -]📱
(ماشین حساب!قابلیت استفاده از 4 عمل اصلی ریاضی)

!spam😈
(تبدیل حالت ربات ضد اسپن به اسپمر!)


!owner😎
returns group owner id
(اونر گروه)

!setowner [id]🤓
Will set id as owner
(تنظیم کردن اونر{آیدی}شخص)

!setflood [value]🔒
Set [value] as flood sensitivity
(تنظیم حساسیت نسبت به اسپم)

!stats📈
Simple message statistics
(اطلاعات گروه)

!save [value] <text>📥
Save <text> as [value]
(ذخیره {عدد} و {متن} دلخواه)

!get [value]🚀
Returns text of [value]
(رفتن به {عدد}مورد نظر)

!clean [modlist|rules|about]🌪
Will clear [modlist|rules|about] and set it to nil
(برای پاک کردن مدیران-قوانین-درباره گروه)

!res [username]🔍
returns user id
"!res @username"
(اطلاعات آیدی)

!log🚶
will return group logs
(آمار ورود و خروج)

!banlist😡
will return group ban list
(لیست بن شده ها)

**U can use both "/" and "!"😉
شما میتوانید از "/" و "!" برای دستورات استفاده کنید


*فقط اونر ها میتوانند ربات در گروه اد کنند


*فقط مدیران و اونر ها میتوانند از دستورات اخراج از گروه-بن-خارج کردن از بن-لینک جدید-لینک-تنظیم عکس-تنظیم اسم-قفل کردن-باز کردن-تنظیم کردن قوانین-تنظیم کردن اطلاعات و دستور تنظیمات استفاده کنند

*فقط اونر ها میتوانند از دستورات درباره ارتقا درجه-گرفتن درجه و دستور لوگ استفاده کنند

]]

  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
