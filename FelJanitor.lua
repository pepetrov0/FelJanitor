--[[ Fel Janitor - Soul Shard cleanup for WotLK 3.3.5
     Whenever the warlock is idle, deletes Soul Shards until only
     the configured minimum is left (10 by default). Loose shards are first
     moved into free soul bag slots; shards in a soul bag count toward the
     minimum but are never deleted - only loose ones in regular bags are.
     Nothing is ever deleted in combat. "Idle" means out of combat, not
     looting, casting or holding an item, and no vendor/bank/mail/trade/
     auction window open, for the delay (5 seconds by default).

     /fj on|off|toggle   enable or disable
     /fj min <n>         shards to keep
     /fj delay <s>       seconds you must be idle before a cleanup (default 5)
     /fj status          show what it is doing
     (long form: /feljanitor)

     File layout: Logging > Data > Shards > Events > Slash.
]]

local ADDON_NAME = ...
local _, MY_CLASS = UnitClass("player") -- never changes, so looked up once
local db
local SOUL_SHARD = 6265
local SOUL_BAG_FAMILY = 4 -- bagType bit for soul bags

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------
local TAG = "|cff9482c9Fel Janitor|r"
local ADDON_VERSION = GetAddOnMetadata("FelJanitor", "Version") or "?"
local function Log(msg) DEFAULT_CHAT_FRAME:AddMessage(TAG .. " " .. msg) end
local function LogLoad(hint) Log("v" .. ADDON_VERSION .. " loaded." .. (hint and (" " .. hint) or "")) end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local DEFAULTS = { enabled = true, minimum = 10, delay = 5 }
local MAX_DELAY = 60

local function InitDB()
	FelJanitorDB = FelJanitorDB or {}
	for k, v in pairs(DEFAULTS) do
		if FelJanitorDB[k] == nil then FelJanitorDB[k] = v end
	end
	db = FelJanitorDB
end

---------------------------------------------------------------------------
-- Shards
---------------------------------------------------------------------------
-- Scan the bags. Returns:
--   loose      unlocked shards in regular bags ({bag, slot}) - the only
--              ones that may be moved or deleted
--   total      every shard carried, soul bag and locked ones included
--   freeSoul   empty slots in soul bags ({bag, slot})
-- Locked shards are counted but not touched: they are already being moved
-- or deleted, and the next BAG_UPDATE recounts.
local function ScanBags()
	local loose, freeSoul, total = {}, {}, 0
	for bag = 0, NUM_BAG_SLOTS do
		local _, bagType = GetContainerNumFreeSlots(bag)
		local isSoulBag = bagType and bit.band(bagType, SOUL_BAG_FAMILY) ~= 0
		for slot = 1, GetContainerNumSlots(bag) do
			local itemID = GetContainerItemID(bag, slot)
			if itemID == SOUL_SHARD then
				total = total + 1
				local _, _, locked = GetContainerItemInfo(bag, slot)
				if not isSoulBag and not locked then
					table.insert(loose, { bag, slot })
				end
			elseif isSoulBag and not itemID and not GetContainerItemInfo(bag, slot) then
				table.insert(freeSoul, { bag, slot })
			end
		end
	end
	return loose, total, freeSoul
end

local function CountShards()
	return GetItemCount(SOUL_SHARD)
end

-- Move loose shards into empty soul bag slots. Returns how many moved.
local function MoveToSoulBags(loose, freeSoul)
	local moved = 0
	for i = 1, math.min(#loose, #freeSoul) do
		PickupContainerItem(loose[i][1], loose[i][2])
		local kind, itemID = GetCursorInfo()
		if kind ~= "item" or itemID ~= SOUL_SHARD then
			ClearCursor()
			break
		end
		PickupContainerItem(freeSoul[i][1], freeSoul[i][2])
		if CursorHasItem() then -- slot refused it; put the shard back and stop
			ClearCursor()
			break
		end
		moved = moved + 1
	end
	return moved
end

local lootOpen = false
local function Shown(f) return f and f:IsShown() end

-- Is the player doing something a cleanup would get in the way of?
local function PlayerBusy()
	if InCombatLockdown() or UnitAffectingCombat("player") then return true end
	if CursorHasItem() or GetCursorInfo() then return true end
	if SpellIsTargeting() or UnitCastingInfo("player") or UnitChannelInfo("player") then return true end
	if lootOpen or Shown(LootFrame) then return true end
	return Shown(MerchantFrame) or Shown(BankFrame) or Shown(GuildBankFrame) or Shown(TradeFrame)
		or Shown(MailFrame) or Shown(AuctionFrame) or Shown(StackSplitFrame) or false
end

-- Only when idle (see PlayerBusy): first move loose shards into soul bags,
-- then delete loose shards above the minimum. Shards in soul bags count
-- toward the minimum but are never deleted. Returns true if shards were
-- moved (the rest is handled by the sweep their BAG_UPDATE triggers).
local function Sweep()
	if not db or not db.enabled or MY_CLASS ~= "WARLOCK" then return end
	if PlayerBusy() then return end

	local loose, total, freeSoul = ScanBags()
	if #loose > 0 and #freeSoul > 0 then
		-- moved shards stay locked until the server confirms; the BAG_UPDATE
		-- that follows triggers another sweep to handle whatever is left
		if MoveToSoulBags(loose, freeSoul) > 0 then return true end
	end

	local excess = math.min(total - db.minimum, #loose)
	local deleted = 0
	for i = 1, excess do
		local bag, slot = loose[i][1], loose[i][2]
		PickupContainerItem(bag, slot)
		local kind, itemID = GetCursorInfo()
		if kind == "item" and itemID == SOUL_SHARD then
			DeleteCursorItem()
			deleted = deleted + 1
		else
			ClearCursor() -- not ours after all; put it back and stop
			break
		end
	end
	if deleted > 0 and db.verbose then
		Log(string.format("deleted %d Soul Shard%s.", deleted, deleted == 1 and "" or "s"))
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local POLL = 0.5
-- pending: a sweep is waiting for the player to go idle.
-- lastBusy: the last time the player was busy (or the bags changed).
-- followUntil: our own soul bag moves fire BAG_UPDATE; until then those don't
-- restart the idle delay, so the deletes follow the moves straight away.
local pending, lastBusy, followUntil, acc = false, 0, 0, 0

-- Ask for a sweep once the player has been idle for db.delay seconds.
-- BAG_UPDATE fires once per bag, often several in a row; they all just
-- restart the wait.
local function Queue()
	if not db or not db.enabled or MY_CLASS ~= "WARLOCK" then return end
	local now = GetTime()
	if now > followUntil then lastBusy = now end
	pending = true
	frame:Show()
end

frame:Hide()
frame:SetScript("OnUpdate", function(self, elapsed)
	acc = acc + elapsed
	if acc < POLL then return end
	acc = 0
	if not pending then return self:Hide() end
	local now = GetTime()
	if PlayerBusy() then lastBusy = now; return end
	if now - lastBusy < db.delay then return end
	pending = false
	if Sweep() then followUntil = now + 2 end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_CLOSED")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		InitDB()
		self:UnregisterEvent("ADDON_LOADED")
		if MY_CLASS == "WARLOCK" then
			LogLoad("Keeping " .. db.minimum .. " Soul Shards. /fj for options.")
		else
			LogLoad("only warlocks carry shards; Fel Janitor sits idle on this character.")
		end
		return
	end
	if event == "LOOT_OPENED" then lootOpen = true; return end
	if event == "LOOT_CLOSED" then lootOpen = false end
	-- combat ended, loot closed, bags changed, or a zone-in: tidy up once idle
	Queue()
end)

---------------------------------------------------------------------------
-- Status & slash command
---------------------------------------------------------------------------
local function Status()
	local state = db.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"
	if MY_CLASS ~= "WARLOCK" then
		Log("Fel Janitor is " .. state .. ", but this character is not a warlock, so it sits idle.")
		return
	end
	local when = UnitAffectingCombat("player") and "in combat" or "out of combat"
	Log(string.format("Fel Janitor is %s (%s). Keeping %d; carrying %d Soul Shards. Idle delay %ss.",
		state, when, db.minimum, CountShards(), db.delay))
end

local function PrintHelp()
	Log("commands:")
	DEFAULT_CHAT_FRAME:AddMessage("  /fj on | off | toggle  - enable or disable")
	DEFAULT_CHAT_FRAME:AddMessage("  /fj min <n>  - Soul Shards to keep (default 10)")
	DEFAULT_CHAT_FRAME:AddMessage("  /fj delay <seconds>  - how long you must be idle before a cleanup (default 5)")
	DEFAULT_CHAT_FRAME:AddMessage("  /fj verbose  - report each cleanup in chat")
	DEFAULT_CHAT_FRAME:AddMessage("  /fj status  - show what it is doing")
end

SLASH_FELJANITOR1 = "/feljanitor"
SLASH_FELJANITOR2 = "/fj"
SlashCmdList["FELJANITOR"] = function(msg)
	if not db then return end

	local cmd, arg = strlower(strtrim(msg or "")):match("^(%S*)%s*(.-)$")
	if cmd == "on" then
		db.enabled = true
		Status()
		Queue()
	elseif cmd == "off" then
		db.enabled = false
		Status()
	elseif cmd == "toggle" then
		db.enabled = not db.enabled
		Status()
		Queue()
	elseif cmd == "min" then
		local n = tonumber(arg)
		if not n or n < 0 or n ~= math.floor(n) then
			Log("usage: /fj min <whole number, 0 or more>  (now " .. db.minimum .. ")")
			return
		end
		db.minimum = n
		Status()
		Queue()
	elseif cmd == "delay" then
		local n = tonumber(arg)
		if not n or n < 1 or n > MAX_DELAY then
			Log("usage: /fj delay <seconds, 1 to " .. MAX_DELAY .. ">  (now " .. db.delay .. ")")
			return
		end
		db.delay = n
		Status()
		Queue()
	elseif cmd == "verbose" then
		db.verbose = not db.verbose
		Log("cleanup reports " .. (db.verbose and "on." or "off."))
	elseif cmd == "status" then
		Status()
	else
		Status()
		PrintHelp()
	end
end
