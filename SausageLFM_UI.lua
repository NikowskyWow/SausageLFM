-- SausageLFM UI (Sausage Design System)
local SLFM = SausageLFM
local SAUSAGE_VERSION = "1.0.2"

local function CreateSausageBackdrop(frame, borderType)
    local color = {0, 0.7, 1, 1} -- Blue
    if borderType == "priority" then color = {1, 0.8, 0, 1} -- Gold
    elseif borderType == "gray" then color = {0.6, 0.6, 0.6, 1} end

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(unpack(color))
end

function SLFM:InitializeUI()
    -- MAIN FRAME
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(400, 480)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    tinsert(UISpecialFrames, "SausageLFM_Main")

    -- HEADER
    local h = f:CreateTexture(nil, "OVERLAY")
    h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    h:SetSize(256, 64)
    h:SetPoint("TOP", 0, 12)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", h, "TOP", 0, -14)
    t:SetText("SAUSAGE LFM")

    -- CONTENT BOX: CLASS SELECTOR
    local cb = CreateFrame("Frame", "SausageLFM_ClassBox", f)
    cb:SetSize(360, 120)
    cb:SetPoint("TOP", 0, -60)
    CreateSausageBackdrop(cb, "priority")
    
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 10, -10)
    lbl:SetText("Hľadané classy (Skenuje raid):")

    local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
    f.classButtons = {}
    for i, class in ipairs(classes) do
        local b = CreateFrame("Button", nil, cb)
        b:SetSize(32, 32)
        local row = i <= 5 and 0 or 1
        local col = (i-1) % 5
        b:SetPoint("TOPLEFT", 25 + (col * 65), -35 - (row * 40))
        
        local tex = b:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        local coords = CLASS_ICON_TCOORDS[class]
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(unpack(coords))
        
        b:SetScript("OnClick", function()
            SausageLFM_DB.neededClasses[class] = not SausageLFM_DB.neededClasses[class]
            SLFM:UpdateUIIcons()
            SLFM:UpdateRaidInfo()
        end)
        f.classButtons[class] = b
    end

    -- RAID OVERVIEW (LEFT)
    local rf = CreateFrame("Frame", "SausageLFM_Raid", f)
    rf:SetSize(220, 240)
    rf:SetPoint("TOPRIGHT", f, "TOPLEFT", -5, 0)
    CreateSausageBackdrop(rf, "gray")
    rf.title = rf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rf.title:SetPoint("TOP", 0, -10)
    rf.title:SetText("Raid Overview")

    -- QUEUE FRAME (RIGHT)
    local qf = CreateFrame("Frame", "SausageLFM_Queue", f)
    qf:SetSize(220, 240)
    qf:SetPoint("TOPLEFT", f, "TOPRIGHT", 5, 0)
    CreateSausageBackdrop(qf, "general")
    qf.title = qf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qf.title:SetPoint("TOP", 0, -10)
    qf.title:SetText("Whisper Queue")

    -- START BUTTON
    local start = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    start:SetSize(120, 30)
    start:SetPoint("BOTTOM", 0, 50)
    start:SetText("START FLOOD")
    start:SetScript("OnClick", function(self)
        SausageLFM_DB.isFlooding = not SausageLFM_DB.isFlooding
        self:SetText(SausageLFM_DB.isFlooding and "STOP FLOOD" or "START FLOOD")
    end)

    -- FOOTER
    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("BOTTOMLEFT", 20, 15)
    ver:SetText("v" .. SAUSAGE_VERSION)
    local cred = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cred:SetPoint("BOTTOM", 0, 15)
    cred:SetText("by Sausage Party")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)
end

function SLFM:UpdateUIIcons()
    if not SausageLFM_Main or not SausageLFM_Main.classButtons then return end
    for class, btn in pairs(SausageLFM_Main.classButtons) do
        btn:SetAlpha(SausageLFM_DB.neededClasses[class] and 1 or 0.3)
    end
end

function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.raidRows then self.raidRows = {} end
    for _, r in ipairs(self.raidRows) do r:Hide() end

    local num = GetNumRaidMembers()
    for i=1, (num > 0 and num or 1) do
        local name, _, sub, _, _, fileName = GetRaidRosterInfo(i)
        if not name then name = UnitName("player") _, fileName = UnitClass("player") sub = 1 end
        
        if not self.raidRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Raid)
            r:SetSize(200, 18)
            r:SetPoint("TOPLEFT", 10, -30 - (i*18))
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.t:SetPoint("LEFT", 5, 0)
            self.raidRows[i] = r
        end
        local color = RAID_CLASS_COLORS[fileName] or {r=1,g=1,b=1}
        self.raidRows[i].t:SetText(string.format("|cff888888%d.|r |cff%02x%02x%02x%s|r", sub, color.r*255, color.g*255, color.b*255, name))
        self.raidRows[i]:Show()
    end
end

function SLFM:AddToQueue(data)
    if not SausageLFM_Queue then return end
    print("|cffffd200SausageLFM:|r " .. data.name .. " (" .. (data.class or "Unknown") .. " " .. data.role .. " " .. data.gs .. "gs) added to queue.")
end