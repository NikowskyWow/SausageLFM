local SLFM = SausageLFM
local SAUSAGE_VERSION = "1.1.0"

local function CreateSausageBackdrop(frame, borderType)
    local color = {0, 0.7, 1, 1} -- Modrá (General)
    if borderType == "priority" then color = {1, 0.8, 0, 1} -- Zlatá
    elseif borderType == "gray" then color = {0.6, 0.6, 0.6, 1} end -- Šedá

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
    -- 1. MAIN FRAME (Stred)
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(400, 350)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SausageLFM_Main")

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Hlavička & Zatváracie tlačidlo
    local h = f:CreateTexture(nil, "OVERLAY")
    h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    h:SetSize(300, 64)
    h:SetPoint("TOP", 0, 12)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", h, "TOP", 0, -14)
    t:SetText("SAUSAGE LFM")
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    -- Sektor: Class Selector (Zlatý)
    local cb = CreateFrame("Frame", nil, f)
    cb:SetSize(360, 120)
    cb:SetPoint("TOP", 0, -40)
    CreateSausageBackdrop(cb, "priority")
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 10, -10)
    lbl:SetText("Hľadané Classy (Klikni -> pridá do MSG, Skenuje Raid):")

    f.classButtons = {}
    local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
    for i, class in ipairs(classes) do
        local btn = CreateFrame("Button", nil, cb)
        btn:SetSize(32, 32)
        local row = i <= 5 and 0 or 1
        local col = (i-1) % 5
        btn:SetPoint("TOPLEFT", 25 + (col * 65), -35 - (row * 40))
        
        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
        
        btn:SetScript("OnClick", function()
            SausageLFM_DB.neededClasses[class] = not SausageLFM_DB.neededClasses[class]
            SLFM:UpdateUIIcons()
            SLFM:UpdateRaidInfo()
        end)
        f.classButtons[class] = btn
    end

    -- Štart Button & Preview
    f.msgPreview = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.msgPreview:SetPoint("TOP", cb, "BOTTOM", 0, -20)
    f.msgPreview:SetWidth(340)
    
    local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    startBtn:SetSize(150, 30)
    startBtn:SetPoint("BOTTOM", 0, 40)
    startBtn:SetText(SausageLFM_DB.isFlooding and "STOP FLOODING" or "START FLOODING")
    startBtn:SetScript("OnClick", function(self)
        SausageLFM_DB.isFlooding = not SausageLFM_DB.isFlooding
        self:SetText(SausageLFM_DB.isFlooding and "STOP FLOODING" or "START FLOODING")
        if SausageLFM_DB.isFlooding then SLFM:UpdateRaidInfo() end
    end)

    -- Footer (Opravené reťazenie metód pre 3.3.5a)
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    verText:SetText("v" .. SAUSAGE_VERSION)

    local credText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    credText:SetPoint("BOTTOM", 0, 15)
    credText:SetText("by Sausage Party")

    local updateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    updateBtn:SetSize(110, 25)
    updateBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    updateBtn:SetText("Check Updates")

    -- 2. RAID OVERVIEW (Ľavé bočné krídlo)
    local rf = CreateFrame("Frame", "SausageLFM_Raid", f)
    rf:SetSize(220, 350)
    rf:SetPoint("TOPRIGHT", f, "TOPLEFT", -5, 0)
    CreateSausageBackdrop(rf, "gray")
    rf.title = rf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rf.title:SetPoint("TOP", 0, -10)
    rf.title:SetText("Raid Overview")

    -- 3. CANDIDATE QUEUE (Pravé bočné krídlo)
    local qf = CreateFrame("Frame", "SausageLFM_Queue", f)
    qf:SetSize(250, 350)
    qf:SetPoint("TOPLEFT", f, "TOPRIGHT", 5, 0)
    CreateSausageBackdrop(qf, "general")
    qf.title = qf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qf.title:SetPoint("TOP", 0, -10)
    qf.title:SetText("Candidate Queue")
    
    local clearBtn = CreateFrame("Button", nil, qf, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("BOTTOM", 0, 10)
    clearBtn:SetText("Clear Queue")
    clearBtn:SetScript("OnClick", function() wipe(SLFM.QueueData); SLFM:RefreshQueueTable() end)

    -- Minimap Icon
    local mini = CreateFrame("Button", "SausageLFM_Minimap", Minimap)
    mini:SetSize(32, 32)
    mini:SetPoint("TOPLEFT")
    mini:SetNormalTexture("Interface\\Icons\\Inv_Misc_Food_54")
    mini:SetScript("OnClick", function() if f:IsShown() then f:Hide() else f:Show() end end)
    
    self:RefreshRaidTable()
end

function SLFM:UpdateUIIcons()
    if not SausageLFM_Main then return end
    for class, btn in pairs(SausageLFM_Main.classButtons) do
        btn:SetAlpha(SausageLFM_DB.neededClasses[class] and 1.0 or 0.2)
    end
    if SausageLFM_Main.msgPreview then
        SausageLFM_Main.msgPreview:SetText(self.CurrentMsg ~= "" and self.CurrentMsg or "Skenujem raid...")
    end
end

-- VYKRESLENIE RAID TABUĽKY
function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.raidRows then self.raidRows = {} end
    for _, r in ipairs(self.raidRows) do r:Hide() end

    local num = GetNumRaidMembers()
    for i = 1, (num > 0 and num or 1) do
        local name, _, sub, _, _, fileName = GetRaidRosterInfo(i)
        if not name then name = UnitName("player"); _, fileName = UnitClass("player"); sub = 1 end
        
        if not self.raidRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Raid)
            r:SetSize(200, 12)
            r:SetPoint("TOPLEFT", 10, -25 - (i*12))
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.t:SetPoint("LEFT", 0, 0)
            self.raidRows[i] = r
        end
        local color = RAID_CLASS_COLORS[fileName] or {r=1,g=1,b=1}
        self.raidRows[i].t:SetText(string.format("|cff888888[G%d]|r |cff%02x%02x%02x%s|r", sub, color.r*255, color.g*255, color.b*255, name))
        self.raidRows[i]:Show()
    end
    self:UpdateUIIcons()
end

-- VYKRESLENIE QUEUE TABUĽKY
function SLFM:RefreshQueueTable()
    if not SausageLFM_Queue or not SausageLFM_Queue:IsShown() then return end
    if not self.queueRows then self.queueRows = {} end
    for _, r in ipairs(self.queueRows) do r:Hide() end

    for i, data in ipairs(self.QueueData) do
        if not self.queueRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Queue)
            r:SetSize(230, 20)
            r:SetPoint("TOPLEFT", 10, -20 - (i*22))
            
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.t:SetPoint("LEFT", 0, 0)
            
            -- Invite Tlačidlo (Opravené reťazenie)
            r.invBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            r.invBtn:SetSize(35, 18)
            r.invBtn:SetPoint("RIGHT", -5, 0)
            r.invBtn:SetText("Inv")
            
            self.queueRows[i] = r
        end
        
        local colorStr = "|cffffffff"
        if data.class ~= "Unknown" and RAID_CLASS_COLORS[data.class] then
            local c = RAID_CLASS_COLORS[data.class]
            colorStr = string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
        end
        
        local gsText = data.gs > 0 and (data.gs .. " GS") or "No GS"
        self.queueRows[i].t:SetText(string.format("%s%s|r |cffffd200(%s)|r", colorStr, data.name, gsText))
        
        self.queueRows[i].invBtn:SetScript("OnClick", function() InviteUnit(data.name) end)
        self.queueRows[i]:Show()
    end
end