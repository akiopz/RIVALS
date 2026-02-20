---@diagnostic disable: undefined-global
-- modules/ui/gui.lua
-- Implements the custom GUI for the exploit using ScreenGui (Safer than Drawing API).

if not getgenv().Rivals_Config_Instance and getgenv().RivalsLoad then
    getgenv().Rivals_Config_Instance = getgenv().RivalsLoad("modules/utils/config.lua")
end
local Config = getgenv().Rivals_Config_Instance
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

if not Config then
    warn("[GUI] Config not found!")
    return {}
end

local UserInputService = Common.GetSafeService("UserInputService")
local Players = Common.GetSafeService("Players")
local CoreGui = Common.GetSafeService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local GUI = {}
local guiElements = {}
local isGuiVisible = true

-- Create ScreenGui with Randomized Name (Anti-Detection)
local function randomString(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local str = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        str = str .. string.sub(chars, rand, rand)
    end
    return str
end

local screenGuiName = randomString(math.random(10, 20))
local screenGui = Instance.new("ScreenGui")
screenGui.Name = screenGuiName
screenGui.ResetOnSpawn = false

-- Apply Protection
Common.ProtectGui(screenGui)

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 400)
mainFrame.Position = UDim2.new(0, 100, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.Active = true
mainFrame.Draggable = true -- Built-in draggable property
mainFrame.Parent = screenGui

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Rivals V5"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

-- Container for toggles
local toggleContainer = Instance.new("Frame")
toggleContainer.Name = "Container"
toggleContainer.Size = UDim2.new(1, -20, 1, -40)
toggleContainer.Position = UDim2.new(0, 10, 0, 40)
toggleContainer.BackgroundTransparency = 1
toggleContainer.Parent = mainFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = toggleContainer
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 5)

-- Cleanup function
table.insert(getgenv().Rivals_Cleanup_Functions, function()
    if screenGui then pcall(function() screenGui:Destroy() end) end
end)

-- Function to add toggle
function GUI.AddToggle(label, configGroup, configKey, callback)
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = label
    toggleButton.Size = UDim2.new(1, 0, 0, 30)
    toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = ""
    toggleButton.AutoButtonColor = false
    toggleButton.Parent = toggleContainer

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -40, 1, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = label
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = toggleButton

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 30, 1, 0)
    statusLabel.Position = UDim2.new(1, -35, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.Parent = toggleButton

    local function updateStatus()
        local isEnabled = false
        if Config[configGroup] and Config[configGroup][configKey] then
            isEnabled = true
        end

        if isEnabled then
            statusLabel.Text = "ON"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            statusLabel.Text = "OFF"
            statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end

    -- Register updater for external refresh
    guiElements[configGroup .. "." .. configKey] = updateStatus

    toggleButton.MouseButton1Click:Connect(function()
        if Config[configGroup] then
            Config[configGroup][configKey] = not Config[configGroup][configKey]
            updateStatus()
            if callback then callback(Config[configGroup][configKey]) end
        end
    end)

    updateStatus()
end

function GUI.Refresh()
    for _, updateFunc in pairs(guiElements) do
        updateFunc()
    end
end

function GUI.Update(dt)
    -- No update loop needed for ScreenGui
end

function GUI.Init()
    -- Function to add cycle button (for Enums like AimMethod)
    function GUI.AddCycle(label, configGroup, configKey, options)
        local button = Instance.new("TextButton")
        button.Name = label
        button.Size = UDim2.new(1, 0, 0, 30)
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.Parent = toggleContainer
    
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, -10, 1, 0)
        textLabel.Position = UDim2.new(0, 10, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = label .. ": " .. tostring(Config[configGroup][configKey])
        textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        textLabel.TextSize = 14
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.Parent = button
    
        button.MouseButton1Click:Connect(function()
            if Config[configGroup] then
                local current = Config[configGroup][configKey]
                local currentIndex = 1
                for i, v in ipairs(options) do
                    if v == current then
                        currentIndex = i
                        break
                    end
                end
                
                local nextIndex = currentIndex + 1
                if nextIndex > #options then nextIndex = 1 end
                
                Config[configGroup][configKey] = options[nextIndex]
                textLabel.Text = label .. ": " .. tostring(Config[configGroup][configKey])
            end
        end)
    end

    GUI.AddToggle("Master Switch", "Main", "Enabled")
    GUI.AddToggle("Aimbot", "Aimbot", "Enabled")
    GUI.AddCycle("Aim Method", "Aimbot", "AimMethod", {"Mouse", "Camera"}) -- Added Cycle
    GUI.AddToggle("TriggerBot", "TriggerBot", "Enabled") -- Added TriggerBot
    GUI.AddToggle("Silent Aim", "SilentAim", "Enabled")
    GUI.AddToggle("Hitbox Expander", "HitboxExpander", "Enabled") -- Added Hitbox Expander
    GUI.AddCycle("Hitbox Size", "HitboxExpander", "Size", {2, 5, 10, 15, 20}) -- Added Hitbox Size
    GUI.AddToggle("Anti-Aim", "AntiAim", "Enabled", function(enabled)
        if enabled then
            -- Force enable Rage features when Anti-Aim is ON
            Config.Aimbot.Enabled = true
            Config.Aimbot.TargetPart = "Head"
            Config.TriggerBot.Enabled = true
            GUI.Refresh()
        end
    end) -- Renamed to generic Anti-Aim
    GUI.AddCycle("AA Yaw", "AntiAim", "Type", {"Spin", "Jitter", "Backward"}) -- Added Yaw Mode
    GUI.AddCycle("AA Pitch", "AntiAim", "Pitch", {"None", "Down", "Up", "Jitter"}) -- Added Pitch Mode
    GUI.AddToggle("ESP Master", "ESP", "Enabled")
    GUI.AddToggle("ESP Box", "ESP", "Boxes")
    GUI.AddToggle("ESP Name", "ESP", "Names")
    GUI.AddToggle("ESP Health", "ESP", "Health")
    GUI.AddToggle("ESP Skeleton", "ESP", "Skeleton")
    GUI.AddToggle("Team Check", "ESP", "TeamCheck")
    GUI.AddToggle("Crosshair", "World", "Crosshair")

    -- Input handling for toggling menu visibility
    table.insert(getgenv().Rivals_Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Config.GUI.Key then
            isGuiVisible = not isGuiVisible
            mainFrame.Visible = isGuiVisible
        end
    end))
end

return GUI
