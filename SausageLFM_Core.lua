-- SausageLFM_Core.lua
local addonName, L = ...
SausageLFM = CreateFrame("Frame", "SausageLFM_CoreFrame", UIParent)
local SLFM = SausageLFM

-- PREMENNÉ A DATABÁZA
SLFM.Version = ""
SLFM.Queue = {}
SLFM.RaidData = {}
SLFM.History = {}
SLFM.IsFlooding = false
SLFM.CurrentMsg = ""
local inspectQueue = {}
local lastFlood, lastInspect = 0, 0
local InCombat = false

local defaults = {
    interval = 45,
    minGS = 0,
    instance = "ICC",
    mode = "25",
    isHC = false,
    reqAchiev = false,
    channels = { ["World"] = true, ["Global"] = true },
    targets = {} -- Neskôr sa naplní specmi
}

-- 🧠 1. GS ROUTER & VERIFICATION ENGINE
function SLFM:GetExternalGS(playerName)
    -- Hľadá v GS_Data (GearScore Lite / 3.1.20)
    local realm = GetRealmName()
    if GS_Data and GS_Data[realm] and GS_Data[realm].Players and GS_Data[realm].Players[playerName] then
        return tonumber(GS_Data[realm].Players[playerName].GearScore) or 0
    end
    return 0 -- Nenájdené v externom addone
end

function SLFM:VerifyPlayer(unit)
    if InCombat then return end
    local name = UnitName(unit)
    if not name then return end

    local pvpCount, isFakeGS, isFakeAchiev = 0, false, false
    local gs = self:GetExternalGS(name)
    
    -- PvP Scan (Base-Item Trick: odrezanie enchantov a gemov)
    for i = 1, 18 do
        local link = GetInventoryItemLink(unit, i)
        if link then
            local itemID = link:match("item:(%d+)")
            if itemID then
                local baseLink = "item:"..itemID..":0:0:0:0:0:0:0"
                local stats = GetItemStats(baseLink)
                if stats and stats["ITEM_MOD_RESILIENCE_RATING_SHORT"] then
                    pvpCount = pvpCount + 1
                end
            end
        end
    end

    -- Uloženie overeného stavu
    SLFM.RaidData[name] = SLFM.RaidData[name] or {}
    SLFM.RaidData[name].pvp = pvpCount
    SLFM.RaidData[name].gs = gs > 0 and gs or SLFM.RaidData[name].gs
    SLFM.RaidData[name].verified = true

    -- Vyhodnotenie "Lebky Hanby"
    local skullReason = nil
    if pvpCount >= 3 then skullReason = "Equipped " .. pvpCount .. " PvP Items." end
    if SausageLFM_DB.minGS > 0 and SLFM.RaidData[name].gs > 0 and SLFM.RaidData[name].gs < SausageLFM_DB.minGS then
        skullReason = "GS is below required minimum (" .. SausageLFM_DB.minGS .. ")."
    end

    SLFM.RaidData[name].skull = skullReason
    
    -- P2P Broadcast (Ghost Mode Sync)
    local p2pMsg = "V:"..name..":"..SLFM.RaidData[name].gs..":"..(skullReason and "1" or "0")
    SendAddonMessage("SAUSAGELFM", p2pMsg, "RAID")

    self:RefreshRaidTable()
    self:RefreshQueueTable()
end

-- 💧 2. TRICKLE INSPECT QUEUE & COMBAT LOCKDOWN
SLFM:SetScript("OnUpdate", function(self, elapsed)
    if InCombat then return end

    -- Flood Engine
    if SLFM.IsFlooding then
        lastFlood = lastFlood + elapsed
        if lastFlood >= SausageLFM_DB.interval then
            self:UpdateMessage()
            for chan, active in pairs(SausageLFM_DB.channels) do
                if active then
                    local id = GetChannelName(chan)
                    if id > 0 then SendChatMessage(SLFM.CurrentMsg, "CHANNEL", nil, id) end
                end
            end
            lastFlood = 0
        end
    end

    -- Trickle Inspect (každé 2 sekundy maximálne 1 sken)
    lastInspect = lastInspect + elapsed
    if lastInspect > 2.0 and #inspectQueue > 0 then
        local unit = table.remove(inspectQueue, 1)
        if CanInspect(unit) and CheckInteractDistance(unit, 1) then
            NotifyInspect(unit)
            lastInspect = 0
        end
    end
end)

-- 🛡️ 3. SMART MESSAGE BUILDER
function SLFM:UpdateMessage()
    local db = SausageLFM_DB
    local count = GetNumRaidMembers() > 0 and GetNumRaidMembers() or 1
    local msg = "LFM " .. db.instance .. " " .. db.mode .. (db.isHC and " HC" or "") .. " ("..count.."/".. (db.mode:find("10") and 10 or 25) ..")"
    
    local needs = ""
    for spec, target in pairs(db.targets) do
        if target > 0 then needs = needs .. target .. "x " .. spec .. ", " end
    end
    
    if db.minGS > 0 then msg = msg .. " | Req: " .. db.minGS .. "+ GS" end
    if db.reqAchiev then msg = msg .. " & Achiev" end
    
    SLFM.CurrentMsg = msg .. " - Need: " .. (needs ~= "" and needs:gsub(", $", "") or "PUMPERS") .. " | w me spec/gs!"
    if SausageLFM_Main and SausageLFM_Main.preview then SausageLFM_Main.preview:SetText(SLFM.CurrentMsg) end
end

-- ⚙️ 4. EVENT MANAGER (WIM Bridge & Parser)
SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")
SLFM:RegisterEvent("INSPECT_READY")
SLFM:RegisterEvent("PLAYER_REGEN_DISABLED")
SLFM:RegisterEvent("PLAYER_REGEN_ENABLED")
SLFM:RegisterEvent("CHAT_MSG_ADDON")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        if IsRaidLeader() or IsRaidOfficer() or GetNumRaidMembers() == 0 then
            self:InitializeUI()
            self:UpdateMessage()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then InCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then InCombat = false
    elseif event == "INSPECT_READY" then
        local guid = ...
        if guid == UnitGUID("target") then self:VerifyPlayer("target") end
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        -- WIM Ochrana & Ukladanie Histórie
        SLFM.History[sender] = SLFM.History[sender] or {}
        table.insert(SLFM.History[sender], "|cff00ff00[Them]:|r " .. msg)
        
        -- Smart Parser
        msg = msg:lower()
        local gsMatch = msg:match("(%d[%.%,]?%d?)k") or msg:match("(%d%d%d%d)")
        local gs = 0
        if gsMatch then gs = tonumber((gsMatch:gsub(",", "."))); if gs < 100 then gs = gs * 1000 end end
        
        -- Zápis do Fronty
        local isNew = true
        for _, q in ipairs(SLFM.Queue) do if q.name == sender then isNew = false; q.gs = gs > 0 and gs or q.gs; q.unread = true break end end
        if isNew then table.insert(SLFM.Queue, 1, { name = sender, raw = msg, gs = gs, unread = true, ds = msg:find("/") ~= nil }) end
        
        if #SLFM.Queue > 15 then table.remove(SLFM.Queue) end
        self:RefreshQueueTable()
    
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, _, sender = ...
        if prefix == "SAUSAGELFM" and sender ~= UnitName("player") then
            -- Spracovanie P2P dát od Assistov/Ghostov
            local cmd, pName, pGs, pSkull = strsplit(":", msg)
            if cmd == "V" then
                SLFM.RaidData[pName] = SLFM.RaidData[pName] or {}
                SLFM.RaidData[pName].gs = tonumber(pGs)
                SLFM.RaidData[pName].skull = pSkull == "1" and "Flagged by Network" or nil
                SLFM.RaidData[pName].verified = true
                self:RefreshRaidTable()
            end
        end
    end
end)

-- -----------------------------------------------------------------------------
-- 🚀 THE IGNITION & SECURITY (Minimap & Slash Command)
-- -----------------------------------------------------------------------------

-- Bezpečnostná kontrola: Kto môže vidieť UI?
local function CanManageLFM()
    if GetNumRaidMembers() == 0 then return true end -- Sólo alebo normálna Party (môže testovať)
    if IsRaidLeader() or IsRaidOfficer() then return true end -- RL alebo Assist
    return false -- Basic Member
end

-- Ikonka na minimape (Sausage Button)
local miniBtn = CreateFrame("Button", "SausageLFM_MinimapBtn", Minimap)
miniBtn:SetSize(32, 32)
miniBtn:SetFrameStrata("MEDIUM")
miniBtn:SetFrameLevel(8)
miniBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, -50) -- Pozícia na minimape
miniBtn:SetNormalTexture("Interface\\Icons\\Inv_Misc_Food_54") -- Ikonka jedla/klobásy
miniBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Blizzard okraj pre ikonku, nech to vyzerá natívne
local border = miniBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT", miniBtn, "TOPLEFT", -10, 10)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Hlavný spúšťač
local function ToggleSausageUI()
    if not CanManageLFM() then
        print("|cffffd200Sausage|rLFM: Si bežný člen raidu (Ghost Agent). UI je skryté a chránené.")
        return
    end

    -- Ak UI ešte neexistuje, vytvoríme ho
    if not SausageLFM_Main then 
        SLFM:InitializeUI() 
    end

    -- Zobraziť / Skryť
    if SausageLFM_Main:IsShown() then 
        SausageLFM_Main:Hide() 
    else 
        SausageLFM_Main:Show() 
        SLFM:RefreshRaidTable()
        SLFM:RefreshQueueTable()
    end
end

-- Kliknutie na minimapu
miniBtn:SetScript("OnClick", ToggleSausageUI)

