-- SausageLFM Core Logic
local addonName, L = ...
local SAUSAGE_VERSION = "1.0.2"

-- Global Namespace initialization
SausageLFM = CreateFrame("Frame", "SausageLFM_MainFrame", UIParent)
local SLFM = SausageLFM

-- Placeholder functions for UI (prevents nil errors before UI loads)
function SLFM:InitializeUI() end
function SLFM:RefreshRaidTable() end
function SLFM:AddToQueue(data) end
function SLFM:UpdateUIIcons() end

-- Default Database
local defaults = {
    interval = 45,
    instance = "ICC",
    mode = "25HC",
    channels = { ["World"] = true, ["Trade"] = false },
    neededRoles = { Tank = 1, Heal = 1, DPS = 1 },
    neededClasses = {},
    isFlooding = false,
}

local lastFloodTime = 0
SLFM.currentMsg = ""

-- 1. SMART WHISPER PARSER
function SLFM:ParseWhisper(msg, sender)
    msg = msg:lower()
    local class, role, gs = nil, "DPS", 0
    
    -- GS Detection (e.g. 6.2k or 6150)
    local gsMatch = msg:match("(%d%.?%d?)k") or msg:match("(%d%d%d%d)")
    if gsMatch then 
        gs = tonumber(gsMatch)
        if gs < 100 then gs = gs * 1000 end
    end
    
    -- Class Detection
    local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
    for _, c in ipairs(classes) do
        if msg:find(c:lower()) or (c == "DEATHKNIGHT" and msg:find("dk")) then 
            class = c 
            break 
        end
    end
    
    -- Role Detection
    if msg:find("tank") or msg:find("bear") or msg:find("prot") then role = "Tank"
    elseif msg:find("heal") or msg:find("tree") or msg:find("rsham") or msg:find("hpaly") then role = "Heal" end

    return { name = sender, class = class, role = role, gs = gs, raw = msg }
end

-- 2. SMART RAID SCANNER
function SLFM:UpdateRaidInfo()
    if not SausageLFM_DB then return end
    
    local numRaid = GetNumRaidMembers()
    local currentCount = numRaid > 0 and numRaid or 1
    local maxCount = (SausageLFM_DB.mode:find("10") and 10 or 25)
    
    -- Build Auto-Message
    local msg = "LFM " .. SausageLFM_DB.instance .. " " .. SausageLFM_DB.mode .. " (" .. currentCount .. "/" .. maxCount .. ") - Need: "
    local needs = ""
    
    -- Check what classes we have in raid to auto-remove from message
    local foundClasses = {}
    if numRaid > 0 then
        for i=1, numRaid do
            local _, _, _, _, _, fileName = GetRaidRosterInfo(i)
            foundClasses[fileName] = true
        end
    end

    -- Add manually selected classes if they aren't in raid
    for class, active in pairs(SausageLFM_DB.neededClasses) do
        if active and not foundClasses[class] then
            needs = needs .. class:sub(1,3) .. ", "
        end
    end

    if needs == "" then needs = "All Classes Welcome! " end
    SLFM.currentMsg = msg .. needs:gsub(", $", "") .. " | Link GS/Achiev"
end

-- 3. FLOOD ENGINE
SLFM:SetScript("OnUpdate", function(self, elapsed)
    if not SausageLFM_DB or not SausageLFM_DB.isFlooding then return end
    lastFloodTime = lastFloodTime + elapsed
    
    if lastFloodTime >= SausageLFM_DB.interval then
        self:UpdateRaidInfo()
        for chan, active in pairs(SausageLFM_DB.channels) do
            if active then
                local id = GetChannelName(chan)
                if id > 0 then SendChatMessage(self.currentMsg, "CHANNEL", nil, id) end
            end
        end
        lastFloodTime = 0
    end
end)

-- EVENT HANDLER
SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")
SLFM:RegisterEvent("RAID_ROSTER_UPDATE")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        self:InitializeUI()
        self:UpdateUIIcons()
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        self:AddToQueue(self:ParseWhisper(msg, sender))
    elseif event == "RAID_ROSTER_UPDATE" then
        self:UpdateRaidInfo()
        self:RefreshRaidTable()
    end
end)

-- Slash Command
SLASH_SAUSAGELFM1 = "/slfm"
SlashCmdList["SAUSAGELFM"] = function() SausageLFM_Main:Show() end