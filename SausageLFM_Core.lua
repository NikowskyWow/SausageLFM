-- SausageLFM_UI.lua
local SLFM = SausageLFM

local function CreateSausageBackdrop(frame, colorType)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    local c = (colorType == "gold") and {1, 0.8, 0, 1} or {0.6, 0.6, 0.6, 1}
    frame:SetBackdropBorderColor(unpack(c))
end

function SLFM:InitializeUI()
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(900, 540)
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
    
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", 0, -15)
    t:SetText("SAUSAGE COMMAND CENTER")
    
    CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -8, -8)

    -- LEFT PANEL (Raid)
    local left = CreateFrame("Frame", nil, f)
    left:SetSize(250, 450)
    left:SetPoint("TOPLEFT", 15, -45)
    CreateSausageBackdrop(left, "gray")

    -- MID PANEL
    local mid = CreateFrame("Frame", nil, f)
    mid:SetSize(350, 450)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)

    -- DROPDOWN: INSTANCE
    local instDrop = CreateFrame("Frame", "SLFM_InstDrop", mid, "UIDropDownMenuTemplate")
    instDrop:SetPoint("TOPLEFT", -15, -10)
    UIDropDownMenu_Initialize(instDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs({"ICC", "TOC", "Ulduar", "Naxx", "Dungeon"}) do
            info.text = v; info.func = function() SausageLFM_DB.instance = v; UIDropDownMenu_SetText(instDrop, v); SLFM:UpdateMessage() end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(instDrop, 100)
    UIDropDownMenu_SetText(instDrop, SausageLFM_DB.instance)

    -- MIN GS BOX
    local gsBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsBox:SetSize(60, 25)
    gsBox:SetPoint("TOPRIGHT", -15, -10)
    gsBox:SetAutoFocus(false)
    gsBox:SetText(tostring(SausageLFM_DB.minGS))
    gsBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gl:SetPoint("RIGHT", gsBox, "LEFT", -5, 0); gl:SetText("Min GS:")

    -- BASIC ROLES (Tank, Heal, mDPS, rDPS)
    local rX = 15
    for _, r in ipairs({"Tank", "Heal", "mDPS", "rDPS"}) do
        local rb = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
        rb:SetSize(35, 25); rb:SetPoint("TOPLEFT", rX, -70); rb:SetAutoFocus(false)
        rb:SetText(tostring(SausageLFM_DB.roles[r] or 0))
        rb:SetScript("OnTextChanged", function(self) SausageLFM_DB.roles[r] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
        local rl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rl:SetPoint("BOTTOM", rb, "TOP", 0, 2); rl:SetText(r)
        rX = rX + 80
    end

    -- SPEC SELECTOR
    local specDrop = CreateFrame("Frame", "SLFM_SpecDrop", mid, "UIDropDownMenuTemplate")
    specDrop:SetPoint("TOPLEFT", -15, -120)
    local selectedSpec = "Holy Paladin"
    UIDropDownMenu_Initialize(specDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs({"Holy Paladin", "Resto Shaman", "Resto Druid", "Disc Priest", "Shadow Priest", "Boomkin"}) do
            info.text = v; info.func = function() selectedSpec = v; UIDropDownMenu_SetText(specDrop, v) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(specDrop, 120); UIDropDownMenu_SetText(specDrop, selectedSpec)

    local addBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 25); addBtn:SetPoint("LEFT", specDrop, "RIGHT", -10, 2); addBtn:SetText("Add")
    
    local specCont = CreateFrame("Frame", nil, mid)
    specCont:SetSize(300, 150); specCont:SetPoint("TOPLEFT", 15, -160)
    
    local function RefreshSpecs()
        if specCont.lines then for _, l in ipairs(specCont.lines) do l:Hide() end end
        specCont.lines = {}
        local i = 0
        for s, n in pairs(SausageLFM_DB.specs) do
            local l = CreateFrame("Frame", nil, specCont)
            l:SetSize(300, 25); l:SetPoint("TOPLEFT", 0, -(i*25))
            local txt = l:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); txt:SetPoint("LEFT", 0, 0); txt:SetText(s)
            local eb = CreateFrame("EditBox", nil, l, "InputBoxTemplate")
            eb:SetSize(30, 25); eb:SetPoint("RIGHT", -50, 0); eb:SetText(tostring(n))
            eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.specs[s] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
            local del = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
            del:SetSize(20, 20); del:SetPoint("RIGHT", 0, 0); del:SetText("X")
            del:SetScript("OnClick", function() SausageLFM_DB.specs[s] = nil; RefreshSpecs(); SLFM:UpdateMessage() end)
            tinsert(specCont.lines, l); i = i + 1
        end
    end
    addBtn:SetScript("OnClick", function() SausageLFM_DB.specs[selectedSpec] = 1; RefreshSpecs(); SLFM:UpdateMessage() end)
    RefreshSpecs()

    -- BROADCAST & TIMER
    local timerBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    timerBox:SetSize(40, 25); timerBox:SetPoint("BOTTOMLEFT", 60, 110); timerBox:SetText(tostring(SausageLFM_DB.interval))
    timerBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.interval = tonumber(self:GetText()) or 45 end)
    local tl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tl:SetPoint("RIGHT", timerBox, "LEFT", -5, 0); tl:SetText("Timer (s):")

    local cX = 15
    for _, ch in ipairs({"World", "Global", "LFG", "Party"}) do
        local cb = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
        cb:SetPoint("BOTTOMLEFT", cX, 80); cb:SetChecked(SausageLFM_DB.channels[ch])
        cb:SetScript("OnClick", function(self) SausageLFM_DB.channels[ch] = self:GetChecked() end)
        local cl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cl:SetPoint("LEFT", cb, "RIGHT", 0, 0); cl:SetText(ch)
        cX = cX + 80
    end

    f.preview = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.preview:SetPoint("BOTTOM", 0, 55); f.preview:SetWidth(330)

    local startBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    startBtn:SetSize(200, 35); startBtn:SetPoint("BOTTOM", 0, 15); startBtn:SetText("START FLOODING")
    startBtn:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)

    -- RIGHT PANEL (Queue)
    local right = CreateFrame("Frame", "SausageLFM_Queue", f)
    right:SetSize(250, 450); right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 10, 0)
    CreateSausageBackdrop(right, "gold")

    self:RefreshRaidTable()
end

function SLFM:RefreshQueueTable()
    if not SausageLFM_Queue or not SausageLFM_Queue:IsShown() then return end
    if not self.qRows then self.qRows = {} end
    for _, r in ipairs(self.qRows) do r:Hide() end
    for i, data in ipairs(self.Queue) do
        if not self.qRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Queue)
            r:SetSize(230, 25); r:SetPoint("TOPLEFT", 5, -15-(i*28))
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.t:SetPoint("LEFT", 25, 0)
            r.env = CreateFrame("Button", nil, r); r.env:SetSize(20, 20); r.env:SetPoint("LEFT", 0, 0); r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
            r.inv = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.inv:SetSize(35, 20); r.inv:SetPoint("RIGHT", -25, 0); r.inv:SetText("Inv")
            r.rej = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.rej:SetSize(20, 20); r.rej:SetPoint("RIGHT", 0, 0); r.rej:SetText("X")
            self.qRows[i] = r
        end
        local r = self.qRows[i]
        r.t:SetText(data.name .. " (" .. (data.gs or "??") .. "gs)")
        r.inv:SetScript("OnClick", function() InviteUnit(data.name) end)
        r.rej:SetScript("OnClick", function() table.remove(SLFM.Queue, i); SLFM:RefreshQueueTable() end)
        r.env:SetScript("OnClick", function() ChatFrame_SendTell(data.name) end)
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
            r:SetSize(230, 20); r:SetPoint("TOPLEFT", 10, -20-(i*22))
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.t:SetPoint("LEFT", 20, 0)
            r.k = CreateFrame("Button", nil, r); r.k:SetSize(16, 16); r.k:SetPoint("RIGHT", -5, 0); r.k:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            self.rRows[i] = r
        end
        local r = self.rRows[i]
        local gs = SLFM:GetExternalGS(name)
        r.t:SetText(name .. " - " .. (gs > 0 and gs or "Unscanned"))
        r.k:SetScript("OnClick", function() UninviteUnit(name) end)
        r:Show()
    end
end