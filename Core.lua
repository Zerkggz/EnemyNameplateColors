local ADDON_NAME = "EnemyNameplateColors"
local ENC = {}
_G[ADDON_NAME] = ENC

ENC.inInstance = false
ENC.interruptSpells = {}
ENC.playerInCombat = false
ENC.neutralCache = {} -- tracks which nameplate units are neutral (yellow nameplates)
ENC.otherTanks = {} -- cached list of other tank unit IDs in the group

-- Custom cast bar fill texture
local CUSTOM_CASTBAR_TEXTURE = "Interface\\AddOns\\EnemyNameplateColors\\Textures\\CastingBar"

-- Blizzard API for detecting secret values (Midnight)
local issecretvalue = _G.issecretvalue

-- Focus target overlay texture
local FOCUS_TARGET_TEXTURE = "Interface\\AddOns\\EnemyNameplateColors\\Textures\\FocusTarget"

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
    focusTarget = {
        enabled = false,
        useTexture = false,
        color = { r = 1.0, g = 0.3, b = 0.9, a = 1.0 },
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
        enabled = false,
        interruptReadyEnabled = true,
        standard = { r = 1.0, g = 0.7, b = 0.0, a = 1.0 },
        uninterruptible = { r = 0.275, g = 0.275, b = 0.275, a = 1.0 },
        channel = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
        important = { r = 1.0, g = 0.0, b = 1.0, a = 1.0 },
        interruptReady = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
    },
    dispelGlow = {
        enabled = true,
        color = { r = 0.0, g = 0.5, b = 1.0 },
    },
}

function ENC:UpdateInstanceStatus()
    local zones = self.db and self.db.enabledZones or self.defaults.enabledZones
    local inInstance, instanceType = IsInInstance()
    
    if inInstance or instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
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
    
    if not self.db.focusTarget then self.db.focusTarget = self:DeepCopy(self.defaults.focusTarget) end
    if self.db.focusTarget.enabled == nil then self.db.focusTarget.enabled = false end
    if self.db.focusTarget.useTexture == nil then self.db.focusTarget.useTexture = false end
    if self.db.focusTarget.color and self.db.focusTarget.color.a == nil then
        self.db.focusTarget.color.a = 1.0
    end
    
    if not self.db.unitType then self.db.unitType = self:DeepCopy(self.defaults.unitType) end
    if not self.db.tank then self.db.tank = self:DeepCopy(self.defaults.tank) end
    if not self.db.dpsHealer then self.db.dpsHealer = self:DeepCopy(self.defaults.dpsHealer) end
    if not self.db.castBar then self.db.castBar = self:DeepCopy(self.defaults.castBar) end
    
    if self.db.castBar.enabled == nil then self.db.castBar.enabled = false end
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
    
    if not self.db.dispelGlow then self.db.dispelGlow = self:DeepCopy(self.defaults.dispelGlow) end
    if self.db.dispelGlow.enabled == nil then self.db.dispelGlow.enabled = true end
    if not self.db.dispelGlow.color then self.db.dispelGlow.color = self:DeepCopy(self.defaults.dispelGlow.color) end
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
    if status == nil then return nil end
    
    -- UnitThreatSituation can return secret numbers in Midnight.
    -- pcall to safely extract a usable value; fall back to nil if tainted.
    local ok, val = pcall(function()
        if status >= 3 then return 3
        elseif status >= 2 then return 2
        elseif status >= 1 then return 1
        else return 0 end
    end)
    
    return ok and val or nil
end

function ENC:IsPlayerTank()
    local spec = GetSpecialization()
    if not spec then return false end
    return GetSpecializationRole(spec) == "TANK"
end

function ENC:UpdateOtherTanks()
    wipe(self.otherTanks)
    for i = 1, GetNumGroupMembers() do
        local groupUnit = (IsInRaid() and "raid" or "party") .. i
        if UnitExists(groupUnit) and not UnitIsUnit(groupUnit, "player")
           and UnitGroupRolesAssigned(groupUnit) == "TANK" then
            table.insert(self.otherTanks, groupUnit)
        end
    end
end

function ENC:IsBeingTankedByOther(unit)
    if not UnitExists(unit) then return false end
    
    for _, tankUnit in ipairs(self.otherTanks) do
        if UnitExists(tankUnit) then
            local otherStatus = UnitThreatSituation(tankUnit, unit)
            if otherStatus and otherStatus >= 2 then
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
    
    -- Don't override class colors on enemy players
    if UnitIsPlayer(unit) then
        return nil
    end
    
    -- Skip neutral units (yellow nameplates) - let Blizzard's default color show
    -- neutralCache is set by reading the health bar color Blizzard assigns before we override
    if self.neutralCache[unit] then
        return nil
    end
    
    -- Don't override Blizzard's grey color on tapped units
    if UnitIsTapDenied(unit) then
        return nil
    end
    
    -- Focus target override (highest priority) - only when using color mode, not texture mode
    if self.db.focusTarget.enabled and not self.db.focusTarget.useTexture
       and UnitExists("focus") and UnitIsUnit(unit, "focus") then
        return self.db.focusTarget.color
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
    
    borderFrame:SetAlpha(0)
    borderFrame:Hide()
    
    -- Safety net: if the frame ever becomes visible while the player is out of combat,
    -- hide it immediately. Catches edge cases from secret number alpha resolution
    -- changing when combat taint context shifts.
    borderFrame:SetScript("OnShow", function(self)
        if not ENC.playerInCombat then
            self:Hide()
        end
    end)
    
    castBar.ENC_interruptBorder = borderFrame
    return borderFrame
end

function ENC:UpdateInterruptBorderColor(borderFrame)
    local color = self.db.castBar.interruptReady
    if borderFrame.texture then
        borderFrame.texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    end
end

function ENC:UpdateInterruptBorder(castBar)
    if not castBar or castBar:IsForbidden() then return end
    
    local borderFrame = self:GetOrCreateInterruptBorder(castBar)
    
    -- Non-secret gates first
    if not self.playerInCombat or not self.db.castBar.interruptReadyEnabled
       or not self.interruptSpells or #self.interruptSpells == 0 then
        borderFrame:Hide()
        return
    end
    
    if not castBar.BorderShield or not borderFrame.SetAlphaFromBoolean then
        borderFrame:Hide()
        return
    end
    
    if not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean
       or not C_Spell or not C_Spell.GetSpellCooldownDuration then
        borderFrame:Hide()
        return
    end
    
    -- Two-layer alpha computation, no secret value is ever branched on:
    --
    -- Layer 1 (cooldown): branchless chain computes anyReady as a secret number (0 or 1).
    -- Layer 2 (interruptibility): SetAlphaFromBoolean uses BorderShield:IsShown() (secret boolean)
    --   to pick between alpha 0 (not interruptible) and anyReady (interruptible).
    --
    -- Final alpha: 1 only when cast IS interruptible AND interrupt IS ready.
    local ok, anyReady = pcall(function()
        local result = 0
        for _, spellID in ipairs(self.interruptSpells) do
            local cooldownDuration = C_Spell.GetSpellCooldownDuration(spellID)
            if cooldownDuration and cooldownDuration.IsZero then
                local isZero = cooldownDuration:IsZero()
                result = C_CurveUtil.EvaluateColorValueFromBoolean(isZero, 1, result)
            end
        end
        return result
    end)
    
    if not ok then
        borderFrame:Hide()
        return
    end
    
    -- BorderShield:IsShown() may return a secret boolean.
    -- SetAlphaFromBoolean handles it natively:
    --   Shield shown (not interruptible) → alpha = 0
    --   Shield hidden (interruptible) → alpha = anyReady (secret number: 0 or 1)
    local okShield, isShielded = pcall(castBar.BorderShield.IsShown, castBar.BorderShield)
    if not okShield then
        borderFrame:Hide()
        return
    end
    
    borderFrame:SetAlphaFromBoolean(isShielded, 0, anyReady)
    self:UpdateInterruptBorderColor(borderFrame)
    borderFrame:Show()
end

function ENC:GetCastBarInfo(castBar)
    if not self.inInstance then return nil end
    if not castBar or not castBar.unit or castBar:IsForbidden() then return nil end
    if not strmatch(castBar.unit, "^nameplate") then return nil end
    if UnitIsFriend("player", castBar.unit) then return nil end
    -- Only color cast bars when the player is in combat to avoid secret value issues
    if not self.playerInCombat then return nil end
    
    local name, _, _, _, _, _, _, notInterruptible, spellID = UnitCastingInfo(castBar.unit)
    local isChanneling = false
    
    if not name then
        name, _, _, _, _, _, notInterruptible, spellID = UnitChannelInfo(castBar.unit)
        isChanneling = true
    end
    
    if not name then return nil end
    
    return name, notInterruptible, spellID, isChanneling
end

function ENC:GetCastBarColorValues(castBar)
    local name, notInterruptible, spellID, isChanneling = self:GetCastBarInfo(castBar)
    if not name then return nil end
    
    local baseColor = isChanneling and self.db.castBar.channel or self.db.castBar.standard
    local r, g, b, a = baseColor.r, baseColor.g, baseColor.b, baseColor.a or 1
    
    -- Apply important spell color layer
    if spellID and C_Spell and C_Spell.IsSpellImportant and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local isImportant = C_Spell.IsSpellImportant(spellID)
        local imp = self.db.castBar.important
        r = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.r, r)
        g = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.g, g)
        b = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.b, b)
        a = C_CurveUtil.EvaluateColorValueFromBoolean(isImportant, imp.a or 1, a)
    end
    
    -- Apply uninterruptible color layer (highest priority — overrides important)
    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local unint = self.db.castBar.uninterruptible
        r = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.r, r)
        g = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.g, g)
        b = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.b, b)
        a = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, unint.a or 1, a)
    end
    
    return r, g, b, a, notInterruptible
end

function ENC:UpdateCastBarColor(castBar)
    if not castBar or castBar:IsForbidden() then return end
    
    local name, notInterruptible = self:GetCastBarInfo(castBar)
    
    -- Interrupt border works independently of cast bar coloring
    if name then
        self:UpdateInterruptBorder(castBar)
    else
        if castBar.ENC_interruptBorder then castBar.ENC_interruptBorder:Hide() end
    end
    
    -- Cast bar coloring requires the enabled toggle
    if self.db.castBar.enabled and name then
        local r, g, b, a = self:GetCastBarColorValues(castBar)
        if r then
            self:ApplyCastBarColor(castBar, r, g, b, a)
            castBar.ENC_hasColor = true
            castBar.ENC_r, castBar.ENC_g, castBar.ENC_b, castBar.ENC_a = r, g, b, a
        end
    else
        self:RestoreCastBarTexture(castBar)
        castBar.ENC_hasColor = false
    end
end

function ENC:RefreshAllInterruptBorders()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        if nameplate.UnitFrame and nameplate.UnitFrame.castBar then
            local castBar = nameplate.UnitFrame.castBar
            if castBar.casting or castBar.channeling then
                self:UpdateInterruptBorder(castBar)
            end
        end
    end
end

function ENC:ClearAllCastBarColors()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        if nameplate.UnitFrame and nameplate.UnitFrame.castBar then
            local castBar = nameplate.UnitFrame.castBar
            if castBar.ENC_hasColor then
                self:RestoreCastBarTexture(castBar)
                castBar.ENC_hasColor = false
                if castBar.ENC_interruptBorder then castBar.ENC_interruptBorder:Hide() end
            end
        end
    end
end

function ENC:GetOrCreateFocusOverlay(healthBar)
    if healthBar.ENC_focusOverlay then
        return healthBar.ENC_focusOverlay
    end
    
    local overlay = healthBar:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(FOCUS_TARGET_TEXTURE)
    overlay:SetAllPoints(healthBar)
    overlay:SetBlendMode("ADD")
    overlay:Hide()
    healthBar.ENC_focusOverlay = overlay
    return overlay
end

function ENC:UpdateFocusOverlay(nameplate, unit)
    if not nameplate.UnitFrame or not nameplate.UnitFrame.healthBar then return end
    local healthBar = nameplate.UnitFrame.healthBar
    
    local showOverlay = self.inInstance
        and self.db.focusTarget.useTexture
        and UnitExists("focus")
        and UnitIsUnit(unit, "focus")
        and not UnitIsFriend("player", unit)
    
    if showOverlay then
        local overlay = self:GetOrCreateFocusOverlay(healthBar)
        local c = self.db.focusTarget.color
        overlay:SetVertexColor(c.r, c.g, c.b, c.a or 0.75)
        overlay:Show()
    else
        if healthBar.ENC_focusOverlay then
            healthBar.ENC_focusOverlay:Hide()
        end
    end
end

function ENC:UpdateNameplateColor(nameplate)
    if not nameplate or not nameplate.UnitFrame then return end
    local unit = nameplate.UnitFrame.unit
    if not unit then return end
    
    -- Update focus target texture overlay
    self:UpdateFocusOverlay(nameplate, unit)
    
    local color = self:GetNameplateColor(unit)
    if color and nameplate.UnitFrame.healthBar then
        nameplate.UnitFrame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

function ENC:HookNameplates()
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
        if not frame.unit or frame:IsForbidden() then return end
        if not strmatch(frame.unit, "^nameplate") then return end
        
        -- Detect neutral units by reading the color Blizzard just set
        -- Neutral/yellow nameplates have r > 0.9, g > 0.7, b < 0.2
        -- Red hostile nameplates have r > 0.9, g < 0.2, b < 0.2
        if frame.healthBar then
            local r, g, b = frame.healthBar:GetStatusBarColor()
            ENC.neutralCache[frame.unit] = (r > 0.9 and g > 0.7 and b < 0.2)
        end
        
        local color = ENC:GetNameplateColor(frame.unit)
        if color and frame.healthBar then
            frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end)
end

function ENC:HookCastBars()
    if not CastingBarMixin then return end
    
    local function SafeUpdateCastBar(castBar)
        if not castBar or not castBar.unit or castBar:IsForbidden() then return end
        -- pcall UnitIsFriend: it can return a secret boolean in Midnight
        local okFriend, isFriend = pcall(UnitIsFriend, "player", castBar.unit)
        if okFriend and isFriend then return end
        ENC:UpdateCastBarColor(castBar)
    end
    
    hooksecurefunc(CastingBarMixin, "OnEvent", function(castBar, event, arg1)
        if not castBar or not castBar.unit or castBar:IsForbidden() then return end
        if arg1 ~= castBar.unit then return end
        
        -- Cast stop cleanup: always runs without tainted API calls.
        -- If UnitIsFriend errors below, this cleanup still happens.
        if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or
           event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            ENC:RestoreCastBarTexture(castBar)
            castBar.ENC_hasColor = false
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
        
        -- Out of combat: always clean up first, no tainted API calls needed.
        -- This MUST run before UnitIsFriend to avoid secret boolean aborts
        -- preventing cleanup.
        if not ENC.playerInCombat then
            if castBar.ENC_hasColor then
                ENC:RestoreCastBarTexture(castBar)
                castBar.ENC_hasColor = false
            end
            if castBar.ENC_interruptBorder then castBar.ENC_interruptBorder:Hide() end
            return
        end
        
        -- In combat: filter friendly units (pcall to handle secret booleans)
        local okFriend, isFriend = pcall(UnitIsFriend, "player", castBar.unit)
        if okFriend and isFriend then return end
        
        if castBar.ENC_hasColor and castBar.ENC_r then
            ENC:ReplaceCastBarTexture(castBar)
            local texture = castBar:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(castBar.ENC_r, castBar.ENC_g, castBar.ENC_b, castBar.ENC_a)
            end
        end
        -- Throttled interrupt border refresh: catches cooldown readiness changes
        -- that happen between SPELL_UPDATE_COOLDOWN events, keeping the border responsive
        if castBar.casting or castBar.channeling then
            local now = GetTime()
            if not castBar.ENC_lastBorderRefresh or (now - castBar.ENC_lastBorderRefresh) >= 0.1 then
                castBar.ENC_lastBorderRefresh = now
                ENC:UpdateInterruptBorder(castBar)
            end
        end
    end)
    
    local function HookIfExists(methodName)
        if CastingBarMixin[methodName] then
            hooksecurefunc(CastingBarMixin, methodName, function(castBar)
                if not castBar or not castBar.unit or castBar:IsForbidden() then return end
                SafeUpdateCastBar(castBar)
            end)
        end
    end
    
    HookIfExists("UpdateInterruptibleState")
    HookIfExists("UpdateHighlightImportantCast")
    HookIfExists("UpdateHighlightWhenCastTarget")
end

-- Dispel Glow System
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"

function ENC:GetOrCreateDispelGlow(buffFrame)
    if buffFrame.ENC_dispelGlow then
        return buffFrame.ENC_dispelGlow
    end
    
    local glow = buffFrame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(GLOW_TEXTURE)
    glow:SetPoint("CENTER", buffFrame, "CENTER", 0, 0)
    -- Use anchor-based sizing instead of GetWidth/GetHeight (which return secret numbers)
    glow:SetPoint("TOPLEFT", buffFrame, "TOPLEFT", -8, 8)
    glow:SetPoint("BOTTOMRIGHT", buffFrame, "BOTTOMRIGHT", 8, -8)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    glow:Hide()
    buffFrame.ENC_dispelGlow = glow
    return glow
end

function ENC:UpdateDispelGlowForNameplate(nameplate)
    if not self.db.dispelGlow.enabled then return end
    if not self.inInstance then return end
    if not nameplate.UnitFrame then return end
    if not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean then return end
    
    local unit = nameplate.UnitFrame.unit
    if not unit then return end
    
    local auraFrame = nameplate.UnitFrame.AurasFrame
    if not auraFrame then return end
    
    local c = self.db.dispelGlow.color
    
    -- Process buff frames - add glow for stealable buffs
    local buffList = auraFrame.BuffListFrame
    if buffList then
        for _, buffFrame in ipairs({buffList:GetChildren()}) do
            if buffFrame and buffFrame:IsShown() and buffFrame.auraInstanceID then
                local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, buffFrame.auraInstanceID)
                if auraData then
                    local isStealable = auraData.isStealable
                    local a = C_CurveUtil.EvaluateColorValueFromBoolean(isStealable, 0.7, 0)
                    
                    local glow = self:GetOrCreateDispelGlow(buffFrame)
                    glow:SetVertexColor(c.r, c.g, c.b, 1.0)
                    glow:SetAlpha(a)
                    glow:Show()
                else
                    if buffFrame.ENC_dispelGlow then buffFrame.ENC_dispelGlow:Hide() end
                end
            else
                if buffFrame and buffFrame.ENC_dispelGlow then buffFrame.ENC_dispelGlow:Hide() end
            end
        end
    end
    
    -- Hide any stale glows on debuff frames (frames may be recycled from buff pool)
    local debuffList = auraFrame.DebuffListFrame
    if debuffList then
        for _, debuffFrame in ipairs({debuffList:GetChildren()}) do
            if debuffFrame and debuffFrame.ENC_dispelGlow then
                debuffFrame.ENC_dispelGlow:Hide()
            end
        end
    end
    
    -- Hide any stale glows on crowd control frames (frames may be recycled from buff pool)
    local ccList = auraFrame.CrowdControlListFrame
    if ccList then
        for _, ccFrame in ipairs({ccList:GetChildren()}) do
            if ccFrame and ccFrame.ENC_dispelGlow then
                ccFrame.ENC_dispelGlow:Hide()
            end
        end
    end
end

function ENC:HookDispelGlows()
    -- Register UNIT_AURA event to detect buff changes on nameplate units.
    -- The old NameplateBuffContainerMixin.UpdateBuffs and CompactUnitFrame_UpdateAuras
    -- hooks were removed by Blizzard. UNIT_AURA is the stable event-based alternative.
    -- Deferred by one frame to ensure Blizzard's buff frames are populated first.
    local auraFrame = CreateFrame("Frame")
    auraFrame:RegisterEvent("UNIT_AURA")
    auraFrame:SetScript("OnEvent", function(_, _, unit)
        if not unit or not strmatch(unit, "^nameplate") then return end
        if not ENC.db.dispelGlow.enabled then return end
        if not ENC.inInstance then return end
        if UnitIsFriend("player", unit) then return end
        
        C_Timer.After(0, function()
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate then
                ENC:UpdateDispelGlowForNameplate(nameplate)
            end
        end)
    end)
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
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ENC:InitDB()
    elseif event == "PLAYER_LOGIN" then
        ENC.playerInCombat = InCombatLockdown()
        ENC:HookNameplates()
        ENC:HookCastBars()
        ENC:HookDispelGlows()
        ENC:UpdateInstanceStatus()
        ENC:UpdateInterruptSpell()
        ENC:UpdateOtherTanks()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ENC:UpdateInstanceStatus()
        ENC:UpdateOtherTanks()
        ENC:UpdateAllNameplates()
    elseif event == "GROUP_ROSTER_UPDATE" then
        ENC:UpdateOtherTanks()
        ENC:UpdateAllNameplates()
    elseif event == "SPELLS_CHANGED" then
        ENC:UpdateInterruptSpell()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if ENC.playerInCombat and ENC.interruptSpells and #ENC.interruptSpells > 0 then
            ENC:RefreshAllInterruptBorders()
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        if nameplate then
            ENC:UpdateNameplateColor(nameplate)
            -- If the mob was already casting when it came into range, update the cast bar too
            if nameplate.UnitFrame and nameplate.UnitFrame.castBar then
                local castBar = nameplate.UnitFrame.castBar
                if castBar.casting or castBar.channeling then
                    ENC:UpdateCastBarColor(castBar)
                end
            end
            -- Check for stealable buffs on the new nameplate
            ENC:UpdateDispelGlowForNameplate(nameplate)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ENC.neutralCache[arg1] = nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        ENC.playerInCombat = false
        ENC:ClearAllCastBarColors()
        ENC:UpdateAllNameplates()
    elseif event == "PLAYER_REGEN_DISABLED" then
        ENC.playerInCombat = true
        ENC:UpdateAllNameplates()
    elseif event == "UNIT_THREAT_LIST_UPDATE" then
        -- High-frequency per-mob threat ticks: update only the affected plate
        if arg1 and strmatch(arg1, "^nameplate") then
            local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
            if nameplate then ENC:UpdateNameplateColor(nameplate) end
        else
            ENC:UpdateAllNameplates()
        end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        -- Meaningful threat transitions (aggro gained/lost): full refresh
        ENC:UpdateAllNameplates()
    elseif event == "PLAYER_FOCUS_CHANGED" then
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
        
        local P = function(label, value)
            print("|cff00ccff[ENC Debug]|r |cffffffff" .. label .. ":|r " .. tostring(value))
        end
        local S = function() print("|cff00ccff[ENC Debug]|r --------------------") end
        
        local name = UnitName(unit)
        local classification = UnitClassification(unit) or "unknown"
        local level = UnitLevel(unit)
        local playerLevel = UnitLevel("player")
        local powerType, powerToken = UnitPowerType(unit)
        local encType = ENC:GetUnitType(unit)
        local isFriend = UnitIsFriend("player", unit)
        local isEnemy = UnitIsEnemy("player", unit)
        local isPlayer = UnitIsPlayer(unit)
        local inCombat = UnitAffectingCombat(unit)
        
        S()
        P("Name", name or "nil")
        P("Classification", classification)
        P("Level", level .. " (Player: " .. playerLevel .. ", Diff: " .. (level - playerLevel) .. ")")
        P("Power Type", powerType .. " (" .. (powerToken or "unknown") .. ")" .. (powerType == 0 and " |cff00ff00= Mana (Caster)|r" or ""))
        P("ENC Type", encType)
        P("Is Player", isPlayer)
        P("Friendly", tostring(isFriend) .. " |cffffffffEnemy:|r " .. tostring(isEnemy))
        P("In Combat (target)", inCombat)
        P("In Combat (player)", ENC.playerInCombat)
        P("Addon Active", ENC.inInstance)
        
        local inInstance, instanceType = IsInInstance()
        P("Instance", tostring(inInstance) .. " |cffffffffType:|r " .. (instanceType or "none"))
        
        local isFocus = UnitExists("focus") and UnitIsUnit(unit, "focus")
        P("Is Focus", isFocus)
        
        -- Interrupt spells
        local spellCount = ENC.interruptSpells and #ENC.interruptSpells or 0
        local spellNames = {}
        for _, spellID in ipairs(ENC.interruptSpells or {}) do
            local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or tostring(spellID)
            table.insert(spellNames, spellName .. " (" .. spellID .. ")")
        end
        P("Interrupt Spells", spellCount .. (spellCount > 0 and " [" .. table.concat(spellNames, ", ") .. "]" or " (none)"))
        
        -- Cast bar state
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate and nameplate.UnitFrame and nameplate.UnitFrame.castBar then
            local castBar = nameplate.UnitFrame.castBar
            S()
            print("|cff00ccff[ENC Debug]|r |cffffff00-- Cast Bar --|r")
            P("Casting", castBar.casting)
            P("Channeling", castBar.channeling)
            
            if castBar.casting or castBar.channeling then
                local castName, _, _, _, _, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
                if not castName then
                    castName, _, _, _, _, _, notInterruptible, spellID = UnitChannelInfo(unit)
                end
                P("Spell", (castName or "nil") .. " (ID: " .. tostring(spellID) .. ")")
                P("notInterruptible (API)", notInterruptible)
                
                if castBar.BorderShield then
                    local okShield, isShielded = pcall(castBar.BorderShield.IsShown, castBar.BorderShield)
                    P("BorderShield:IsShown()", okShield and tostring(isShielded) or "ERROR: " .. tostring(isShielded))
                    if okShield and issecretvalue then
                        P("BorderShield IsShown secret", issecretvalue(isShielded))
                    end
                else
                    P("BorderShield", "nil")
                end
            end
            
            P("ENC_hasColor", castBar.ENC_hasColor)
            P("ENC_textureReplaced", castBar.ENC_textureReplaced)
            
            -- Interrupt border state
            if castBar.ENC_interruptBorder then
                local border = castBar.ENC_interruptBorder
                local okShown, borderShown = pcall(border.IsShown, border)
                local okAlpha, borderAlpha = pcall(border.GetAlpha, border)
                P("Border Exists", true)
                P("Border Shown", okShown and tostring(borderShown) or "ERROR")
                P("Border Alpha", okAlpha and tostring(borderAlpha) or "ERROR")
            else
                P("Border Exists", false)
            end
        else
            S()
            P("Cast Bar", "not found on nameplate")
        end
        
        -- Dispel glow state
        if nameplate and nameplate.UnitFrame and nameplate.UnitFrame.AurasFrame then
            local auraFrame = nameplate.UnitFrame.AurasFrame
            local buffList = auraFrame.BuffListFrame
            if buffList then
                local glowCount = 0
                local buffCount = 0
                for i = 1, buffList:GetNumChildren() do
                    local child = select(i, buffList:GetChildren())
                    if child and child:IsShown() then
                        buffCount = buffCount + 1
                        if child.ENC_dispelGlow and child.ENC_dispelGlow:IsShown() then
                            glowCount = glowCount + 1
                        end
                    end
                end
                P("Visible Buffs", buffCount)
                P("Active Glows", glowCount)
            end
        end
        
        S()
        return
    end
    
    if ENC.OpenOptions then
        ENC:OpenOptions()
    end
end