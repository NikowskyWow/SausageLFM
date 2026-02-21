-- SausageLFM_Core.lua
local addonName, L = ...
SausageLFM = CreateFrame("Frame", "SausageLFM_CoreFrame", UIParent)
local SLFM = SausageLFM

SLFM.Version = "" -- Pripravené pre tvoj automatický skript
SLFM.Queue = {}
SLFM.RaidData = {}
SLFM.History = {}
SLFM.IsFlooding = false
SLFM.CurrentMsg = ""
local lastFlood = 0

local defaults = {
    interval = 45,
    minGS = 0,
    instance = "ICC",
    mode = "25",
    isHC = false,
    reqAchiev = false,
    roles = { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 },
    specs = {},
    channels = { World = false, Global = false, LFG = false, Party = true }
}

function SLFM:GetExternalGS(name)
    local realm = GetRealmName()
    if GS_Data and GS_Data[realm] and GS_Data[realm].Players and GS_Data[realm].Players[name] then
        return tonumber(GS_Data[realm].Players[name].GearScore) or 0
    end
    return 0
end

-- V7 Smart Message Builder
function SLFM:UpdateMessage()
    local db = SausageLFM_DB
    local count = GetNumRaidMembers() > 0 and GetNumRaidMembers() or (GetNumPartyMembers() > 0 and GetNumPartyMembers() + 1 or 1)
    
    local maxCount = 25
    local msg = ""

    if db.instance == "Dungeon" then
        maxCount = 5
        msg = "LFM " .. (db.mode or "Random HC") .. (db.isHC and " HC" or "") .. " (" .. count .. "/" .. maxCount .. ")"
    else
        maxCount = (db.mode == "10") and 10 or 25
        msg = "LFM " .. (db.instance or "ICC") .. " " .. (db.mode or "25") .. (db.isHC and " HC" or "") .. " (" .. count .. "/" .. maxCount .. ")"
    end
    
    local needs = ""
    if db.roles.Tank > 0 then needs = needs .. db.roles.Tank .. "x Tank, " end
    if db.roles.Heal > 0 then needs = needs .. db.roles.Heal .. "x Heal, " end
    if db.roles.mDPS > 0 then needs = needs .. db.roles.mDPS .. "x mDPS, " end
    if db.roles.rDPS > 0 then needs = needs .. db.roles.rDPS .. "x rDPS, " end
    
    -- Dynamické specy (napr. 1x Holy Paladin (OS Prot))
    for spec, target in pairs(db.specs) do
        if target > 0 then needs = needs .. target .. "x " .. spec .. ", " end
    end
    
    if db.minGS > 0 then msg = msg .. " | Req: " .. db.minGS .. "+ GS" end
    if db.reqAchiev then msg = msg .. " & Achiev" end
    
    SLFM.CurrentMsg = msg .. " - Need: " .. (needs ~= "" and needs:gsub(", $", "") or "PUMPERS") .. " | w me spec/gs!"
    if SausageLFM_Main and SausageLFM_Main.preview then SausageLFM_Main.preview:SetText(SLFM.CurrentMsg) end
end

SLFM:SetScript("OnUpdate", function(self, elapsed)
    if not SLFM.IsFlooding then return end
    lastFlood = lastFlood + elapsed
    if lastFlood >= (SausageLFM_DB.interval or 45) then
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
        lastFlood = 0
    end
end)

SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        SausageLFM_DB.roles = SausageLFM_DB.roles or { Tank = 0, Heal = 0, mDPS = 0, rDPS = 0 }
        SausageLFM_DB.specs = SausageLFM_DB.specs or {}
        SausageLFM_DB.channels = SausageLFM_DB.channels or { World = false, Global = false, LFG = false, Party = true }
        SausageLFM_DB.interval = SausageLFM_DB.interval or 45
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        msg = msg:lower()
        local gsMatch = msg:match("(%d[%.%,]?%d?)k") or msg:match("(%d%d%d%d)")
        local gs = 0
        if gsMatch then 
            gs = tonumber((gsMatch:gsub(",", ".")))
            if gs and gs < 100 then gs = gs * 1000 end
        end
        local isNew = true
        for _, q in ipairs(SLFM.Queue) do
            if q.name == sender then isNew = false; q.gs = gs > 0 and gs or q.gs; break end
        end
        if isNew then
            table.insert(SLFM.Queue, 1, { name = sender, gs = gs, unread = true })
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