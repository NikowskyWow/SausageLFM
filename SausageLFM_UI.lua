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
    f:SetSize(920, 560)
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

    local left = CreateFrame("Frame", "SausageLFM_Raid", f)
    left:SetSize(240, 460)
    left:SetPoint("TOPLEFT", 20, -60)
    CreateBackdrop(left)

    local mid = CreateFrame("Frame", nil, f)
    mid:SetSize(380, 460)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)

    -- Dropdowns
    local instDrop = CreateFrame("Frame", "SLFM_InstDrop", mid, "UIDropDownMenuTemplate")
    instDrop:SetPoint("TOPLEFT", -15, 0)
    UIDropDownMenu_Initialize(instDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        local list = {"ICC", "TOC", "Ulduar", "Naxx", "RS", "OS", "EoE", "VoA", "Dungeon"}
        for _, v in ipairs(list) do
            info.text = v
            info.func = function() SausageLFM_DB.instance = v; UIDropDownMenu_SetText(instDrop, v); SLFM:UpdateMessage() end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(instDrop, SausageLFM_DB.instance)
    UIDropDownMenu_SetWidth(instDrop, 100)

    local modeDrop = CreateFrame("Frame", "SLFM_ModeDrop", mid, "UIDropDownMenuTemplate")
    modeDrop:SetPoint("LEFT", instDrop, "RIGHT", -30, 0)
    UIDropDownMenu_Initialize(modeDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs({"10", "25"}) do
            info.text = v
            info.func = function() SausageLFM_DB.mode = v; UIDropDownMenu_SetText(modeDrop, v); SLFM:UpdateMessage() end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(modeDrop, SausageLFM_DB.mode)
    UIDropDownMenu_SetWidth(modeDrop, 50)

    -- Toggles & GS (Opravený bezpečný kód bez zreťazenia nil hodnôt)
    local hc = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    hc:SetPoint("TOPLEFT", 10, -40)
    hc:SetChecked(SausageLFM_DB.isHC)
    hc:SetScript("OnClick", function(self) SausageLFM_DB.isHC = self:GetChecked(); SLFM:UpdateMessage() end)
    local hcText = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hcText:SetPoint("LEFT", hc, "RIGHT", 2, 0)
    hcText:SetText("HC")

    local ach = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    ach:SetPoint("LEFT", hcText, "RIGHT", 20, 0)
    ach:SetChecked(SausageLFM_DB.reqAchiev)
    ach:SetScript("OnClick", function(self) SausageLFM_DB.reqAchiev = self:GetChecked(); SLFM:UpdateMessage() end)
    local achText = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    achText:SetPoint("LEFT", ach, "RIGHT", 2, 0)
    achText:SetText("Achiev")

    local gsIn = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsIn:SetSize(60, 20)
    gsIn:SetPoint("TOPRIGHT", -20, -45)
    gsIn:SetAutoFocus(false)
    gsIn:SetText(tostring(SausageLFM_DB.minGS))
    gsIn:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gsl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gsl:SetPoint("RIGHT", gsIn, "LEFT", -5, 0)
    gsl:SetText("Min GS:")

    -- Roles
    local brLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    brLbl:SetPoint("TOPLEFT", 10, -85)
    brLbl:SetText("Basic Roles:")
    
    local rX = 10
    for _, r in ipairs({"Tank", "Heal", "mDPS", "rDPS"}) do
        local eb = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
        eb:SetSize(35, 20)
        eb:SetPoint("TOPLEFT", rX, -115)
        eb:SetAutoFocus(false)
        eb:SetText(tostring(SausageLFM_DB.roles[r] or 0))
        eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.roles[r] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
        local rl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rl:SetPoint("BOTTOM", eb, "TOP", 0, 5)
        rl:SetText(r)
        rX = rX + 90
    end

    -- Specs
    local spLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spLbl:SetPoint("TOPLEFT", 10, -150)
    spLbl:SetText("Specific Specs:")
    
    local sDrop = CreateFrame("Frame", "SLFM_SpecDrop", mid, "UIDropDownMenuTemplate")
    sDrop:SetPoint("TOPLEFT", -15, -165)
    local curSpec = "Holy Paladin"
    UIDropDownMenu_Initialize(sDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        local specs = {"Holy Paladin", "Prot Paladin", "Ret Paladin", "Resto Shaman", "Enhance Shaman", "Ele Shaman", "Resto Druid", "Feral Druid", "Boomkin", "Disc Priest", "Shadow Priest", "Blood DK", "Unholy DK", "Rogue", "Hunter", "Mage", "Warlock"}
        for _, s in ipairs(specs) do
            info.text = s
            info.func = function() curSpec = s; UIDropDownMenu_SetText(sDrop, s) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(sDrop, curSpec)
    UIDropDownMenu_SetWidth(sDrop, 140)

    local sCont = CreateFrame("Frame", nil, mid)
    sCont:SetSize(340, 120)
    sCont:SetPoint("TOPLEFT", 10, -200)
    
    local function UpdateSpecs()
        if sCont.rows then for _, r in ipairs(sCont.rows) do r:Hide() end end
        sCont.rows = {}
        local i = 0
        for name, count in pairs(SausageLFM_DB.specs) do
            local r = CreateFrame("Frame", nil, sCont)
            r:SetSize(340, 22)
            r:SetPoint("TOPLEFT", 0, -(i*24))
            
            local txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 0, 0)
            txt:SetText(name)
            
            local eb = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
            eb:SetSize(30, 18)
            eb:SetPoint("RIGHT", -50, 0)
            eb:SetText(tostring(count))
            eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.specs[name] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
            
            local del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            del:SetSize(20, 18)
            del:SetPoint("RIGHT", 0, 0)
            del:SetText("X")
            del:SetScript("OnClick", function() SausageLFM_DB.specs[name] = nil; UpdateSpecs(); SLFM:UpdateMessage() end)
            
            tinsert(sCont.rows, r)
            i = i + 1
        end
    end

    local addBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", sDrop, "RIGHT", -10, 2)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function() SausageLFM_DB.specs[curSpec] = 1; UpdateSpecs(); SLFM:UpdateMessage() end)
    UpdateSpecs()

    -- Timer & Channels (Opravené bezpečne bez GetName() volaní)
    local timer = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    timer:SetSize(40, 20)
    timer:SetPoint("BOTTOMLEFT", 60, 105)
    timer:SetAutoFocus(false)
    timer:SetText(tostring(SausageLFM_DB.interval))
    timer:SetScript("OnTextChanged", function(self) SausageLFM_DB.interval = tonumber(self:GetText()) or 45 end)
    
    local tl1 = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tl1:SetPoint("RIGHT", timer, "LEFT", -5, 0)
    tl1:SetText("Timer:")
    
    local tl2 = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tl2:SetPoint("LEFT", timer, "RIGHT", 5, 0)
    tl2:SetText("sec")

    local cX = 10
    for _, ch in ipairs({"World", "Global", "LFG", "Party"}) do
        local cb = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
        cb:SetPoint("BOTTOMLEFT", cX, 75)
        cb:SetChecked(SausageLFM_DB.channels[ch])
        cb:SetScript("OnClick", function(self) SausageLFM_DB.channels[ch] = self:GetChecked() end)
        
        local cbText = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cbText:SetText(ch)
        
        cX = cX + 85
    end

    f.preview = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.preview:SetPoint("BOTTOM", 0, 55)
    f.preview:SetWidth(340)

    local flood = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    flood:SetSize(220, 35)
    flood:SetPoint("BOTTOM", 0, 15)
    flood:SetText("START FLOODING")
    flood:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)

    local right = CreateFrame("Frame", "SausageLFM_Queue", f)
    right:SetSize(250, 460)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 10, 0)
    CreateBackdrop(right, true)
    
    -- Opravený Failsafe pre verziu (pre istotu ak skript vymaže všetko)
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    local verString = SLFM.Version
    if type(verString) ~= "string" or verString == "" then verString = "1.5.0" end
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
            r:SetSize(235, 25)
            r:SetPoint("TOPLEFT", 5, -15-(i*28))
            
            local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("LEFT", 5, 0)
            r.t = t
            
            local inv = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            inv:SetSize(40, 20)
            inv:SetPoint("RIGHT", -30, 0)
            inv:SetText("Inv")
            r.inv = inv
            
            local rej = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            rej:SetSize(25, 20)
            rej:SetPoint("RIGHT", 0, 0)
            rej:SetText("X")
            r.rej = rej
            
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
            r:SetSize(230, 20)
            r:SetPoint("TOPLEFT", 5, -15-(i*22))
            
            local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("LEFT", 5, 0)
            r.t = t
            
            self.rRows[i] = r
        end
        local r = self.rRows[i]
        local gs = SLFM:GetExternalGS(name)
        r.t:SetText(name .. " - " .. (gs > 0 and gs or "Unscanned"))
        r:Show()
    end
end