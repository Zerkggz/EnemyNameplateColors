local ADDON_NAME = "EnemyNameplateColors"
local ENC = {}
_G[ADDON_NAME] = ENC

ENC.inInstance = false
ENC.interruptSpells = {}

-- Custom cast bar fill texture
local CUSTOM_CASTBAR_TEXTURE = "Interface\\AddOns\\EnemyNameplateColors\\Textures\\CastingBar"

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
    enabledZones = {
        dungeons = true,
        raids = true,
        delvesScenarios = true,
        openWorld = false,
    },
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
        standard = { r = 1.0, g = 0.7, b = 0.0, a = 1.0 },
        uninterruptible = { r = 0.275, g = 0.275, b = 0.275, a = 1.0 },
        channel = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
        important = { r = 1.0, g = 0.0, b = 1.0, a = 1.0 },
        interruptReady = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
    },
}

function ENC:UpdateInstanceStatus()
    local zones = self.db and self.db.enabledZones or self.defaults.enabledZones
    local inInstance, instanceType = IsInInstance()
    
    if inInstance then
        if instanceType == "party" and zones.dungeons then
            self.inInstance = true
        elseif instanceType == "raid" and zones.raids then
            self.inInstance = true
        elseif instanceType == "scenario" and zones.delvesScenarios then
            self.inInstance = true
        else
            self.inInstance = false
        end
    else
        self.inInstance = zones.openWorld or false
    end
    
    -- Delves fallback check
    if not self.inInstance and zones.delvesScenarios and C_DelvesUI and C_DelvesUI.HasActiveDelve then
        self.inInstance = C_DelvesUI.HasActiveDelve()
    end
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
    
    if not self.db.enabledZones then self.db.enabledZones = self:DeepCopy(self.defaults.enabledZones) end
    -- Migrate old separate delves/scenarios keys
    if self.db.enabledZones.delves ~= nil or self.db.enabledZones.scenarios ~= nil then
        self.db.enabledZones.delvesScenarios = (self.db.enabledZones.delves ~= false) or (self.db.enabledZones.scenarios ~= false)
        self.db.enabledZones.delves = nil
        self.db.enabledZones.scenarios = nil
    end
    -- Ensure new zone keys exist for upgrades
    for k, v in pairs(self.defaults.enabledZones) do
        if self.db.enabledZones[k] == nil then self.db.enabledZones[k] = v end
    end
    
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
    -- Returns: 0 = not on threat table, 1 = has threat but not tanking, 2 = insecurely tanking, 3 = securely tanking
    local status = UnitThreatSituation("player", unit)
    return status
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
            local otherStatus = UnitThreatSituation(groupUnit, unit)
            if otherStatus and otherStatus >= 2 and UnitGroupRolesAssigned(groupUnit) == "TANK" then
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
    local status = self:GetThreatStatus(unit)
    
    -- status can be nil if the unit isn't on our threat table
    if isPlayerTank then
        if self:IsBeingTankedByOther(unit) then
            return self.db.tank.onOtherTank
        elseif status and status >= 3 then
            return self.db.unitType[unitType]
        elseif status and status == 2 then
            return self.db.tank.losingThreat
        elseif status and status <= 1 then
            return self.db.tank.noThreat
        elseif UnitAffectingCombat(unit) then
            return self.db.tank.noThreat
        elseif unitType ~= "standard" then
            return self.db.unitType[unitType]
        end
        return nil
    else
        if status and status >= 3 then
            return self.db.dpsHealer.hasThreat
        elseif status and status >= 1 then
            return self.db.dpsHealer.gainingThreat
        elseif UnitAffectingCombat(unit) or unitType ~= "standard" then
            return self.db.unitType[unitType]
        end
        return nil
    end
end

function ENC:ReplaceCastBarTexture(castBar)
    if not castBar or castBar:IsForbidden() then return end
    local texture = castBar:GetStatusBarTexture()
    if not texture then return end
    texture:SetTexture(CUSTOM_CASTBAR_TEXTURE)
    texture:SetTexCoord(0, 1, 0, 1)
    castBar.ENC_textureReplaced = true
end

function ENC:RestoreCastBarTexture(castBar)
    if not castBar or castBar:IsForbidden() or not castBar.ENC_textureReplaced then return end
    local texture = castBar:GetStatusBarTexture()
    if texture then
        texture:SetVertexColor(1, 1, 1, 1)
    end
    castBar.ENC_textureReplaced = false
end

function ENC:ApplyCastBarColor(castBar, r, g, b, a)
    if not castBar or castBar:IsForbidden() then return end
    self:ReplaceCastBarTexture(castBar)
    local texture = castBar:GetStatusBarTexture()
    if texture then
        texture:SetVertexColor(r, g, b, a or 1.0)
    end
end

local INTERRUPT_FLASH_TEXTURE = "Interface\\AddOns\\EnemyNameplateColors\\Textures\\ui-castingbar-flash-small"

function ENC:GetOrCreateInterruptBorder(castBar)
    if castBar.ENC_interruptBorder then
        return castBar.ENC_interruptBorder
    end
    
    local borderFrame = CreateFrame("Frame", nil, castBar)
    borderFrame:SetFrameLevel(castBar:GetFrameLevel() + 2)
    borderFrame:SetPoint("TOPLEFT", castBar, "TOPLEFT", -1, 1)
    borderFrame:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 1, -1)
    
    local tex = borderFrame:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(INTERRUPT_FLASH_TEXTURE)
    tex:SetAllPoints(borderFrame)
    tex:SetBlendMode("BLEND")
    borderFrame.texture = tex
    
    borderFrame:Hide()
    castBar.ENC_interruptBorder = borderFrame
    return borderFrame
end

function ENC:UpdateInterruptBorderColor(borderFrame)
    local color = self.db.castBar.interruptReady
    if borderFrame.texture then
        borderFrame.texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
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
    
    -- If notInterruptible is nil, hide border until we know for sure
    if notInterruptible == nil then
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
    
    -- If notInterruptible is true (can't interrupt), alpha becomes 0
    -- If notInterruptible is false (can interrupt), alpha stays as anyReady
    alpha = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0, alpha)
    
    borderFrame:SetAlpha(alpha)
end

function ENC:GetCastBarColorValues(castBar)
    if not self.inInstance then return nil end
    if not castBar or not castBar.unit or castBar:IsForbidden() then return nil end
    if not self.db.castBar.enabled then return nil end
    if not strmatch(castBar.unit, "^nameplate") then return nil end
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
        self:RestoreCastBarTexture(castBar)
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
            ENC:RestoreCastBarTexture(castBar)
            castBar.ENC_hasColor = false
            castBar.ENC_notInterruptible = nil
            if castBar.ENC_interruptBorder then castBar.ENC_interruptBorder:Hide() end
            return
        end
        
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or
           event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" or
           event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            SafeUpdateCastBar(castBar)
        end
    end)
    
    hooksecurefunc(CastingBarMixin, "OnUpdate", function(castBar)
        if not castBar or not castBar.unit or castBar:IsForbidden() then return end
        if not UnitIsEnemy("player", castBar.unit) then return end
        if castBar.ENC_hasColor and castBar.ENC_r then
            ENC:ReplaceCastBarTexture(castBar)
            local texture = castBar:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(castBar.ENC_r, castBar.ENC_g, castBar.ENC_b, castBar.ENC_a)
            end
        end
    end)
    
    local function HookIfExists(methodName)
        if CastingBarMixin[methodName] then
            hooksecurefunc(CastingBarMixin, methodName, function(castBar)
                if not castBar or not castBar.unit or castBar:IsForbidden() then return end
                if not UnitIsEnemy("player", castBar.unit) then return end
                SafeUpdateCastBar(castBar)
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
SlashCmdList["ENC"] = function(msg)
    msg = strtrim(msg or ""):lower()
    
    if msg == "debug" then
        local unit = "target"
        if not UnitExists(unit) then
            print("|cff00ccff[ENC Debug]|r No target selected.")
            return
        end
        
        local name = UnitName(unit)
        local classification = UnitClassification(unit) or "unknown"
        local level = UnitLevel(unit)
        local playerLevel = UnitLevel("player")
        local powerType, powerToken = UnitPowerType(unit)
        local encType = ENC:GetUnitType(unit)
        local isFriend = UnitIsFriend("player", unit)
        local isEnemy = UnitIsEnemy("player", unit)
        local inCombat = UnitAffectingCombat(unit)
        
        print("|cff00ccff[ENC Debug]|r --------------------")
        print("|cff00ccff[ENC Debug]|r |cffffffffName:|r " .. (name or "nil"))
        print("|cff00ccff[ENC Debug]|r |cffffffffClassification:|r " .. classification)
        print("|cff00ccff[ENC Debug]|r |cffffffffLevel:|r " .. level .. " (Player: " .. playerLevel .. ", Diff: " .. (level - playerLevel) .. ")")
        print("|cff00ccff[ENC Debug]|r |cffffffffPower Type:|r " .. powerType .. " (" .. (powerToken or "unknown") .. ")" .. (powerType == 0 and " |cff00ff00= Mana (Caster)|r" or ""))
        print("|cff00ccff[ENC Debug]|r |cffffffffENC Type:|r " .. encType)
        print("|cff00ccff[ENC Debug]|r |cffffffffFriendly:|r " .. tostring(isFriend) .. " |cffffffffEnemy:|r " .. tostring(isEnemy))
        print("|cff00ccff[ENC Debug]|r |cffffffffIn Combat:|r " .. tostring(inCombat))
        print("|cff00ccff[ENC Debug]|r |cffffffffAddon Active:|r " .. tostring(ENC.inInstance))
        
        local inInstance, instanceType = IsInInstance()
        print("|cff00ccff[ENC Debug]|r |cffffffffInstance:|r " .. tostring(inInstance) .. " |cffffffffType:|r " .. (instanceType or "none"))
        print("|cff00ccff[ENC Debug]|r --------------------")
        return
    end
    
    if ENC.OpenOptions then
        ENC:OpenOptions()
    end
end