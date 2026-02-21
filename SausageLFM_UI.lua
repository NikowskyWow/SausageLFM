-- SausageLFM_UI.lua
local SLFM = SausageLFM

local function CreateBackdrop(f, gold)
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.8)
    if gold then f:SetBackdropBorderColor(1, 0.8, 0) else f:SetBackdropBorderColor(0.5, 0.5, 0.5) end
end

function SLFM:InitializeUI()
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(960, 600)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SausageLFM_Main")
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -15)
    title:SetText("SAUSAGE COMMAND CENTER")
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    -- LEFT PANEL
    local left = CreateFrame("Frame", "SausageLFM_Raid", f)
    left:SetSize(250, 490)
    left:SetPoint("TOPLEFT", 20, -50)
    CreateBackdrop(left)
    local lTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lTitle:SetPoint("BOTTOM", left, "TOP", 0, 5)
    lTitle:SetText("Raid Overview")

    -- MID PANEL
    local mid = CreateFrame("Frame", nil, f)
    mid:SetSize(410, 490)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 15, 0)

    -- RIGHT PANEL
    local right = CreateFrame("Frame", "SausageLFM_Queue", f)
    right:SetSize(250, 490)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 15, 0)
    CreateBackdrop(right, true)
    local rTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rTitle:SetPoint("BOTTOM", right, "TOP", 0, 5)
    rTitle:SetText("Candidate Queue")

    -- =====================================
    -- 🎛️ MID PANEL OBSAH (Command & Control)
    -- =====================================

    -- DROPDOWNS & SMART REFRESH
    local instDrop = CreateFrame("Frame", "SLFM_InstDrop", mid, "UIDropDownMenuTemplate")
    instDrop:SetPoint("TOPLEFT", -15, -10)
    local modeDrop = CreateFrame("Frame", "SLFM_ModeDrop", mid, "UIDropDownMenuTemplate")
    modeDrop:SetPoint("LEFT", instDrop, "RIGHT", -20, 0)

    local function InitModeDropdown()
        UIDropDownMenu_Initialize(modeDrop, function()
            local info = UIDropDownMenu_CreateInfo()
            local list = {}
            if SausageLFM_DB.instance == "Dungeon" then
                list = {"Random HC", "FoS", "PoS", "HoR", "ToC5", "Daily HC"}
                if SausageLFM_DB.mode == "10" or SausageLFM_DB.mode == "25" then SausageLFM_DB.mode = "FoS" end
            else
                list = {"10", "25"}
                if SausageLFM_DB.mode ~= "10" and SausageLFM_DB.mode ~= "25" then SausageLFM_DB.mode = "25" end
            end
            UIDropDownMenu_SetText(modeDrop, SausageLFM_DB.mode)
            for _, v in ipairs(list) do
                info.text = v
                info.func = function() SausageLFM_DB.mode = v; UIDropDownMenu_SetText(modeDrop, v); SLFM:UpdateMessage() end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end

    UIDropDownMenu_Initialize(instDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        local list = {"ICC", "RS", "TOC", "Ulduar", "Naxx", "OS", "EoE", "VoA", "Dungeon"}
        for _, v in ipairs(list) do
            info.text = v
            info.func = function() 
                SausageLFM_DB.instance = v
                UIDropDownMenu_SetText(instDrop, v)
                InitModeDropdown()
                SLFM:UpdateMessage() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(instDrop, SausageLFM_DB.instance)
    UIDropDownMenu_SetWidth(instDrop, 100)

    InitModeDropdown()
    UIDropDownMenu_SetWidth(modeDrop, 90)

    -- CHECKBOXY A GS
    local hc = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    hc:SetPoint("TOPLEFT", 10, -45)
    hc:SetChecked(SausageLFM_DB.isHC)
    hc:SetScript("OnClick", function(self) SausageLFM_DB.isHC = self:GetChecked(); SLFM:UpdateMessage() end)
    local hcText = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); hcText:SetPoint("LEFT", hc, "RIGHT", 0, 0); hcText:SetText("HC")

    local ach = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    ach:SetPoint("LEFT", hcText, "RIGHT", 10, 0)
    ach:SetChecked(SausageLFM_DB.reqAchiev)
    ach:SetScript("OnClick", function(self) SausageLFM_DB.reqAchiev = self:GetChecked(); SLFM:UpdateMessage() end)
    local achText = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); achText:SetPoint("LEFT", ach, "RIGHT", 0, 0); achText:SetText("Achiev")

    local gsIn = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsIn:SetSize(60, 20)
    gsIn:SetPoint("TOPRIGHT", -15, -48)
    gsIn:SetAutoFocus(false)
    gsIn:SetText(tostring(SausageLFM_DB.minGS))
    gsIn:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gsl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); gsl:SetPoint("RIGHT", gsIn, "LEFT", -5, 0); gsl:SetText("Min GS:")

    -- BASIC ROLES & DEFAULT BUTTON
    local brLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    brLbl:SetPoint("TOPLEFT", 10, -90)
    brLbl:SetText("Basic Roles:")

    -- References pre krabice, aby sme ich mohli updatnuť z Default buttonu
    local rBoxes = {} 
    
    local rX = 10
    for _, r in ipairs({"Tank", "Heal", "mDPS", "rDPS"}) do
        local eb = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
        eb:SetSize(35, 20)
        eb:SetPoint("TOPLEFT", rX, -120)
        eb:SetAutoFocus(false)
        eb:SetText(tostring(SausageLFM_DB.roles[r] or 0))
        eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.roles[r] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
        local rl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rl:SetPoint("BOTTOM", eb, "TOP", 0, 3)
        rl:SetText(r)
        rBoxes[r] = eb
        rX = rX + 65
    end

    local defBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    defBtn:SetSize(70, 25)
    defBtn:SetPoint("TOPLEFT", rX + 10, -118)
    defBtn:SetText("Default")
    defBtn:SetScript("OnClick", function()
        if SausageLFM_DB.instance == "Dungeon" then
            SausageLFM_DB.roles = {Tank = 1, Heal = 1, mDPS = 1, rDPS = 2}
        elseif SausageLFM_DB.mode == "10" then
            SausageLFM_DB.roles = {Tank = 2, Heal = 2, mDPS = 3, rDPS = 3}
        else
            SausageLFM_DB.roles = {Tank = 2, Heal = 5, mDPS = 9, rDPS = 9}
        end
        for r, box in pairs(rBoxes) do box:SetText(tostring(SausageLFM_DB.roles[r])) end
        SLFM:UpdateMessage()
    end)

    -- THE SPEC GRID (20 Buttons)
    local spLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spLbl:SetPoint("TOPLEFT", 10, -160)
    spLbl:SetText("Quick Add Specific Specs:")

    local specGridCont = CreateFrame("Frame", nil, mid)
    specGridCont:SetSize(390, 100)
    specGridCont:SetPoint("TOPLEFT", 10, -180)

    local specData = {
        {n="HPal", c="|cFFF58CBA", f="Holy Paladin"}, {n="ProtP", c="|cFFF58CBA", f="Prot Paladin"}, {n="RetP", c="|cFFF58CBA", f="Ret Paladin"}, {n="DiscP", c="|cFFFFFFFF", f="Disc Priest"}, {n="HolyP", c="|cFFFFFFFF", f="Holy Priest"},
        {n="RSham", c="|cFF0070DE", f="Resto Shaman"}, {n="EnhS", c="|cFF0070DE", f="Enhance Shaman"}, {n="EleS", c="|cFF0070DE", f="Ele Shaman"}, {n="SPri", c="|cFFFFFFFF", f="Shadow Priest"}, {n="Mage", c="|cFF69CCF0", f="Mage"},
        {n="RDru", c="|cFFFF7D0A", f="Resto Druid"}, {n="FerD", c="|cFFFF7D0A", f="Feral Druid"}, {n="Boom", c="|cFFFF7D0A", f="Boomkin"}, {n="Lock", c="|cFF9482C9", f="Warlock"}, {n="Hunt", c="|cFFABD473", f="Hunter"},
        {n="BDK", c="|cFFC41F3B", f="Blood DK"}, {n="FDK", c="|cFFC41F3B", f="Frost DK"}, {n="UDK", c="|cFFC41F3B", f="Unholy DK"}, {n="Warr", c="|cFFC79C6E", f="Warrior"}, {n="Rogue", c="|cFFFFF569", f="Rogue"}
    }

    local activeCont = CreateFrame("Frame", nil, mid)
    activeCont:SetSize(390, 100)
    activeCont:SetPoint("TOPLEFT", 10, -290)

    local function DrawActiveSpecs()
        if activeCont.rows then for _, r in ipairs(activeCont.rows) do r:Hide() end end
        activeCont.rows = {}
        local idx = 0
        for name, count in pairs(SausageLFM_DB.specs) do
            if count > 0 then
                -- Dvojstĺpcový layout (zabraňuje pretekaniu do iných UI prvkov)
                local col = idx % 2
                local rowN = math.floor(idx / 2)
                
                local r = CreateFrame("Frame", nil, activeCont)
                r:SetSize(190, 24)
                r:SetPoint("TOPLEFT", col * 195, -(rowN * 26))
                
                local txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", 0, 0); txt:SetText(name)
                
                local eb = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
                eb:SetSize(25, 18); eb:SetPoint("RIGHT", -35, 0); eb:SetText(tostring(count))
                eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.specs[name] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
                
                local del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
                del:SetSize(20, 18); del:SetPoint("RIGHT", 0, 0); del:SetText("X")
                del:SetScript("OnClick", function() SausageLFM_DB.specs[name] = nil; DrawActiveSpecs(); SLFM:UpdateMessage() end)
                
                tinsert(activeCont.rows, r)
                idx = idx + 1
            end
        end
    end

    for i, data in ipairs(specData) do
        local col = (i-1) % 5
        local rowN = math.floor((i-1) / 5)
        local btn = CreateFrame("Button", nil, specGridCont, "UIPanelButtonTemplate")
        btn:SetSize(72, 22)
        btn:SetPoint("TOPLEFT", col * 75, -(rowN * 25))
        btn:SetText(data.c .. data.n .. "|r")
        btn:SetScript("OnClick", function()
            SausageLFM_DB.specs[data.f] = (SausageLFM_DB.specs[data.f] or 0) + 1
            DrawActiveSpecs()
            SLFM:UpdateMessage()
        end)
    end
    DrawActiveSpecs()

    -- BROADCAST ENGINE
    local timer = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    timer:SetSize(40, 20)
    timer:SetPoint("BOTTOMLEFT", 60, 110)
    timer:SetAutoFocus(false)
    timer:SetText(tostring(SausageLFM_DB.interval))
    timer:SetScript("OnTextChanged", function(self) SausageLFM_DB.interval = tonumber(self:GetText()) or 45 end)
    
    local tl1 = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); tl1:SetPoint("RIGHT", timer, "LEFT", -5, 0); tl1:SetText("Timer:")
    local tl2 = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); tl2:SetPoint("LEFT", timer, "RIGHT", 5, 0); tl2:SetText("sec")

    local cX = 10
    for _, ch in ipairs({"World", "Global", "LFG", "Party"}) do
        local cb = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
        cb:SetPoint("BOTTOMLEFT", cX, 80)
        cb:SetChecked(SausageLFM_DB.channels[ch])
        cb:SetScript("OnClick", function(self) SausageLFM_DB.channels[ch] = self:GetChecked() end)
        local cbText = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0); cbText:SetText(ch)
        cX = cX + 90
    end

    f.preview = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.preview:SetPoint("BOTTOM", 0, 55)
    f.preview:SetWidth(400)

    local flood = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    flood:SetSize(250, 35)
    flood:SetPoint("BOTTOM", 0, 15)
    flood:SetText("START FLOODING")
    flood:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)
    
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    local verString = SLFM.Version; if type(verString) ~= "string" or verString == "" then verString = "1.6.0" end
    verText:SetText("v" .. verString)
    
    self:RefreshRaidTable()
end

function SLFM:RefreshQueueTable()
    if not SausageLFM_Queue or not SausageLFM_Queue:IsShown() then return end
    if not self.qRows then self.qRows = {} end
    for _, r in ipairs(self.qRows) do r:Hide() end
    for i, d in ipairs(self.Queue) do
        if not self.qRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Queue)
            r:SetSize(235, 25); r:SetPoint("TOPLEFT", 5, -15-(i*28))
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.t:SetPoint("LEFT", 5, 0)
            r.inv = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.inv:SetSize(40, 20); r.inv:SetPoint("RIGHT", -30, 0); r.inv:SetText("Inv")
            r.rej = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.rej:SetSize(25, 20); r.rej:SetPoint("RIGHT", 0, 0); r.rej:SetText("X")
            self.qRows[i] = r
        end
        local r = self.qRows[i]
        r.t:SetText(d.name .. " (" .. (d.gs or "??") .. "gs)")
        r.inv:SetScript("OnClick", function() InviteUnit(d.name) end)
        r.rej:SetScript("OnClick", function() table.remove(SLFM.Queue, i); SLFM:RefreshQueueTable() end)
        r:Show()
    end
end

function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.rRows then self.rRows = {} end
    for _, r in ipairs(self.rRows) do r:Hide() end
    for i=1, (GetNumRaidMembers() > 0 and GetNumRaidMembers() or 1) do
        local name = GetRaidRosterInfo(i) or UnitName("player")
        if not self.rRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Raid)
            r:SetSize(230, 20); r:SetPoint("TOPLEFT", 5, -15-(i*22))
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.t:SetPoint("LEFT", 5, 0)
            self.rRows[i] = r
        end
        local r = self.rRows[i]
        local gs = SLFM:GetExternalGS(name)
        r.t:SetText(name .. " - " .. (gs > 0 and gs or "Unscanned"))
        r:Show()
    end
end