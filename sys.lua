--[[
    ╔══════════════════════════════════════════╗
    ║      SPECTRE HUB - MAIN LOADER           ║
    ║   Direct Firestore Version               ║
    ╚══════════════════════════════════════════╝
    
    ไฟล์นี้จะถูก load จาก GitHub
    ทำหน้าที่ตรวจสอบ License แล้วรัน Script หลัก
]]

-- ============================================
-- CONFIGURATION (แก้ไขตรงนี้)
-- ============================================
local CONFIG = {
    PROJECT_ID = "oxgauth",  -- Firebase Project ID
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

-- Check if date is expired (check at END of day, same as web dashboard)
local function isExpired(expiryDate)
    if not expiryDate then return false end
    
    local y, m, d = expiryDate:match("(%d+)-(%d+)-(%d+)")
    if not y then return false end
    
    -- Check at END of day (23:59:59) to match web dashboard
    local expiryTime = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 23,
        min = 59,
        sec = 59
    })
    
    return os.time() > expiryTime
end

-- Validate License
local function validateLicense()
    local hwid = getHWID()
    local url = string.format(
        "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/licenseKeys",
        CONFIG.PROJECT_ID
    )
    
    local success, response = pcall(function()
        return reqFunc({
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" }
        })
    end)
    
    if not success or response.StatusCode ~= 200 then
        return false, "CONNECTION_ERROR", "Failed to connect to server"
    end
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    
    if not ok or not data.documents then
        return false, "PARSE_ERROR", "Invalid response"
    end
    
    -- Find license
    for _, doc in pairs(data.documents) do
        local fields = doc.fields
        if fields and fields.key and fields.key.stringValue == LICENSE_KEY then
            
            -- Check active
            local isActive = not fields.active or fields.active.booleanValue ~= false
            if not isActive then
                return false, "DEACTIVATED", "License deactivated"
            end
            
            -- Check expiry (FIXED: uses END of day check)
            local expiryDate = fields.expiryDate and fields.expiryDate.stringValue
            
            -- DEBUG: Show expiry info
            print("[DEBUG] Expiry Date from DB:", expiryDate or "nil")
            print("[DEBUG] Current Time (os.time):", os.time())
            
            if expiryDate then
                local y, m, d = expiryDate:match("(%d+)-(%d+)-(%d+)")
                if y then
                    local expiryTime = os.time({
                        year = tonumber(y),
                        month = tonumber(m),
                        day = tonumber(d),
                        hour = 23,
                        min = 59,
                        sec = 59
                    })
                    print("[DEBUG] Expiry Time (end of day):", expiryTime)
                    print("[DEBUG] Is Expired?:", os.time() > expiryTime)
                    
                    if os.time() > expiryTime then
                        return false, "EXPIRED", "License expired on " .. expiryDate
                    end
                end
            end
            
            -- Check HWID
            local storedHwid = fields.hwid and fields.hwid.stringValue
            if storedHwid and storedHwid ~= "" and storedHwid ~= hwid then
                return false, "HWID_MISMATCH", "Device not authorized"
            end
            
            -- Bind HWID if not bound
            if not storedHwid or storedHwid == "" then
                pcall(function()
                    reqFunc({
                        Url = "https://firestore.googleapis.com/v1/" .. doc.name .. "?updateMask.fieldPaths=hwid",
                        Method = "PATCH",
                        Headers = { ["Content-Type"] = "application/json" },
                        Body = HttpService:JSONEncode({
                            fields = { hwid = { stringValue = hwid } }
                        })
                    })
                end)
            end
            
            return true, "VALID", expiryDate or "Never"
        end
    end
    
    return false, "NOT_FOUND", "Invalid license key"
end

-- ============================================
-- MAIN
-- ============================================

print("")
print("╔═══════════════════════════════════════╗")
print("║        SPECTRE HUB v3.1               ║")
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
