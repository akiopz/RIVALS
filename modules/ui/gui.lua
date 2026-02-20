---@diagnostic disable: undefined-global
-- modules/ui/gui.lua
-- Implements the custom GUI for the exploit.

local Config = getgenv().Rivals_Config_Instance or getgenv().RivalsLoad("modules/utils/config.lua")

local UserInputService = game:GetService("UserInputService")
local Drawing = Drawing or getgenv().Drawing -- Ensure Drawing library is available

local GUI = {}

local guiElements = {}
local isGuiVisible = true -- Default to visible
local isDragging = false
local dragOffset = Vector2.new(0, 0)
local guiPosition = Vector2.new(100, 100)
local guiSize = Vector2.new(250, 400)

-- Main GUI window drawing
local guiBackground = Drawing.new("Square")
guiBackground.Visible = false
guiBackground.Color = Color3.fromRGB(30, 30, 30)
guiBackground.Thickness = 1
guiBackground.Filled = true
guiBackground.ZIndex = 100

local guiBorder = Drawing.new("Square")
guiBorder.Visible = false
guiBorder.Color = Color3.fromRGB(50, 50, 50)
guiBorder.Thickness = 2
guiBorder.Filled = false
guiBorder.ZIndex = 101

local guiTitle = Drawing.new("Text")
guiTitle.Visible = false
guiTitle.Color = Color3.fromRGB(255, 255, 255)
guiTitle.Text = "Rivals V5"
guiTitle.Size = 18
guiTitle.Center = true
guiTitle.ZIndex = 102

-- Cleanup function for GUI elements
table.insert(getgenv().Rivals_Cleanup_Functions, function()
    if guiBackground then pcall(function() guiBackground:Remove() end) end
    if guiBorder then pcall(function() guiBorder:Remove() end) end
    if guiTitle then pcall(function() guiTitle:Remove() end) end
    for _, element in pairs(guiElements) do
        if element.drawing then pcall(function() element.drawing:Remove() end) end
    end
    guiElements = {}
end)

-- Function to update GUI element positions
local function updateGuiElements()
    guiBackground.Position = guiPosition
    guiBackground.Size = guiSize
    guiBorder.Position = guiPosition
    guiBorder.Size = guiSize
    guiTitle.Position = guiPosition + Vector2.new(guiSize.X / 2, 10)

    local currentY = guiPosition.Y + 40 -- Start below title

    for _, element in pairs(guiElements) do
        if element.type == "toggle" then
            element.drawing.Position = Vector2.new(guiPosition.X + 10, currentY)
            element.drawing.Text = element.label .. ": " .. (Config[element.configGroup][element.configKey] and "開啟" or "關閉")
            element.drawing.Visible = isGuiVisible
            currentY = currentY + 20
        end
        -- Add other element types here (sliders, buttons, etc.)
    end
end

-- Input handling for GUI
local function onInputBegan(input, gameProcessedEvent)
    if gameProcessedEvent then return end

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.GUI.Key then
        isGuiVisible = not isGuiVisible
        guiBackground.Visible = isGuiVisible
        guiBorder.Visible = isGuiVisible
        guiTitle.Visible = isGuiVisible
        updateGuiElements()
    end

    if isGuiVisible and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = UserInputService:GetMouseLocation()
        if mousePos.X >= guiPosition.X and mousePos.X <= guiPosition.X + guiSize.X and
           mousePos.Y >= guiPosition.Y and mousePos.Y <= guiPosition.Y + 30 then -- Title bar area
            isDragging = true
            dragOffset = mousePos - guiPosition
        else
            -- Check for clicks on toggle buttons
            local currentY = guiPosition.Y + 40
            for _, element in pairs(guiElements) do
                if element.type == "toggle" then
                    local toggleRect = {
                        X = guiPosition.X + 10,
                        Y = currentY,
                        Width = guiSize.X - 20,
                        Height = 20
                    }
                    if mousePos.X >= toggleRect.X and mousePos.X <= toggleRect.X + toggleRect.Width and
                       mousePos.Y >= toggleRect.Y and mousePos.Y <= toggleRect.Y + toggleRect.Height then
                        Config[element.configGroup][element.configKey] = not Config[element.configGroup][element.configKey]
                        updateGuiElements()
                        break
                    end
                    currentY = currentY + 20
                end
            end
        end
    end
end

local function onInputEnded(input, gameProcessedEvent)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = false
    end
end

local function onMouseMoved(input)
    if isDragging then
        local mousePos = UserInputService:GetMouseLocation()
        guiPosition = mousePos - dragOffset
        updateGuiElements()
    end
end

-- Add a toggle button to the GUI
function GUI.AddToggle(label, configGroup, configKey)
    local toggleDrawing = Drawing.new("Text")
    toggleDrawing.Visible = false
    toggleDrawing.Color = Color3.fromRGB(255, 255, 255)
    toggleDrawing.Size = 14
    toggleDrawing.Center = false
    toggleDrawing.ZIndex = 103
    
    table.insert(guiElements, {
        type = "toggle",
        label = label,
        configGroup = configGroup,
        configKey = configKey,
        drawing = toggleDrawing
    })
    -- updateGuiElements() -- Optimization: Don't update on every add
end

function GUI.Update(dt)
    -- No continuous update needed for GUI elements themselves,
    -- they are updated on interaction or visibility change.
end

function GUI.Init()
    -- Add initial toggles with delay to prevent detection
    local toggles = {
        {"總開關", "Main", "Enabled"},
        {"自瞄", "Aimbot", "Enabled"},
        {"靜默瞄準", "SilentAim", "Enabled"},
        {"方框透視", "ESP", "Boxes"},
        {"名稱透視", "ESP", "Names"},
        {"血條透視", "ESP", "Health"},
        {"骨骼透視", "ESP", "Skeleton"},
        {"隊友檢查", "ESP", "TeamCheck"},
        {"十字準星", "World", "Crosshair"}
    }

    for _, toggle in ipairs(toggles) do
        GUI.AddToggle(toggle[1], toggle[2], toggle[3])
        task.wait(0.05) -- Small delay between creating drawing objects
    end

    -- Ensure GUI is visible initially
    isGuiVisible = true
    guiBackground.Visible = true
    guiBorder.Visible = true
    guiTitle.Visible = true
    
    updateGuiElements() -- Initial update
    
    task.wait(0.5) -- Wait before enabling input

    -- Register input handlers
    table.insert(getgenv().Rivals_Connections, UserInputService.InputBegan:Connect(onInputBegan))
    table.insert(getgenv().Rivals_Connections, UserInputService.InputEnded:Connect(onInputEnded))
    table.insert(getgenv().Rivals_Connections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            onMouseMoved(input)
        end
    end))
end

return GUI
