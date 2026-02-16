-- SausageLFM_UI.lua
local SLFM = SausageLFM

local function CreateSausageBackdrop(frame, colorType)
    local c = {0, 0.7, 1, 1} -- Default Blue
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

-- Rýchly Tooltip generátor pre Hover
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
    -- 🏰 MAIN FRAME
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(880, 480)
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

    -- HEADER
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
    left:SetSize(250, 390)
    left:SetPoint("TOPLEFT", 15, -45)
    CreateSausageBackdrop(left, "gray")
    left.t = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    left.t:SetPoint("TOP", 0, -10)
    left.t:SetText("Raid Overview")

    -- 🎛️ MID PANEL (Controls)
    local mid = CreateFrame("Frame", "SausageLFM_Ctrl", f)
    mid:SetSize(330, 390)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    
    -- EditBox pre Min GS
    local gsBox = CreateFrame("EditBox", nil, mid, "InputBoxTemplate")
    gsBox:SetSize(50, 20)
    gsBox:SetPoint("TOPRIGHT", -20, -20)
    gsBox:SetAutoFocus(false)
    gsBox:SetText(tostring(SausageLFM_DB.minGS or 0))
    gsBox:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    local gsLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gsLbl:SetPoint("RIGHT", gsBox, "LEFT", -5, 0)
    gsLbl:SetText("Min GS:")

    -- Zoznam Specov (Statický)
    local specs = {"Holy Paladin", "Resto Shaman", "Resto Druid", "Disc Priest", "Prot Paladin", "Blood DK", "Ranged DPS", "Melee DPS"}
    for i, spec in ipairs(specs) do
        local row = CreateFrame("Frame", nil, mid)
        row:SetSize(300, 22)
        row:SetPoint("TOPLEFT", 20, -50 - (i*25))
        
        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txt:SetPoint("LEFT", 0, 0)
        txt:SetText(spec)
        
        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(25, 20)
        box:SetPoint("RIGHT", -10, 0)
        box:SetAutoFocus(false)
        box:SetText(tostring(SausageLFM_DB.targets[spec] or 0))
        box:SetScript("OnTextChanged", function(self) SausageLFM_DB.targets[spec] = tonumber(self:GetText()) or 0; SLFM:UpdateMessage() end)
    end

    -- Štart Button & Preview
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
    right:SetSize(250, 390)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 10, 0)
    CreateSausageBackdrop(right, "gold")
    right.t = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    right.t:SetPoint("TOP", 0, -10)
    right.t:SetText("Candidate Queue")

    -- FOOTER (Fixnuté WotLK reťazenie)
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verText:SetPoint("BOTTOMLEFT", 20, 15)
    verText:SetText("v" .. (SLFM.Version or "1.3.0"))

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
            
            -- WIM Envelope (Mail Icon)
            r.env = CreateFrame("Button", nil, r)
            r.env:SetSize(16, 16)
            r.env:SetPoint("LEFT", 0, 0)
            r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
            
            r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.txt:SetPoint("LEFT", r.env, "RIGHT", 5, 0)

            -- Lebka Hanby
            r.skull = r:CreateTexture(nil, "OVERLAY")
            r.skull:SetSize(16, 16)
            r.skull:SetPoint("RIGHT", r, "LEFT", 180, 0)
            r.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
            
            -- Actions (Fixnuté WotLK reťazenie)
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
        -- Envelope Logic (WIM Bridge)
        if data.unread then UIFrameFlash(r.env, 0.5, 0.5, -1, false, 0, 0) else UIFrameFlashStop(r.env); r.env:SetAlpha(0.4) end
        r.env:SetScript("OnClick", function() 
            data.unread = false; self:RefreshQueueTable()
            ChatFrame_SendTell(data.name) -- Natively triggers WIM!
        end)

        -- Hover History Tooltip
        local histText = ""
        if SLFM.History[data.name] then for _, h in ipairs(SLFM.History[data.name]) do histText = histText .. h .. "\n" end end
        SetHoverTooltip(r.env, "Whisper History", histText)

        -- Formatting
        local vData = SLFM.RaidData[data.name]
        local gsColor = (vData and vData.verified) and "|cff00ff00" or "|cff888888"
        local theGS = (vData and vData.gs > 0) and vData.gs or (data.gs > 0 and data.gs or "??")
        r.txt:SetText(data.name .. (data.ds and "|cff00ccff[DS]|r" or "") .. " " .. gsColor .. theGS .. "gs|r")

        -- Skull Logic
        if vData and vData.skull then 
            r.skull:Show()
            SetHoverTooltip(r, "|cffff0000Verification Failed|r", vData.skull)
            r.skull:SetScript("OnMouseDown", function() vData.skull = nil; vData.verified = true; self:RefreshQueueTable() end) -- Override
        else r.skull:Hide(); r:SetScript("OnEnter", nil); r:SetScript("OnLeave", nil) end

        -- Buttons
        r.inv:SetScript("OnClick", function() InviteUnit(data.name) end)
        r.rej:SetScript("OnClick", function()
            SendChatMessage("Sorry, our group is full or your spec/gear doesn't match our current needs. Good luck!", "WHISPER", nil, data.name)
            table.remove(SLFM.Queue, i); self:RefreshQueueTable()
        end)
        r:Show()
    end
end

function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.rRows then self.rRows = {} end
    for _, r in ipairs(self.rRows) do r:Hide() end

    local numMembers = GetNumRaidMembers()
    for i=1, (numMembers > 0 and numMembers or 1) do
        local name = GetRaidRosterInfo(i)
        if not name then name = UnitName("player") end -- Pre testovanie v solo
        
        if not self.rRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Raid)
            r:SetSize(230, 16)
            r:SetPoint("TOPLEFT", 10, -25 - (i*18))
            
            -- Fixnuté reťazenie
            r.env = CreateFrame("Button", nil, r)
            r.env:SetSize(14, 14)
            r.env:SetPoint("LEFT", 0, 0)
            r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
            
            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.t:SetPoint("LEFT", r.env, "RIGHT", 5, 0)
            
            -- Fixnuté reťazenie
            r.k = CreateFrame("Button", nil, r)
            r.k:SetSize(14, 14)
            r.k:SetPoint("RIGHT", -5, 0)
            r.k:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            
            r.k:SetScript("OnClick", function() 
                StaticPopupDialogs["SAUSAGELFM_KICK"] = {
                    text = "Naozaj chceš vyhodiť hráča " .. name .. "?",
                    button1 = "Yes", button2 = "No",
                    OnAccept = function() UninviteUnit(name) end,
                    timeout = 0, whileDead = true, hideOnEscape = true,
                }
                StaticPopup_Show("SAUSAGELFM_KICK")
            end)
            self.rRows[i] = r
        end

        local r = self.rRows[i]
        r.env:SetScript("OnClick", function() ChatFrame_SendTell(name) end)

        local vData = SLFM.RaidData[name]
        local gsColor = (vData and vData.verified) and "|cff00ff00" or "|cff888888"
        local gsText = (vData and vData.gs and vData.gs > 0) and vData.gs or "Unscanned"
        
        r.t:SetText(name .. " - " .. gsColor .. gsText .. "|r " .. ((vData and vData.skull) and "|cffff0000[!]Lebka|r" or ""))
        r:Show()
    end
end