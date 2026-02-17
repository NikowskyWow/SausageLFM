-- SausageLFM_UI.lua
local SLFM = SausageLFM

local function CreateSausageBackdrop(frame, colorType)
    local c = {0, 0.7, 1, 1}
    if colorType == "gold" then c = {1, 0.8, 0, 1}
    elseif colorType == "gray" then c = {0.6, 0.6, 0.6, 1} end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(unpack(c))
end

local function SetHoverTooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.8, 0)
        if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function SLFM:InitializeUI()
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(900, 540)
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

    local h = f:CreateTexture(nil, "OVERLAY")
    h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    h:SetSize(350, 64)
    h:SetPoint("TOP", 0, 12)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", h, "TOP", 0, -14)
    t:SetText("SAUSAGE COMMAND CENTER")
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    -- 📋 LEFT PANEL (Raid)
    local left = CreateFrame("Frame", "SausageLFM_Raid", f)
    left:SetSize(250, 450)
    left:SetPoint("TOPLEFT", 15, -45)
    CreateSausageBackdrop(left, "gray")
    left.t = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    left.t:SetPoint("TOP", 0, -10)
    left.t:SetText("Raid Overview (Right-Click: Role)")

    -- 🎛️ MID PANEL (Command & Control)
    local mid = CreateFrame("Frame", "SausageLFM_Ctrl", f)
    mid:SetSize(350, 450)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)

    -- Dropdown: Instance
    local instDrop = CreateFrame("Frame", "SLFM_InstDrop", mid, "UIDropDownMenuTemplate")
    instDrop:SetPoint("TOPLEFT", -5, -10)
    UIDropDownMenu_Initialize(instDrop, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        local insts = {"ICC", "TOC", "Ulduar", "Naxxramas", "Obsidian Sanctum", "Eye of Eternity", "Vault of Archavon", "Dungeon"}
        for _, v in ipairs(insts) do
            info.text = v
            info.arg1 = v
            info.func = function(self, arg1)
                SausageLFM_DB.instance = arg1
                UIDropDownMenu_SetText(instDrop, arg1)
                SLFM:UpdateMessage()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(instDrop, SausageLFM_DB.instance)
    UIDropDownMenu_SetWidth(instDrop, 130)

    -- Dropdown: Mode
    local modeDrop = CreateFrame("Frame", "SLFM_ModeDrop", mid, "UIDropDownMenuTemplate")
    modeDrop:SetPoint("LEFT", instDrop, "RIGHT", -25, 0)
    UIDropDownMenu_Initialize(modeDrop, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        local modes = {"10", "25"}
        for _, v in ipairs(modes) do
            info.text = v
            info.arg1 = v
            info.func = function(self, arg1)
                SausageLFM_DB.mode = arg1
                UIDropDownMenu_SetText(modeDrop, arg1)
                SLFM:UpdateMessage()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(modeDrop, SausageLFM_DB.mode)
    UIDropDownMenu_SetWidth(modeDrop, 60)

    -- Toggles & Min GS
    local hcBtn = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    hcBtn:SetPoint("TOPLEFT", 10, -45)
    hcBtn:SetSize(26, 26)
    hcBtn.t = hcBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hcBtn.t:SetPoint("LEFT", hcBtn, "RIGHT", 2, 0)
    hcBtn.t:SetText("HC")
    hcBtn:SetChecked(SausageLFM_DB.isHC)
    hcBtn:SetScript("OnClick", function(self) SausageLFM_DB.isHC = self:GetChecked(); SLFM:UpdateMessage() end)

    local achBtn = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    achBtn:SetPoint("LEFT", hcBtn.t, "RIGHT", 5, 0)
    achBtn:SetSize(26, 26)
    achBtn.t = achBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    achBtn.t:SetPoint("LEFT", achBtn, "RIGHT", 2, 0)
    achBtn.t:SetText("Achiev")
    achBtn:SetChecked(SausageLFM_DB.reqAchiev)
    achBtn:SetScript("OnClick", function(self) SausageLFM_DB.reqAchiev = self:GetChecked(); SLFM:UpdateMessage() end)

    local gsBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsBox:SetSize(45, 20)
    gsBox:SetPoint("TOPRIGHT", -15, -48)
    gsBox:SetAutoFocus(false)
    gsBox:SetText(tostring(SausageLFM_DB.minGS))
    gsBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gsLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gsLbl:SetPoint("RIGHT", gsBox, "LEFT", -5, 0)
    gsLbl:SetText("Min GS:")

    -- Generické Role (Tank, Heal, mDPS, rDPS)
    mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"):SetPoint("TOPLEFT", 15, -80):SetText("Basic Roles:")
    local rList = {"Tank", "Heal", "mDPS", "rDPS"}
    for i, r in ipairs(rList) do
        local rLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rLbl:SetPoint("TOPLEFT", 15 + ((i-1)*80), -95)
        rLbl:SetText(r)
        
        local rBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
        rBox:SetSize(30, 20)
        rBox:SetPoint("TOPLEFT", 15 + ((i-1)*80), -110)
        rBox:SetAutoFocus(false)
        rBox:SetText(tostring(SausageLFM_DB.roles[r] or 0))
        rBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.roles[r] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    end

    -- Spec Dropdown (Pridávanie)
    mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"):SetPoint("TOPLEFT", 15, -145):SetText("Specific Specs:")
    local currentSelSpec = "Holy Paladin"
    local specDrop = CreateFrame("Frame", "SLFM_SpecDrop", mid, "UIDropDownMenuTemplate")
    specDrop:SetPoint("TOPLEFT", -5, -160)
    UIDropDownMenu_Initialize(specDrop, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        local specs = {"Holy Paladin", "Prot Paladin", "Ret Paladin", "Resto Shaman", "Enhance Shaman", "Ele Shaman", "Resto Druid", "Feral Druid", "Boomkin", "Disc Priest", "Holy Priest", "Shadow Priest", "Blood DK", "Frost DK", "Unholy DK", "Rogue", "Hunter", "Mage", "Warlock", "Warrior"}
        for _, v in ipairs(specs) do
            info.text = v
            info.arg1 = v
            info.func = function(self, arg1)
                currentSelSpec = arg1
                UIDropDownMenu_SetText(specDrop, arg1)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(specDrop, currentSelSpec)
    UIDropDownMenu_SetWidth(specDrop, 140)

    -- Kontajner na aktívne specy
    local specCont = CreateFrame("Frame", nil, mid)
    specCont:SetSize(300, 100)
    specCont:SetPoint("TOPLEFT", 15, -195)
    
    local function DrawSpecs()
        if specCont.rows then for _, r in ipairs(specCont.rows) do r:Hide() end end
        specCont.rows = {}
        local idx = 1
        for sp, num in pairs(SausageLFM_DB.specs) do
            if num > 0 then
                local row = CreateFrame("Frame", nil, specCont)
                row:SetSize(300, 22)
                row:SetPoint("TOPLEFT", 0, -((idx-1)*24))
                
                local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                btn:SetSize(20, 20):SetPoint("LEFT", 0, 0):SetText("X")
                btn:SetScript("OnClick", function() SausageLFM_DB.specs[sp] = nil; DrawSpecs(); SLFM:UpdateMessage() end)
                
                local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                txt:SetPoint("LEFT", btn, "RIGHT", 5, 0):SetText(sp)
                
                local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                box:SetSize(30, 20):SetPoint("RIGHT", -20, 0):SetAutoFocus(false):SetText(tostring(num))
                box:SetScript("OnTextChanged", function(self) SausageLFM_DB.specs[sp] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
                
                table.insert(specCont.rows, row)
                idx = idx + 1
            end
        end
    end

    local addSpecBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    addSpecBtn:SetSize(50, 22)
    addSpecBtn:SetPoint("LEFT", specDrop, "RIGHT", -10, 3)
    addSpecBtn:SetText("Add")
    addSpecBtn:SetScript("OnClick", function()
        SausageLFM_DB.specs[currentSelSpec] = 1
        DrawSpecs()
        SLFM:UpdateMessage()
    end)
    DrawSpecs() -- Init kreslenie

    -- Kanály a Delay (Broadcast Engine)
    mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", 15, 120):SetText("Broadcast:")
    
    local delayBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    delayBox:SetSize(30, 20):SetPoint("BOTTOMLEFT", 60, 118):SetAutoFocus(false):SetText(tostring(SausageLFM_DB.interval))
    delayBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.interval = tonumber(self:GetText()) or 45 end)
    mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"):SetPoint("RIGHT", delayBox, "LEFT", -5, 0):SetText("Delay:")
    mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"):SetPoint("LEFT", delayBox, "RIGHT", 5, 0):SetText("sec")

    local cX = 15
    for _, ch in ipairs({"World", "Global", "LFG", "Party"}) do
        local cb = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("BOTTOMLEFT", cX, 95)
        cb.t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cb.t:SetPoint("LEFT", cb, "RIGHT", 0, 0)
        cb.t:SetText(ch)
        cb:SetChecked(SausageLFM_DB.channels[ch])
        cb:SetScript("OnClick", function(self) SausageLFM_DB.channels[ch] = self:GetChecked() end)
        cX = cX + 75
    end

    f.preview = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.preview:SetPoint("BOTTOM", 0, 50)
    f.preview:SetWidth(330)
    
    local startBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    startBtn:SetSize(200, 30)
    startBtn:SetPoint("BOTTOM", 0, 10)
    startBtn:SetText("START FLOODING")
    startBtn:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)

    -- 🛡️ RIGHT PANEL (Queue)
    local right = CreateFrame("Frame", "SausageLFM_Queue", f)
    right:SetSize(250, 450)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 10, 0)
    CreateSausageBackdrop(right, "gold")
    right.t = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    right.t:SetPoint("TOP", 0, -10)
    right.t:SetText("Candidate Queue")

    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    verText:SetText("v" .. (SLFM.Version ~= "" and SLFM.Version or "1.4.0"))

    local authorText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    authorText:SetPoint("BOTTOM", 0, 15)
    authorText:SetText("by Sausage Party")
    
    self:RefreshRaidTable()
end

function SLFM:RefreshQueueTable()
    if not SausageLFM_Queue or not SausageLFM_Queue:IsShown() then return end
    if not self.qRows then self.qRows = {} end
    for _, r in ipairs(self.qRows) do r:Hide() end

    for i, data in ipairs(self.Queue) do
        if not self.qRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Queue)
            r:SetSize(230, 24)
            r:SetPoint("TOPLEFT", 10, -25 - (i*26))
            
            r.env = CreateFrame("Button", nil, r)
            r.env:SetSize(16, 16):SetPoint("LEFT", 0, 0):SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
            r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.txt:SetPoint("LEFT", r.env, "RIGHT", 5, 0)

            r.skull = r:CreateTexture(nil, "OVERLAY")
            r.skull:SetSize(16, 16):SetPoint("RIGHT", r, "LEFT", 180, 0)
            r.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
            
            r.rej = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            r.rej:SetSize(20, 18):SetPoint("RIGHT", 0, 0):SetText("X")
            r.inv = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            r.inv:SetSize(35, 18):SetPoint("RIGHT", r.rej, "LEFT", -2, 0):SetText("Inv")
            
            self.qRows[i] = r
        end

        local r = self.qRows[i]
        if data.unread then UIFrameFlash(r.env, 0.5, 0.5, -1, false, 0, 0) else UIFrameFlashStop(r.env); r.env:SetAlpha(0.4) end
        r.env:SetScript("OnClick", function() data.unread = false; self:RefreshQueueTable(); ChatFrame_SendTell(data.name) end)

        local histText = ""
        if SLFM.History[data.name] then for _, h in ipairs(SLFM.History[data.name]) do histText = histText .. h .. "\n" end end
        SetHoverTooltip(r.env, "Whisper History", histText)

        local vData = SLFM.RaidData[data.name]
        local gsColor = (vData and vData.verified) and "|cff00ff00" or "|cff888888"
        local theGS = (vData and vData.gs and vData.gs > 0) and vData.gs or (data.gs > 0 and data.gs or "??")
        r.txt:SetText(data.name .. (data.ds and "|cff00ccff[DS]|r" or "") .. " " .. gsColor .. theGS .. "gs|r")

        if vData and vData.skull then 
            r.skull:Show()
            SetHoverTooltip(r, "|cffff0000Verification Failed|r", vData.skull)
            r.skull:SetScript("OnMouseDown", function() vData.skull = nil; vData.verified = true; self:RefreshQueueTable() end)
        else r.skull:Hide(); r:SetScript("OnEnter", nil); r:SetScript("OnLeave", nil) end

        r.inv:SetScript("OnClick", function() InviteUnit(data.name) end)
        r.rej:SetScript("OnClick", function()
            SendChatMessage("Sorry, group full or specs don't match.", "WHISPER", nil, data.name)
            table.remove(SLFM.Queue, i); self:RefreshQueueTable()
        end)
        r:Show()
    end
end

-- ========================================================
-- RAID ROSTER KATEGÓRIE
-- ========================================================
function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.rRows then self.rRows = {} end
    for _, r in ipairs(self.rRows) do r:Hide() end

    local categories = { ["Tank"]={}, ["Healer"]={}, ["DPS"]={}, ["Uncategorized"]={} }
    local numMembers = GetNumRaidMembers()
    
    for i=1, (numMembers > 0 and numMembers or 1) do
        local name = GetRaidRosterInfo(i)
        if not name then name = UnitName("player") end
        
        SLFM.RaidData[name] = SLFM.RaidData[name] or {}
        local role = SLFM.RaidData[name].role or "Uncategorized"
        table.insert(categories[role], name)
    end

    local yOffset = -25
    local rowIndex = 1
    local order = {"Tank", "Healer", "DPS", "Uncategorized"}
    
    for _, role in ipairs(order) do
        if #categories[role] > 0 or role == "Uncategorized" then
            if not self.rRows[rowIndex] then self.rRows[rowIndex] = CreateFrame("Button", nil, SausageLFM_Raid) end
            local head = self.rRows[rowIndex]
            head:SetSize(230, 14):SetPoint("TOPLEFT", 10, yOffset)
            if not head.t then head.t = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") end
            head.t:SetPoint("LEFT", 0, 0):SetText("- " .. role .. " -")
            if head.env then head.env:Hide() end
            if head.k then head.k:Hide() end
            head:SetScript("OnClick", nil)
            head:Show()
            
            yOffset = yOffset - 16
            rowIndex = rowIndex + 1

            for _, name in ipairs(categories[role]) do
                if not self.rRows[rowIndex] then self.rRows[rowIndex] = CreateFrame("Button", nil, SausageLFM_Raid) end
                local r = self.rRows[rowIndex]
                r:SetSize(230, 16):SetPoint("TOPLEFT", 10, yOffset)
                
                if not r.env then
                    r.env = CreateFrame("Button", nil, r)
                    r.env:SetSize(14, 14):SetPoint("LEFT", 0, 0):SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
                end
                r.env:Show()
                r.env:SetScript("OnClick", function() ChatFrame_SendTell(name) end)

                if not r.t then r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
                r.t:SetPoint("LEFT", r.env, "RIGHT", 5, 0)

                if not r.k then
                    r.k = CreateFrame("Button", nil, r)
                    r.k:SetSize(14, 14):SetPoint("RIGHT", -5, 0):SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                end
                r.k:Show()
                r.k:SetScript("OnClick", function() 
                    StaticPopupDialogs["SAUSAGELFM_KICK"] = {
                        text = "Vyhodiť " .. name .. "?", button1 = "Yes", button2 = "No",
                        OnAccept = function() UninviteUnit(name) end, timeout = 0, whileDead = true, hideOnEscape = true,
                    }
                    StaticPopup_Show("SAUSAGELFM_KICK")
                end)

                local vData = SLFM.RaidData[name]
                local gsColor = (vData and vData.verified) and "|cff00ff00" or "|cff888888"
                local gsText = (vData and vData.gs and vData.gs > 0) and vData.gs or "Unscanned"
                r.t:SetText(name .. " - " .. gsColor .. gsText .. "|r " .. ((vData and vData.skull) and "|cffff0000[!]Lebka|r" or ""))
                
                r:RegisterForClicks("RightButtonUp")
                r:SetScript("OnClick", function(self, button)
                    if button == "RightButton" then
                        local nextRole = {["Uncategorized"]="Tank", ["Tank"]="Healer", ["Healer"]="DPS", ["DPS"]="Uncategorized"}
                        SLFM.RaidData[name].role = nextRole[SLFM.RaidData[name].role or "Uncategorized"]
                        SLFM:RefreshRaidTable()
                    end
                end)
                r:Show()
                yOffset = yOffset - 16
                rowIndex = rowIndex + 1
            end
            yOffset = yOffset - 5
        end
    end
end