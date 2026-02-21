-- SausageLFM_UI.lua
local SLFM = SausageLFM

local ClassData = {
    ["Paladin"] = {"Holy", "Prot", "Ret"}, ["Warrior"] = {"Arms", "Fury", "Prot"},
    ["Death Knight"] = {"Blood", "Frost", "Unholy"}, ["Hunter"] = {"BM", "MM", "Surv"},
    ["Shaman"] = {"Ele", "Enh", "Resto"}, ["Rogue"] = {"Assa", "Combat", "Sub"},
    ["Druid"] = {"Boom", "Feral", "Resto"}, ["Mage"] = {"Arcane", "Fire", "Frost"},
    ["Priest"] = {"Disc", "Holy", "Shadow"}, ["Warlock"] = {"Affli", "Demo", "Destro"}
}
local ClassList = {"Paladin", "Warrior", "Death Knight", "Hunter", "Shaman", "Rogue", "Druid", "Mage", "Priest", "Warlock"}

local function CreateBackdrop(f, colorType)
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.8)
    if colorType == "gold" then f:SetBackdropBorderColor(1, 0.8, 0)
    elseif colorType == "blue" then f:SetBackdropBorderColor(0, 0.5, 1) -- Modrý rámik
    else f:SetBackdropBorderColor(0.5, 0.5, 0.5) end
end

function SLFM:InitializeUI()
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(960, 680) -- Zväčšené okno smerom dole
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

    -- LEFT PANEL (Modrý rámček)
    local left = CreateFrame("Frame", "SausageLFM_Raid", f)
    left:SetSize(250, 570)
    left:SetPoint("TOPLEFT", 20, -50)
    CreateBackdrop(left, "blue")
    local lTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lTitle:SetPoint("BOTTOM", left, "TOP", 0, 5)
    lTitle:SetText("Raid Overview")

    -- MID PANEL
    local mid = CreateFrame("Frame", nil, f)
    mid:SetSize(410, 570)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 15, 0)

    -- RIGHT PANEL (Zlatý rámček)
    local right = CreateFrame("Frame", "SausageLFM_Queue", f)
    right:SetSize(250, 570)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 15, 0)
    CreateBackdrop(right, "gold")
    local rTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rTitle:SetPoint("BOTTOM", right, "TOP", 0, 5)
    rTitle:SetText("Candidate Queue")

    -- =====================================
    -- 🎛️ SMART DUNGEON/RAID DROPDOWNS
    -- =====================================
    local instDrop = CreateFrame("Frame", "SLFM_InstDrop", mid, "UIDropDownMenuTemplate")
    instDrop:SetPoint("TOPLEFT", -15, -10)
    local modeDrop = CreateFrame("Frame", "SLFM_ModeDrop", mid, "UIDropDownMenuTemplate")
    modeDrop:SetPoint("LEFT", instDrop, "RIGHT", -10, 0)

    local function UpdateHCVisibility()
        if SausageLFM_DB.instance == "Dungeon" then
            SLFM_HC:Show()
            _G["SLFM_HCText"]:Show()
        else
            SLFM_HC:Hide()
            _G["SLFM_HCText"]:Hide()
            SausageLFM_DB.isHC = false -- Auto turn off for raids
        end
    end

    local function InitModeDropdown()
        UIDropDownMenu_Initialize(modeDrop, function()
            local info = UIDropDownMenu_CreateInfo()
            local list = {}
            if SausageLFM_DB.instance == "Dungeon" then
                list = {"Random Heroic", "Daily Heroic", "Forge of Souls", "Pit of Saron", "Halls of Reflection", "Trial of the Champion", "Utgarde Keep", "The Nexus", "Azjol-Nerub", "Ahn'kahet: The Old Kingdom", "Drak'Tharon Keep", "The Violet Hold", "Gundrak", "Halls of Stone", "Halls of Lightning", "Utgarde Pinnacle", "The Oculus", "The Culling of Stratholme"}
                if SausageLFM_DB.mode == "10" or SausageLFM_DB.mode == "25" then SausageLFM_DB.mode = "Random Heroic" end
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
        local list = {"Icecrown Citadel", "Ruby Sanctum", "Trial of the Crusader", "Ulduar", "Naxxramas", "The Obsidian Sanctum", "The Eye of Eternity", "Vault of Archavon", "Dungeon"}
        for _, v in ipairs(list) do
            info.text = v
            info.func = function() 
                SausageLFM_DB.instance = v
                UIDropDownMenu_SetText(instDrop, v)
                InitModeDropdown()
                UpdateHCVisibility()
                SLFM:UpdateMessage() 
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(instDrop, SausageLFM_DB.instance)
    UIDropDownMenu_SetWidth(instDrop, 130)
    InitModeDropdown()
    UIDropDownMenu_SetWidth(modeDrop, 130)

    -- CHECKBOXY A GS (Vymenené pozície, HC skryté pre raidy)
    local ach = CreateFrame("CheckButton", "SLFM_Ach", mid, "UICheckButtonTemplate")
    ach:SetPoint("TOPLEFT", 10, -45)
    ach:SetChecked(SausageLFM_DB.reqAchiev)
    ach:SetScript("OnClick", function(self) SausageLFM_DB.reqAchiev = self:GetChecked(); SLFM:UpdateMessage() end)
    local achText = mid:CreateFontString("SLFM_AchText", "OVERLAY", "GameFontHighlightSmall")
    achText:SetPoint("LEFT", ach, "RIGHT", 0, 0); achText:SetText("Achiev")

    local hc = CreateFrame("CheckButton", "SLFM_HC", mid, "UICheckButtonTemplate")
    hc:SetPoint("LEFT", achText, "RIGHT", 15, 0)
    hc:SetChecked(SausageLFM_DB.isHC)
    hc:SetScript("OnClick", function(self) SausageLFM_DB.isHC = self:GetChecked(); SLFM:UpdateMessage() end)
    local hcText = mid:CreateFontString("SLFM_HCText", "OVERLAY", "GameFontHighlightSmall")
    hcText:SetPoint("LEFT", hc, "RIGHT", 0, 0); hcText:SetText("HC")

    UpdateHCVisibility() -- Skryje HC ak je zapnuty Raid

    local gsIn = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsIn:SetSize(60, 20)
    gsIn:SetPoint("TOPRIGHT", -15, -48)
    gsIn:SetAutoFocus(false)
    gsIn:SetText(tostring(SausageLFM_DB.minGS))
    gsIn:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gsl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); gsl:SetPoint("RIGHT", gsIn, "LEFT", -5, 0); gsl:SetText("Min GS:")

    -- =====================================
    -- 🎛️ BASIC ROLES & DEFAULT AUTO-FILL
    -- =====================================
    local brLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    brLbl:SetPoint("TOPLEFT", 10, -90); brLbl:SetText("Basic Roles:")

    local rBoxes = {} 
    local rX = 10
    for _, r in ipairs({"Tank", "Heal", "mDPS", "rDPS"}) do
        local eb = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
        eb:SetSize(35, 20); eb:SetPoint("TOPLEFT", rX, -120); eb:SetAutoFocus(false)
        eb:SetText(tostring(SausageLFM_DB.roles[r] or 0))
        eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.roles[r] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
        local rl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rl:SetPoint("BOTTOM", eb, "TOP", 0, 3); rl:SetText(r)
        rBoxes[r] = eb; rX = rX + 65
    end

    local defBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    defBtn:SetSize(70, 25); defBtn:SetPoint("TOPLEFT", rX + 10, -118); defBtn:SetText("Default")
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

    -- =====================================
    -- 🎛️ DUAL-SPEC KASKÁDA (Opravený filter)
    -- =====================================
    local spLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spLbl:SetPoint("TOPLEFT", 10, -165); spLbl:SetText("Add Specific / Dual Specs:")

    local selClass = "Paladin"
    local selMain = "Holy"
    local selOff = "None"

    local cDrop = CreateFrame("Frame", "SLFM_CDrop", mid, "UIDropDownMenuTemplate")
    cDrop:SetPoint("TOPLEFT", -15, -185)
    local mDrop = CreateFrame("Frame", "SLFM_MDrop", mid, "UIDropDownMenuTemplate")
    mDrop:SetPoint("LEFT", cDrop, "RIGHT", -20, 0)
    local oDrop = CreateFrame("Frame", "SLFM_ODrop", mid, "UIDropDownMenuTemplate")
    oDrop:SetPoint("LEFT", mDrop, "RIGHT", -20, 0)

    local function InitSpecDropdowns()
        UIDropDownMenu_Initialize(mDrop, function()
            local info = UIDropDownMenu_CreateInfo()
            for _, v in ipairs(ClassData[selClass]) do
                info.text = v
                info.func = function() 
                    selMain = v
                    UIDropDownMenu_SetText(mDrop, v) 
                    if selOff == selMain then 
                        selOff = "None"
                        UIDropDownMenu_SetText(oDrop, "None")
                    end
                    InitSpecDropdowns() -- Re-init offspec menu to apply filter
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        UIDropDownMenu_Initialize(oDrop, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text = "None"; info.func = function() selOff = "None"; UIDropDownMenu_SetText(oDrop, "None") end
            UIDropDownMenu_AddButton(info)
            
            for _, v in ipairs(ClassData[selClass]) do
                if v ~= selMain then -- FILTER: Skryje main spec z Off-spec menu
                    local oInfo = UIDropDownMenu_CreateInfo()
                    oInfo.text = v
                    oInfo.func = function() selOff = v; UIDropDownMenu_SetText(oDrop, v) end
                    UIDropDownMenu_AddButton(oInfo)
                end
            end
        end)
    end

    UIDropDownMenu_Initialize(cDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs(ClassList) do
            info.text = v
            info.func = function() 
                selClass = v
                selMain = ClassData[v][1]
                selOff = "None"
                UIDropDownMenu_SetText(cDrop, v)
                UIDropDownMenu_SetText(mDrop, selMain)
                UIDropDownMenu_SetText(oDrop, selOff)
                InitSpecDropdowns()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(cDrop, selClass); UIDropDownMenu_SetWidth(cDrop, 95)
    InitSpecDropdowns()
    UIDropDownMenu_SetText(mDrop, selMain); UIDropDownMenu_SetWidth(mDrop, 70)
    UIDropDownMenu_SetText(oDrop, selOff); UIDropDownMenu_SetWidth(oDrop, 70)

    local specCont = CreateFrame("Frame", nil, mid)
    specCont:SetSize(390, 180); specCont:SetPoint("TOPLEFT", 10, -225)

    local function DrawActiveSpecs()
        if specCont.rows then for _, r in ipairs(specCont.rows) do r:Hide() end end
        specCont.rows = {}
        local idx = 0
        for name, count in pairs(SausageLFM_DB.specs) do
            if count > 0 then
                local col = idx % 2
                local rowN = math.floor(idx / 2)
                local r = CreateFrame("Frame", nil, specCont)
                r:SetSize(190, 24); r:SetPoint("TOPLEFT", col * 195, -(rowN * 26))
                
                local txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT", 0, 0); txt:SetText(name)
                
                local eb = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
                eb:SetSize(25, 18); eb:SetPoint("RIGHT", -30, 0); eb:SetText(tostring(count))
                eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.specs[name] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
                
                local del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
                del:SetSize(20, 18); del:SetPoint("RIGHT", 0, 0); del:SetText("X")
                del:SetScript("OnClick", function() SausageLFM_DB.specs[name] = nil; DrawActiveSpecs(); SLFM:UpdateMessage() end)
                
                tinsert(specCont.rows, r); idx = idx + 1
            end
        end
    end

    local addSpecBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    addSpecBtn:SetSize(45, 24); addSpecBtn:SetPoint("LEFT", oDrop, "RIGHT", -10, 2); addSpecBtn:SetText("Add")
    addSpecBtn:SetScript("OnClick", function()
        local formattedName = selMain .. " " .. selClass
        if selOff ~= "None" then formattedName = formattedName .. " (OS " .. selOff .. ")" end
        SausageLFM_DB.specs[formattedName] = (SausageLFM_DB.specs[formattedName] or 0) + 1
        DrawActiveSpecs(); SLFM:UpdateMessage()
    end)
    DrawActiveSpecs()

    -- =====================================
    -- 🎛️ BROADCAST ENGINE (Sivý Box)
    -- =====================================
    local bcBox = CreateFrame("Frame", nil, mid)
    bcBox:SetSize(410, 150)
    bcBox:SetPoint("BOTTOMLEFT", 0, 0)
    CreateBackdrop(bcBox, "gray")
    
    local bcTitle = bcBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bcTitle:SetPoint("TOPLEFT", 10, -10)
    bcTitle:SetText("Broadcast Engine")

    local timer = CreateFrame("EditBox", nil, bcBox, "InputBoxTemplate")
    timer:SetSize(40, 20); timer:SetPoint("TOPLEFT", 60, -35); timer:SetAutoFocus(false)
    timer:SetText(tostring(SausageLFM_DB.interval))
    timer:SetScript("OnTextChanged", function(self) SausageLFM_DB.interval = tonumber(self:GetText()) or 45 end)
    
    local tl1 = bcBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); tl1:SetPoint("RIGHT", timer, "LEFT", -5, 0); tl1:SetText("Timer:")
    local tl2 = bcBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); tl2:SetPoint("LEFT", timer, "RIGHT", 5, 0); tl2:SetText("sec")

    local cX = 10
    for _, ch in ipairs({"World", "Global", "LFG", "Party"}) do
        local cb = CreateFrame("CheckButton", nil, bcBox, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", cX, -65); cb:SetChecked(SausageLFM_DB.channels[ch])
        cb:SetScript("OnClick", function(self) SausageLFM_DB.channels[ch] = self:GetChecked() end)
        local cbText = bcBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0); cbText:SetText(ch)
        cX = cX + 90
    end

    f.preview = bcBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.preview:SetPoint("BOTTOM", 0, 45); f.preview:SetWidth(390)

    local flood = CreateFrame("Button", nil, bcBox, "UIPanelButtonTemplate")
    flood:SetSize(250, 30); flood:SetPoint("BOTTOM", 0, 10); flood:SetText("START FLOODING")
    flood:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)
    
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    local verString = SLFM.Version; if type(verString) ~= "string" or verString == "" then verString = "1.8.0" end
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