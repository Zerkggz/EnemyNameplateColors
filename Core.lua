local ADDON_NAME = "EnemyNameplateColors"
local ENC = {}
_G[ADDON_NAME] = ENC

ENC.inInstance = false
ENC.interruptSpells = {}

local interruptMap = {
    ["DEATHKNIGHT"] = {47528},
    ["WARRIOR"] = {6552},
    ["WARLOCK"] = {19647, 89766, 1276467, 119910, 119914, 132409},
    ["SHAMAN"] = {57994},
    ["ROGUE"] = {1766},
    ["PRIEST"] = {15487},
    ["PALADIN"] = {96231},
    ["MONK"] = {116705},
    ["MAGE"] = {2139},
    ["HUNTER"] = {187707, 147362},
    ["EVOKER"] = {351338},
    ["DRUID"] = {78675, 106839},
    ["DEMONHUNTER"] = {183752},
}

ENC.defaults = {
    unitType = {
        boss = { r = 0.8, g = 0.2, b = 1.0 },
        miniBoss = { r = 0.2, g = 0.4, b = 1.0 },
        caster = { r = 0.0, g = 0.8, b = 1.0 },
        standard = { r = 0.8, g = 0.6, b = 1.0 },
    },
    tank = {
        onOtherTank = { r = 0.28, g = 0.59, b = 1.0 },
        noThreat = { r = 1.0, g = 0.0, b = 0.0 },
        losingThreat = { r = 1.0, g = 0.6, b = 0.0 },
    },
    dpsHealer = {
        hasThreat = { r = 1.0, g = 0.0, b = 0.0 },
        gainingThreat = { r = 1.0, g = 0.6, b = 0.0 },
    },
    castBar = {
        enabled = true,
        interruptReadyEnabled = true,
        standard = { r = 1.0, g = 0.7, b = 0.0, a = 0.75 },
        uninterruptible = { r = 0.5, g = 0.5, b = 0.5, a = 0.75 },
        channel = { r = 0.0, g = 1.0, b = 0.0, a = 0.75 },
        important = { r = 1.0, g = 0.0, b = 1.0, a = 0.75 },
        interruptReady = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
    },
}

function ENC:UpdateInstanceStatus()
    local inInstance, instanceType = IsInInstance()
    self.inInstance = inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
end

function ENC:UpdateInterruptSpell()
    local class = UnitClassBase("player")
    self.interruptSpells = {}
    
    local spells = interruptMap[class] or {}
    for _, spellID in ipairs(spells) do
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            if C_SpellBook.IsSpellKnownOrInSpellBook(spellID) or 
               C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet) then
                table.insert(self.interruptSpells, spellID)
            end
        elseif IsSpellKnown and IsSpellKnown(spellID) then
            table.insert(self.interruptSpells, spellID)
        end
    end
end

-- Returns a secret number: 1 if any interrupt is ready, 0 if all on cooldown
function ENC:GetAnyInterruptReady()
    if not self.interruptSpells or #self.interruptSpells == 0 then return nil end
    if not C_Spell or not C_Spell.GetSpellCooldownDuration then return nil end
    if not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean then return nil end
    
    -- Accumulate: if any interrupt's IsZero is true, result becomes 1
    local anyReady = 0
    for _, spellID in ipairs(self.interruptSpells) do
        local cooldownDuration = C_Spell.GetSpellCooldownDuration(spellID)
        if cooldownDuration and cooldownDuration.IsZero then
            local isZero = cooldownDuration:IsZero()
            -- If isZero is true, set anyReady to 1; otherwise keep current anyReady
            anyReady = C_CurveUtil.EvaluateColorValueFromBoolean(isZero, 1, anyReady)
        end
    end
    
    return anyReady
end

function ENC:InitDB()
    if not EnemyNameplateColorsDB then
        EnemyNameplateColorsDB = {}
    end
    self.db = EnemyNameplateColorsDB
    
    if not self.db.unitType then self.db.unitType = self:DeepCopy(self.defaults.unitType) end
    if not self.db.tank then self.db.tank = self:DeepCopy(self.defaults.tank) end
    if not self.db.dpsHealer then self.db.dpsHealer = self:DeepCopy(self.defaults.dpsHealer) end
    if not self.db.castBar then self.db.castBar = self:DeepCopy(self.defaults.castBar) end
    
    if self.db.castBar.enabled == nil then self.db.castBar.enabled = true end
    if self.db.castBar.interruptReadyEnabled == nil then self.db.castBar.interruptReadyEnabled = true end
    if not self.db.castBar.interruptReady then
        self.db.castBar.interruptReady = self:DeepCopy(self.defaults.castBar.interruptReady)
    end
    
    -- Ensure alpha values exist for upgrades
    local castBarColors = {"standard", "uninterruptible", "channel", "important", "interruptReady"}
    for _, colorName in ipairs(castBarColors) do
        if self.db.castBar[colorName] and self.db.castBar[colorName].a == nil then
            self.db.castBar[colorName].a = self.defaults.castBar[colorName].a
        end
    end
end

function ENC:DeepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = self:DeepCopy(v)
    end
    return copy
end

function ENC:GetUnitType(unit)
    if not unit then return "standard" end
    
    local classification = UnitClassification(unit)
    
    if classification == "worldboss" then
        return "boss"
    elseif classification == "rare" then
        return "miniBoss"
    elseif classification == "elite" or classification == "rareelite" then
        local levelDiff = UnitLevel(unit) - UnitLevel("player")
        if UnitLevel(unit) == -1 or levelDiff >= 2 then
            return "boss"
        elseif levelDiff >= 1 then
            return "miniBoss"
        end
    end
    
    if UnitPowerType(unit) == 0 then
        return "caster"
    end
    
    return "standard"
end

function ENC:GetThreatStatus(unit)
    local isTanking, status = UnitDetailedThreatSituation("player", unit)
    return isTanking, status
end

function ENC:IsPlayerTank()
    local spec = GetSpecialization()
    if not spec then return false end
    return GetSpecializationRole(spec) == "TANK"
end

function ENC:IsBeingTankedByOther(unit)
    if not UnitExists(unit) then return false end
    
    for i = 1, GetNumGroupMembers() do
        local groupUnit = (IsInRaid() and "raid" or "party") .. i
        if UnitExists(groupUnit) and groupUnit ~= "player" then
            local isTanking = UnitDetailedThreatSituation(groupUnit, unit)
            if isTanking and UnitGroupRolesAssigned(groupUnit) == "TANK" then
                return true
            end
        end
    end
    return false
end

function ENC:GetNameplateColor(unit)
    if not self.inInstance or UnitIsFriend("player", unit) then
        return nil
    end
    
    local unitType = self:GetUnitType(unit)
    
    if not UnitAffectingCombat("player") then
        return unitType ~= "standard" and self.db.unitType[unitType] or nil
    end
    
    local isPlayerTank = self:IsPlayerTank()
    local isTanking, status = self:GetThreatStatus(unit)
    
    if isPlayerTank then
        if self:IsBeingTankedByOther(unit) then
            return self.db.tank.onOtherTank
        elseif status == 3 or isTanking then
            return self.db.unitType[unitType]
        elseif status == 2 then
            return self.db.tank.losingThreat
        elseif status == 1 or (UnitAffectingCombat(unit) and (status == 0 or not status)) then
            return self.db.tank.noThreat
        elseif unitType ~= "standard" then
            return self.db.unitType[unitType]
        end
        return nil
    else
        if isTanking or status == 3 then
            return self.db.dpsHealer.hasThreat
        elseif status == 2 or status == 1 then
            return self.db.dpsHealer.gainingThreat
        elseif UnitAffectingCombat(unit) or unitType ~= "standard" then
            return self.db.unitType[unitType]
        end
        return nil
    end
end

function ENC:ApplyCastBarColor(castBar, r, g, b, a)
    if not castBar or castBar:IsForbidden() then return end
    local texture = castBar:GetStatusBarTexture()
    if texture then
        texture:SetVertexColor(r, g, b, a or 1.0)
    end
end

function ENC:GetOrCreateInterruptBorder(castBar)
    if castBar.ENC_interruptBorder then
        return castBar.ENC_interruptBorder
    end
    
    local borderFrame = CreateFrame("Frame", nil, castBar)
    borderFrame:SetFrameLevel(castBar:GetFrameLevel() + 1)
    
    local size = 2
    local color = self.db.castBar.interruptReady
    
    borderFrame:SetPoint("TOPLEFT", castBar, "TOPLEFT", -size, size)
    borderFrame:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", size, -size)
    
    local function CreateBorderTexture()
        local tex = borderFrame:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        return tex
    end
    
    borderFrame.top = CreateBorderTexture()
    borderFrame.top:SetHeight(size)
    borderFrame.top:SetPoint("TOPLEFT")
    borderFrame.top:SetPoint("TOPRIGHT")
    
    borderFrame.bottom = CreateBorderTexture()
    borderFrame.bottom:SetHeight(size)
    borderFrame.bottom:SetPoint("BOTTOMLEFT")
    borderFrame.bottom:SetPoint("BOTTOMRIGHT")
    
    borderFrame.left = CreateBorderTexture()
    borderFrame.left:SetWidth(size)
    borderFrame.left:SetPoint("TOPLEFT")
    borderFrame.left:SetPoint("BOTTOMLEFT")
    
    borderFrame.right = CreateBorderTexture()
    borderFrame.right:SetWidth(size)
    borderFrame.right:SetPoint("TOPRIGHT")
    borderFrame.right:SetPoint("BOTTOMRIGHT")
    
    borderFrame:Hide()
    castBar.ENC_interruptBorder = borderFrame
    return borderFrame
end

function ENC:UpdateInterruptBorderColor(borderFrame)
    local color = self.db.castBar.interruptReady
    for _, edge in ipairs({"top", "bottom", "left", "right"}) do
        if borderFrame[edge] then
            borderFrame[edge]:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        end
    end
end

function ENC:UpdateInterruptBorder(castBar, notInterruptible)
    if not castBar or castBar:IsForbidden() then return end
    
    local borderFrame = self:GetOrCreateInterruptBorder(castBar)
    
    if not self.db.castBar.interruptReadyEnabled or not self.interruptSpells or #self.interruptSpells == 0 then
        borderFrame:Hide()
        return
    end
    
    if not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean then
        borderFrame:Hide()
        return
    end
    
    local anyReady = self:GetAnyInterruptReady()
    if anyReady == nil then
        borderFrame:Hide()
        return
    end
    
    self:UpdateInterruptBorderColor(borderFrame)
    borderFrame:Show()
    
    -- Start with interrupt ready status (anyReady is already 1 or 0 as secret number)
    local alpha = anyReady
    
    -- Multiply by interruptibility: if notInterruptible is true, alpha becomes 0
    if notInterruptible ~= nil then
        local canInterrupt = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0, 1)
        -- Multiply alpha by canInterrupt (both are secret numbers, but we can use EvaluateColorValueFromBoolean)
        -- If canInterrupt is 0 (can't interrupt), we want alpha to be 0
        -- If canInterrupt is 1 (can interrupt), we want alpha to stay as anyReady
        -- We need to express: alpha = anyReady * canInterrupt
        -- Use: if canInterrupt would be 0, result is 0; if canInterrupt would be 1, result is anyReady
        -- Since canInterrupt comes from notInterruptible, we can combine differently:
        -- alpha = EvaluateColorValueFromBoolean(notInterruptible, 0, anyReady)
        alpha = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0, alpha)
    end
    
    borderFrame:SetAlpha(alpha)
end

function ENC:GetCastBarColorValues(castBar)
    if not self.inInstance then return nil end
    if not castBar or not castBar.unit or castBar:IsForbidden() then return nil end
    if not self.db.castBar.enabled then return nil end
    if not UnitIsEnemy("player", castBar.unit) then return nil end
    
    local name, _, _, _, _, _, _, notInterruptible, spellID = UnitCastingInfo(castBar.unit)
    local isChanneling = false
    
    if not name then
        name, _, _, _, _, _, notInterruptible, spellID = UnitChannelInfo(castBar.unit)
        isChanneling = true
    end
    
    if not name then return nil end
    
    local baseColor = isChanneling and self.db.castBar.channel or self.db.castBar.standard
    local r, g, b, a = baseColor.r, baseColor.g, baseColor.b, baseColor.a or 1
    
    -- Apply uninterruptible color layer
    if notInterruptible ~= nil and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local unint = self.db.castBar.uninterruptible
        r = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.r, r)
        g = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.g, g)
        b = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.b, b)
        a = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.a or 1, a)
    end
    
    -- Apply important spell color layer
    if spellID and C_Spell and C_Spell.IsSpellImportant and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local isImportant = C_Spell.IsSpellImportant(spellID)
        local imp = self.db.castBar.important
        r = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.r, r)
        g = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.g, g)
        b = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.b, b)
        a = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.a or 1, a)
    end
    
    return r, g, b, a, notInterruptible
end

function ENC:UpdateCastBarColor(castBar)
    if not castBar or castBar:IsForbidden() then return end
    
    local r, g, b, a, notInterruptible = self:GetCastBarColorValues(castBar)
    if r then
        self:ApplyCastBarColor(castBar, r, g, b, a)
        castBar.ENC_hasColor = true
        castBar.ENC_r, castBar.ENC_g, castBar.ENC_b, castBar.ENC_a = r, g, b, a
        castBar.ENC_notInterruptible = notInterruptible
        self:UpdateInterruptBorder(castBar, notInterruptible)
    else
        castBar.ENC_hasColor = false
        castBar.ENC_notInterruptible = nil
        if castBar.ENC_interruptBorder then
            castBar.ENC_interruptBorder:Hide()
        end
    end
end

function ENC:RefreshAllInterruptBorders()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        if nameplate.UnitFrame and nameplate.UnitFrame.castBar then
            local castBar = nameplate.UnitFrame.castBar
            if castBar.ENC_hasColor then
                self:UpdateInterruptBorder(castBar, castBar.ENC_notInterruptible)
            end
        end
    end
end

function ENC:UpdateNameplateColor(nameplate)
    if not nameplate or not nameplate.UnitFrame then return end
    local unit = nameplate.UnitFrame.unit
    if not unit then return end
    
    local color = self:GetNameplateColor(unit)
    if color and nameplate.UnitFrame.healthBar then
        nameplate.UnitFrame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

function ENC:HookNameplates()
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
        if frame.unit and not frame:IsForbidden() and UnitIsEnemy("player", frame.unit) then
            local color = ENC:GetNameplateColor(frame.unit)
            if color and frame.healthBar then
                frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    end)
end

function ENC:HookCastBars()
    if not CastingBarMixin then return end
    
    local function SafeUpdateCastBar(castBar)
        if not castBar or not castBar.unit or castBar:IsForbidden() then return end
        if not UnitIsEnemy("player", castBar.unit) then return end
        ENC:UpdateCastBarColor(castBar)
    end
    
    hooksecurefunc(CastingBarMixin, "OnEvent", function(castBar, event, arg1)
        if not castBar or not castBar.unit or castBar:IsForbidden() then return end
        if arg1 ~= castBar.unit or not UnitIsEnemy("player", castBar.unit) then return end
        
        if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or
           event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            castBar.ENC_hasColor = false
            castBar.ENC_notInterruptible = nil
            if castBar.ENC_interruptBorder then castBar.ENC_interruptBorder:Hide() end
            return
        end
        
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or
           event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" or
           event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            C_Timer.After(0, function() SafeUpdateCastBar(castBar) end)
        end
    end)
    
    hooksecurefunc(CastingBarMixin, "OnUpdate", function(castBar)
        if not castBar or not castBar.unit or castBar:IsForbidden() then return end
        if not UnitIsEnemy("player", castBar.unit) then return end
        if castBar.ENC_hasColor and castBar.ENC_r then
            ENC:ApplyCastBarColor(castBar, castBar.ENC_r, castBar.ENC_g, castBar.ENC_b, castBar.ENC_a)
        end
    end)
    
    local function HookIfExists(methodName)
        if CastingBarMixin[methodName] then
            hooksecurefunc(CastingBarMixin, methodName, function(castBar)
                if not castBar or not castBar.unit or castBar:IsForbidden() then return end
                if not UnitIsEnemy("player", castBar.unit) then return end
                C_Timer.After(0, function() SafeUpdateCastBar(castBar) end)
            end)
        end
    end
    
    HookIfExists("UpdateInterruptibleState")
    HookIfExists("UpdateHighlightImportantCast")
    HookIfExists("UpdateHighlightWhenCastTarget")
end

function ENC:UpdateAllNameplates()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        self:UpdateNameplateColor(nameplate)
        if nameplate.UnitFrame and nameplate.UnitFrame.castBar then
            local castBar = nameplate.UnitFrame.castBar
            if castBar.casting or castBar.channeling then
                self:UpdateCastBarColor(castBar)
            end
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ENC:InitDB()
    elseif event == "PLAYER_LOGIN" then
        ENC:HookNameplates()
        ENC:HookCastBars()
        ENC:UpdateInstanceStatus()
        ENC:UpdateInterruptSpell()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ENC:UpdateInstanceStatus()
        ENC:UpdateAllNameplates()
    elseif event == "SPELLS_CHANGED" then
        ENC:UpdateInterruptSpell()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        ENC:RefreshAllInterruptBorders()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        if nameplate then ENC:UpdateNameplateColor(nameplate) end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" or
           event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        ENC:UpdateAllNameplates()
    end
end)

SLASH_ENC1 = "/enc"
SLASH_ENC2 = "/enemynameplatecolors"
SlashCmdList["ENC"] = function()
    if ENC.OpenOptions then
        ENC:OpenOptions()
    end
end