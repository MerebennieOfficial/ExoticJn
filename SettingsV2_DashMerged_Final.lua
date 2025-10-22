-- Settings V2 + Dash Settings (full merged) 
-- Standalone LocalScript
-- Adjust (opens Dash Settings UI exactly like the script you provided)
-- Save button added (saves toggles + sliders to player attribute "SettingsV2")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- Basic settings used by the mini Adjust menu
local ARC_APPROACH_RADIUS = 8
local SPEED_SETTING = 0.8

-- Table to expose slider values from Dash Settings (populated by createDashPanel)
local Sliders = {}

-- cached saved settings (loaded from player attribute)
local savedSettings = nil
do
    local attr = player:GetAttribute("SettingsV2")
    if type(attr) == "string" then
        pcall(function()
            savedSettings = HttpService:JSONDecode(attr)
        end)
    end
end

-- helper: make frames draggable
local function makeDraggable(frame)
    local dragToggle, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragToggle = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragToggle and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                        startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- safe remote fire helper
local function safeFireCommunicate(argsTable)
    pcall(function()
        local ch = player.Character
        if ch and ch:FindFirstChild("Communicate") then
            ch.Communicate:FireServer(unpack(argsTable))
        end
    end)
end

-- create the main ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "SettingsGUI_Only_V2"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- small click sound used for button interactions
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6042053626"
clickSound.Volume = 0.7
clickSound.Parent = gui

-- Helper to create toggle-styled buttons used inside the grid
-- Now returns: btn, setState(state, runCallback)
-- setState(true/false, true) will optionally call the original callback
local function createToggleButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 15, 0, 15)
    circle.Position = UDim2.new(1, -24, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local toggled = false

    local function updateVisuals()
        circle.BackgroundColor3 = toggled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(180, 180, 180)
        btn.BackgroundColor3 = toggled and Color3.fromRGB(220,220,220) or Color3.fromRGB(245,245,245)
    end

    local function setState(state, runCallback)
        toggled = not not state
        updateVisuals()
        if runCallback and callback then
            pcall(function() callback(toggled) end)
        end
    end

    btn.MouseButton1Click:Connect(function()
        pcall(function() clickSound:Play() end)
        setState(not toggled, true)
    end)

    -- return setter so external code may set initial states
    return btn, setState
end

-- MAIN SETTINGS FRAME ---------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 280, 0, 270)
mainFrame.Position = UDim2.new(0.5, -140, 0.5, -135)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderSizePixel = 2
mainFrame.AnchorPoint = Vector2.new(0.5,0.5)
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

mainFrame.Visible = true
mainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
{Size = UDim2.new(0, 280, 0, 270)}):Play()

-- Title bar (now shows V2)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
title.BackgroundTransparency = 0
title.Text = "⚙️ Settings V2"
title.TextColor3 = Color3.fromRGB(0, 0, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)

-- Minimize button (collapses to the small miniFrame)
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 35, 0, 35)
minimizeBtn.Position = UDim2.new(1, -40, 0, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Text = "-"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextColor3 = Color3.fromRGB(0,0,0)
minimizeBtn.TextSize = 20
minimizeBtn.Parent = mainFrame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(1, 0)

-- Button holder (grid) for toggle/options
local buttonHolder = Instance.new("Frame")
buttonHolder.Size = UDim2.new(1, -20, 0, 90)
buttonHolder.Position = UDim2.new(0, 10, 0, 45)
buttonHolder.BackgroundTransparency = 1
buttonHolder.Parent = mainFrame

local UIGrid = Instance.new("UIGridLayout")
UIGrid.CellSize = UDim2.new(0.5, -10, 0, 35)
UIGrid.CellPadding = UDim2.new(0, 10, 0, 10)
UIGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIGrid.VerticalAlignment = Enum.VerticalAlignment.Top
UIGrid.Parent = buttonHolder

-- Toggle buttons / Save button
local m1Enabled = false
local espEnabled = false
local selectedPlayer = nil

-- M1 toggle: when turned on, fire the provided LeftClick payloads (once)
local m1Btn, m1SetState = createToggleButton("M1", function(state)
    m1Enabled = state
    if state then
        local args1 = {
            [1] = {
                ["Mobile"] = true,
                ["Goal"] = "LeftClick"
            }
        }
        safeFireCommunicate(args1)

        task.delay(0.05, function()
            local args2 = {
                [1] = {
                    ["Goal"] = "LeftClickRelease",
                    ["Mobile"] = true
                }
            }
            safeFireCommunicate(args2)
        end)
    end
end)
m1Btn.Parent = buttonHolder

-- Dash toggle (renamed from ESP). When turned on, fire the KeyPress payload
local espBtn, espSetState = createToggleButton("Dash", function(state)
    espEnabled = state
    if state then
        local args = {
            [1] = {
                ["Dash"] = Enum.KeyCode.W,
                ["Key"] = Enum.KeyCode.Q,
                ["Goal"] = "KeyPress"
            }
        }
        safeFireCommunicate(args)
    end
end)
espBtn.Parent = buttonHolder

-- SAVE button (replaces the old Skill2 toggle)
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0, 100, 0, 35)
saveBtn.BackgroundColor3 = Color3.fromRGB(180,180,180)
saveBtn.Text = "Save"
saveBtn.TextColor3 = Color3.fromRGB(0,0,0)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 14
saveBtn.AutoButtonColor = true
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0,8)
saveBtn.Parent = buttonHolder

saveBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    -- collect slider values (if available), otherwise nil
    local sliderValues = {}
    local titleLabels = {"Dash speed", "Dash Degrees", "Dash gap"}
    for _, name in ipairs(titleLabels) do
        local fn = Sliders[name]
        if type(fn) == "function" then
            sliderValues[name] = fn()
        else
            sliderValues[name] = nil
        end
    end

    local settings = {
        Dash = espEnabled or false,
        M1 = m1Enabled or false,
        Sliders = sliderValues,
        ARC_APPROACH_RADIUS = ARC_APPROACH_RADIUS,
        SPEED_SETTING = SPEED_SETTING,
    }

    local ok, encoded = pcall(function() return HttpService:JSONEncode(settings) end)
    if ok and encoded then
        pcall(function() player:SetAttribute("SettingsV2", encoded) end)
        -- brief feedback
        saveBtn.Text = "Saved"
        task.delay(0.9, function() pcall(function() saveBtn.Text = "Save" end) end)
    end
end)

-- PLAYER LIST (scrolling)
local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, -20, 0, 70)
playerList.Position = UDim2.new(0, 10, 0, 145)
playerList.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
playerList.ScrollBarThickness = 4
playerList.Parent = mainFrame
Instance.new("UICorner", playerList).CornerRadius = UDim.new(0, 8)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = playerList
UIListLayout.Padding = UDim.new(0, 2)

local function refreshPlayers()
    for _, child in ipairs(playerList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -5, 0, 22)
            btn.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
            btn.TextColor3 = Color3.fromRGB(0,0,0)
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.Text = "   " .. plr.Name
            btn.Parent = playerList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

            btn.MouseButton1Click:Connect(function()
                pcall(function() clickSound:Play() end)
                for _, b in ipairs(playerList:GetChildren()) do
                    if b:IsA("TextButton") then
                        b.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
                    end
                end
                btn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
                selectedPlayer = plr
                -- previous behavior cleared skill mode here; not needed anymore
            end)
        end
    end
end
refreshPlayers()

-- Refresh and Adjust buttons (styled to match image; Adjust is on bottom-left)
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 110, 0, 36)
refreshBtn.Position = UDim2.new(1, -122, 1, -44)
refreshBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 16
refreshBtn.Parent = mainFrame
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 12)

local adjustBtn = Instance.new("TextButton")
adjustBtn.Size = UDim2.new(0, 110, 0, 36)
adjustBtn.Position = UDim2.new(0, 12, 1, -44)
adjustBtn.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
adjustBtn.Text = "Adjust"
adjustBtn.TextColor3 = Color3.fromRGB(255,255,255)
adjustBtn.Font = Enum.Font.GothamBold
adjustBtn.TextSize = 16
adjustBtn.Parent = mainFrame
Instance.new("UICorner", adjustBtn).CornerRadius = UDim.new(0, 12)

refreshBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    refreshPlayers()
end)

-- MINI ADJUST FRAME
local miniFrame = Instance.new("TextButton")
miniFrame.Size = UDim2.new(0, 60, 0, 35) -- fixed small UI size
miniFrame.Position = UDim2.new(0.5, -30, 0.5, -17) -- centered
miniFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
miniFrame.Text = "Settings"
miniFrame.TextColor3 = Color3.fromRGB(0,0,0)
miniFrame.Font = Enum.Font.GothamBold
miniFrame.TextSize = 14
miniFrame.Visible = false
miniFrame.Parent = gui
miniFrame.BorderSizePixel = 2
miniFrame.BorderColor3 = Color3.fromRGB(0,0,0)
Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(0, 10)

-- press anim helper
local function pressAnim(button, cb)
    button.MouseButton1Click:Connect(function()
        button:TweenSize(button.Size - UDim2.new(0,5,0,5), "Out", "Quad", 0.08, true, function()
            button:TweenSize(button.Size + UDim2.new(0,5,0,5), "Out", "Quad", 0.08)
            if cb then cb() end
        end)
    end)
end

-- minimize behavior: animate and show miniFrame
pressAnim(minimizeBtn, function()
    pcall(function() clickSound:Play() end)
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    {Size = UDim2.new(0, 0, 0, 0)})
    tween:Play()
    tween.Completed:Wait()
    mainFrame.Visible = false
    miniFrame.Visible = true
end)

-- restore from miniFrame
pressAnim(miniFrame, function()
    pcall(function() clickSound:Play() end)
    miniFrame.Visible = false
    mainFrame.Visible = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Size = UDim2.new(0, 280, 0, 270)}):Play()
end)

-- Draggable
makeDraggable(mainFrame)
makeDraggable(miniFrame)

-- DASH SETTINGS UI (replacing "Adjust Settings" with the exact Dash panel)
local dashGui -- a separate ScreenGui for the dash panel (created/destroyed)
local function createDashPanel()
    -- If dashGui exists, destroy it (toggle behavior)
    if dashGui and dashGui.Parent then
        dashGui:Destroy()
        dashGui = nil
        return
    end

    -- Create a new ScreenGui to host the dash panel (keeps it separate)
    dashGui = Instance.new("ScreenGui")
    dashGui.Name = "DashSettingsGui"
    dashGui.Parent = player:WaitForChild("PlayerGui")
    dashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Frame (200x200)
    local MainFrame = Instance.new("Frame")
    MainFrame.Parent = dashGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    MainFrame.BackgroundTransparency = 0.3 -- decreased transparency
    MainFrame.Position = UDim2.new(0.4, 0, 0.35, 0)
    MainFrame.Size = UDim2.new(0, 200, 0, 200)
    MainFrame.Active = true
    makeDraggable(MainFrame)

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 14)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Parent = MainFrame
    UIStroke.Color = Color3.fromRGB(255, 255, 255)
    UIStroke.Thickness = 1
    UIStroke.Transparency = 0.5

    -- Close Button (red with white X)
    local CloseButton = Instance.new("TextButton")
    local CloseCorner = Instance.new("UICorner")
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    CloseButton.Position = UDim2.new(0.82, 0, 0.05, 0)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextScaled = true
    CloseButton.AutoButtonColor = true
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        pcall(function() clickSound:Play() end)
        if dashGui and dashGui.Parent then
            dashGui:Destroy()
            dashGui = nil
        end
    end)

    -- Create sliders (labels left, slider on right but shorter leaving gap)
    local TitleLabels = {"Dash speed", "Dash Degrees", "Dash gap"}
    for i, name in ipairs(TitleLabels) do
        local Label = Instance.new("TextLabel")
        local SliderFrame = Instance.new("Frame")
        local SliderBar = Instance.new("Frame")
        local SliderButton = Instance.new("TextButton")
        local SliderBarCorner = Instance.new("UICorner")

        -- Label (moved a bit left)
        Label.Parent = MainFrame
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.Font = Enum.Font.Gotham
        Label.TextColor3 = Color3.fromRGB(120,120,120) -- label text gray
        Label.TextScaled = true
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Size = UDim2.new(0, 90, 0, 20)
        Label.Position = UDim2.new(0.05, 0, 0.18 + (i - 1) * 0.25, 0) -- slightly left

        -- SliderFrame (shorter width, leaving right gap inside the 200px frame)
        SliderFrame.Parent = MainFrame
        SliderFrame.BackgroundTransparency = 1
        SliderFrame.Size = UDim2.new(0, 65, 0, 20) -- shorter slider width
        SliderFrame.Position = UDim2.new(0.55, 5, 0.18 + (i - 1) * 0.25, 0) -- gap between label and slider, and gap on right side

        -- Slider bar (thin)
        SliderBar.Parent = SliderFrame
        SliderBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderBar.BackgroundTransparency = 0.7
        SliderBar.Size = UDim2.new(1, 0, 0, 3)
        SliderBar.Position = UDim2.new(0, 0, 0.5, -2)
        SliderBarCorner.CornerRadius = UDim.new(1, 0)
        SliderBarCorner.Parent = SliderBar

        -- Knob
        SliderButton.Parent = SliderFrame
        SliderButton.BackgroundColor3 = Color3.fromRGB(180,180,180) -- knob gray
        SliderButton.Size = UDim2.new(0, 14, 0, 14)
        SliderButton.Position = UDim2.new(0, -7, 0.5, -7) -- start at leftmost
        SliderButton.Text = ""
        SliderButton.AutoButtonColor = false
        SliderButton.ZIndex = 2
        local ButtonCorner = Instance.new("UICorner", SliderButton)
        ButtonCorner.CornerRadius = UDim.new(1, 0)

        -- Dragging logic: touching knob OR bar moves the slider.
        local dragging = false
        local value = 0

        -- If we have saved settings, initialize value from them
        local savedValue = nil
        if savedSettings and savedSettings.Sliders and savedSettings.Sliders[name] then
            savedValue = tonumber(savedSettings.Sliders[name]) -- may be nil
        end
        if savedValue and type(savedValue) == "number" then
            value = math.clamp(math.floor(savedValue), 0, 100)
            SliderButton.Position = UDim2.new(value / 100, -7, 0.5, -7)
        end

        -- Update function: sets knob position based on absolute X (mouse/touch)
        local function update(absX)
            -- ensure Absolute sizes are available
            local barSize = SliderBar.AbsoluteSize.X
            local barPos = SliderBar.AbsolutePosition.X
            if barSize == 0 then return end
            local relative = math.clamp((absX - barPos) / barSize, 0, 1)
            -- place knob (offset half knob width)
            SliderButton.Position = UDim2.new(relative, -7, 0.5, -7)
            value = math.floor(relative * 100)
        end

        -- When knob pressed
        SliderButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                if input.Position then
                    update(input.Position.X)
                end
            end
        end)
        SliderButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        -- When bar pressed (touch anywhere on the bar should move knob and start dragging)
        SliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                if input.Position then
                    update(input.Position.X)
                end
            end
        end)
        SliderBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        -- Also allow starting drag if player touches the empty SliderFrame area
        SliderFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                if input.Position then
                    update(input.Position.X)
                end
            end
        end)
        SliderFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        -- Global update while dragging (mouse movement or touch move)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                if input.Position then
                    update(input.Position.X)
                end
            end
        end)

        -- Expose value getter into top-level Sliders table
        Sliders[name] = function() return value end
    end
end

-- Connect Adjust button to toggle the Dash panel
adjustBtn.MouseButton1Click:Connect(function()
    pcall(function() clickSound:Play() end)
    createDashPanel()
end)

-- Apply saved toggle states (if any) after toggle buttons were created
if savedSettings then
    if savedSettings.Dash ~= nil then
        if espSetState then espSetState(savedSettings.Dash, true) end
        espEnabled = savedSettings.Dash
    end
    if savedSettings.M1 ~= nil then
        if m1SetState then m1SetState(savedSettings.M1, true) end
        m1Enabled = savedSettings.M1
    end
end

-- Keep player list fresh
Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)

print("Standalone Settings GUI V2 (with Dash Settings + Save) loaded.")
