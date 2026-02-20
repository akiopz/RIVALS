---@diagnostic disable: deprecated
---@diagnostic disable: undefined-global
---@diagnostic disable: param-type-mismatch
---@diagnostic disable: inject-field
---@diagnostic disable: undefined-field
---@diagnostic disable: lowercase-global
-- Rivals V5 Loader (Enhanced)
-- [Secure] [Fast] [Reliable]

local function Bootstrap()
    -- 1. [Environment Check]
    if not getgenv then
        -- Polyfill for executors without getgenv (e.g. some mobile executors)
        getgenv = function() return _G end
    end

    -- 2. [Setup Global Config]
    getgenv().GITHUB_RAW_URL = "https://raw.githubusercontent.com/akiopz/RIVALS/main/"
    
    -- 3. [Secure HTTP Get]
    local function SecureGet(url)
        local content = nil
        local success = false
        
        -- Try request() (Standard / Electron / Synapse)
        if request or http_request or (syn and syn.request) then
            local reqFunc = request or http_request or (syn and syn.request)
            local response = reqFunc({
                Url = url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "Roblox/WinInet", -- Mimic Roblox
                    ["Cache-Control"] = "no-cache"
                }
            })
            if response and response.Body then
                content = response.Body
                success = true
            end
        end
        
        -- Fallback to game:HttpGet
        if not success then
            success, content = pcall(function()
                return game:HttpGet(url, true)
            end)
        end
        
        return success, content
    end

    -- 4. [Load Configuration]
    local configUrl = getgenv().GITHUB_RAW_URL .. "modules.json"
    local success, modulesJsonContent = SecureGet(configUrl)

    -- [Fallback] Try local file if network fails
    if not success or not modulesJsonContent then
        if isfile and isfile("modules.json") then
            success, modulesJsonContent = pcall(readfile, "modules.json")
        end
    end

    if not success or not modulesJsonContent then
        warn("[Loader] Failed to fetch config.")
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals Loader",
            Text = "無法連接伺服器 (Config Error)",
            Duration = 5
        })
        return
    end

    -- 5. [Parse Config]
    local HttpService = game:GetService("HttpService")
    local modulesData = HttpService:JSONDecode(modulesJsonContent)
    
    if not modulesData or not modulesData.mainScript then
        warn("[Loader] Invalid config.")
        return
    end

    -- 6. [Load Main Script]
    local mainScriptPath = modulesData.mainScript
    local scriptContent
    local scriptSuccess = false

    -- Try local first (Development Mode)
    if isfile and isfile(mainScriptPath) then
        scriptSuccess, scriptContent = pcall(readfile, mainScriptPath)
    end

    -- Try Remote
    if not scriptSuccess then
        local mainScriptUrl = getgenv().GITHUB_RAW_URL .. mainScriptPath
        scriptSuccess, scriptContent = SecureGet(mainScriptUrl)
    end

    if not scriptSuccess or not scriptContent then
        warn("[Loader] Failed to fetch core.")
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals Loader",
            Text = "核心腳本下載失敗!",
            Duration = 5
        })
        return
    end

    -- 7. [Execute Core]
    local chunk, err = loadstring(scriptContent)
    if not chunk then
        warn("[Loader] Syntax Error: " .. tostring(err))
        return
    end

    task.spawn(chunk)
    
    -- 8. [Self Cleanup]
    -- Remove the bootstrap function from memory if possible (Lua handles this via GC)
end

-- Run Bootstrap safely
local success, err = pcall(Bootstrap)
if not success then
    warn("[Loader] Fatal Error: " .. tostring(err))
end
