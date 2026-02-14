-- SausageLFM Core Logic
local addonName, L = ...
local SAUSAGE_VERSION = "1.0.2"

-- Global Namespace for UI and Logic interaction
SausageLFM = CreateFrame("Frame", "SausageLFM_MainFrame", UIParent)
local SLFM = SausageLFM

-- Defaults
local defaults = {
    interval = 45,
    minGS = 0,
    instance = "ICC",
    mode = "25HC",
    channels = { ["World"] = true, ["Trade"] = false },
    neededRoles = { Tank = 0, Heal = 0, DPS = 0 },
    neededClasses = {},
    isFlooding = false,
}

local queue = {}
local raidComposition = {}
local lastFloodTime = 0

-- Utils
local function GetClassColorText(class, text)
    local color = RAID_CLASS_COLORS[class:upper()] or {r=1, g=1, b=1}
    return string.format("|cff%02x%02x%02x%s|r", color.r*255, color.g*255, color.b*255, text)
end

-- 1. SMART PARSER
function SLFM:ParseWhisper(msg, sender)
    msg = msg:lower()
    local class, role, gs = nil, nil, 0
    
    -- Detect GS
    local gsMatch = msg:match("(%d%.?%d?)k") or msg:match("(%d%d%d%d)")
    if gsMatch then gs = tonumber(gsMatch) > 100 and tonumber(gsMatch) or tonumber(gsMatch)*1000 end
    
    -- Detect Class
    for i=1, GetNumClasses() do
        local _, cTag = GetClassInfo(i)
        if msg:find(cTag:lower()) then class = cTag break end
    end
    
    -- Detect Role
    if msg:find("tank") or msg:find("bear") or msg:find("prot") then role = "Tank"
    elseif msg:find("heal") or msg:find("tree") or msg:find("rdruid") or msg:find("rsham") or msg:find("hpaly") then role = "Heal"
    else role = "DPS" end

    return { name = sender, class = class, role = role, gs = gs, raw = msg }
end

-- 2. RAID SCANNER & MSG BUILDER
function SLFM:UpdateRaidInfo()
    local numRaid = GetNumRaidMembers()
    local currentCount = numRaid > 0 and numRaid or 1 -- 1 for player
    local maxCount = (SausageLFM_DB.mode:find("10") and 10 or 25)
    
    -- Auto-detect missing classes based on current raid
    local foundClasses = {}
    if numRaid > 0 then
        for i=1, numRaid do
            local _, _, _, _, _, fileName = GetRaidRosterInfo(i)
            foundClasses[fileName] = true
        end
    end

    -- Build Message
    local msg = "LFM " .. SausageLFM_DB.instance .. " " .. SausageLFM_DB.mode .. " (" .. currentCount .. "/" .. maxCount .. ") - Need: "
    local needs = ""
    
    -- Roles first
    if SausageLFM_DB.neededRoles.Tank > 0 then needs = needs .. SausageLFM_DB.neededRoles.Tank .. "x Tank, " end
    if SausageLFM_DB.neededRoles.Heal > 0 then needs = needs .. SausageLFM_DB.neededRoles.Heal .. "x Heal, " end
    
    -- Classes (only if they are NOT in raid or manually forced)
    for class, needed in pairs(SausageLFM_DB.neededClasses) do
        if needed and not foundClasses[class] then
            needs = needs .. class:sub(1,3) .. ", "
        end
    end

    if needs == "" then needs = "DPS / Big Dicks " end
    SLFM.currentMsg = msg .. needs:gsub(", $", "") .. " | Link GS & Achiev"
end

-- 3. FLOOD ENGINE
SLFM:SetScript("OnUpdate", function(self, elapsed)
    if not SausageLFM_DB.isFlooding then return end
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

-- EVENT HANDLING
SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")
SLFM:RegisterEvent("RAID_ROSTER_UPDATE")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        SLFM:InitializeUI()
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        local data = self:ParseWhisper(msg, sender)
        SLFM:AddToQueue(data)
    elseif event == "RAID_ROSTER_UPDATE" then
        self:UpdateRaidInfo()
        SLFM:RefreshRaidTable()
    end
end)