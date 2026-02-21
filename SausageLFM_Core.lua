-- SausageLFM_Core.lua
local addonName, L = ...
SausageLFM = CreateFrame("Frame", "SausageLFM_CoreFrame", UIParent)
local SLFM = SausageLFM

SLFM.Version = "1.10.1"
SLFM.Queue = {}
SLFM.RaidData = {}
SLFM.History = {}
SLFM.IsFlooding = false
SLFM.CurrentMsg = ""
SLFM.lastFlood = 0

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

function SLFM:GetExternalGS(name)
    local realm = GetRealmName()
    if GS_Data and GS_Data[realm] and GS_Data[realm].Players and GS_Data[realm].Players[name] then
        return tonumber(GS_Data[realm].Players[name].GearScore) or 0
    end
    return 0
end

function SLFM:UpdateMessage()
    local db = SausageLFM_DB
    local count = GetNumRaidMembers() > 0 and GetNumRaidMembers() or (GetNumPartyMembers() > 0 and GetNumPartyMembers() + 1 or 1)
    
    -- BEZPEČNOSTNÁ POISTKA: Nedovolí mať nezmyselný mód (napr. Naxx VH)
    if db.instance ~= "Dungeon" and db.mode ~= "10" and db.mode ~= "25" then
        db.mode = "25"
    end

    local instName = abbr[db.instance] or db.instance
    local modeName = abbr[db.mode] or db.mode
    local maxCount = 25
    local msg = ""

    if db.instance == "Dungeon" then
        maxCount = 5
        msg = "LFM " .. modeName .. (db.isHC and " HC" or "") .. " (" .. count .. "/" .. maxCount .. ")"
    else
        maxCount = (db.mode == "10") and 10 or 25
        msg = "LFM " .. instName .. " " .. modeName .. (db.isHC and " HC" or "") .. " (" .. count .. "/" .. maxCount .. ")"
    end
    
    local needs = ""
    if db.roles.Tank > 0 then needs = needs .. db.roles.Tank .. "x Tank, " end
    if db.roles.Heal > 0 then needs = needs .. db.roles.Heal .. "x Heal, " end
    if db.roles.mDPS > 0 then needs = needs .. db.roles.mDPS .. "x mDPS, " end
    if db.roles.rDPS > 0 then needs = needs .. db.roles.rDPS .. "x rDPS, " end
    
    for spec, target in pairs(db.specs) do
        if target > 0 then needs = needs .. target .. "x " .. spec .. ", " end
    end
    
    -- OPRAVA INVALID ESCAPE CODE: Vymenené všetky `|` za `-`
    if db.minGS > 0 then msg = msg .. " - Req: " .. db.minGS .. "+ GS" end
    if db.reqAchiev then msg = msg .. " & Achiev" end
    
    SLFM.CurrentMsg = msg .. " - Need: " .. (needs ~= "" and needs:gsub(", $", "") or "PUMPERS") .. " - w me spec/gs!"
    if SausageLFM_Main and SausageLFM_Main.preview then SausageLFM_Main.preview:SetText(SLFM.CurrentMsg) end
end

SLFM:SetScript("OnUpdate", function(self, elapsed)
    if not SLFM.IsFlooding then return end
    SLFM.lastFlood = SLFM.lastFlood + elapsed
    if SLFM.lastFlood >= (SausageLFM_DB.interval or 45) then
        self:UpdateMessage()
        for chan, active in pairs(SausageLFM_DB.channels) do
            if active then
                if chan == "Party" then
                    if GetNumPartyMembers() > 0 then SendChatMessage(SLFM.CurrentMsg, "PARTY") end
                else
                    local id = GetChannelName(chan)
                    if id > 0 then SendChatMessage(SLFM.CurrentMsg, "CHANNEL", nil, id) end
                end
            end
        end
        SLFM.lastFlood = 0
    end
end)

SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")
SLFM:RegisterEvent("RAID_ROSTER_UPDATE")
SLFM:RegisterEvent("PARTY_MEMBERS_CHANGED")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        SausageLFM_DB.roles = SausageLFM_DB.roles or { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 }
        SausageLFM_DB.specs = SausageLFM_DB.specs or {}
        SausageLFM_DB.channels = SausageLFM_DB.channels or { World = false, Global = false, LFG = false, Party = true }
        SausageLFM_DB.interval = SausageLFM_DB.interval or 45
        
        local fixMap = {
            ["ICC"] = "Icecrown Citadel", ["Naxx"] = "Naxxramas", ["TOC"] = "Trial of the Crusader", 
            ["RS"] = "Ruby Sanctum", ["OS"] = "The Obsidian Sanctum", ["EoE"] = "The Eye of Eternity", 
            ["VoA"] = "Vault of Archavon"
        }
        if fixMap[SausageLFM_DB.instance] then SausageLFM_DB.instance = fixMap[SausageLFM_DB.instance] end

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        local inGroup = {}
        if GetNumRaidMembers() > 0 then
            for i=1, GetNumRaidMembers() do
                local n = GetRaidRosterInfo(i)
                if n then inGroup[n] = true end
            end
        elseif GetNumPartyMembers() > 0 then
            for i=1, GetNumPartyMembers() do
                local n = UnitName("party"..i)
                if n then inGroup[n] = true end
            end
            -- BEZPEČNÝ ZÁPIS UnitName()
            inGroup[(UnitName("player"))] = true
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
btn:SetSize(32, 32)
btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, -50)
btn:SetNormalTexture("Interface\\Icons\\Inv_Misc_Food_54")
btn:SetScript("OnClick", function()
    if not SausageLFM_Main then SLFM:InitializeUI() end
    if SausageLFM_Main:IsShown() then SausageLFM_Main:Hide() else SausageLFM_Main:Show() end
end)