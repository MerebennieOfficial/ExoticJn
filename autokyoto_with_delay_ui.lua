-- Delta Mobile — Core logic + On/Off UI Button + Sound + Tap Animation + Watermark (Top-left)
-- Animation trigger: rbxassetid://12273188754 (1.5s delay) -> Teleport 22.5 -> press "2"

-- =========================
-- CONFIG
-- =========================
local TELEPORT_DISTANCE = 22.5
local TRIGGER_ANIM_ID = "rbxassetid://12273188754"
local ANIM_DELAY = 1.5
local COOLDOWN = 0.6

-- =========================
-- SERVICES
-- =========================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInput = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- =========================
-- STATE
-- =========================
local lastTriggerTime = 0
local animConn = nil
local autoEnabled = true
local dragging = false

-- =========================
-- UTILITIES
-- =========================
local function now() return os.clock() end

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function performAction()
    if now() - lastTriggerTime < COOLDOWN then return end
    lastTriggerTime = now()

    local hrp = getHRP()
    if not hrp then return end

    hrp.CFrame = hrp.CFrame + (hrp.CFrame.LookVector * TELEPORT_DISTANCE)

    pcall(function()
        VirtualInput:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
        task.wait(0.05)
        VirtualInput:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    end)
end

-- =========================
-- ANIMATION MONITORING
-- =========================
local function hookHumanoidAnimations(humanoid)
    if animConn then
        animConn:Disconnect()
        animConn = nil
    end
    if not humanoid then return end

    animConn = humanoid.AnimationPlayed:Connect(function(track)
        local ok, animId = pcall(function()
            return (track and track.Animation and tostring(track.Animation.AnimationId)) or ""
        end)
        if not ok then return end
        if not autoEnabled then return end
        if animId == TRIGGER_ANIM_ID then
            task.delay(ANIM_DELAY, function()
                if autoEnabled then
                    performAction()
                end
            end)
        end
    end)
end

local function onCharacterReady(char)
    local hum = char:WaitForChild("Humanoid")
    hookHumanoidAnimations(hum)
end

Players.LocalPlayer.CharacterAdded:Connect(onCharacterReady)
if Players.LocalPlayer.Character then
    onCharacterReady(Players.LocalPlayer.Character)
end

-- =========================
-- UI TOGGLE BUTTON
-- =========================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 80, 0, 40)
ToggleButton.Position = UDim2.new(0, 50, 0, 50)
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Text = "On"
ToggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.TextSize = 22
ToggleButton.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleButton

-- Click Sound
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6042053626"
clickSound.Volume = 1
clickSound.Parent = ToggleButton

-- Dragging
local dragStart, startPos
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        dragStart = input.Position
        startPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or
       input.UserInputType == Enum.UserInputType.Touch then
        if dragStart then
            dragging = true
            local delta = input.Position - dragStart
            ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                               startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

-- Tap Animation + Toggle Logic
ToggleButton.MouseButton1Click:Connect(function()
    if dragging then return end

    autoEnabled = not autoEnabled
    ToggleButton.Text = autoEnabled and "On" or "Off"

    clickSound:Play()

    local shrink = TweenService:Create(ToggleButton, TweenInfo.new(0.1), {Size = UDim2.new(0, 72, 0, 36)})
    local grow = TweenService:Create(ToggleButton, TweenInfo.new(0.1), {Size = UDim2.new(0, 80, 0, 40)})
    shrink:Play()
    shrink.Completed:Connect(function()
        grow:Play()
    end)
end)

-- =========================
-- DELAY ADJUST UI
-- =========================
local DelayFrame = Instance.new("Frame")
DelayFrame.Size = UDim2.new(0, 150, 0, 60)
DelayFrame.Position = UDim2.new(0, 150, 0, 50)
DelayFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
DelayFrame.BackgroundTransparency = 0.3 -- 70% opacity
DelayFrame.Parent = ScreenGui
DelayFrame.Active = true
DelayFrame.Draggable = true

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 10)
UICorner2.Parent = DelayFrame

local DelayLabel = Instance.new("TextLabel")
DelayLabel.Size = UDim2.new(1, -20, 0, 25)
DelayLabel.Position = UDim2.new(0, 10, 0, 5)
DelayLabel.BackgroundTransparency = 1
DelayLabel.Text = "Delay: " .. ANIM_DELAY
DelayLabel.TextColor3 = Color3.fromRGB(0,0,0)
DelayLabel.Font = Enum.Font.SourceSansBold
DelayLabel.TextScaled = true
DelayLabel.Parent = DelayFrame

-- Helper for button effects
local function buttonClickEffect(btn)
    clickSound:Play()
    local shrink = TweenService:Create(btn, TweenInfo.new(0.1), {Size = btn.Size - UDim2.new(0,8,0,4)})
    local grow = TweenService:Create(btn, TweenInfo.new(0.1), {Size = btn.Size})
    shrink:Play()
    shrink.Completed:Connect(function()
        grow:Play()
    end)
end

-- Minus button
local Minus = Instance.new("TextButton")
Minus.Size = UDim2.new(0, 40, 0, 25)
Minus.Position = UDim2.new(0, 10, 0, 30)
Minus.BackgroundColor3 = Color3.fromRGB(255,255,255)
Minus.BackgroundTransparency = 0.3
Minus.Text = "-"
Minus.TextColor3 = Color3.fromRGB(0,0,0)
Minus.Font = Enum.Font.SourceSansBold
Minus.TextSize = 22
Minus.Parent = DelayFrame

-- Plus button
local Plus = Instance.new("TextButton")
Plus.Size = UDim2.new(0, 40, 0, 25)
Plus.Position = UDim2.new(0, 100, 0, 30)
Plus.BackgroundColor3 = Color3.fromRGB(255,255,255)
Plus.BackgroundTransparency = 0.3
Plus.Text = "+"
Plus.TextColor3 = Color3.fromRGB(0,0,0)
Plus.Font = Enum.Font.SourceSansBold
Plus.TextSize = 22
Plus.Parent = DelayFrame

-- Minimize button
local Mini = Instance.new("TextButton")
Mini.Size = UDim2.new(0, 20, 0, 20)
Mini.Position = UDim2.new(1, -25, 0, 5)
Mini.BackgroundColor3 = Color3.fromRGB(255,255,255)
Mini.BackgroundTransparency = 0.3
Mini.Text = "-"
Mini.TextColor3 = Color3.fromRGB(0,0,0)
Mini.Font = Enum.Font.SourceSansBold
Mini.TextSize = 18
Mini.Parent = DelayFrame

local minimized = false
Mini.MouseButton1Click:Connect(function()
    minimized = not minimized
    DelayLabel.Visible = not minimized
    Minus.Visible = not minimized
    Plus.Visible = not minimized
    Mini.Text = minimized and "+" or "-"
    buttonClickEffect(Mini)
end)

-- Adjust logic
local function updateLabel()
    DelayLabel.Text = "Delay: " .. string.format("%.1f", ANIM_DELAY)
end

Minus.MouseButton1Click:Connect(function()
    ANIM_DELAY = math.max(0, ANIM_DELAY - 0.1)
    updateLabel()
    buttonClickEffect(Minus)
end)

Plus.MouseButton1Click:Connect(function()
    ANIM_DELAY = ANIM_DELAY + 0.1
    updateLabel()
    buttonClickEffect(Plus)
end)

updateLabel()

-- =========================
-- WATERMARK (Top-left)
-- =========================
local Watermark = Instance.new("TextLabel")
Watermark.Size = UDim2.new(0, 250, 0, 25)
Watermark.Position = UDim2.new(0, 10, 0, 10)
Watermark.BackgroundTransparency = 1
Watermark.Text = "Merebennie on YouTube"
Watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
Watermark.TextTransparency = 0.3
Watermark.TextScaled = true
Watermark.Font = Enum.Font.Arcade
Watermark.Parent = ScreenGui
