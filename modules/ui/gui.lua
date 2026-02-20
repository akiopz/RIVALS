---@diagnostic disable: undefined-global
-- modules/ui/gui.lua
-- High Performance, Tabbed GUI for Rivals V5

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
local currentTab = "Legit" -- Default Tab

-- Theme
local Theme = {
    Background = Color3.fromRGB(25, 25, 25),
    DarkBackground = Color3.fromRGB(20, 20, 20),
    Accent = Color3.fromRGB(0, 120, 215), -- Windows Blue
    Text = Color3.fromRGB(240, 240, 240),
    TextDim = Color3.fromRGB(180, 180, 180),
    Border = Color3.fromRGB(45, 45, 45)
}

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
screenGui.IgnoreGuiInset = true -- Fullscreen coverage if needed

-- Apply Protection
Common.ProtectGui(screenGui)

-- Cleanup function
if not getgenv().Rivals_Cleanup_Functions then getgenv().Rivals_Cleanup_Functions = {} end
table.insert(getgenv().Rivals_Cleanup_Functions, function()
    if screenGui then pcall(function() screenGui:Destroy() end) end
end)

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 500, 0, 350)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -175) -- Center
mainFrame.BackgroundColor3 = Theme.Background
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Theme.Border
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Rounded Corners
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent = mainFrame

-- Title Bar
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -20, 0, 40)
titleLabel.Position = UDim2.new(0, 20, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "RIVALS V5"
titleLabel.TextColor3 = Theme.Text
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Tab Container
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(0, 120, 1, -50)
tabContainer.Position = UDim2.new(0, 10, 0, 45)
tabContainer.BackgroundColor3 = Theme.DarkBackground
tabContainer.BorderSizePixel = 0
tabContainer.Parent = mainFrame

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 4)
tabCorner.Parent = tabContainer

local tabListLayout = Instance.new("UIListLayout")
tabListLayout.Parent = tabContainer
tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabListLayout.Padding = UDim.new(0, 5)

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingTop = UDim.new(0, 10)
tabPadding.PaddingLeft = UDim.new(0, 5)
tabPadding.PaddingRight = UDim.new(0, 5)
tabPadding.Parent = tabContainer

-- Content Container
local contentContainer = Instance.new("Frame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, -145, 1, -50)
contentContainer.Position = UDim2.new(0, 140, 0, 45)
contentContainer.BackgroundColor3 = Theme.DarkBackground
contentContainer.BorderSizePixel = 0
contentContainer.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 4)
contentCorner.Parent = contentContainer

-- Toggle GUI Keybind (Insert)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Insert then
        isGuiVisible = not isGuiVisible
        mainFrame.Visible = isGuiVisible
    end
end)

-- Helper Functions
local tabs = {}
local pages = {}

function GUI.CreateTab(name)
    -- Tab Button
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(1, 0, 0, 30)
    tabButton.BackgroundColor3 = Theme.Background
    tabButton.Text = name
    tabButton.TextColor3 = Theme.TextDim
    tabButton.TextSize = 12
    tabButton.Font = Enum.Font.GothamSemibold
    tabButton.AutoButtonColor = false
    tabButton.Parent = tabContainer

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = tabButton

    -- Tab Page
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.Visible = false
    page.Parent = contentContainer
    
    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Parent = page
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 5)
    
    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 10)
    pagePadding.PaddingLeft = UDim.new(0, 10)
    pagePadding.PaddingRight = UDim.new(0, 10)
    pagePadding.Parent = page

    tabs[name] = tabButton
    pages[name] = page

    tabButton.MouseButton1Click:Connect(function()
        -- Update UI for Tab Switch
        for tName, btn in pairs(tabs) do
            if tName == name then
                btn.TextColor3 = Theme.Text
                btn.BackgroundColor3 = Theme.Accent
                pages[tName].Visible = true
            else
                btn.TextColor3 = Theme.TextDim
                btn.BackgroundColor3 = Theme.Background
                pages[tName].Visible = false
            end
        end
        currentTab = name
    end)

    -- Select first tab by default
    if currentTab == name then
        tabButton.TextColor3 = Theme.Text
        tabButton.BackgroundColor3 = Theme.Accent
        page.Visible = true
    end

    return page
end

function GUI.AddToggle(page, label, configGroup, configKey, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 30)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = page

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 20, 0, 20)
    button.Position = UDim2.new(0, 0, 0.5, -10)
    button.BackgroundColor3 = Theme.Background
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = toggleFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(1, -6, 1, -6)
    indicator.Position = UDim2.new(0, 3, 0, 3)
    indicator.BackgroundColor3 = Theme.Accent
    indicator.BackgroundTransparency = 1 -- Hidden by default
    indicator.Parent = button

    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(0, 2)
    indCorner.Parent = indicator

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -30, 1, 0)
    text.Position = UDim2.new(0, 30, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = label
    text.TextColor3 = Theme.Text
    text.TextSize = 12
    text.Font = Enum.Font.Gotham
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = toggleFrame

    local function update()
        local state = false
        if Config[configGroup] and Config[configGroup][configKey] then
            state = Config[configGroup][configKey]
        end
        
        if state then
            indicator.BackgroundTransparency = 0
        else
            indicator.BackgroundTransparency = 1
        end
    end

    button.MouseButton1Click:Connect(function()
        if Config[configGroup] then
            Config[configGroup][configKey] = not Config[configGroup][configKey]
            update()
            if callback then callback(Config[configGroup][configKey]) end
        end
    end)

    update()
    return toggleFrame
end

function GUI.AddSlider(page, label, configGroup, configKey, min, max, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 45)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = page

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 0, 20)
    text.BackgroundTransparency = 1
    text.Text = label
    text.TextColor3 = Theme.Text
    text.TextSize = 12
    text.Font = Enum.Font.Gotham
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = sliderFrame
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -50, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(Config[configGroup][configKey] or min)
    valueLabel.TextColor3 = Theme.TextDim
    valueLabel.TextSize = 12
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = sliderFrame

    local sliderBg = Instance.new("TextButton") -- Button for interaction
    sliderBg.Size = UDim2.new(1, 0, 0, 6)
    sliderBg.Position = UDim2.new(0, 0, 0, 30)
    sliderBg.BackgroundColor3 = Theme.Background
    sliderBg.Text = ""
    sliderBg.AutoButtonColor = false
    sliderBg.Parent = sliderFrame

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local dragging = false

    local function update(input)
        local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + ((max - min) * pos))
        
        -- Update Config
        Config[configGroup][configKey] = value
        
        -- Update UI
        fill.Size = UDim2.new(pos, 0, 1, 0)
        valueLabel.Text = tostring(value)
        
        if callback then callback(value) end
    end
    
    -- Set Initial State
    local current = Config[configGroup][configKey] or min
    local startPos = (current - min) / (max - min)
    fill.Size = UDim2.new(startPos, 0, 1, 0)
    valueLabel.Text = tostring(current)

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
end

function GUI.AddSection(page, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Theme.Accent
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = page
end

-- Initialize GUI
function GUI.Init()
    -- Tab: Legit
    local legitPage = GUI.CreateTab("Legit")
    
    GUI.AddSection(legitPage, "Aimbot")
    GUI.AddToggle(legitPage, "Enable Aimbot", "Aimbot", "Enabled")
    GUI.AddToggle(legitPage, "Show FOV", "Aimbot", "ShowFOV")
    GUI.AddSlider(legitPage, "FOV Size", "Aimbot", "FOV", 10, 500)
    GUI.AddSlider(legitPage, "Smoothness", "Aimbot", "Smoothing", 0, 20)
    
    GUI.AddSection(legitPage, "Silent Aim")
    GUI.AddToggle(legitPage, "Enable Silent Aim", "SilentAim", "Enabled")
    GUI.AddSlider(legitPage, "Hit Chance", "SilentAim", "HitChance", 0, 100)
    
    GUI.AddSection(legitPage, "TriggerBot")
    GUI.AddToggle(legitPage, "Enable TriggerBot", "TriggerBot", "Enabled")
    GUI.AddSlider(legitPage, "Delay (ms)", "TriggerBot", "Delay", 0, 500)

    GUI.AddSection(legitPage, "Hitbox Expander")
    GUI.AddToggle(legitPage, "Enable Expander", "HitboxExpander", "Enabled")
    GUI.AddSlider(legitPage, "Size", "HitboxExpander", "Size", 1, 20)

    -- Tab: Visuals
    local visualsPage = GUI.CreateTab("Visuals")
    
    GUI.AddSection(visualsPage, "ESP")
    GUI.AddToggle(visualsPage, "Enable ESP", "ESP", "Enabled")
    GUI.AddToggle(visualsPage, "Boxes", "ESP", "Boxes")
    GUI.AddToggle(visualsPage, "Names", "ESP", "Names")
    GUI.AddToggle(visualsPage, "Health Bar", "ESP", "Health")
    GUI.AddToggle(visualsPage, "Team Check", "ESP", "TeamCheck")

    -- Tab: Misc
    local miscPage = GUI.CreateTab("Misc")

    GUI.AddSection(miscPage, "Anti-Aim")
    GUI.AddToggle(miscPage, "Enable Anti-Aim", "AntiAim", "Enabled")
    GUI.AddSlider(miscPage, "Spin Speed", "AntiAim", "SpinSpeed", 1, 100)
    
    GUI.AddSection(miscPage, "Settings")
    GUI.AddToggle(miscPage, "Main Switch", "Main", "Enabled")
end

function GUI.Update(dt)
    -- Placeholder
end

return GUI