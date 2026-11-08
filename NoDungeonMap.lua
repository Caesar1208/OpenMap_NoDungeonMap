-- Turns off OpenMap's dungeon map (Map/Dungeons.lua) and hands OpenMap's dungeon
-- entrance icons over to Dungeon Journal (ForeverDungeonJournal): clicking one shows
-- Dungeon Journal's map of that dungeon on the world map, the same view it gives you
-- inside the dungeon. Right-click, its "World Map" button or Esc goes back.
-- No dungeon map in Dungeon Journal: its journal page for the dungeon opens instead.
--
-- Loads after both addons (## Dependencies / OptionalDeps) but before their
-- PLAYER_LOGIN setup, so everything below is in place before they wire anything up.

local ns = _G.OpenMap
local mod = ns and ns.GetModule and ns:GetModule("worldmap")
if not mod then
	print("|cffff6060OpenMap_NoDungeonMap|r: OpenMap not found, nothing done.")
	return
end

--------------------------------------------------------------------------------
-- 1. OpenMap's dungeon map off: no taking over the world map inside a dungeon,
--    no dungeon card or side panel, no preloading dungeon floor textures.
--------------------------------------------------------------------------------
mod.SetupDungeons = function() end
mod.HoldDungeonHere = function() end

--------------------------------------------------------------------------------
-- 2. Dungeon Journal's map on the world map, for a dungeon you're not in
--------------------------------------------------------------------------------
local FDJ = _G.ForeverDungeonJournal_NS
local preview            -- Dungeon Journal's name of the dungeon being shown, or nil

if FDJ and type(FDJ.RefreshWorldMapOverlay) == "function" then
	-- Its overlay shows the map of FDJ.CurrentDungeon(). Only while the overlay refreshes,
	-- and only while previewing, that answers the clicked dungeon (nothing else sees it).
	local refresh = FDJ.RefreshWorldMapOverlay
	FDJ.RefreshWorldMapOverlay = function(...)
		if not preview then return refresh(...) end
		local current = FDJ.CurrentDungeon
		FDJ.CurrentDungeon = function() return preview end
		local ok, err = pcall(refresh, ...)
		FDJ.CurrentDungeon = current
		if not ok then error(err, 0) end
	end
else
	FDJ = nil
end

local function HasMap(key) return FDJ and FDJ.DUNGEON_MAPS and FDJ.DUNGEON_MAPS[key] ~= nil end

-- The overlay went away (right-click, its World Map button, the map closed): preview over
local hookedBackdrop
local function WatchBackdrop()
	local journal = _G.ForeverDungeonJournalFrame
	local backdrop = journal and journal.dungeonMapPanel and journal.dungeonMapPanel:GetParent()
	if not backdrop or backdrop == journal or hookedBackdrop == backdrop then return end
	hookedBackdrop = backdrop
	backdrop:HookScript("OnHide", function()
		if not preview then return end
		preview = nil
		-- (its World Map / Dungeon Map button off again, unless you're in a dungeon)
		C_Timer.After(0, function()
			if WorldMapFrame and WorldMapFrame:IsShown() then pcall(FDJ.RefreshWorldMapOverlay) end
		end)
	end)
end

local function OpenJournalPage(key)
	if not (FDJ and FDJ.DB and FDJ.DB[key]) then return false end
	local frame, toggle = _G.ForeverDungeonJournalFrame, _G.ForeverDungeonJournal_Toggle
	if not (frame and frame:IsShown()) and type(toggle) == "function" then pcall(toggle) end
	if HasMap(key) and type(FDJ.OpenDungeonMap) == "function" then
		return (pcall(FDJ.OpenDungeonMap, key))
	end
	return type(FDJ.OpenBossPage) == "function" and (pcall(FDJ.OpenBossPage, key)) or false
end

local function ShowOnWorldMap(key)
	if not (HasMap(key) and WorldMapFrame and WorldMapFrame:IsShown()) then return false end
	if FDJ.IsDungeonMapLocked and FDJ.IsDungeonMapLocked(key) then return false end   -- (its RPG mode)
	local journal = _G.ForeverDungeonJournalFrame
	if journal and journal:IsShown() then return false end   -- (it's using its map panel itself)
	preview = key
	pcall(FDJ.RefreshWorldMapOverlay)
	if not FDJ.IsWorldMapOverlayAttached() then
		-- (switched to the world map earlier: its button switches back to the dungeon map)
		local button = _G.ForeverDungeonJournalWorldMapToggle
		if button and button:IsShown() then button:Click() end
	end
	if FDJ.IsWorldMapOverlayAttached() then
		WatchBackdrop()
		return true
	end
	preview = nil
	pcall(FDJ.RefreshWorldMapOverlay)
	return false
end

local function Open(key)
	if not ShowOnWorldMap(key) and not OpenJournalPage(key) then
		print("|cffe6b85cOpenMap_NoDungeonMap|r: Dungeon Journal has nothing for " .. key .. ".")
	end
end

--------------------------------------------------------------------------------
-- OpenMap's names for dungeons -> Dungeon Journal's
--------------------------------------------------------------------------------
local function Plain(name)
	return ((name or ""):lower():gsub("^the ", ""):gsub("%s*[-:]%s*", ": "))
end
local ALIAS = { ["stormwind stockade"] = "stockade" }

-- Dungeon Journal's dungeons for one of OpenMap's instances: by name, or its parts
-- ("Stratholme" -> "Stratholme: Living", "Stratholme: Undead")
local function JournalKeys(inst)
	local keys = {}
	if not (FDJ and FDJ.DB) then return keys end
	local want = Plain(inst[2])
	want = ALIAS[want] or want
	local exact, parts = nil, {}
	for key, entry in pairs(FDJ.DB) do
		if type(entry) == "table" and (not entry.previewOnly or HasMap(key)) then
			local p = Plain(key)
			if p == want then exact = key
			elseif p:sub(1, #want + 2) == want .. ": " then parts[#parts + 1] = key end
		end
	end
	if exact then keys[1] = exact return keys end
	table.sort(parts)
	return parts
end

--------------------------------------------------------------------------------
-- Several at one entrance (Scarlet Monastery's wings, Blackrock Mountain): pick one
--------------------------------------------------------------------------------
local chooser
local function Choose(pin, keys)
	if not chooser then
		chooser = CreateFrame("Frame", "OpenMapNoDungeonMapChooser", WorldMapFrame)
		chooser:SetFrameStrata("TOOLTIP")
		chooser:EnableMouse(true)
		local bg = chooser:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.05, 0.04, 0.03, 0.92)
		chooser.rows = {}
		WorldMapFrame:HookScript("OnHide", function() chooser:Hide() end)
	end
	local width = 160
	for i, key in ipairs(keys) do
		local row = chooser.rows[i]
		if not row then
			row = CreateFrame("Button", nil, chooser, "UIPanelButtonTemplate")
			row:SetHeight(22)
			row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 24)
			row:SetScript("OnClick", function(self) chooser:Hide() Open(self.key) end)
			chooser.rows[i] = row
		end
		row.key = key
		row:SetText(HasMap(key) and key or (key .. "  |cff999999(journal)|r"))
		width = math.max(width, (row:GetFontString():GetStringWidth() or 0) + 30)
		row:Show()
	end
	for i = #keys + 1, #chooser.rows do chooser.rows[i]:Hide() end
	for i = 1, #keys do chooser.rows[i]:SetWidth(width) end
	chooser:SetSize(width + 12, #keys * 24 + 10)
	chooser:ClearAllPoints()
	chooser:SetPoint("TOPLEFT", pin, "BOTTOMRIGHT", 2, 2)
	chooser:Show()
end

local function Click(pin)
	if GameTooltip then GameTooltip:Hide() end
	if chooser then chooser:Hide() end
	local keys, seen = {}, {}
	for _, inst in ipairs(pin.instances or {}) do
		for _, key in ipairs(JournalKeys(inst)) do
			if not seen[key] then seen[key] = true keys[#keys + 1] = key end
		end
	end
	if #keys == 0 then
		local names = {}
		for _, inst in ipairs(pin.instances or {}) do names[#names + 1] = inst[2] end
		print("|cffe6b85cOpenMap_NoDungeonMap|r: Dungeon Journal has nothing for " .. table.concat(names, ", ") .. ".")
	elseif #keys == 1 then
		Open(keys[1])
	else
		Choose(pin, keys)
	end
end

--------------------------------------------------------------------------------
-- 3. OpenMap's entrance icons: kept (tooltip, level range), their click is ours.
--    To hide them, untick "Dungeons and raids" in OpenMap's options.
--------------------------------------------------------------------------------
local S = ns.MapStitch
local build = S and S.BuildDungeonPins
if build then
	S.BuildDungeonPins = function(...)
		local pins = build(...)
		for _, pin in ipairs(pins) do pin.OnClick = FDJ and Click or nil end
		return pins
	end
end
