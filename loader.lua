---@diagnostic disable: deprecated
---@diagnostic disable: undefined-global
---@diagnostic disable: param-type-mismatch
-- loader.lua
-- This script is responsible for downloading modules.json and then loading the main script.

getgenv().GITHUB_RAW_URL = "https://raw.githubusercontent.com/akiopz/RIVALS/main/"

local function loadScript()
    local success, modulesJsonContent = pcall(function()
        return game:HttpGet(GITHUB_RAW_URL .. "modules.json", true)
    end)

    -- If GitHub fetch fails, try local file
    if not success or not modulesJsonContent then
        if isfile and isfile("modules.json") then
            warn("[Rivals Loader] Failed to fetch from GitHub, trying local file...")
            success, modulesJsonContent = pcall(readfile, "modules.json")
        end
    end

    if not success or not modulesJsonContent then
        warn("[Rivals Loader] Failed to download/read modules.json: " .. tostring(modulesJsonContent))
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals V5 Loader",
            Text = "無法下載模組配置！",
            Duration = 5,
            Icon = "rbxassetid://6675147490"
        })
        return
    end

    local modulesData = game:GetService("HttpService"):JSONDecode(modulesJsonContent)
    if not modulesData or not modulesData.mainScript then
        warn("[Rivals Loader] Invalid modules.json format.")
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals V5 Loader",
            Text = "模組配置格式錯誤！",
            Duration = 5,
            Icon = "rbxassetid://6675147490"
        })
        return
    end

    -- Download and execute the main script
    local mainScript = modulesData.mainScript
    local scriptContent
    local scriptSuccess

    -- Try local file first
    if isfile and isfile(mainScript) then
        scriptSuccess, scriptContent = pcall(readfile, mainScript)
    end

    -- If local fails, try GitHub
    if not scriptSuccess then
        local mainScriptUrl = GITHUB_RAW_URL .. mainScript
        scriptSuccess, scriptContent = pcall(function()
            return game:HttpGet(mainScriptUrl, true)
        end)
    end

    if not scriptSuccess or not scriptContent then
        warn("[Rivals Loader] Failed to download/read main script: " .. tostring(scriptContent))
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals V5 Loader",
            Text = "無法下載主腳本！",
            Duration = 5,
            Icon = "rbxassetid://6675147490"
        })
        return
    end

    -- Load and execute the main script
    local loadSuccess, loadResult = pcall(loadstring(scriptContent))
    if not loadSuccess then
        warn("[Rivals Loader] Error executing main script: " .. tostring(loadResult))
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals V5 Loader",
            Text = "主腳本執行錯誤！",
            Duration = 5,
            Icon = "rbxassetid://6675147490"
        })
    end
end

loadScript()
