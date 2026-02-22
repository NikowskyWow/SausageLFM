-- SausageLFM_UI.lua
local SLFM = SausageLFM

StaticPopupDialogs["SLFM_KICK_CONFIRM"] = {
    text = "Kick player %s from group?", button1 = "Yes", button2 = "No",
    OnAccept = function(self, name) UninviteUnit(name) end, timeout = 0, whileDead = true, hideOnEscape = true,
}

local ClassData = {
    ["Generic Role"] = {"Tank", "Healer", "Melee DPS", "Ranged DPS"},
    ["Paladin"] = {"Holy", "Prot", "Ret"}, ["Warrior"] = {"Arms", "Fury", "Prot"},
    ["Death Knight"] = {"Blood", "Frost", "Unholy"}, ["Hunter"] = {"BM", "MM", "Surv"},
    ["Shaman"] = {"Ele", "Enh", "Resto"}, ["Rogue"] = {"Assa", "Combat", "Sub"},
    ["Druid"] = {"Boom", "Feral", "Resto"}, ["Mage"] = {"Arcane", "Fire", "Frost"},
    ["Priest"] = {"Disc", "Holy", "Shadow"}, ["Warlock"] = {"Affli", "Demo", "Destro"}
}
local ClassList = {"Generic Role", "Paladin", "Warrior", "Death Knight", "Hunter", "Shaman", "Rogue", "Druid", "Mage", "Priest", "Warlock"}

local ClassColors = {
    ["WARRIOR"] = "C79C6E", ["PALADIN"] = "F58CBA", ["HUNTER"] = "ABD473",
    ["ROGUE"] = "FFF569", ["PRIEST"] = "FFFFFF", ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"] = "0070DE", ["MAGE"] = "69CCF0", ["WARLOCK"] = "9482C9", ["DRUID"] = "FF7D0A"
}

local function CreateBackdrop(f, colorType)
    f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, 0.8)
    if colorType == "gold" then f:SetBackdropBorderColor(1, 0.8, 0)
    elseif colorType == "blue" then f:SetBackdropBorderColor(0, 0.5, 1)
    elseif colorType == "gray" then f:SetBackdropBorderColor(0.5, 0.5, 0.5)
    else f:SetBackdropBorderColor(0.5, 0.5, 0.5) end
end

local function CreateFlatEditBox(parent, w, h)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(w, h); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal); eb:SetJustifyH("CENTER")
    eb:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    eb:SetBackdropColor(0.1, 0.1, 0.1, 0.9); eb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb
end

SLFM_ActiveRolePlayer = nil

function SLFM:InitializeUI()
    local f = CreateFrame("Frame", "SausageLFM_Main", UIParent)
    f:SetSize(1050, 700); f:SetPoint("CENTER"); f:EnableMouse(true); f:SetMovable(true)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SausageLFM_Main")
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18); title:SetText("SAUSAGE COMMAND CENTER")
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton"); closeBtn:SetPoint("TOPRIGHT", -8, -8)
    
    local updateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    updateBtn:SetSize(110, 22); updateBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0); updateBtn:SetText("Check Updates")
    updateBtn:SetScript("OnClick", function() print("|cff00ccff[SausageLFM]|r You are running the latest V16 (The Raid Master)!") end)

    local left = CreateFrame("Frame", "SausageLFM_Raid", f); left:SetSize(280, 570); left:SetPoint("TOPLEFT", 20, -60); CreateBackdrop(left, "blue")
    local mid = CreateFrame("Frame", nil, f); mid:SetSize(410, 570); mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 15, 0)
    local right = CreateFrame("Frame", "SausageLFM_Queue", f); right:SetSize(280, 570); right:SetPoint("TOPLEFT", mid, "TOPRIGHT", 15, 0); CreateBackdrop(right, "gold")

    local qTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qTitle:SetPoint("BOTTOM", right, "TOP", 0, 5)
    qTitle:SetText("Candidate Queue")

    local lTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lTitle:SetPoint("BOTTOM", left, "TOP", 0, 5)
    lTitle:SetText("Raid Overview")

    -- V16: MULTI-LEVEL DROPDOWN (Role, Set OS, Whitelist)
    local roleDrop = CreateFrame("Frame", "SLFM_RoleDrop", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(roleDrop, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        local name = SLFM_ActiveRolePlayer
        if not name then return end

        if level == 1 then
            info.text = "Set Role"; info.hasArrow = true; info.menuList = "ROLES"; info.notCheckable = true; UIDropDownMenu_AddButton(info)
            info.text = "Set Off-Spec"; info.hasArrow = true; info.menuList = "OFFSPECS"; info.notCheckable = true; UIDropDownMenu_AddButton(info)
            
            local isWl = SausageLFM_DB.whitelist and SausageLFM_DB.whitelist[name]
            info.text = isWl and "|cff00ff00Remove from Whitelist|r" or "|cffffffffAdd to Whitelist|r"
            info.hasArrow = false; info.menuList = nil; info.notCheckable = true
            info.func = function()
                SausageLFM_DB.whitelist = SausageLFM_DB.whitelist or {}
                SausageLFM_DB.whitelist[name] = not SausageLFM_DB.whitelist[name]
                SLFM:RefreshRaidTable(); SLFM:RefreshQueueTable()
            end
            UIDropDownMenu_AddButton(info)
        elseif level == 2 then
            if menuList == "ROLES" then
                for _, role in ipairs({"Tank", "Heal", "mDPS", "rDPS", "Uncategorized"}) do
                    info.text = role; info.notCheckable = true
                    info.func = function()
                        SLFM.RaidData[name] = SLFM.RaidData[name] or {}
                        SLFM.RaidData[name].role = role
                        SLFM:RefreshRaidTable(); SLFM:UpdateMessage()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "OFFSPECS" then
                local _, class = UnitClass(name)
                if class and ClassData[class] then
                    for _, spec in ipairs(ClassData[class]) do
                        info.text = spec; info.notCheckable = true
                        info.func = function()
                            SLFM.RaidData[name] = SLFM.RaidData[name] or {}
                            SLFM.RaidData[name].manualOS = spec
                            SLFM:RefreshRaidTable(); SLFM:UpdateMessage()
                        end
                        UIDropDownMenu_AddButton(info, level)
                    end
                    info.text = "Clear Off-Spec"
                    info.func = function()
                        if SLFM.RaidData[name] then SLFM.RaidData[name].manualOS = nil end
                        SLFM:RefreshRaidTable(); SLFM:UpdateMessage()
                    end
                    UIDropDownMenu_AddButton(info, level)
                else
                    info.text = "Target not in range"; info.notCheckable = true; UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end, "MENU")
    f.roleDrop = roleDrop

    -- Middle Panel Settings
    local ach = CreateFrame("CheckButton", nil, mid, "UICheckButtonTemplate"); ach:SetPoint("TOPLEFT", 10, -45); ach:SetChecked(SausageLFM_DB.reqAchiev)
    ach:SetScript("OnClick", function(self) SausageLFM_DB.reqAchiev = self:GetChecked(); SLFM:UpdateMessage(); SLFM:RefreshQueueTable() end)
    local achTxt = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); achTxt:SetPoint("LEFT", ach, "RIGHT", 2, 0); achTxt:SetText("Achiev")

    local hc = CreateFrame("CheckButton", "SLFM_HC_BTN", mid, "UICheckButtonTemplate"); hc:SetPoint("LEFT", ach, "RIGHT", 55, 0); hc:SetChecked(SausageLFM_DB.isHC)
    hc:SetScript("OnClick", function(self) SausageLFM_DB.isHC = self:GetChecked(); SLFM:UpdateMessage() end)
    local hcText = mid:CreateFontString("SLFM_HC_TEXT", "OVERLAY", "GameFontHighlightSmall"); hcText:SetPoint("LEFT", hc, "RIGHT", 2, 0); hcText:SetText("HC")

    local function UpdateHCVisibility()
        if SausageLFM_DB.instance == "Dungeon" then hc:Show(); hcText:Show() else hc:Hide(); hcText:Hide(); SausageLFM_DB.isHC = false end
    end

    local instDrop = CreateFrame("Frame", "SLFM_InstDrop", mid, "UIDropDownMenuTemplate"); instDrop:SetPoint("TOPLEFT", -15, -10)
    local modeDrop = CreateFrame("Frame", "SLFM_ModeDrop", mid, "UIDropDownMenuTemplate"); modeDrop:SetPoint("LEFT", instDrop, "RIGHT", -10, 0)

    local function InitModeDropdown()
        UIDropDownMenu_Initialize(modeDrop, function()
            local info = UIDropDownMenu_CreateInfo()
            local list = SausageLFM_DB.instance == "Dungeon" and {"Random Heroic", "Daily Heroic", "Forge of Souls", "Pit of Saron", "Halls of Reflection", "Trial of the Champion", "Utgarde Keep", "The Nexus", "Azjol-Nerub", "Ahn'kahet: The Old Kingdom", "Drak'Tharon Keep", "The Violet Hold", "Gundrak", "Halls of Stone", "Halls of Lightning", "Utgarde Pinnacle", "The Oculus", "The Culling of Stratholme"} or {"10", "25"}
            UIDropDownMenu_SetText(modeDrop, SausageLFM_DB.mode)
            for _, v in ipairs(list) do info.text = v; info.func = function() SausageLFM_DB.mode = v; UIDropDownMenu_SetText(modeDrop, v); SLFM:UpdateMessage() end; UIDropDownMenu_AddButton(info) end
        end)
    end

    UIDropDownMenu_Initialize(instDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs({"Icecrown Citadel", "Ruby Sanctum", "Trial of the Crusader", "Ulduar", "Naxxramas", "The Obsidian Sanctum", "The Eye of Eternity", "Vault of Archavon", "Dungeon"}) do
            info.text = v; info.func = function() SausageLFM_DB.instance = v; UIDropDownMenu_SetText(instDrop, v); InitModeDropdown(); UpdateHCVisibility(); SLFM:UpdateMessage() end; UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(instDrop, SausageLFM_DB.instance); UIDropDownMenu_SetWidth(instDrop, 140)
    InitModeDropdown(); UIDropDownMenu_SetWidth(modeDrop, 130); UpdateHCVisibility()

    local gsIn = CreateFlatEditBox(mid, 60, 20); gsIn:SetPoint("TOPRIGHT", -15, -45); gsIn:SetText(tostring(SausageLFM_DB.minGS))
    gsIn:SetScript("OnTextChanged", function(self) SausageLFM_DB.minGS = tonumber(self:GetText()) or 0; SLFM:UpdateMessage(); SLFM:RefreshQueueTable(); SLFM:RefreshRaidTable() end)
    local gsTxt = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); gsTxt:SetPoint("RIGHT", gsIn, "LEFT", -5, 0); gsTxt:SetText("Min GS:")

    local brLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); brLbl:SetPoint("TOPLEFT", 10, -90); brLbl:SetText("Raid Target (Total Needed):")
    
    local rBoxes = {}; local rX = 10
    for _, r in ipairs({"Tank", "Heal", "mDPS", "rDPS"}) do
        local eb = CreateFlatEditBox(mid, 30, 20); eb:SetPoint("TOPLEFT", rX, -120); eb:SetText(tostring(SausageLFM_DB.roles[r] or 0))
        eb:SetScript("OnTextChanged", function(self) SausageLFM_DB.roles[r] = tonumber(self:GetText()) or 0; SLFM:RefreshRaidTable(); SLFM:UpdateMessage() end)
        local rl = mid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); rl:SetPoint("BOTTOM", eb, "TOP", 0, 3); rl:SetText(r)
        rBoxes[r] = eb; rX = rX + 60
    end

    local defBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate"); defBtn:SetSize(70, 25); defBtn:SetPoint("TOPLEFT", rX + 15, -118); defBtn:SetText("Default")
    defBtn:SetScript("OnClick", function()
        if SausageLFM_DB.instance == "Dungeon" then SausageLFM_DB.roles = {Tank = 1, Heal = 1, mDPS = 1, rDPS = 2}
        elseif SausageLFM_DB.mode == "10" then SausageLFM_DB.roles = {Tank = 2, Heal = 2, mDPS = 3, rDPS = 3}
        else SausageLFM_DB.roles = {Tank = 2, Heal = 5, mDPS = 9, rDPS = 9} end
        for r, box in pairs(rBoxes) do box:SetText(tostring(SausageLFM_DB.roles[r])) end; SLFM:RefreshRaidTable(); SLFM:UpdateMessage()
    end)

    local spLbl = mid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); spLbl:SetPoint("TOPLEFT", 10, -165); spLbl:SetText("Add Specific / Dual Specs:")
    local selClass, selMain, selOff = "Generic Role", "Tank", "None"

    local cDrop = CreateFrame("Frame", "SLFM_CDrop", mid, "UIDropDownMenuTemplate"); cDrop:SetPoint("TOPLEFT", -15, -185)
    local mDrop = CreateFrame("Frame", "SLFM_MDrop", mid, "UIDropDownMenuTemplate"); mDrop:SetPoint("LEFT", cDrop, "RIGHT", -20, 0)
    local oDrop = CreateFrame("Frame", "SLFM_ODrop", mid, "UIDropDownMenuTemplate"); oDrop:SetPoint("LEFT", mDrop, "RIGHT", -20, 0)

    local function InitSpecDropdowns()
        UIDropDownMenu_Initialize(mDrop, function()
            local info = UIDropDownMenu_CreateInfo()
            for _, v in ipairs(ClassData[selClass]) do
                info.text = v; info.func = function() selMain = v; UIDropDownMenu_SetText(mDrop, v); if selOff == selMain then selOff = "None"; UIDropDownMenu_SetText(oDrop, "None") end; InitSpecDropdowns() end; UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_Initialize(oDrop, function()
            local info = UIDropDownMenu_CreateInfo(); info.text = "None"; info.func = function() selOff = "None"; UIDropDownMenu_SetText(oDrop, "None") end; UIDropDownMenu_AddButton(info)
            for _, v in ipairs(ClassData[selClass]) do
                if v ~= selMain then
                    local oInfo = UIDropDownMenu_CreateInfo(); oInfo.text = v; oInfo.func = function() selOff = v; UIDropDownMenu_SetText(oDrop, v) end; UIDropDownMenu_AddButton(oInfo)
                end
            end
        end)
    end

    UIDropDownMenu_Initialize(cDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs(ClassList) do
            info.text = v; info.func = function() selClass = v; selMain = ClassData[v][1]; selOff = "None"; UIDropDownMenu_SetText(cDrop, v); UIDropDownMenu_SetText(mDrop, selMain); UIDropDownMenu_SetText(oDrop, selOff); InitSpecDropdowns() end; UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(cDrop, selClass); UIDropDownMenu_SetWidth(cDrop, 100)
    InitSpecDropdowns(); UIDropDownMenu_SetText(mDrop, selMain); UIDropDownMenu_SetWidth(mDrop, 70)
    UIDropDownMenu_SetText(oDrop, selOff); UIDropDownMenu_SetWidth(oDrop, 70)

    local specCont = CreateFrame("Frame", nil, mid); specCont:SetSize(390, 160); specCont:SetPoint("TOPLEFT", 10, -225)

    local function DrawActiveSpecs()
        if specCont.rows then for _, r in ipairs(specCont.rows) do r:Hide() end end
        specCont.rows = {}
        local idx = 0
        for name, count in pairs(SausageLFM_DB.specs) do
            if count > 0 then
                local r = CreateFrame("Frame", nil, specCont); r:SetSize(380, 24); r:SetPoint("TOPLEFT", 5, -(idx * 26))
                
                local specTxt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); specTxt:SetPoint("LEFT", 0, 0); specTxt:SetText(name)
                local del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); del:SetSize(20, 18); del:SetPoint("RIGHT", 0, 0); del:SetText("X")
                del:SetScript("OnClick", function() SausageLFM_DB.specs[name] = nil; DrawActiveSpecs(); SLFM:UpdateMessage() end)
                local btnPlus = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); btnPlus:SetSize(20, 18); btnPlus:SetPoint("RIGHT", del, "LEFT", -5, 0); btnPlus:SetText("+")
                btnPlus:SetScript("OnClick", function() SausageLFM_DB.specs[name] = SausageLFM_DB.specs[name] + 1; DrawActiveSpecs(); SLFM:UpdateMessage() end)
                local eb = CreateFlatEditBox(r, 25, 18); eb:SetPoint("RIGHT", btnPlus, "LEFT", -5, 0); eb:SetText(tostring(count))
                eb:SetScript("OnTextChanged", function(self) local val = tonumber(self:GetText()); if val then SausageLFM_DB.specs[name] = val; SLFM:UpdateMessage() end end)
                local btnMinus = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); btnMinus:SetSize(20, 18); btnMinus:SetPoint("RIGHT", eb, "LEFT", -5, 0); btnMinus:SetText("-")
                btnMinus:SetScript("OnClick", function() SausageLFM_DB.specs[name] = math.max(0, SausageLFM_DB.specs[name] - 1); if SausageLFM_DB.specs[name] == 0 then SausageLFM_DB.specs[name] = nil end; DrawActiveSpecs(); SLFM:UpdateMessage() end)
                tinsert(specCont.rows, r); idx = idx + 1
            end
        end
    end

    local addSpecBtn = CreateFrame("Button", nil, mid, "UIPanelButtonTemplate"); addSpecBtn:SetSize(45, 24); addSpecBtn:SetPoint("LEFT", oDrop, "RIGHT", -10, 2); addSpecBtn:SetText("Add")
    addSpecBtn:SetScript("OnClick", function()
        local formattedName = ""
        if selClass == "Generic Role" then formattedName = selMain else formattedName = selMain .. " " .. selClass end
        if selOff ~= "None" then formattedName = formattedName .. " (OS " .. selOff .. ")" end
        SausageLFM_DB.specs[formattedName] = (SausageLFM_DB.specs[formattedName] or 0) + 1
        DrawActiveSpecs(); SLFM:UpdateMessage()
    end)
    DrawActiveSpecs()

    local bcBox = CreateFrame("Frame", nil, mid); bcBox:SetSize(410, 110); bcBox:SetPoint("BOTTOMLEFT", 0, 15); CreateBackdrop(bcBox, "gray")
    local bcTitle = bcBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); bcTitle:SetPoint("TOPLEFT", 10, -10); bcTitle:SetText("Broadcast Engine")
    local timer = CreateFlatEditBox(bcBox, 35, 20); timer:SetPoint("TOPLEFT", 60, -35); timer:SetText(tostring(SausageLFM_DB.interval))
    timer:SetScript("OnTextChanged", function(self) SausageLFM_DB.interval = tonumber(self:GetText()) or 45 end)
    local t1 = bcBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t1:SetPoint("RIGHT", timer, "LEFT", -5, 0); t1:SetText("Timer:")
    local t2 = bcBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t2:SetPoint("LEFT", timer, "RIGHT", 5, 0); t2:SetText("sec")

    local cX = 10
    for _, ch in ipairs({"World", "Global", "LFG", "Party"}) do
        local cb = CreateFrame("CheckButton", nil, bcBox, "UICheckButtonTemplate"); cb:SetPoint("TOPLEFT", cX, -65); cb:SetChecked(SausageLFM_DB.channels[ch])
        cb:SetScript("OnClick", function(self) SausageLFM_DB.channels[ch] = self:GetChecked() end)
        local cbt = bcBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); cbt:SetPoint("LEFT", cb, "RIGHT", 2, 0); cbt:SetText(ch)
        cX = cX + 95
    end

    local flood = CreateFrame("Button", nil, bcBox, "UIPanelButtonTemplate"); flood:SetSize(200, 30); flood:SetPoint("TOPRIGHT", -15, -25); flood:SetText("START FLOODING")
    flood:SetScript("OnClick", function(self)
        SLFM.IsFlooding = not SLFM.IsFlooding
        if SLFM.IsFlooding then SLFM.lastFlood = 999 end
        self:SetText(SLFM.IsFlooding and "STOP FLOODING" or "START FLOODING")
    end)

    local previewBar = CreateFrame("Frame", nil, f); previewBar:SetSize(1010, 45); previewBar:SetPoint("BOTTOM", 0, 25); CreateBackdrop(previewBar, "gray")
    f.preview = previewBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.preview:SetPoint("CENTER", 0, 0); f.preview:SetSize(990, 40); f.preview:SetWordWrap(true); f.preview:SetJustifyH("CENTER"); f.preview:SetJustifyV("MIDDLE"); f.preview:SetTextColor(1, 0.82, 0)
    
    local verText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); verText:SetPoint("BOTTOMRIGHT", -20, 10); verText:SetText("v" .. (SLFM.Version or "1.16.0") .. " by Sausage Party")

    self:RefreshRaidTable()
    self:RefreshQueueTable()
end

-- =====================================
-- 🛡️ V16 CANDIDATE QUEUE (S Inteligentnou Lebkou)
-- =====================================
function SLFM:RefreshQueueTable()
    if not SausageLFM_Queue or not SausageLFM_Queue:IsShown() then return end
    if not self.qRows then self.qRows = {} end
    for _, r in ipairs(self.qRows) do r:Hide() end
    for i, d in ipairs(self.Queue) do
        if not self.qRows[i] then
            local r = CreateFrame("Frame", nil, SausageLFM_Queue)
            r:SetSize(265, 25); r:SetPoint("TOPLEFT", 5, -15-(i*28)); r:EnableMouse(true)
            
            -- V16: Zväčšená Obálka
            r.env = CreateFrame("Button", nil, r); r.env:SetSize(16, 16); r.env:SetPoint("LEFT", 5, 0); r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
            
            -- V16: Zväčšený Achiev Shield
            r.achi = CreateFrame("Button", nil, r); r.achi:SetSize(20, 20); r.achi:SetPoint("LEFT", r.env, "RIGHT", 4, 0)
            r.achi:SetNormalTexture("Interface\\AchievementFrame\\UI-Achievement-TinyShield")
            
            -- V16: Skull Button
            r.skull = CreateFrame("Button", nil, r); r.skull:SetSize(18, 18); r.skull:SetPoint("LEFT", r.achi, "RIGHT", 4, 0)
            r.skull:SetNormalTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")

            r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.t:SetPoint("LEFT", r.skull, "RIGHT", 4, 0); r.t:SetWidth(140); r.t:SetJustifyH("LEFT"); r.t:SetWordWrap(false)
            
            r.inv = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.inv:SetSize(35, 20); r.inv:SetPoint("RIGHT", -30, 0); r.inv:SetText("Inv")
            r.rej = CreateFrame("Button", nil, r, "UIPanelButtonTemplate"); r.rej:SetSize(25, 20); r.rej:SetPoint("RIGHT", 0, 0); r.rej:SetText("X")
            self.qRows[i] = r
        end
        local r = self.qRows[i]
        
        if SausageLFM_DB.reqAchiev then
            r.achi:Show()
            if d.hasAchi then
                r.achi:GetNormalTexture():SetDesaturated(false)
                r.achi:SetScript("OnClick", nil)
            else
                r.achi:GetNormalTexture():SetDesaturated(true)
                r.achi:SetScript("OnClick", function() SendChatMessage("Can you please link the achievement for this raid?", "WHISPER", nil, d.name) end)
            end
        else
            r.achi:Hide()
            r.skull:SetPoint("LEFT", r.env, "RIGHT", 4, 0) -- Posun doľava, ak achiev nesvieti
        end

        -- V16: SKULL WARNING MATRIX
        local warnings = SLFM:GetWarnings(d.name, d.gs, d.role, d.isPvP)
        if #warnings > 0 then
            r.skull:Show()
            r.skull:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Warning Matrix", 1, 0, 0)
                for _, w in ipairs(warnings) do GameTooltip:AddLine("- " .. w, 1, 1, 1, true) end
                GameTooltip:Show()
            end)
            r.skull:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r.t:SetPoint("LEFT", r.skull, "RIGHT", 4, 0)
        else
            r.skull:Hide()
            r.t:SetPoint("LEFT", (SausageLFM_DB.reqAchiev) and r.achi or r.env, "RIGHT", 4, 0)
        end

        local roleShort = {["Tank"]="T", ["Heal"]="H", ["mDPS"]="M", ["rDPS"]="R"}
        local infoStr = ""
        if d.role and d.role ~= "Uncategorized" then
            infoStr = " |cff00ccff[" .. (roleShort[d.role] or d.role)
            if d.spec and d.spec ~= "" then infoStr = infoStr .. ": " .. d.spec end
            if d.os and d.os ~= "" then infoStr = infoStr .. "|OS: " .. d.os end
            infoStr = infoStr .. "]|r"
        end

        r.t:SetText(d.name .. " (" .. (d.gs or "??") .. ")" .. infoStr)
        r.env:SetScript("OnClick", function() ChatFrame_SendTell(d.name) end)
        
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(d.name .. "'s Whisper", 1, 0.82, 0)
            GameTooltip:AddLine(d.msg or "No message recorded.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r.inv:SetScript("OnClick", function() InviteUnit(d.name) end)
        r.rej:SetScript("OnClick", function() 
            SendChatMessage("Sorry, declined or raid is full.", "WHISPER", nil, d.name)
            for idx, val in ipairs(SLFM.Queue) do if val.name == d.name then table.remove(SLFM.Queue, idx); break end end
            SLFM:RefreshQueueTable() 
        end)
        r:Show()
    end
end

-- =====================================
-- 🛡️ V16 RAID OVERVIEW (Main Spec, Manual OS, Skull Matrix)
-- =====================================
function SLFM:RefreshRaidTable()
    if not SausageLFM_Raid or not SausageLFM_Raid:IsShown() then return end
    if not self.rRows then self.rRows = {} end
    for _, r in ipairs(self.rRows) do r:Hide() end

    local categories = { ["Tank"]={}, ["Heal"]={}, ["mDPS"]={}, ["rDPS"]={}, ["Uncategorized"]={} }
    local inGroupNames = {}
    if GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do local n = GetRaidRosterInfo(i); if n then table.insert(inGroupNames, n) end end
    else
        table.insert(inGroupNames, (UnitName("player")))
        for i=1, GetNumPartyMembers() do local n = UnitName("party"..i); if n then table.insert(inGroupNames, n) end end
    end

    for _, name in ipairs(inGroupNames) do
        SLFM.RaidData[name] = SLFM.RaidData[name] or {}
        local role = SLFM.RaidData[name].role or "Uncategorized"
        if categories[role] then table.insert(categories[role], name) else table.insert(categories["Uncategorized"], name) end
    end

    local yOffset = -20; local rowIndex = 1
    for _, role in ipairs({"Tank", "Heal", "mDPS", "rDPS", "Uncategorized"}) do
        local target = SausageLFM_DB.roles[role] or 0
        local current = #categories[role]
        
        local showHeader = true
        if role == "Uncategorized" and current == 0 then showHeader = false end
        if role ~= "Uncategorized" and current == 0 and target == 0 then showHeader = false end

        if showHeader then
            if not self.rRows[rowIndex] then self.rRows[rowIndex] = CreateFrame("Button", nil, SausageLFM_Raid) end
            local head = self.rRows[rowIndex]; head:SetSize(260, 14); head:SetPoint("TOPLEFT", 10, yOffset)
            
            if not head.t then head.t = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") end
            head.t:SetPoint("LEFT", 0, 0)
            
            if role ~= "Uncategorized" then
                head.t:SetText("- " .. role .. " (" .. current .. " / " .. target .. ") -")
                if current >= target and target > 0 then head.t:SetTextColor(0, 1, 0) else head.t:SetTextColor(0.5, 0.5, 0.5) end
            else
                head.t:SetText("- Uncategorized -"); head.t:SetTextColor(0.5, 0.5, 0.5)
            end

            if head.env then head.env:Hide() end; if head.k then head.k:Hide() end; if head.gear then head.gear:Hide() end; if head.skull then head.skull:Hide() end
            head:Show(); yOffset = yOffset - 16; rowIndex = rowIndex + 1

            for _, name in ipairs(categories[role]) do
                if not self.rRows[rowIndex] then self.rRows[rowIndex] = CreateFrame("Button", nil, SausageLFM_Raid) end
                local r = self.rRows[rowIndex]; r:SetSize(260, 16); r:SetPoint("TOPLEFT", 10, yOffset)
                
                if not r.env then r.env = CreateFrame("Button", nil, r); r.env:SetSize(14, 14); r.env:SetPoint("LEFT", 0, 0); r.env:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox") end
                r.env:Show(); r.env:SetScript("OnClick", function() ChatFrame_SendTell(name) end)

                if not r.k then r.k = CreateFrame("Button", nil, r); r.k:SetSize(14, 14); r.k:SetPoint("RIGHT", -5, 0); r.k:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up") end
                r.k:Show(); r.k:SetScript("OnClick", function() StaticPopup_Show("SLFM_KICK_CONFIRM", name, nil, name) end)

                if not r.gear then r.gear = CreateFrame("Button", nil, r); r.gear:SetSize(14, 14); r.gear:SetPoint("RIGHT", r.k, "LEFT", -5, 0); r.gear:SetNormalTexture("Interface\\GossipFrame\\BinderGossipIcon") end
                r.gear:Show()
                r.gear:SetScript("OnClick", function(self) SLFM_ActiveRolePlayer = name; ToggleDropDownMenu(1, nil, SausageLFM_Main.roleDrop, self, 0, 0) end)

                if not r.skull then r.skull = CreateFrame("Button", nil, r); r.skull:SetSize(16, 16); r.skull:SetPoint("RIGHT", r.gear, "LEFT", -3, 0); r.skull:SetNormalTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull") end
                
                if not r.t then r.t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
                r.t:SetPoint("LEFT", r.env, "RIGHT", 5, 0)
                
                local _, class = UnitClass(name)
                local colorCode = ClassColors[class] or "FFFFFF"
                local gs = SLFM:GetExternalGS(name)
                local pData = SLFM.RaidData[name] or {}
                
                -- V16: SKULL WARNING MATRIX pre Raid Overview
                local warnings = SLFM:GetWarnings(name, gs, role, false)
                if #warnings > 0 then
                    r.skull:Show()
                    r.skull:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Warning Matrix", 1, 0, 0)
                        for _, w in ipairs(warnings) do GameTooltip:AddLine("- " .. w, 1, 1, 1, true) end
                        GameTooltip:Show()
                    end)
                    r.skull:SetScript("OnLeave", function() GameTooltip:Hide() end)
                else
                    r.skull:Hide()
                end

                -- V16: MAIN SPEC / MANUAL OS DISPLAY
                local specString = ""
                if pData.talents and pData.talents ~= "" then
                    specString = pData.talents
                end
                if pData.manualOS then
                    if specString ~= "" then specString = specString .. "|OS:" .. pData.manualOS else specString = pData.manualOS end
                end
                
                local talentInfo = (specString ~= "") and (" |cff00ccff[" .. specString .. "]|r") or ""
                r.t:SetText("|cff" .. colorCode .. name .. "|r - " .. (gs > 0 and gs or "Unscanned") .. talentInfo)
                
                r:Show(); yOffset = yOffset - 16; rowIndex = rowIndex + 1
            end
            yOffset = yOffset - 5
        end
    end
end