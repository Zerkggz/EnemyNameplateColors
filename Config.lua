local ADDON_NAME = "EnemyNameplateColors"
local ENC = _G[ADDON_NAME]

-- Color picker callback
function ENC:ShowColorPicker(colorTable, callback)
    local r, g, b = colorTable.r, colorTable.g, colorTable.b
    local a = colorTable.a or 1.0
    
    local info = {}
    
    info.r = r
    info.g = g
    info.b = b
    info.opacity = a
    
    info.swatchFunc = function()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha()
        colorTable.r = newR
        colorTable.g = newG
        colorTable.b = newB
        if colorTable.a ~= nil then
            colorTable.a = newA
        end
        
        if callback then
            callback(newR, newG, newB, newA)
        end

        ENC:UpdateAllNameplates()
    end
    
    info.cancelFunc = function()
        colorTable.r = r
        colorTable.g = g
        colorTable.b = b
        if colorTable.a ~= nil then
            colorTable.a = a
        end
        
        if callback then
            callback(r, g, b, a)
        end

        ENC:UpdateAllNameplates()
    end
    
    info.hasOpacity = (colorTable.a ~= nil)
    
    ColorPickerFrame:SetupColorPickerAndShow(info)
end

-- Color swatch button with optional alpha
function ENC:CreateColorSwatch(parent, colorTable, label, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    
    -- Create the color texture background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)
    
    -- Create the color texture
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", -1, 1)
    if colorTable.a then
        texture:SetColorTexture(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    else
        texture:SetColorTexture(colorTable.r, colorTable.g, colorTable.b)
    end
    button.texture = texture
    button.colorTable = colorTable
    
    -- Label
    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", button, "RIGHT", 10, 0)
    labelText:SetText(label)
    button.label = labelText
    
    -- Click handler
    button:SetScript("OnClick", function()
        ENC:ShowColorPicker(colorTable, function(r, g, b, a)
            if colorTable.a then
                texture:SetColorTexture(r, g, b, a)
            else
                texture:SetColorTexture(r, g, b)
            end
            if callback then
                callback(r, g, b, a)
            end
        end)
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to change color")
        if colorTable.a then
            GameTooltip:AddLine(string.format("RGBA: %.2f, %.2f, %.2f, %.2f", colorTable.r, colorTable.g, colorTable.b, colorTable.a), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format("RGB: %.2f, %.2f, %.2f", colorTable.r, colorTable.g, colorTable.b), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return button
end

-- Reset to defaults
function ENC:ResetToDefaults()
    self.db.enabledZones = self:DeepCopy(self.defaults.enabledZones)
    self.db.focusTarget = self:DeepCopy(self.defaults.focusTarget)
    self.db.unitType = self:DeepCopy(self.defaults.unitType)
    self.db.tank = self:DeepCopy(self.defaults.tank)
    self.db.dpsHealer = self:DeepCopy(self.defaults.dpsHealer)
    self.db.castBar = self:DeepCopy(self.defaults.castBar)

    self:UpdateInstanceStatus()
    self:UpdateAllNameplates()
    
    -- Refresh options panel if it exists
    if self.OptionsPanel then
        self.OptionsPanel:RefreshColors()
    end
end

-- Convert hex to RGB
function ENC:HexToRGB(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end

-- Convert RGB to hex
function ENC:RGBToHex(r, g, b)
    return string.format("#%02x%02x%02x", r * 255, g * 255, b * 255)
end