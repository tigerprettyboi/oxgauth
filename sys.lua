--[[
    ╔══════════════════════════════════════════╗
    ║      SPECTRE HUB - MAIN LOADER           ║
    ║   Secure Version with API Secret         ║
    ╚══════════════════════════════════════════╝
    
    ไฟล์นี้จะถูก load จาก GitHub
    ทำหน้าที่ตรวจสอบ License แล้วรัน Script หลัก
]]

-- ============================================
-- CONFIGURATION (แก้ไขตรงนี้)
-- ============================================
local CONFIG = {
    API_URL = "https://oxgauth.web.app/api.html",
    API_SECRET = "s913919191319252121",  -- ต้องตรงกับใน Firebase config/api
    MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/tigerprettyboi/spectrehub/refs/heads/main/loader.lua"
}

-- ============================================
-- DO NOT MODIFY BELOW
-- ============================================

local HttpService = game:GetService("HttpService")
local reqFunc = request or http_request or (syn and syn.request) or (http and http.request)

if not reqFunc then
    warn("[SPECTRE] HTTP request function not available")
    return
end

-- Get License Key from getgenv()
local LICENSE_KEY = getgenv().Key

if not LICENSE_KEY or LICENSE_KEY == "" then
    warn("[SPECTRE] No license key provided!")
    warn("[SPECTRE] Usage: getgenv().Key = 'YOUR-KEY' before loading")
    return
end

-- Get HWID
local function getHWID()
    if gethwid then
        local ok, hwid = pcall(gethwid)
        if ok and hwid then return hwid end
    end
    
    local ok, hwid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and hwid then return hwid end
    
    return "fallback-" .. tostring(game.PlaceId) .. "-" .. tostring(game.JobId):sub(1, 8)
end

-- URL Encode
local function urlEncode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w _%%%-%.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- Validate License via Web API
local function validateLicense()
    local hwid = getHWID()
    
    local url = string.format(
        "%s?key=%s&hwid=%s&secret=%s",
        CONFIG.API_URL,
        urlEncode(LICENSE_KEY),
        urlEncode(hwid),
        urlEncode(CONFIG.API_SECRET)
    )
    
    local success, response = pcall(function()
        return reqFunc({
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" }
        })
    end)
    
    if not success then
        return false, "CONNECTION_ERROR", "Failed to connect to server"
    end
    
    if response.StatusCode ~= 200 then
        return false, "SERVER_ERROR", "Server returned " .. tostring(response.StatusCode)
    end
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    
    if not ok or not data then
        return false, "PARSE_ERROR", "Invalid server response"
    end
    
    if data.valid then
        return true, "VALID", data.expiresAt or "Never"
    else
        return false, data.error or "UNKNOWN", data.message or "Validation failed"
    end
end

-- ============================================
-- MAIN
-- ============================================

print("")
print("╔═══════════════════════════════════════╗")
print("║        SPECTRE HUB v3.0 SECURE        ║")
print("╠═══════════════════════════════════════╣")
print("║  Validating license...                ║")
print("╚═══════════════════════════════════════╝")
print("")

local valid, code, info = validateLicense()

if valid then
    print("  [✓] License: VALID")
    print("  [✓] Expires: " .. tostring(info))
    print("  [✓] Loading script...")
    print("")
    
    -- Load main script
    local success, err = pcall(function()
        loadstring(game:HttpGet(CONFIG.MAIN_SCRIPT_URL))()
    end)
    
    if not success then
        warn("  [✗] Failed to load script: " .. tostring(err))
    end
else
    warn("  [✗] License: DENIED")
    warn("  [✗] Code: " .. tostring(code))
    warn("  [✗] Reason: " .. tostring(info))
    warn("")
    warn("  Get a license at: https://discord.gg/Ds4ZygS8gj ")
end
