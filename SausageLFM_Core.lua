local addonName, L = ...
SausageLFM = CreateFrame("Frame", "SausageLFM_EventFrame", UIParent)
local SLFM = SausageLFM

-- Globálne premenné a "Placeholder" funkcie (ochrana proti chybám pred načítaním UI)
SLFM.QueueData = {}
SLFM.CurrentMsg = ""
local lastFloodTime = 0

function SLFM:InitializeUI() end
function SLFM:RefreshRaidTable() end
function SLFM:RefreshQueueTable() end
function SLFM:UpdateUIIcons() end

local defaults = {
    interval = 45,
    instance = "ICC",
    mode = "25HC",
    channels = { ["World"] = true, ["Global"] = true },
    neededClasses = {},
    isFlooding = false,
}

-- 🧠 1. SMART WHISPER PARSER
function SLFM:ParseWhisper(msg, sender)
    msg = msg:lower()
    local class, role, gs = "Unknown", "DPS", 0
    
    -- Extrakcia GearScore (napr. 6.2k, 6k, 6200)
    local gsMatch = msg:match("(%d[%.%,]?%d?)k") or msg:match("(%d%d%d%d)")
    if gsMatch then 
        gs = tonumber((gsMatch:gsub(",", ".")))
        if gs and gs < 100 then gs = gs * 1000 end
    end
    
    -- Extrakcia Classy
    local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
    for _, c in ipairs(classes) do
        if msg:find(c:lower()) or (c == "DEATHKNIGHT" and msg:find("dk")) or (c == "PALADIN" and msg:find("pala")) then 
            class = c 
            break 
        end
    end
    
    -- Extrakcia Role
    if msg:find("tank") or msg:find("bear") or msg:find("prot") then role = "Tank"
    elseif msg:find("heal") or msg:find("tree") or msg:find("rsham") or msg:find("hpaly") or msg:find("resto") then role = "Heal" end

    -- Pridanie do Queue
    table.insert(SLFM.QueueData, 1, { name = sender, class = class, role = role, gs = gs or 0, raw = msg })
    if #SLFM.QueueData > 15 then table.remove(SLFM.QueueData) end -- Limit na 15 ľudí
    
    self:RefreshQueueTable()
end

-- 👁️ 2. SMART RAID SCANNER
function SLFM:UpdateRaidInfo()
    if not SausageLFM_DB then return end
    
    local numRaid = GetNumRaidMembers()
    local currentCount = numRaid > 0 and numRaid or 1
    local maxCount = (SausageLFM_DB.mode:find("10") and 10 or 25)
    
    -- Zistenie klás v raide
    local foundClasses = {}
    if numRaid > 0 then
        for i = 1, numRaid do
            local _, _, _, _, _, fileName = GetRaidRosterInfo(i)
            if fileName then foundClasses[fileName] = true end
        end
    end

    -- Skladanie správy
    local msg = string.format("LFM %s %s (%d/%d) - Need: ", SausageLFM_DB.instance, SausageLFM_DB.mode, currentCount, maxCount)
    local needs = ""
    
    for class, active in pairs(SausageLFM_DB.neededClasses) do
        -- Ak to hľadáme a NIE JE to v raide, pridáme to do správy
        if active and not foundClasses[class] then
            needs = needs .. class:sub(1,1):upper() .. class:sub(2,3):lower() .. ", "
        end
    end

    if needs == "" then needs = "Pumpers / Big Dicks " end
    SLFM.CurrentMsg = msg .. needs:gsub(", $", "") .. " | w me inv/gs"
end

-- 🌊 3. FLOOD ENGINE
SLFM:SetScript("OnUpdate", function(self, elapsed)
    if not SausageLFM_DB or not SausageLFM_DB.isFlooding then return end
    lastFloodTime = lastFloodTime + elapsed
    
    if lastFloodTime >= SausageLFM_DB.interval then
        self:UpdateRaidInfo()
        for chan, active in pairs(SausageLFM_DB.channels) do
            if active then
                local id = GetChannelName(chan)
                if id > 0 then SendChatMessage(SLFM.CurrentMsg, "CHANNEL", nil, id) end
            end
        end
        lastFloodTime = 0
    end
end)

-- ⚙️ EVENT HANDLERS
SLFM:RegisterEvent("ADDON_LOADED")
SLFM:RegisterEvent("CHAT_MSG_WHISPER")
SLFM:RegisterEvent("RAID_ROSTER_UPDATE")

SLFM:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        SausageLFM_DB = SausageLFM_DB or defaults
        -- Fix pre chýbajúce tabuľky v starých DB
        SausageLFM_DB.neededClasses = SausageLFM_DB.neededClasses or {}
        SausageLFM_DB.isFlooding = false
        
        self:InitializeUI()
        self:UpdateUIIcons()
        self:UpdateRaidInfo()
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        self:ParseWhisper(msg, sender)
    elseif event == "RAID_ROSTER_UPDATE" then
        self:UpdateRaidInfo()
        self:RefreshRaidTable()
    end
end)

SLASH_SAUSAGELFM1 = "/slfm"
SlashCmdList["SAUSAGELFM"] = function() 
    if SausageLFM_Main and SausageLFM_Main:IsShown() then SausageLFM_Main:Hide() else SausageLFM_Main:Show() end 
end