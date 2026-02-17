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
    f:SetSize(880, 520) -- Trošku vyššie, nech sa tam všetko vojde
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

    -- 📋 LFT PANEL (Raid Overview)
    local left = CreateFrame("Frame", "SausageLFM_Raid", f)
    left:SetSize(250, 430)
    left:SetPoint("TOPLEFT", 15, -45)
    CreateSausageBackdrop(left, "gray")
    left.t = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    left.t:SetPoint("TOP", 0, -10)
    left.t:SetText("Raid Overview (Right-Click: Set Role)")

    -- 🎛️ MID PANEL (Controls)
    local mid = CreateFrame("Frame", "SausageLFM_Ctrl", f)
    mid:SetSize(330, 430)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    
    -- == NOVÉ WIDGETY V STREDE ==

    -- Instance Dropdown (Zjednodušený cez cyklické tlačidlo pre WotLK stabilitu)
    local instBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    instBtn:SetSize(140, 25)
    instBtn:SetPoint("TOPLEFT", 15, -15)
    instBtn:SetText(SausageLFM_DB.instance or "ICC")
    local instances = {"Naxxramas", "Obsidian Sanctum", "Eye of Eternity", "Vault of Archavon", "Ulduar", "TOC", "ICC", "Dungeon"}
    instBtn:SetScript("OnClick", function(self)
        local cur = SausageLFM_DB.instance
        local nextInst = instances[1]
        for i, v in ipairs(instances) do if v == cur and instances[i+1] then nextInst = instances[i+1] break end end
        SausageLFM_DB.instance = nextInst
        self:SetText(nextInst)
        SLFM:UpdateMessage()
    end)
    SetHoverTooltip(instBtn, "Instance", "Klikaj pre zmenu inštancie.")

    -- Mode Button (10 / 25)
    local modeBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    modeBtn:SetSize(50, 25)
    modeBtn:SetPoint("LEFT", instBtn, "RIGHT", 5, 0)
    modeBtn:SetText(SausageLFM_DB.mode or "25")
    modeBtn:SetScript("OnClick", function(self)
        SausageLFM_DB.mode = SausageLFM_DB.mode == "25" and "10" or "25"
        self:SetText(SausageLFM_DB.mode)
        SLFM:UpdateMessage()
    end)

    -- Checkboxes (HC a Achiev)
    local hcBtn = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    hcBtn:SetPoint("TOPLEFT", 15, -45)
    hcBtn:SetSize(26, 26)
    hcBtn.t = hcBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hcBtn.t:SetPoint("LEFT", hcBtn, "RIGHT", 2, 0)
    hcBtn.t:SetText("HC")
    hcBtn:SetChecked(SausageLFM_DB.isHC)
    hcBtn:SetScript("OnClick", function(self) SausageLFM_DB.isHC = self:GetChecked(); SLFM:UpdateMessage() end)

    local achBtn = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate")
    achBtn:SetPoint("LEFT", hcBtn.t, "RIGHT", 10, 0)
    achBtn:SetSize(26, 26)
    achBtn.t = achBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    achBtn.t:SetPoint("LEFT", achBtn, "RIGHT", 2, 0)
    achBtn.t:SetText("Achiev")
    achBtn:SetChecked(SausageLFM_DB.reqAchiev)
    achBtn:SetScript("OnClick", function(self) SausageLFM_DB.reqAchiev = self:GetChecked(); SLFM:UpdateMessage() end)

    -- EditBox pre Min GS
    local gsBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsBox:SetSize(40, 20)
    gsBox:SetPoint("TOPRIGHT", -25, -45)
    gsBox:SetAutoFocus(false)
    gsBox:SetTextInsets(5, 0, 0, 0)
    gsBox:SetText(tostring(SausageLFM_DB.minGS or 0))
    gsBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gsLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gsLbl:SetPoint("RIGHT", gsBox, "LEFT", -5, 0)
    gsLbl:SetText("Min GS:")

    -- Zoznam Specov (Posunuté nižšie)
    local specs = {"Holy Paladin", "Resto Shaman", "Resto Druid", "Disc Priest", "Prot Paladin", "Blood DK", "Ranged DPS", "Melee DPS"}
    for i, spec in ipairs(specs) do
        local row = CreateFrame("Frame", nil, mid)
        row:SetSize(300, 22)
        row:SetPoint("TOPLEFT", 20, -75 - (i*25))
        
        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txt:SetPoint("LEFT", 0, 0)
        txt:SetText(spec)
        
        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(30, 20) -- Rozšírené pre lepšiu viditeľnosť
        box:SetPoint("RIGHT", -15, 0)
        box:SetAutoFocus(false)
        box:SetTextInsets(5, 0, 0, 0)
        box:SetText(tostring(SausageLFM_DB.targets[spec] or 0))
        box:SetScript("OnTextChanged", function(self) SausageLFM_DB.targets[spec] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    end

    f.preview = mid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.preview:SetPoint("BOTTOM", 0, 50)
    f.preview:SetWidth(310)
    
    local startBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate")
    startBtn:SetSize(180, 30)
    startBtn:SetPoint("BOTTOM", 0, 10)
    startBtn:SetText("START FLOODING")
    startBtn:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)

    -- 🛡️ RIGHT PANEL (Candidate Queue)
    local right = CreateFrame("Frame", "SausageLFM_Queue", f)
    right:SetSize(250, 430)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 10, 0)
    CreateSausageBackdrop(right, "gold")
    right.t = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    right.t:SetPoint("TOP", 0, -10)
    right.t:SetText("Candidate Queue")

    -- FOOTER
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    verText:SetText("v" .. (SLFM.Version ~= "" and SLFM.Version or "1.3.0"))

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
            r.env:SetSize(16, 16)
            r.env:SetPoint("LEFT", 0, 0)
            r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
            
            r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.txt:SetPoint("LEFT", r.env, "RIGHT", 5, 0)

            r.skull = r:CreateTexture(nil, "OVERLAY")
            r.skull:SetSize(16, 16)
            r.skull:SetPoint("RIGHT", r, "LEFT", 180, 0)
            r.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
            
            r.rej = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            r.rej:SetSize(20, 18)
            r.rej:SetPoint("RIGHT", 0, 0)
            r.rej:SetText("X")
            
            r.inv = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
            r.inv:SetSize(35, 18)
            r.inv:SetPoint("RIGHT", r.rej, "LEFT", -2, 0)
            r.inv:SetText("Inv")
            
            self.qRows[i] = r
        end

        local r = self.qRows[i]
        if data.unread then UIFrameFlash(r.env, 0.5, 0.5, -1, false, 0, 0) else UIFrameFlashStop(r.env); r.env:SetAlpha(0.4) end
        r.env:SetScript("OnClick", function() 
            data.unread = false; self:RefreshQueueTable()
            ChatFrame_SendTell(data.name) 
        end)

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
            SendChatMessage("Sorry, our group is full or your spec/gear doesn't match our current needs. Good luck!", "WHISPER", nil, data.name)
            table.remove(SLFM.Queue, i); self:RefreshQueueTable()
        end)
        r:Show()
    end
end

-- ========================================================
-- RAID ROSTER KATEGÓRIE (NOVÝ ENGINE)
-- ========================================================
function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.rRows then self.rRows = {} end
    for _, r in ipairs(self.rRows) do r:Hide() end

    -- 1. Zoskupenie hráčov podľa rolí
    local categories = { ["Tank"]={}, ["Healer"]={}, ["DPS"]={}, ["Uncategorized"]={} }
    local numMembers = GetNumRaidMembers()
    
    for i=1, (numMembers > 0 and numMembers or 1) do
        local name = GetRaidRosterInfo(i)
        if not name then name = UnitName("player") end -- Pre test v solo móde
        
        SLFM.RaidData[name] = SLFM.RaidData[name] or {}
        local role = SLFM.RaidData[name].role or "Uncategorized"
        table.insert(categories[role], name)
    end

    -- 2. Vykreslenie hlavičiek a hráčov
    local yOffset = -25
    local rowIndex = 1

    local order = {"Tank", "Healer", "DPS", "Uncategorized"}
    for _, role in ipairs(order) do
        if #categories[role] > 0 or role == "Uncategorized" then
            
            -- Hlavička kategórie (napr. "--- Tank ---")
            if not self.rRows[rowIndex] then self.rRows[rowIndex] = CreateFrame("Button", nil, SausageLFM_Raid) end
            local head = self.rRows[rowIndex]
            head:SetSize(230, 14)
            head:SetPoint("TOPLEFT", 10, yOffset)
            if not head.t then head.t = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") end
            head.t:SetPoint("LEFT", 0, 0)
            head.t:SetText("- " .. role .. " -")
            
            -- Skrytie nepoužitých widgetov
            if head.env then head.env:Hide() end
            if head.k then head.k:Hide() end
            head:SetScript("OnClick", nil)
            head:Show()
            
            yOffset = yOffset - 16
            rowIndex = rowIndex + 1

            -- Zoznam hráčov v tejto kategórii
            for _, name in ipairs(categories[role]) do
                if not self.rRows[rowIndex] then self.rRows[rowIndex] = CreateFrame("Button", nil, SausageLFM_Raid) end
                local r = self.rRows[rowIndex]
                r:SetSize(230, 16)
                r:SetPoint("TOPLEFT", 10, yOffset)
                
                -- Buttony (Env a Kick)
                if not r.env then
                    r.env = CreateFrame("Button", nil, r)
                    r.env:SetSize(14, 14)
                    r.env:SetPoint("LEFT", 0, 0)
                    r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
                end
                r.env:Show()
                r.env:SetScript("OnClick", function() ChatFrame_SendTell(name) end)

                if not r.t then r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
                r.t:SetPoint("LEFT", r.env, "RIGHT", 5, 0)

                if not r.k then
                    r.k = CreateFrame("Button", nil, r)
                    r.k:SetSize(14, 14)
                    r.k:SetPoint("RIGHT", -5, 0)
                    r.k:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                end
                r.k:Show()
                r.k:SetScript("OnClick", function() 
                    StaticPopupDialogs["SAUSAGELFM_KICK"] = {
                        text = "Vyhodiť hráča " .. name .. "?", button1 = "Yes", button2 = "No",
                        OnAccept = function() UninviteUnit(name) end, timeout = 0, whileDead = true, hideOnEscape = true,
                    }
                    StaticPopup_Show("SAUSAGELFM_KICK")
                end)

                -- Formátovanie textu a dát
                local vData = SLFM.RaidData[name]
                local gsColor = (vData and vData.verified) and "|cff00ff00" or "|cff888888"
                local gsText = (vData and vData.gs and vData.gs > 0) and vData.gs or "Unscanned"
                r.t:SetText(name .. " - " .. gsColor .. gsText .. "|r " .. ((vData and vData.skull) and "|cffff0000[!]Lebka|r" or ""))
                
                -- Cyklovanie Rolí na Pravý Klik
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
            yOffset = yOffset - 5 -- Odskok po kategórii
        end
    end
end