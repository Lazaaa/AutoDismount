-- AutoDismount
-- Automatically dismounts and cancels shapeshifts when:
--   - Targeting a friendly NPC (prevents "Can't speak while shapeshifted")
--   - Trying to interact with game objects (mining, herbalism, quest items)
--   - Opening a merchant window
--   - Opening the taxi map
-- Emberveil (1.12.1) compatible.

AutoDismount = AutoDismount or {}
local AD = AutoDismount

-- =====================================================
--  BINDING STRINGS
-- =====================================================

BINDING_HEADER_AUTODISMOUNT = "AutoDismount"
BINDING_NAME_AUTODISMOUNT_TRIGGER = "Dismount and cancel forms"

-- =====================================================
--  SAVED VARIABLES
-- =====================================================

local function InitDB()
    if not AutoDismountDB then
        AutoDismountDB = {
            enabled = true,
            onMerchant = true,
            onTaxi = true,
            onNpcTarget = true,
            onError = true,
            cancelForms = true,
            debug = false,
        }
    end
    if AutoDismountDB.enabled == nil then AutoDismountDB.enabled = true end
    if AutoDismountDB.onMerchant == nil then AutoDismountDB.onMerchant = true end
    if AutoDismountDB.onTaxi == nil then AutoDismountDB.onTaxi = true end
    if AutoDismountDB.onNpcTarget == nil then AutoDismountDB.onNpcTarget = true end
    if AutoDismountDB.onError == nil then AutoDismountDB.onError = true end
    if AutoDismountDB.cancelForms == nil then AutoDismountDB.cancelForms = true end
    if AutoDismountDB.debug == nil then AutoDismountDB.debug = false end
end

InitDB()

-- =====================================================
--  DEBUG HELPER
--  Prints only when AutoDismountDB.debug is true.
-- =====================================================

local function Debug(msg)
    if AutoDismountDB and AutoDismountDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff808080[AutoDismount DEBUG]|r " .. tostring(msg))
    end
end

-- =====================================================
--  HELPER: extract icon name
-- =====================================================

local function ExtractIconName(raw)
    if not raw then return nil end
    local iconName = raw
    iconName = string.match(iconName, "([^/\\]+)$") or iconName
    iconName = string.gsub(iconName, "_TEX$", "")
    return iconName
end

-- =====================================================
--  FORM DETECTION
-- =====================================================

local FORM_PATTERNS = {
    "spiritwolf", "ghostwolf",
    "bearform", "catform", "aquaticform",
    "travelform", "forceofnature", "moonkin", "shadowform",
}

local function IsFormName(iconName)
    if not iconName then return false end
    local lower = string.lower(iconName)
    for _, pattern in ipairs(FORM_PATTERNS) do
        if string.find(lower, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- =====================================================
--  FORM TOGGLE SPELLS
-- =====================================================

local FORM_TOGGLE_SPELLS = {
    ["Spell_Nature_SpiritWolf"]    = "Ghost Wolf",
    ["Ability_Racial_BearForm"]    = "Bear Form",
    ["Ability_Racial_CatForm"]     = "Cat Form",
    ["Ability_Druid_AquaticForm"]  = "Aquatic Form",
    ["Ability_Druid_TravelForm"]   = "Travel Form",
    ["Spell_Nature_ForceOfNature"] = "Moonkin Form",
    ["Spell_Shadow_Shadowform"]    = "Shadowform",
}

local FORM_SPELL_ALIASES = {
    ["Ability_Racial_BearForm"]    = { "Bear Form", "Dire Bear Form" },
}

-- =====================================================
--  RUNSPELL HELPER
-- =====================================================

local function RunSpellByName(spellName)
    if not spellName then return false end

    local hadTarget = UnitExists("target") and true or false
    local targetIsEnemy = false
    if hadTarget then
        local ok, result = pcall(UnitIsEnemy, "player", "target")
        if ok then targetIsEnemy = result end
    end

    Debug("Target before cast: " .. tostring(hadTarget) .. " (enemy=" .. tostring(targetIsEnemy) .. ")")

    if hadTarget and not targetIsEnemy then
        ClearTarget()
        Debug("Cleared friendly target before cast")
    end

    local ok1 = pcall(CastSpellByName, spellName)
    if ok1 then
        Debug("Cast via direct CastSpellByName('" .. spellName .. "')")
    else
        local escaped = string.gsub(spellName, "'", "\\'")
        local ok2 = pcall(RunScript, "CastSpellByName('" .. escaped .. "')")
        if ok2 then
            Debug("Cast via RunScript('" .. spellName .. "')")
        else
            Debug("Both cast methods failed for: " .. spellName)
        end
    end

    if hadTarget and not targetIsEnemy then
        local restoreFrame = CreateFrame("Frame")
        local t = 0
        restoreFrame:SetScript("OnUpdate", function()
            t = t + (arg1 or 0)
            if t > 0.05 then
                pcall(TargetLastTarget)
                Debug("Restored last target")
                restoreFrame:SetScript("OnUpdate", nil)
                restoreFrame:Hide()
            end
        end)
    end

    return true
end

-- =====================================================
--  LIVE FORM DETECTION
-- =====================================================

local function DetectCurrentForm()
    for i = 32, 1, -1 do
        local ok, name, rank, texture = pcall(UnitBuff, "player", i)
        if ok and name then
            local iconName = ExtractIconName(texture) or ExtractIconName(name)
            if IsFormName(iconName) then
                local spellNames = FORM_SPELL_ALIASES[iconName] or { FORM_TOGGLE_SPELLS[iconName] }
                if spellNames and spellNames[1] then
                    return spellNames[1], iconName
                end
            end
        end
    end
    return nil, nil
end

-- =====================================================
--  FORM CACHE (updated every 0.5 sec)
-- =====================================================

local cachedFormSpell = nil
local cachedFormIcon = nil
local cachedFormTime = 0
local cacheAccum = 0
local suppressCacheUntil = 0

local cacheFrame = CreateFrame("Frame")
cacheFrame:SetScript("OnUpdate", function()
    cacheAccum = cacheAccum + (arg1 or 0)
    if cacheAccum < 0.5 then return end
    cacheAccum = 0

    if not AutoDismountDB or not AutoDismountDB.enabled then return end

    if GetTime() < suppressCacheUntil then
        return
    end

    local spell, icon = DetectCurrentForm()
    if spell then
        if spell ~= cachedFormSpell then
            Debug("Form cache: " .. tostring(cachedFormSpell) .. " -> " .. spell)
        end
        cachedFormSpell = spell
        cachedFormIcon = icon
        cachedFormTime = GetTime()
    end
end)

local function GetCachedForm()
    if cachedFormSpell and (GetTime() - cachedFormTime) < 3 then
        return cachedFormSpell, cachedFormIcon
    end
    return nil, nil
end

local function ClearFormCache()
    cachedFormSpell = nil
    cachedFormIcon = nil
    cachedFormTime = 0
end

-- =====================================================
--  CANCEL SHAPESHIFT FORMS
-- =====================================================

local cancellingForm = false
local lastCancelTime = 0
local CANCEL_COOLDOWN = 2.0

local function TryCancelForms()
    if cancellingForm then return 0 end

    local now = GetTime()
    if (now - lastCancelTime) < CANCEL_COOLDOWN then
        Debug("Cancel on cooldown (" .. string.format("%.1f", CANCEL_COOLDOWN - (now - lastCancelTime)) .. "s left)")
        return 0
    end

    cancellingForm = true
    lastCancelTime = now
    suppressCacheUntil = now + 3.0

    local result = 0

    local liveSpell = DetectCurrentForm()
    if liveSpell then
        Debug("Live form detected: " .. liveSpell)
        RunSpellByName(liveSpell)
        ClearFormCache()
        result = 1
    else
        local cachedSpell = GetCachedForm()
        if cachedSpell then
            Debug("Using cached form: " .. cachedSpell)
            RunSpellByName(cachedSpell)
            ClearFormCache()
            result = 1
        else
            Debug("No form detected")
        end
    end

    cancellingForm = false
    return result
end

-- =====================================================
--  DISMOUNT
-- =====================================================

local function TryDismount()
    local mounted = false
    if IsMounted then
        local ok, result = pcall(IsMounted)
        if ok then mounted = result end
    end
    Debug("IsMounted: " .. tostring(mounted))
    if not mounted then return false end

    if type(SitStandOrDescendStart) == "function" then
        local ok = pcall(SitStandOrDescendStart)
        if ok then
            Debug("Used SitStandOrDescendStart()")
            return true
        end
    end

    if type(Dismount) == "function" then
        local ok = pcall(Dismount)
        if ok then
            Debug("Used Dismount()")
            return true
        end
    end

    local ok3 = pcall(RunScript, "/sit")
    if ok3 then
        Debug("Used RunScript('/sit')")
        return true
    end

    for i = 1, 32 do
        local ok, name, rank, texture = pcall(UnitBuff, "player", i)
        if not ok or not name then break end
        local iconName = ExtractIconName(texture) or ExtractIconName(name)
        if iconName and string.find(string.lower(iconName), "ability_mount", 1, true) then
            if CancelPlayerBuff then
                local ok2 = pcall(CancelPlayerBuff, i)
                if ok2 then
                    Debug("Cancelled mount buff: " .. tostring(iconName))
                    return true
                end
            end
        end
    end

    return false
end

-- =====================================================
--  MAIN ACTION
-- =====================================================

local lastActionTime = 0
local actionInProgress = false

local function DismountAndUnshift(verbose)
    if actionInProgress then return end
    local now = GetTime()
    if (now - lastActionTime) < 1.0 then return end
    actionInProgress = true
    lastActionTime = now

    local didDismount = TryDismount()
    local didCancel = 0
    if AutoDismountDB.cancelForms then
        didCancel = TryCancelForms()
    end

    if verbose then
        if didDismount then
            Debug("Dismount triggered")
        end
        if didCancel and didCancel > 0 then
            Debug("Cancelled " .. didCancel .. " form(s)")
        end
        if not didDismount and (not didCancel or didCancel == 0) then
            Debug("Nothing to dismount or cancel")
        end
    end

    actionInProgress = false
end

-- =====================================================
--  GLOBAL TRIGGER
-- =====================================================

function AutoDismount_Trigger()
    DismountAndUnshift(true)
end

-- =====================================================
--  GLOBAL SCAN
-- =====================================================

function AutoDismount_Scan()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount|r buff scan:")
    local count = 0
    for i = 1, 32 do
        local ok, name, rank, texture = pcall(UnitBuff, "player", i)
        if not ok or not name then break end
        local extracted = ExtractIconName(texture) or ExtractIconName(name)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ": " .. tostring(extracted))
        count = count + 1
    end
    if count == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  |cff808080(no buffs - UnitBuff is empty)|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount|r cached form: " .. tostring(GetCachedForm()))
end

-- =====================================================
--  ERROR PATTERNS
-- =====================================================

local ERROR_PATTERNS = {
    "shapeshift",
    "shapeshifted",
    "shift form",
    "shifted form",
}

local function IsShapeshiftError(msg)
    if not msg then return false end
    local lower = string.lower(msg)
    for _, pattern in ipairs(ERROR_PATTERNS) do
        if string.find(lower, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- =====================================================
--  SCHEDULED CANCEL
-- =====================================================

local scheduledCancelPending = false

local function ScheduleCancelWithDelay(delaySeconds)
    if scheduledCancelPending then return end
    scheduledCancelPending = true

    local delayFrame = CreateFrame("Frame")
    local delayTime = 0
    delayFrame:SetScript("OnUpdate", function()
        delayTime = delayTime + (arg1 or 0)
        if delayTime >= delaySeconds then
            delayFrame:SetScript("OnUpdate", nil)
            delayFrame:Hide()
            scheduledCancelPending = false

            Debug("Delayed cancel executing now")
            local didCancel = TryCancelForms()
            if didCancel > 0 then
                Debug("Cancelled " .. didCancel .. " form(s)")
            end
        end
    end)
end

-- =====================================================
--  EVENT HANDLER
-- =====================================================

local eventFrame = CreateFrame("Frame", "AutoDismountFrame")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("TAXIMAP_OPENED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == "AutoDismount" then
            InitDB()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount|r by Kharon v1.9.1 loaded. Use |cffFFD700/ad|r for options.")
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if AutoDismountDB.enabled and AutoDismountDB.onNpcTarget and AutoDismountDB.cancelForms then
            if UnitExists("target") and UnitIsFriend("player", "target") and not UnitIsPlayer("target") then
                Debug("Friendly NPC targeted - cancelling form")
                local didCancel = TryCancelForms()
                if didCancel > 0 then
                    Debug("Cancelled " .. didCancel .. " form(s) (NPC targeted)")
                end
            end
        end

    elseif event == "UI_ERROR_MESSAGE" then
        if AutoDismountDB.enabled and AutoDismountDB.onError and AutoDismountDB.cancelForms then
            local errorMessage = arg2 or arg1

            Debug("UI_ERROR_MESSAGE: a1=" .. tostring(arg1) .. " a2=" .. tostring(arg2))

            if IsShapeshiftError(errorMessage) then
                Debug("Shapeshift error detected - scheduling cancel in 0.2s")
                ScheduleCancelWithDelay(0.2)
            end
        end

    elseif event == "MERCHANT_SHOW" then
        if AutoDismountDB.enabled and AutoDismountDB.onMerchant then
            Debug("MERCHANT_SHOW event fired")
            DismountAndUnshift(false)
        end

    elseif event == "TAXIMAP_OPENED" then
        if AutoDismountDB.enabled and AutoDismountDB.onTaxi then
            Debug("TAXIMAP_OPENED event fired")
            DismountAndUnshift(false)
        end
    end
end)

-- =====================================================
--  POLLER (fallback for unrealUI and similar)
-- =====================================================

local POLL_INTERVAL = 0.3
local merchantWasShown = false
local taxiWasShown = false
local pollAccum = 0

local poller = CreateFrame("Frame", "AutoDismountPoller")
poller:SetScript("OnUpdate", function()
    pollAccum = pollAccum + (arg1 or 0)
    if pollAccum < POLL_INTERVAL then return end
    pollAccum = 0

    if not AutoDismountDB or not AutoDismountDB.enabled then return end

    local merchantFrame = MerchantFrame or _G["MerchantFrame"]
    if merchantFrame then
        local shown = merchantFrame:IsShown() and true or false
        if shown and not merchantWasShown then
            Debug("Poller: MerchantFrame just opened")
            if AutoDismountDB.onMerchant then
                DismountAndUnshift(false)
            end
        end
        merchantWasShown = shown
    end

    local taxiFrame = TaxiFrame or _G["TaxiFrame"]
    if taxiFrame then
        local shown = taxiFrame:IsShown() and true or false
        if shown and not taxiWasShown then
            Debug("Poller: TaxiFrame just opened")
            if AutoDismountDB.onTaxi then
                DismountAndUnshift(false)
            end
        end
        taxiWasShown = shown
    end
end)

-- =====================================================
--  SLASH COMMANDS
-- =====================================================

SLASH_AUTODISMOUNT1 = "/ad"
SLASH_AUTODISMOUNT2 = "/autodismount"

SlashCmdList["AUTODISMOUNT"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "toggle" then
        AutoDismountDB.enabled = not AutoDismountDB.enabled
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r Addon " ..
            (AutoDismountDB.enabled and "enabled" or "disabled"))

    elseif msg == "merchant" then
        AutoDismountDB.onMerchant = not AutoDismountDB.onMerchant
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r Merchant trigger " ..
            (AutoDismountDB.onMerchant and "enabled" or "disabled"))

    elseif msg == "taxi" then
        AutoDismountDB.onTaxi = not AutoDismountDB.onTaxi
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r Taxi trigger " ..
            (AutoDismountDB.onTaxi and "enabled" or "disabled"))

    elseif msg == "npc" then
        AutoDismountDB.onNpcTarget = not AutoDismountDB.onNpcTarget
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r NPC target trigger " ..
            (AutoDismountDB.onNpcTarget and "enabled" or "disabled"))

    elseif msg == "error" then
        AutoDismountDB.onError = not AutoDismountDB.onError
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r Error trigger " ..
            (AutoDismountDB.onError and "enabled" or "disabled"))

    elseif msg == "forms" then
        AutoDismountDB.cancelForms = not AutoDismountDB.cancelForms
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r Cancel forms " ..
            (AutoDismountDB.cancelForms and "enabled" or "disabled"))

    elseif msg == "debug" then
        AutoDismountDB.debug = not AutoDismountDB.debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount:|r Debug " ..
            (AutoDismountDB.debug and "enabled" or "disabled"))

    elseif msg == "test" then
        DismountAndUnshift(true)

    elseif msg == "scan" then
        AutoDismount_Scan()

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoDismount|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad toggle|r - Enable/disable the addon")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad merchant|r - Toggle trigger at merchants")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad taxi|r - Toggle trigger at taxi map")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad npc|r - Toggle trigger when targeting NPCs")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad error|r - Toggle trigger on interaction errors (mining)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad forms|r - Toggle shapeshift cancellation")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad debug|r - Toggle debug messages")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad test|r - Trigger manually")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700/ad scan|r - List buffs + cached form")
    end
end
