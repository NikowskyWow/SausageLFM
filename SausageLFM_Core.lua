-- SausageLFM_Core.lua
local addonName, L = ...
SausageLFM = CreateFrame("Frame", "SausageLFM_CoreFrame", UIParent)
local SLFM = SausageLFM

SLFM.Version = "1.11.0"
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
    channels = { World = false, Global = false, LFG = false, Party = true }
}

local abbr = {
    ["Icecrown Citadel"] = "ICC", ["Ruby Sanctum"] = "RS", ["Trial of the Crusader"] = "ToC",
    ["Ulduar"] = "Ulduar", ["Naxxramas"] = "Naxx", ["The Obsidian Sanctum"] = "OS",
    ["The Eye of Eternity"] = "EoE", ["Vault of Archavon"] = "VoA", ["Dungeon"] = "Dung",
    ["Random Heroic"] = "RHC", ["Daily Heroic"] = "Daily HC", ["Forge of Souls"] = "FoS",
    ["Pit of Saron"] = "PoS", ["Halls of Reflection"] = "HoR", ["Trial of the Champion"] = "ToC5",
    ["Utgarde Keep"] = "UK", ["The Nexus"] = "Nexus", ["Azjol-Nerub"] = "AN",
    ["Ahn'kahet: The Old Kingdom"] = "AK", ["Drak'Tharon Keep"] = "DTK", ["The Violet Hold"] = "VH",
    ["Gundrak"] = "GD", ["Halls of Stone"] = "HoS", ["Halls of Lightning"] = "HoL",
    ["Utgarde Pinnacle"] = "UP", ["The Oculus"] = "Oculus", ["The Culling of Stratholme"] = "CoS"
}

-- Slovník pre Smart Math (aby addon vedel, že Warlock je rDPS a odpočítal ho)
local SpecToRole = {
    ["Holy Paladin"] = "Heal", ["Prot Paladin"] = "Tank", ["Ret Paladin"] = "mDPS",
    ["Resto Shaman"] = "Heal", ["Ele Shaman"] = "rDPS", ["Enhance Shaman"] = "mDPS",
    ["Resto Druid"] = "Heal", ["Feral Druid"] = "mDPS", ["Boomkin"] = "rDPS",
    ["Disc Priest"] = "Heal", ["Holy Priest"] = "Heal", ["Shadow Priest"] = "rDPS",
    ["Affli Warlock"] = "rDPS", ["Demo Warlock"] = "rDPS", ["Destro Warlock"] = "rDPS",
    ["Arcane Mage"] = "rDPS", ["Fire Mage"] = "rDPS", ["Frost Mage"] = "rDPS",
    ["BM Hunter"] = "rDPS", ["MM Hunter"] = "rDPS", ["Surv Hunter"] = "rDPS",
    ["Assa Rogue"] = "mDPS", ["Combat Rogue"] = "mDPS", ["Sub Rogue"] = "mDPS",
    ["Prot Warrior"] = "Tank", ["Arms Warrior"] = "mDPS", ["Fury Warrior"] = "mDPS",
    ["Blood Death Knight"] = "Tank", ["Frost Death Knight"] = "mDPS", ["Unholy Death Knight"] = "mDPS"
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

function SLFM:GetExternalGS(name)
    if GearScore_GetScore then 
        local gs = GearScore_GetScore(name)
        if gs and gs > 0 then return gs end
    end
    local realm = GetRealmName()
    if GS_Data and GS_Data[realm] and GS_Data[realm].Players and GS_Data[realm].Players[name] then
        return tonumber(GS_Data[realm].Players[name].GearScore) or 0
    end
    return 0
end

function SLFM:UpdateMessage()
    local db = SausageLFM_DB
    local count = GetNumRaidMembers() > 0 and GetNumRaidMembers() or (GetNumPartyMembers() > 0 and GetNumPartyMembers() + 1 or 1)
    
    if db.instance ~= "Dungeon" and db.mode ~= "10" and db.mode ~= "25" then db.mode = "25" end

    -- 1. Zrátame ľudí v raide podľa rolí
    local current = { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 }
    for name, data in pairs(SLFM.RaidData) do
        if data.role and current[data.role] then
            current[data.role] = current[data.role] + 1
        end
    end

    -- 2. Smart Math: Odpočítame špecifické specy od základného targetu
    local neededGeneric = { Tank = db.roles.Tank or 0, Heal = db.roles.Heal or 0, mDPS = db.roles.mDPS or 0, rDPS = db.roles.rDPS or 0 }
    local neededSpecific = {}
    
    for spec, target in pairs(db.specs) do
        if target > 0 then
            neededSpecific[spec] = target
            local parentRole = SpecToRole[spec]
            
            -- Fallback pre Generic Roles (napr. "Melee DPS (OS Tank)")
            if not parentRole then
                if spec:find("Tank") then parentRole = "Tank"
                elseif spec:find("Healer") then parentRole = "Heal"
                elseif spec:find("Melee") then parentRole = "mDPS"
                elseif spec:find("Ranged") then parentRole = "rDPS" end
            end

            if parentRole and neededGeneric[parentRole] then
                neededGeneric[parentRole] = math.max(0, neededGeneric[parentRole] - target)
            end
        end
    end

    -- 3. Odpočítame ľudí, ktorí už v raide sú
    for role, target in pairs(neededGeneric) do
        neededGeneric[role] = math.max(0, target - current[role])
    end

    local instName = abbr[db.instance] or db.instance
    local modeName = abbr[db.mode] or db.mode
    local msg = ""

    if db.instance == "Dungeon" then
        msg = "LFM " .. modeName .. (db.isHC and " HC" or "") .. " (" .. count .. "/5)"
    else
        msg = "LFM " .. instName .. " " .. modeName .. (db.isHC and " HC" or "") .. " (" .. count .. "/" .. ((db.mode == "10") and 10 or 25) .. ")"
    end
    
    local needs = ""
    if neededGeneric.Tank > 0 then needs = needs .. neededGeneric.Tank .. "x Tank, " end
    if neededGeneric.Heal > 0 then needs = needs .. neededGeneric.Heal .. "x Heal, " end
    if neededGeneric.mDPS > 0 then needs = needs .. neededGeneric.mDPS .. "x mDPS, " end
    if neededGeneric.rDPS > 0 then needs = needs .. neededGeneric.rDPS .. "x rDPS, " end
    
    for spec, t in pairs(neededSpecific) do
        needs = needs .. t .. "x " .. spec .. ", "
    end
    
    if db.minGS > 0 then msg = msg .. " - Req: " .. db.minGS .. "+ GS" end
    if db.reqAchiev then msg = msg .. " & Achiev" end
    
    SLFM.CurrentMsg = msg .. " - Need: " .. (needs ~= "" and needs:gsub(", $", "") or "PUMPERS") .. " - w me spec/gs!"
    if SausageLFM_Main and SausageLFM_Main.preview then SausageLFM_Main.preview:SetText(SLFM.CurrentMsg) end
end

local function GetSpecName(unit, group)
    local _, class = UnitClass(unit)
    if not class or not ClassTalents[class] then return "Unknown" end
    local maxPts, specIdx = 0, 0
    for i=1, 3 do
        local _, _, pts = GetTalentTabInfo(i, true, false, group)
        if pts > maxPts then maxPts = pts; specIdx = i end
    end
    return ClassTalents[class][specIdx] or "Unknown"
end

SLFM:SetScript("OnUpdate", function(self, elapsed)
    if SLFM.IsFlooding then
        SLFM.lastFlood = SLFM.lastFlood + elapsed
        if SLFM.lastFlood >= (SausageLFM_DB.interval or 45) then
            self:UpdateMessage()
            for chan, active in pairs(SausageLFM_DB.channels) do
                if active then
                    if chan == "Party" and GetNumPartyMembers() > 0 then SendChatMessage(SLFM.CurrentMsg, "PARTY")
                    else
                        local id = GetChannelName(chan)
                        if id > 0 then SendChatMessage(SLFM.CurrentMsg, "CHANNEL", nil, id) end
                    end
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
            SLFM.CurrentInspectUnit = unit
            NotifyInspect(unit) 
        end
        SLFM.lastInspect = 0
    elseif SLFM.lastInspect > 5 then
        SLFM.CurrentInspectUnit = nil -- Timeout poistka
    end
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

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        local inGroup = {}
        local isRaid = GetNumRaidMembers() > 0
        
        if isRaid then
            for i=1, GetNumRaidMembers() do
                local n = GetRaidRosterInfo(i)
                if n then 
                    inGroup[n] = true 
                    if not SLFM.RaidData[n] then table.insert(SLFM.InspectQueue, "raid"..i) end
                end
            end
        else
            for i=1, GetNumPartyMembers() do
                local n = UnitName("party"..i)
                if n then 
                    inGroup[n] = true
                    if not SLFM.RaidData[n] then table.insert(SLFM.InspectQueue, "party"..i) end
                end
            end
            local pName = (UnitName("player"))
            inGroup[pName] = true
            if not SLFM.RaidData[pName] then table.insert(SLFM.InspectQueue, "player") end
        end

        for i = #SLFM.Queue, 1, -1 do
            local qName = SLFM.Queue[i].name
            if inGroup[qName] then
                SLFM.RaidData[qName] = SLFM.RaidData[qName] or {}
                if not SLFM.RaidData[qName].role or SLFM.RaidData[qName].role == "Uncategorized" then
                    SLFM.RaidData[qName].role = SLFM.Queue[i].role or "Uncategorized"
                end
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
                local s1 = GetSpecName(SLFM.CurrentInspectUnit, 1)
                local s2 = GetSpecName(SLFM.CurrentInspectUnit, 2)
                if s2 ~= "Unknown" and s2 ~= s1 then
                    SLFM.RaidData[name].talents = s1 .. "/" .. s2
                else
                    SLFM.RaidData[name].talents = s1
                end
            end
        end
        SLFM.CurrentInspectUnit = nil
        if self.RefreshRaidTable then self:RefreshRaidTable() end

    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        local lmsg = msg:lower()
        
        local gsMatch = lmsg:match("(%d[%.%,]?%d?)k") or lmsg:match("(%d%d%d%d)")
        local gs = 0
        if gsMatch then 
            gs = tonumber((gsMatch:gsub(",", ".")))
            if gs and gs < 100 then gs = gs * 1000 end
        end

        local detectedRole = "Uncategorized"
        local detectedSpecStr = ""
        
        if lmsg:find("tank") or lmsg:find("prot") or lmsg:find("blood") or lmsg:find("bear") then detectedRole = "Tank" end
        if lmsg:find("heal") or lmsg:find("resto") or lmsg:find("holy") or lmsg:find("disc") or lmsg:find("tree") then detectedRole = "Healer" end
        if lmsg:find("dps") or lmsg:find("ret") or lmsg:find("shadow") or lmsg:find("boom") or lmsg:find("feral") or lmsg:find("rogue") or lmsg:find("mage") or lmsg:find("lock") or lmsg:find("hunt") or lmsg:find("ele") or lmsg:find("enh") or lmsg:find("warr") or lmsg:find("dk") then detectedRole = "DPS" end
        
        local specKeywords = {"prot", "ret", "holy", "resto", "feral", "boom", "shadow", "disc", "blood", "frost", "unholy", "ele", "enh", "tree", "bear"}
        for _, s in ipairs(specKeywords) do
            if lmsg:find(s) then detectedSpecStr = s; break end
        end

        local isNew = true
        for _, q in ipairs(SLFM.Queue) do
            if q.name == sender then 
                isNew = false
                q.gs = gs > 0 and gs or q.gs
                if detectedRole ~= "Uncategorized" then q.role = detectedRole end
                if detectedSpecStr ~= "" then q.spec = detectedSpecStr end
                break 
            end
        end
        
        if isNew then
            table.insert(SLFM.Queue, 1, { name = sender, gs = gs, role = detectedRole, spec = detectedSpecStr, unread = true })
            if #SLFM.Queue > 15 then table.remove(SLFM.Queue) end
        end
        if self.RefreshQueueTable then self:RefreshQueueTable() end
    end
end)

local btn = CreateFrame("Button", "SausageLFM_Minimap", Minimap)
btn:SetSize(32, 32); btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, -50)
btn:SetNormalTexture("Interface\\Icons\\Inv_Misc_Food_54")
btn:SetScript("OnClick", function()
    if not SausageLFM_Main then SLFM:InitializeUI() end
    if SausageLFM_Main:IsShown() then SausageLFM_Main:Hide() else SausageLFM_Main:Show() end
end)