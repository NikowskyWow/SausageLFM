-- SausageLFM_Core.lua
local addonName, L = ...
SausageLFM = CreateFrame("Frame", "SausageLFM_CoreFrame", UIParent)
local SLFM = SausageLFM

SLFM.Version = "1.16.1"
SLFM.Queue = {}
SLFM.RaidData = {}
SLFM.History = {}
SLFM.IsFlooding = false
SLFM.CurrentMsg = ""
SLFM.lastFlood = 0
SLFM.InspectQueue = {}
SLFM.CurrentInspectUnit = nil

local defaults = {
    interval = 45, minGS = 0, instance = "Icecrown Citadel", mode = "25",
    isHC = false, reqAchiev = false,
    roles = { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 },
    specs = {},
    channels = { World = false, Global = false, LFG = false, Party = true },
    whitelist = {} -- V16 Whitelist
}

local SpecToRole = {
    ["Holy"] = "Heal", ["Prot"] = "Tank", ["Ret"] = "mDPS",
    ["Resto"] = "Heal", ["Ele"] = "rDPS", ["Enh"] = "mDPS",
    ["Boom"] = "rDPS", ["Feral"] = "mDPS",
    ["Disc"] = "Heal", ["Shadow"] = "rDPS",
    ["Affli"] = "rDPS", ["Demo"] = "rDPS", ["Destro"] = "rDPS",
    ["Arcane"] = "rDPS", ["Fire"] = "rDPS", ["Frost"] = "rDPS",
    ["BM"] = "rDPS", ["MM"] = "rDPS", ["Surv"] = "rDPS",
    ["Assa"] = "mDPS", ["Combat"] = "mDPS", ["Sub"] = "mDPS",
    ["Arms"] = "mDPS", ["Fury"] = "mDPS",
    ["Blood"] = "Tank", ["Unholy"] = "mDPS"
}

local ClassTalents = {
    ["PALADIN"] = { [1]="Holy", [2]="Prot", [3]="Ret" },
    ["WARRIOR"] = { [1]="Arms", [2]="Fury", [3]="Prot" },
    ["DEATHKNIGHT"] = { [1]="Blood", [2]="Frost", [3]="Unholy" },
    ["SHAMAN"] = { [1]="Ele", [2]="Enh", [3]="Resto" },
    ["DRUID"] = { [1]="Boom", [2]="Feral", [3]="Resto" },
    ["PRIEST"] = { [1]="Disc", [2]="Holy", [3]="Shadow" },
    ["WARLOCK"] = { [1]="Affli", [2]="Demo", [3]="Destro" },
    ["MAGE"] = { [1]="Arcane", [2]="Fire", [3]="Frost" },
    ["HUNTER"] = { [1]="BM", [2]="MM", [3]="Surv" },
    ["ROGUE"] = { [1]="Assa", [2]="Combat", [3]="Sub" }
}

-- Neviditeľný Tooltip pre skenovanie PvP itemov bez enchantov
local ScanTT = CreateFrame("GameTooltip", "SLFM_ScanTT", nil, "GameTooltipTemplate")
ScanTT:SetOwner(WorldFrame, "ANCHOR_NONE")

-- V16 PvP Base Item Scanner (Ignoruje enchanty a gemy)
local function HasBaseResilience(itemLink)
    if not itemLink then return false end
    local itemID = itemLink:match("item:(%d+)")
    if not itemID then return false end
    
    local baseLink = "item:" .. itemID .. ":0:0:0:0:0:0:0:80"
    ScanTT:ClearLines()
    ScanTT:SetHyperlink(baseLink)
    
    for i = 2, ScanTT:NumLines() do
        local text = _G["SLFM_ScanTTTextLeft"..i]:GetText()
        if text and text:find("Resilience") then
            return true
        end
    end
    return false
end

-- V16 GEARSCORELITE HOOKER
function SLFM:GetExternalGS(name)
    local gs = 0
    if type(GearScore_GetScore) == "function" then
        local targetUnit = (name == UnitName("player")) and "player" or name
        local rawGS = GearScore_GetScore(name, targetUnit)
        if rawGS and type(rawGS) == "number" and rawGS > 0 then return rawGS end
    end
    local realm = GetRealmName()
    if GS_Data and GS_Data[realm] and GS_Data[realm].Players and GS_Data[realm].Players[name] then
        gs = tonumber(GS_Data[realm].Players[name].GearScore) or 0
        if gs > 0 then return gs end
    end
    return 0
end

-- V16 WARNING MATRIX
function SLFM:GetWarnings(name, gs, role, msgIsPvP)
    local warnings = {}
    if SausageLFM_DB.whitelist and SausageLFM_DB.whitelist[name] then return warnings end -- Whitelist Ignorácia

    -- 1. Low GS
    if gs and gs > 0 and SausageLFM_DB.minGS > 0 and gs < SausageLFM_DB.minGS then
        table.insert(warnings, "Low GearScore: " .. gs .. " (Req: " .. SausageLFM_DB.minGS .. ")")
    end

    local pData = SLFM.RaidData[name] or {}

    -- 2. PvP Gear Detekcia
    if pData.pvpItems and pData.pvpItems > 1 then
        table.insert(warnings, "PvP Gear detected! (" .. pData.pvpItems .. " pure PvP items equipped)")
    elseif msgIsPvP then
        table.insert(warnings, "Player mentioned PvP in whisper")
    end

    -- 3. Role Mismatch
    if role and role ~= "Uncategorized" and pData.activeSpec then
        local expectedRole = SpecToRole[pData.activeSpec]
        if expectedRole and expectedRole ~= role then
            if expectedRole == "mDPS" and role == "Tank" then
                -- Ignorujeme
            else
                table.insert(warnings, "Wrong Gear/Spec! Assigned: " .. role .. ", Active Spec: " .. pData.activeSpec)
            end
        end
    end

    return warnings
end

function SLFM:UpdateMessage()
    local db = SausageLFM_DB
    local count = GetNumRaidMembers() > 0 and GetNumRaidMembers() or (GetNumPartyMembers() > 0 and GetNumPartyMembers() + 1 or 1)
    if db.instance ~= "Dungeon" and db.mode ~= "10" and db.mode ~= "25" then db.mode = "25" end

    local current = { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 }
    for name, data in pairs(SLFM.RaidData) do
        if data.role and current[data.role] then current[data.role] = current[data.role] + 1 end
    end

    local neededGeneric = { Tank = db.roles.Tank or 0, Heal = db.roles.Heal or 0, mDPS = db.roles.mDPS or 0, rDPS = db.roles.rDPS or 0 }
    local neededSpecific = {}
    for spec, target in pairs(db.specs) do
        if target > 0 then
            neededSpecific[spec] = target
            local cleanSpec = spec:match("^(.-) %(") or spec
            local parentRole = SpecToRole[cleanSpec]
            if not parentRole then
                if cleanSpec == "Tank" then parentRole = "Tank" elseif cleanSpec == "Healer" then parentRole = "Heal" elseif cleanSpec == "Melee DPS" then parentRole = "mDPS" elseif cleanSpec == "Ranged DPS" then parentRole = "rDPS" end
            end
            if parentRole and neededGeneric[parentRole] then neededGeneric[parentRole] = math.max(0, neededGeneric[parentRole] - target) end
        end
    end

    for role, target in pairs(neededGeneric) do neededGeneric[role] = math.max(0, target - current[role]) end

    local modeName = (db.instance == "Dungeon") and db.mode or (db.instance .. " " .. db.mode)
    local msg = "LFM " .. modeName .. (db.isHC and " HC" or "") .. " (" .. count .. "/" .. ((db.instance == "Dungeon") and 5 or ((db.mode == "10") and 10 or 25)) .. ")"
    
    local needs = ""
    if neededGeneric.Tank > 0 then needs = needs .. neededGeneric.Tank .. "x Tank, " end
    if neededGeneric.Heal > 0 then needs = needs .. neededGeneric.Heal .. "x Heal, " end
    if neededGeneric.mDPS > 0 then needs = needs .. neededGeneric.mDPS .. "x mDPS, " end
    if neededGeneric.rDPS > 0 then needs = needs .. neededGeneric.rDPS .. "x rDPS, " end
    for spec, t in pairs(neededSpecific) do needs = needs .. t .. "x " .. spec .. ", " end
    
    if db.minGS > 0 then msg = msg .. " - Req: " .. db.minGS .. "+ GS" end
    if db.reqAchiev then msg = msg .. " & Achiev" end
    SLFM.CurrentMsg = msg .. " - Need: " .. (needs ~= "" and needs:gsub(", $", "") or "PUMPERS") .. " - w me spec/gs!"
    if SausageLFM_Main and SausageLFM_Main.preview then SausageLFM_Main.preview:SetText(SLFM.CurrentMsg) end
end

local function GetSpecName(unit, group)
    local _, class = UnitClass(unit)
    if not class or not ClassTalents[class] then return "" end
    local maxPts, specIdx = 0, 0
    for i=1, 3 do
        local _, _, pts = GetTalentTabInfo(i, true, false, group)
        if pts and pts > maxPts then maxPts = pts; specIdx = i end
    end
    return ClassTalents[class][specIdx] or ""
end

SLFM:SetScript("OnUpdate", function(self, elapsed)
    if SLFM.IsFlooding then
        SLFM.lastFlood = SLFM.lastFlood + elapsed
        if SLFM.lastFlood >= (SausageLFM_DB.interval or 45) then
            self:UpdateMessage()
            for chan, active in pairs(SausageLFM_DB.channels) do
                if active then
                    local id = GetChannelName(chan)
                    if id > 0 then SendChatMessage(SLFM.CurrentMsg, "CHANNEL", nil, id) end
                end
            end
            SLFM.lastFlood = 0
        end
    end

    if not SLFM.lastInspect then SLFM.lastInspect = 0 end
    SLFM.lastInspect = SLFM.lastInspect + elapsed
    if SLFM.lastInspect > 2 and #SLFM.InspectQueue > 0 and not SLFM.CurrentInspectUnit then
        local unit = table.remove(SLFM.InspectQueue, 1)
        if UnitExists(unit) and CanInspect(unit) then 
            SLFM.CurrentInspectUnit = unit; NotifyInspect(unit) 
        end
        SLFM.lastInspect = 0
    elseif SLFM.lastInspect > 5 then SLFM.CurrentInspectUnit = nil end
end)

SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")
SLFM:RegisterEvent("RAID_ROSTER_UPDATE")
SLFM:RegisterEvent("PARTY_MEMBERS_CHANGED")
SLFM:RegisterEvent("INSPECT_TALENT_READY")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        SausageLFM_DB.roles = SausageLFM_DB.roles or { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 }
        SausageLFM_DB.specs = SausageLFM_DB.specs or {}
        SausageLFM_DB.channels = SausageLFM_DB.channels or { World = false, Global = false, LFG = false, Party = true }
        SausageLFM_DB.interval = SausageLFM_DB.interval or 45
        SausageLFM_DB.whitelist = SausageLFM_DB.whitelist or {}

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        local inGroup = {}
        local count = GetNumRaidMembers()
        if count > 0 then
            for i=1, count do local n = GetRaidRosterInfo(i); if n then inGroup[n] = true; if not SLFM.RaidData[n] then table.insert(SLFM.InspectQueue, "raid"..i) end end end
        else
            for i=1, GetNumPartyMembers() do local n = UnitName("party"..i); if n then inGroup[n] = true; if not SLFM.RaidData[n] then table.insert(SLFM.InspectQueue, "party"..i) end end end
            local pName = UnitName("player")
            inGroup[pName] = true
            if not SLFM.RaidData[pName] then table.insert(SLFM.InspectQueue, "player") end
        end

        for i = #SLFM.Queue, 1, -1 do
            local qName = SLFM.Queue[i].name
            if inGroup[qName] then
                SLFM.RaidData[qName] = SLFM.RaidData[qName] or {}
                if not SLFM.RaidData[qName].role or SLFM.RaidData[qName].role == "Uncategorized" then SLFM.RaidData[qName].role = SLFM.Queue[i].role or "Uncategorized" end
                table.remove(SLFM.Queue, i)
            end
        end
        if self.RefreshQueueTable then self:RefreshQueueTable() end
        if self.RefreshRaidTable then self:RefreshRaidTable() end
        self:UpdateMessage()

    elseif event == "INSPECT_TALENT_READY" then
        if SLFM.CurrentInspectUnit and UnitExists(SLFM.CurrentInspectUnit) then
            local name = UnitName(SLFM.CurrentInspectUnit)
            if name then
                SLFM.RaidData[name] = SLFM.RaidData[name] or {}
                
                local numGroups = GetNumTalentGroups(true) or 1
                local activeGroup = GetActiveTalentGroup(true) or 1
                local activeSpec = GetSpecName(SLFM.CurrentInspectUnit, activeGroup)
                
                SLFM.RaidData[name].activeSpec = activeSpec
                
                if numGroups > 1 then
                    local offGroup = (activeGroup == 1) and 2 or 1
                    local offSpec = GetSpecName(SLFM.CurrentInspectUnit, offGroup)
                    if offSpec ~= "" and offSpec ~= activeSpec then
                        SLFM.RaidData[name].talents = activeSpec .. "/" .. offSpec
                    else
                        SLFM.RaidData[name].talents = activeSpec
                    end
                else
                    SLFM.RaidData[name].talents = activeSpec
                end

                local pvpCount = 0
                for i = 1, 19 do
                    local link = GetInventoryItemLink(SLFM.CurrentInspectUnit, i)
                    if link and HasBaseResilience(link) then
                        pvpCount = pvpCount + 1
                    end
                end
                SLFM.RaidData[name].pvpItems = pvpCount
            end
        end
        SLFM.CurrentInspectUnit = nil
        if self.RefreshRaidTable then self:RefreshRaidTable() end

    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender, _, _, _, _, _, _, _, _, _, guid = ...
        local lmsg = msg:lower()
        
        local gsMatch = lmsg:match("(%d[%.%,]%d?)%s*k") or lmsg:match("(%d[%.%,]%d?)%s*gs") or lmsg:match("(%d%s)k") or lmsg:match("(%d%s)gs") or lmsg:match("(%d%d%d%d)")
        local gs = 0
        if gsMatch then 
            gs = tonumber((gsMatch:gsub(",", ".")))
            if gs and gs < 100 then gs = gs * 1000 end
        end

        local detectedRole = "Uncategorized"
        if lmsg:find("tank") or lmsg:find("prot") or lmsg:find("blood") or lmsg:find("bear") then detectedRole = "Tank" end
        if lmsg:find("heal") or lmsg:find("resto") or lmsg:find("holy") or lmsg:find("disc") or lmsg:find("tree") then detectedRole = "Heal" end
        if lmsg:find("mdps") or lmsg:find("melee") or lmsg:find("ret") or lmsg:find("feral") or lmsg:find("rogue") or lmsg:find("enh") or lmsg:find("warr") or lmsg:find("dk") then detectedRole = "mDPS" end
        if lmsg:find("rdps") or lmsg:find("ranged") or lmsg:find("shadow") or lmsg:find("boom") or lmsg:find("mage") or lmsg:find("lock") or lmsg:find("hunt") or lmsg:find("ele") then detectedRole = "rDPS" end
        
        local specKeywords = {"prot", "ret", "holy", "resto", "feral", "boom", "shadow", "disc", "blood", "frost", "unholy", "ele", "enh", "tree", "bear", "assa", "combat", "sub", "arcane", "fire", "destro", "demo", "affli", "bm", "mm", "surv", "arms", "fury"}
        local foundSpecs = {}
        for _, s in ipairs(specKeywords) do
            local pos = lmsg:find(s)
            if pos then table.insert(foundSpecs, {name=s, pos=pos}) end
        end
        table.sort(foundSpecs, function(a,b) return a.pos < b.pos end)

        local detectedSpecStr = ""
        local detectedOSStr = ""
        if #foundSpecs > 0 then detectedSpecStr = foundSpecs[1].name end
        if #foundSpecs > 1 then detectedOSStr = foundSpecs[2].name end

        local hasAchi = false
        if msg:upper():find("|HACHIEVEMENT:") then
            local hexGuid = (guid and type(guid) == "string") and string.sub(guid, 3) or ""
            hexGuid = string.upper(hexGuid)
            if hexGuid ~= "" and msg:upper():find(hexGuid) then hasAchi = true end
        end

        local isPvP = false
        if lmsg:find("pvp") or lmsg:find("resil") then isPvP = true end

        local isNew = true
        for _, q in ipairs(SLFM.Queue) do
            if q.name == sender then 
                isNew = false; q.gs = gs > 0 and gs or q.gs; q.msg = msg
                if detectedRole ~= "Uncategorized" then q.role = detectedRole end
                if detectedSpecStr ~= "" then q.spec = detectedSpecStr end
                if detectedOSStr ~= "" then q.os = detectedOSStr end
                q.hasAchi = hasAchi; q.isPvP = isPvP
                break 
            end
        end
        
        if isNew then
            table.insert(SLFM.Queue, 1, { name = sender, gs = gs, role = detectedRole, spec = detectedSpecStr, os = detectedOSStr, hasAchi = hasAchi, isPvP = isPvP, msg = msg, unread = true })
            if #SLFM.Queue > 15 then table.remove(SLFM.Queue) end
        end
        if self.RefreshQueueTable then self:RefreshQueueTable() end
    end
end)

-- ==========================================
-- 🛡️ MINIMAP ICON
-- ==========================================
local btn = CreateFrame("Button", "SausageLFM_Minimap", Minimap)
btn:SetSize(32, 32)
btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, -50)
btn:SetNormalTexture("Interface\\Icons\\Inv_Misc_Food_54")
btn:SetScript("OnClick", function()
    if not SausageLFM_Main then SLFM:InitializeUI() end
    if SausageLFM_Main:IsShown() then SausageLFM_Main:Hide() else SausageLFM_Main:Show() end
end)