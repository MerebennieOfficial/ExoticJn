
-- supa_v3_updated.lua
-- Optimized and UI-updated version of your original script.
-- Changes:
-- 1) Button label redesigned to a rainbow-style RichText "Supa v3: On/Off" (same size)
-- 2) Target search optimized to iterate players only (much faster than GetDescendants)
-- 3) Watermark (credit) animation changed to persistent badge with animated green/cyan outline
-- 4) Removed the slide-out destroy; watermark no longer destroys itself
-- 5) General micro-optimizations to reduce heavy GetDescendants calls and pcall usage in hot loops
-- NOTE: Keep this run in an executor environment that supports functions like getnilinstances and setclipboard.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character, Humanoid, HumanoidRootPart

local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.3
local enabled = true
local uiOnCooldown = false
local COOLDOWN_DURATION = 4

local DISCORD_LINK = "https://discord.gg/RsxcaHhRqb"

-- optimized nearest target: iterate players only (very cheap compared to GetDescendants)
local function getNearestTarget(maxDist)
    maxDist = maxDist or 20
    if not HumanoidRootPart then return nil end
    local nearest, dist = nil, maxDist
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local char = pl.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ok, mag = pcall(function()
                        return (HumanoidRootPart.Position - hrp.Position).Magnitude
                    end)
                    if ok and mag and mag < dist then
                        dist = mag
                        nearest = char
                    end
                end
            end
        end
    end
    return nearest
end

local function fireQ()
    pcall(function()
        local args = {
            [1] = {
                ["Dash"] = Enum.KeyCode.W,
                ["Key"] = Enum.KeyCode.Q,
                ["Goal"] = "KeyPress"
            }
        }
        if Character and Character:FindFirstChild("Communicate") then
            Character.Communicate:FireServer(unpack(args))
        end
    end)

    local function getNil(name, class)
        for _, v in pairs(getnilinstances()) do
            if v.ClassName == class and v.Name == name then
                return v
            end
        end
    end

    pcall(function()
        local args2 = {
            [1] = {
                ["Goal"] = "delete bv",
                ["BV"] = getNil("moveme", "BodyVelocity")
            }
        }
        if Character and Character:FindFirstChild("Communicate") then
            Character.Communicate:FireServer(unpack(args2))
        end
    end)
end

local function stickDash()
    if not (Character and Humanoid and HumanoidRootPart) then return end

    local target = getNearestTarget(20)
    if not target then return end
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- save small set of properties (use pcall once)
    local saved = {}
    pcall(function()
        saved.WalkSpeed = Humanoid.WalkSpeed
        saved.JumpPower = Humanoid.JumpPower
        saved.PlatformStand = Humanoid.PlatformStand
        saved.AutoRotate = Humanoid.AutoRotate
    end)

    local antiConn

    local function startImmobilize()
        if not Humanoid or not HumanoidRootPart or not Character then return end
        -- set immutable values once and then keep resetting simple vars in a heartbeat connection
        pcall(function()
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            Humanoid.PlatformStand = true
            Humanoid.AutoRotate = false
            HumanoidRootPart.Velocity = Vector3.new(0,0,0)
            HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
        end)
        -- remove dangerous physics objects once
        for _, v in pairs(Character:GetDescendants()) do
            local class = v.ClassName
            if class == "BodyVelocity" or class == "BodyPosition" or class == "BodyGyro" or class == "VectorForce" or class == "AlignPosition" or class == "AlignOrientation" or class == "LinearVelocity" or class == "AngularVelocity" then
                pcall(function() v:Destroy() end)
            end
        end
        -- lightweight heartbeat to clamp velocity only while immobilized
        antiConn = RunService.Heartbeat:Connect(function()
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
            if Humanoid then
                Humanoid.WalkSpeed = 0
            end
        end)
    end

    local function stopImmobilize()
        if antiConn then
            pcall(function() antiConn:Disconnect() end)
            antiConn = nil
        end
        pcall(function()
            if Humanoid then
                Humanoid.WalkSpeed = saved.WalkSpeed or 16
                Humanoid.JumpPower = saved.JumpPower or 50
                Humanoid.PlatformStand = saved.PlatformStand or false
                if saved.AutoRotate ~= nil then Humanoid.AutoRotate = saved.AutoRotate end
            end
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
        end)
    end

    startImmobilize()
    pcall(fireQ) -- Fire Q first
    task.wait(0.2) -- wait 0.2s before laying down

    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
    if HumanoidRootPart then
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(60), 0, 0)
    end

    local layDuration = 0.2
    local startTime = tick()
    local movementConn
    movementConn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= layDuration then
            if movementConn then pcall(function() movementConn:Disconnect() end) end
            return
        end
        local success, newCFrame = pcall(function()
            return CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(60), 0, 0)
        end)
        if success and newCFrame and HumanoidRootPart then
            HumanoidRootPart.CFrame = newCFrame
        end
    end)

    repeat task.wait() until tick() - startTime >= layDuration

    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    pcall(stopImmobilize)
end

-- GUI creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Merebennie_StickDashGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.Parent = playerGui

-- Button (same size as before)
local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
Button.Size = UDim2.new(0, 140, 0, 25)
Button.Position = UDim2.new(0.4, 0, 0.8, 0)
Button.Font = Enum.Font.GothamBold
Button.TextScaled = true
Button.BackgroundColor3 = Color3.fromRGB(0,0,0)
Button.TextStrokeTransparency = 1
Button.AutoButtonColor = false
Button.ZIndex = 9999
Button.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 12)
btnCorner.Parent = Button

-- small inner glow using UIStroke
local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 1.5
btnStroke.Color = Color3.fromRGB(20,200,180) -- subtle cyan
btnStroke.Transparency = 0.5
btnStroke.Parent = Button

-- create a separate TextLabel as child for rich per-character colors
local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(1, -6, 1, -4)
TextLabel.Position = UDim2.new(0, 3, 0, 2)
TextLabel.BackgroundTransparency = 1
TextLabel.Font = Enum.Font.GothamBold
TextLabel.TextScaled = true
TextLabel.RichText = true
TextLabel.TextStrokeTransparency = 1
TextLabel.TextWrap = false
TextLabel.Parent = Button

local ButtonClickSound = Instance.new("Sound")
ButtonClickSound.Name = "ButtonClickSound"
ButtonClickSound.SoundId = "rbxassetid://6042053626"
ButtonClickSound.Volume = 1
ButtonClickSound.Looped = false
ButtonClickSound.Parent = Button

Button.MouseButton1Click:Connect(function()
    pcall(function() ButtonClickSound:Play() end)
    Button:TweenSize(UDim2.new(0,136,0,23),"Out","Quad",0.05,true)
    task.wait(0.05)
    Button:TweenSize(UDim2.new(0,140,0,25),"Out","Quad",0.05,true)
end)

local dragging, dragInput, dragStart, startPos
Button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Button.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
Button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging and startPos then
        local delta = input.Position - dragStart
        Button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- rainbow text helper (wraps each char in a <font color> tag)
local rainbowColors = {
    "#ff3b30", -- red
    "#ff9500", -- orange
    "#ffd60a", -- yellow
    "#32d74b", -- green
    "#00c7ff", -- cyan
    "#007aff", -- blue
    "#af52de"  -- purple
}

local function makeRainbowText(s)
    local out = ""
    local n = #rainbowColors
    for i = 1, #s do
        local ch = s:sub(i,i)
        local color = rainbowColors[((i-1) % n) + 1]
        -- escape special html chars minimally
        if ch == "<" then ch = "&lt;" end
        if ch == ">" then ch = "&gt;" end
        out = out .. string.format('<font color="%s">%s</font>', color, ch)
    end
    return out
end

local function updateButtonLabel(isEnabled)
    local label = isEnabled and "Supa v3: On" or "Supa v3: Off"
    TextLabel.Text = makeRainbowText(label)
end

-- hook toggle logic
Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    updateButtonLabel(enabled)
end)

-- init label
updateButtonLabel(enabled)

-- CreditFrame (watermark) placed bottom-left and kept persistent
local Outer = Instance.new("Frame")
Outer.Name = "Merebennie_OuterWatermark"
Outer.Size = UDim2.new(0, 220, 0, 36)
Outer.Position = UDim2.new(0.02, 0, 0.02, 0) -- top-left-ish; adjust as you like
Outer.BackgroundTransparency = 1
Outer.ZIndex = 9998
Outer.Parent = ScreenGui

local Outline = Instance.new("Frame")
Outline.Size = UDim2.new(1, 4, 1, 4)
Outline.Position = UDim2.new(0, -2, 0, -2)
Outline.BackgroundTransparency = 1
Outline.ZIndex = 9998
Outline.Parent = Outer

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,200,255))
}
gradient.Rotation = 0
gradient.Parent = Outline

local outlineCorner = Instance.new("UICorner")
outlineCorner.CornerRadius = UDim.new(0, 18)
outlineCorner.Parent = Outline

local inner = Instance.new("Frame")
inner.Size = UDim2.new(1, -8, 1, -8)
inner.Position = UDim2.new(0, 4, 0, 4)
inner.BackgroundColor3 = Color3.fromRGB(0,0,0)
inner.BackgroundTransparency = 0
inner.ZIndex = 9999
inner.Parent = Outer

local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0, 18)
innerCorner.Parent = inner

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Made by Merebennie on YouTube"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled = true
TitleLabel.TextStrokeTransparency = 1
TitleLabel.Parent = inner

-- animate gradient rotation in a loop without destroying the watermark
do
    local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false)
    local t = TweenService:Create(gradient, tweenInfo, {Rotation = 360})
    t:Play()
end

-- Cooldown UI (unchanged visuals but cleaned layout)
local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Name = "CooldownLabel"
CooldownLabel.Size = UDim2.new(0, 120, 0, 30)
CooldownLabel.Position = UDim2.new(0, 10, 1, -40)
CooldownLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CooldownLabel.BackgroundTransparency = 0.35 -- 35% transparent
CooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CooldownLabel.Text = "Cooldown: 4"
CooldownLabel.Font = Enum.Font.GothamBold
CooldownLabel.TextScaled = true
CooldownLabel.TextStrokeTransparency = 1
CooldownLabel.Visible = false
CooldownLabel.ZIndex = 9999
CooldownLabel.Parent = ScreenGui

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 8)
cooldownCorner.Parent = CooldownLabel

-- connection management
local connections = {}
local function clearConns()
    for _,c in pairs(connections) do
        if c then
            pcall(function() c:Disconnect() end)
        end
    end
    connections = {}
end

local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick()-lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        uiOnCooldown = true
        task.spawn(function() pcall(stickDash) end)
        
        -- Start cooldown UI
        CooldownLabel.Position = UDim2.new(0, 10, 1, -40)
        CooldownLabel.Visible = true
        local popUpTween = TweenService:Create(CooldownLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 10, 1, -40)})
        popUpTween:Play()
        
        task.spawn(function()
            for i = COOLDOWN_DURATION, 1, -1 do
                CooldownLabel.Text = "Cooldown: " .. i
                task.wait(1)
            end
            uiOnCooldown = false
            CooldownLabel.Visible = false
        end)
    end
end

local function onAnim(track)
    local anim = track and track.Animation
    if anim then
        local idStr = tostring(anim.AnimationId or "")
        -- if specific animation id triggers, use short delay then tryTrigger
        if string.find(idStr, "10503381238", 1, true) or string.find(idStr, "13379003796", 1, true) then
            task.delay(0.3, tryTrigger)
            return
        end
    end
end

local function setupChar(char)
    clearConns()
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")

    local ok, conn = pcall(function()
        return Humanoid.AnimationPlayed:Connect(onAnim)
    end)
    if ok and conn then table.insert(connections, conn) end

    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local ok2, conn2 = pcall(function()
            return animator.AnimationPlayed:Connect(onAnim)
        end)
        if ok2 and conn2 then table.insert(connections, conn2) end
    end
end

LocalPlayer.CharacterAdded:Connect(setupChar)
if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
