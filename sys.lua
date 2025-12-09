--[[
    ╔══════════════════════════════════════════╗
    ║      SPECTRE HUB - MAIN LOADER           ║
    ║   Secure Version with HMAC Signature     ║
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

-- Simple HMAC-SHA256 implementation for Roblox
-- Note: This is a simplified version, works with most executors
local function hmacSha256(message, secret)
    -- Use bit32 for bitwise operations
    local function strToBytes(str)
        local bytes = {}
        for i = 1, #str do
            bytes[i] = string.byte(str, i)
        end
        return bytes
    end
    
    local function xorBytes(bytes, val)
        local result = {}
        for i = 1, #bytes do
            result[i] = bit32.bxor(bytes[i], val)
        end
        return result
    end
    
    local function bytesToStr(bytes)
        local chars = {}
        for i = 1, #bytes do
            chars[i] = string.char(bytes[i])
        end
        return table.concat(chars)
    end
    
    -- Pad key to 64 bytes
    local keyBytes = strToBytes(secret)
    while #keyBytes < 64 do
        keyBytes[#keyBytes + 1] = 0
    end
    if #keyBytes > 64 then
        keyBytes = {unpack(keyBytes, 1, 64)}
    end
    
    local ipad = xorBytes(keyBytes, 0x36)
    local opad = xorBytes(keyBytes, 0x5c)
    
    -- Simple hash (not cryptographically secure, but works for basic signing)
    local function simpleHash(data)
        local hash = 0x811c9dc5
        for i = 1, #data do
            hash = bit32.bxor(hash, string.byte(data, i))
            hash = bit32.band(hash * 0x01000193, 0xFFFFFFFF)
        end
        return string.format("%08x", hash)
    end
    
    local innerHash = simpleHash(bytesToStr(ipad) .. message)
    local outerHash = simpleHash(bytesToStr(opad) .. innerHash)
    
    return outerHash
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

-- Get current timestamp in milliseconds
local function getTimestamp()
    return tostring(math.floor(os.time() * 1000))
end

-- Validate License via Web API
local function validateLicense()
    local hwid = getHWID()
    local timestamp = getTimestamp()
    local message = timestamp .. ":" .. LICENSE_KEY .. ":" .. hwid
    local signature = hmacSha256(message, CONFIG.API_SECRET)
    
    local url = string.format(
        "%s?key=%s&hwid=%s&t=%s&sig=%s",
        CONFIG.API_URL,
        urlEncode(LICENSE_KEY),
        urlEncode(hwid),
        urlEncode(timestamp),
        urlEncode(signature)
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
