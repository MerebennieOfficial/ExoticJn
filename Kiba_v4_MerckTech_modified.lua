--// Kiba v4 Tech (modified UI)
-- Based on: Merck Tech final with Watermark.lua.txt. Visual/UI edits: cooldown -> purple + light-green text, thin black outlines, 75% transparency.
-- Toggle button renamed to "Kiba v4 Tech:On"/"Kiba v4 Tech:Off" with dark-gray -> black gradient, compact size 40x80.
-- Note: Roblox doesn't provide a "Fedoka" font in Enum.Font; using GothamBold as a close, clean rounded sans in Roblox UI. 
-- If you have a custom font asset, replace the Font property accordingly.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function protectAndParent(gui)
    gui.ResetOnSpawn = false
    if type(syn) == "table" and syn.protect_gui then
        pcall(function() syn.protect_gui(gui) end)
        if gethui then
            gui.Parent = gethui()
            return
        end
    end
    if gethui then
        gui.Parent = gethui()
    else
        local ok, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui") end)
        if ok and pg then
            gui.Parent = pg
        else
            gui.Parent = game:GetService("CoreGui")
        end
    end
end

local Character, Humanoid, HumanoidRootPart
local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.35
local enabled = true
local uiOnCooldown = false
local COOLDOWN_DURATION = 7.2
local IMMOB_EXTRA_AFTER = 0.3

local function getNearestTarget()
    local nearest, dist = nil, math.huge
    if not (HumanoidRootPart) then return nil end
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= Character then
            local ok, mag = pcall(function()
                return (HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
            end)
            if ok and mag and mag < dist then
                dist = mag
                nearest = v
            end
        end
    end
    return nearest
end

local function fireQ()
    task.delay(0.1, function()
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
    end)

    local function getNil(name, class)
        if type(getnilinstances) ~= "function" then return nil end
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

    local target = getNearestTarget()
    if not target then return end

    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local saved = {}
    pcall(function()
        saved.WalkSpeed = Humanoid.WalkSpeed
        saved.JumpPower = Humanoid.JumpPower
        saved.PlatformStand = Humanoid.PlatformStand
        if Humanoid:GetAttribute("AutoRotate") == nil then
            pcall(function() saved.AutoRotate = Humanoid.AutoRotate end)
        else
            saved.AutoRotate = Humanoid.AutoRotate
        end
    end)

    local antiConn
    local function startImmobilize()
        if not Humanoid or not HumanoidRootPart or not Character then return end
        pcall(function()
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            Humanoid.PlatformStand = true
            pcall(function() Humanoid.AutoRotate = false end)
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
        end)

        for _, v in pairs(Character:GetDescendants()) do
            local class = v.ClassName
            if class == "BodyVelocity" or class == "BodyPosition" or class == "BodyGyro" or class == "VectorForce" or class == "AlignPosition" or class == "AlignOrientation" or class == "LinearVelocity" or class == "AngularVelocity" then
                pcall(function() v:Destroy() end)
            end
        end

        antiConn = RunService.Heartbeat:Connect(function()
            if HumanoidRootPart then
                pcall(function()
                    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                    HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
                end)
            end
            if Humanoid and Humanoid.WalkSpeed then
                pcall(function() Humanoid.WalkSpeed = 0 end)
            end
        end)
    end

    local function stopImmobilize()
        if antiConn and antiConn.Disconnect then
            pcall(function() antiConn:Disconnect() end)
        end
        pcall(function()
            if Humanoid then
                Humanoid.WalkSpeed = saved.WalkSpeed or 16
                Humanoid.JumpPower = saved.JumpPower or 50
                Humanoid.PlatformStand = saved.PlatformStand or false
                if saved.AutoRotate ~= nil then pcall(function() Humanoid.AutoRotate = saved.AutoRotate end) end
            end
            if HumanoidRootPart then
                pcall(function()
                    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                    HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
                end)
            end
        end)
    end

    startImmobilize()

    pcall(function()
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end)
    HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(85), 0, 0)

    local startTime = tick()
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= 0.7 then
            connection:Disconnect()
            return
        end
        local success, newCFrame = pcall(function()
            return CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(85), 0, 0)
        end)
        if success and newCFrame then
            HumanoidRootPart.CFrame = newCFrame
        end
    end)

    task.delay(0.18, function()
        pcall(fireQ)
    end)

    task.delay(0.3, function()
        pcall(function()
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end)

    local totalImmobilize = 0.7 + IMMOB_EXTRA_AFTER
    task.delay(totalImmobilize, function()
        pcall(stopImmobilize)
    end)
end

-- === GUI creation ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Kiba_v4_StickDashGui"
ScreenGui.IgnoreGuiInset = true
protectAndParent(ScreenGui)

-- === Toggle button (renamed + redesigned) ===
local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
-- User requested "40x80" (width x height). If you'd prefer 80x40, swap these numbers.
Button.Size = UDim2.new(0, 40, 0, 80)
Button.Position = UDim2.new(0.4, 0, 0.8, 0)
Button.Text = "Kiba v4 Tech:On"
-- Fedoka is not a Roblox Enum.Font option; using GothamBold for a rounded, readable look.
Button.Font = Enum.Font.GothamBold
Button.TextSize = 14
Button.BackgroundColor3 = Color3.fromRGB(64,64,64) -- dark gray base
Button.TextColor3 = Color3.new(1,1,1)
Button.Parent = ScreenGui
Button.ZIndex = 9999
Button.Active = true

local btnCorner = Instance.new("UICorner", Button)
btnCorner.CornerRadius = UDim.new(0, 10)

local btnStroke = Instance.new("UIStroke", Button)
btnStroke.Thickness = 1
btnStroke.Color = Color3.fromRGB(0,0,0)
btnStroke.Transparency = 0 -- thin black outline

-- Gradient from dark gray -> black for a sleek tech look
local btnGradient = Instance.new("UIGradient", Button)
btnGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(70,70,70)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0))
}
btnGradient.Rotation = 90

-- Draggable support (touch + mouse)
do
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
end

Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        Button.Text = "Kiba v4 Tech:On"
        -- keep gradient, but ensure base color indicates ON (slightly lighter)
        Button.BackgroundColor3 = Color3.fromRGB(64,64,64)
    else
        Button.Text = "Kiba v4 Tech:Off"
        -- darker base when OFF
        Button.BackgroundColor3 = Color3.fromRGB(40,40,40)
    end
end)

-- === Cooldown bubble (bottom-left) ===
local CooldownFrame = Instance.new("Frame")
CooldownFrame.Name = "KibaCooldown"
CooldownFrame.Size = UDim2.new(0, 140, 0, 34)
CooldownFrame.Position = UDim2.new(0, 8, 1, -48)
CooldownFrame.AnchorPoint = Vector2.new(0, 0)
-- Purple background, user requested 75% transparent -> BackgroundTransparency = 0.75
CooldownFrame.BackgroundColor3 = Color3.fromRGB(138,43,226) -- medium purple (blueviolet)
CooldownFrame.BackgroundTransparency = 0.75
CooldownFrame.Visible = false
CooldownFrame.Parent = ScreenGui
CooldownFrame.ZIndex = 9998
CooldownFrame.Active = true

local cdCorner = Instance.new("UICorner", CooldownFrame)
cdCorner.CornerRadius = UDim.new(0, 12)

-- Very thin black outline around frame
local cdStroke = Instance.new("UIStroke", CooldownFrame)
cdStroke.Thickness = 1
cdStroke.Color = Color3.fromRGB(0,0,0)
cdStroke.Transparency = 0 -- solid thin outline

local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Name = "CooldownText"
CooldownLabel.Size = UDim2.new(1, -12, 1, 0)
CooldownLabel.Position = UDim2.new(0, 8, 0, 0)
CooldownLabel.BackgroundTransparency = 1
CooldownLabel.Text = "Kiba v4 : 0.0s"
-- light green text per request
CooldownLabel.TextColor3 = Color3.fromRGB(144,238,144)
CooldownLabel.Font = Enum.Font.GothamBold -- Fedoka not available in Enum.Font
CooldownLabel.TextSize = 14
CooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
CooldownLabel.Parent = CooldownFrame
CooldownLabel.ZIndex = 9999

-- thin black outline around the text for legibility
local cdLabelStroke = Instance.new("UIStroke", CooldownLabel)
cdLabelStroke.Thickness = 1
cdLabelStroke.Color = Color3.fromRGB(0,0,0)
cdLabelStroke.Transparency = 0

-- subtle pulsing tween (from 75% -> 60% transparency)
local pulseInfo = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local pulseTween = TweenService:Create(CooldownFrame, pulseInfo, {BackgroundTransparency = 0.6})
local pulseActive = false

local function startUICooldown(duration)
    if uiOnCooldown then return end
    uiOnCooldown = true
    CooldownFrame.Visible = true
    if not pulseActive then
        pulseActive = true
        pcall(function() pulseTween:Play() end)
    end

    local startTime = tick()
    local remaining = duration
    while remaining > 0 do
        remaining = duration - (tick() - startTime)
        if remaining < 0 then remaining = 0 end
        CooldownLabel.Text = string.format("Kiba v4 : %.1fs", remaining)
        task.wait(0.1)
    end

    uiOnCooldown = false
    CooldownFrame.Visible = false
    pcall(function() pulseTween:Cancel() end)
    pulseActive = false
end

-- === Compact Info Box (kept mostly as-is; watermark retained) ===
local InfoFrame = Instance.new("Frame")
InfoFrame.Name = "MerebennieInfoBox"
InfoFrame.Size = UDim2.new(0, 200, 0, 92)
InfoFrame.Position = UDim2.new(0.05, 0, 0.12, 0)
InfoFrame.BackgroundColor3 = Color3.fromRGB(240,240,240)
InfoFrame.Parent = ScreenGui
InfoFrame.ZIndex = 10000
InfoFrame.Active = true

local infoCorner = Instance.new("UICorner", InfoFrame)
infoCorner.CornerRadius = UDim.new(0, 10)
local infoStroke = Instance.new("UIStroke", InfoFrame)
infoStroke.Transparency = 0.35

local Title = Instance.new("TextLabel")
Title.Name = "InfoTitle"
Title.Size = UDim2.new(1, -40, 0, 24)
Title.Position = UDim2.new(0, 10, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "Made by Merebennie"
Title.TextColor3 = Color3.fromRGB(30,30,30)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = InfoFrame
Title.ZIndex = 10001

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "InfoClose"
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Parent = InfoFrame
CloseBtn.ZIndex = 10002
local closeCorner = Instance.new("UICorner", CloseBtn)
closeCorner.CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function()
    InfoFrame.Visible = false
end)

local Desc = Instance.new("TextLabel")
Desc.Name = "InfoDesc"
Desc.Size = UDim2.new(1, -20, 0, 34)
Desc.Position = UDim2.new(0, 10, 0, 32)
Desc.BackgroundTransparency = 1
Desc.TextWrapped = true
Desc.Text = "Join our discord for more Scripts!\nhttps://discord.gg/5x4xbPvuSc"
Desc.TextColor3 = Color3.fromRGB(40,40,40)
Desc.Font = Enum.Font.Gotham
Desc.TextSize = 12
Desc.TextXAlignment = Enum.TextXAlignment.Left
Desc.TextYAlignment = Enum.TextYAlignment.Top
Desc.Parent = InfoFrame
Desc.ZIndex = 10001

local CopyBtn = Instance.new("TextButton")
CopyBtn.Name = "InfoCopy"
CopyBtn.Size = UDim2.new(0, 96, 0, 26)
CopyBtn.Position = UDim2.new(0, 10, 1, -34)
CopyBtn.Text = "Copy Link"
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 12
CopyBtn.BackgroundColor3 = Color3.fromRGB(30,136,229)
CopyBtn.TextColor3 = Color3.new(1,1,1)
CopyBtn.Parent = InfoFrame
CopyBtn.ZIndex = 10001
local copyCorner = Instance.new("UICorner", CopyBtn)
copyCorner.CornerRadius = UDim.new(0, 6)
CopyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard("https://discord.gg/5x4xbPvuSc")
        elseif toclipboard then
            toclipboard("https://discord.gg/5x4xbPvuSc")
        end
    end)
end)

do
    local dragging, dragInput, dragStart, startPos
    InfoFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = InfoFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    InfoFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and startPos then
            local delta = input.Position - dragStart
            InfoFrame.Position = UDim2.new(
                startPos.X.Scale,
                math.clamp(startPos.X.Offset + delta.X, 0, math.max(0, workspace.CurrentCamera.ViewportSize.X - InfoFrame.AbsoluteSize.X)),
                startPos.Y.Scale,
                math.clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, workspace.CurrentCamera.ViewportSize.Y - InfoFrame.AbsoluteSize.Y))
            )
        end
    end)
end

local connections = {}

local function clearCharacterConnections()
    for _, conn in pairs(connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    connections = {}
end

local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        task.spawn(function() pcall(stickDash) end)
        task.spawn(function() startUICooldown(COOLDOWN_DURATION) end)
    end
end

local function onAnimationPlayed(track)
    if not track then return end
    local anim = track.Animation
    if not anim then return end
    local animId = tostring(anim.AnimationId or "")
    if string.find(animId, "10503381238", 1, true) then
        tryTrigger()
    end
end

local function setupCharacter(char)
    clearCharacterConnections()
    Character = char
    Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart", 5)
    if not Humanoid or not HumanoidRootPart then return end

    local ok, conn = pcall(function()
        return Humanoid.AnimationPlayed:Connect(onAnimationPlayed)
    end)
    if ok and conn then table.insert(connections, conn) end

    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local success, animConn = pcall(function()
            return animator.AnimationPlayed:Connect(onAnimationPlayed)
        end)
        if success and animConn then table.insert(connections, animConn) end
    end

    local descConn = Character.DescendantAdded:Connect(function(desc)
        if desc:IsA("Animation") then
            local aid = tostring(desc.AnimationId or "")
            if string.find(aid, "10503381238", 1, true) then
                tryTrigger()
            end
        end
    end)
    table.insert(connections, descConn)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    pcall(setupCharacter, char)
end)

if LocalPlayer.Character then
    pcall(setupCharacter, LocalPlayer.Character)
end

-- End of modified script
