-- Supa V3 - adjusted: only watermark outline moves; changed watermark animation to fade-in + bob.
-- Optimized by assistant.

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

local MAX_TARGET_DIST = 20

local function getNearestTarget()
    if not HumanoidRootPart then return nil end
    local nearest, nearestDist = nil, MAX_TARGET_DIST
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.PrimaryPart then
            local ok, mag = pcall(function()
                return (HumanoidRootPart.Position - p.Character.PrimaryPart.Position).Magnitude
            end)
            if ok and mag and mag < nearestDist then
                nearestDist = mag
                nearest = p.Character
            end
        end
    end
    return nearest
end

local function fireQ()
    pcall(function()
        if Character and Character:FindFirstChild("Communicate") then
            local args = {
                [1] = {
                    ["Dash"] = Enum.KeyCode.W,
                    ["Key"] = Enum.KeyCode.Q,
                    ["Goal"] = "KeyPress"
                }
            }
            Character.Communicate:FireServer(unpack(args))
        end
    end)
    pcall(function()
        if Character and Character:FindFirstChild("Communicate") then
            local bv = nil
            for _, v in ipairs(Character:GetDescendants()) do
                if v.ClassName == "BodyVelocity" and v.Name == "moveme" then
                    bv = v
                    break
                end
            end
            local args2 = {
                [1] = {
                    ["Goal"] = "delete bv",
                    ["BV"] = bv
                }
            }
            Character.Communicate:FireServer(unpack(args2))
        end
    end)
end

local function stickDash()
    if not (Character and Humanoid and HumanoidRootPart) then return end
    local target = getNearestTarget()
    if not target then return end
    local targetHRP = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not targetHRP then return end

    local saved = {}
    pcall(function()
        saved.WalkSpeed = Humanoid.WalkSpeed
        saved.JumpPower = Humanoid.JumpPower
        saved.PlatformStand = Humanoid.PlatformStand
        saved.AutoRotate = Humanoid.AutoRotate
    end)

    pcall(function()
        Humanoid.WalkSpeed = 0
        Humanoid.JumpPower = 0
        Humanoid.PlatformStand = true
        pcall(function() Humanoid.AutoRotate = false end)
        for i = 1, 4 do
            if HumanoidRootPart then
                pcall(function()
                    if HumanoidRootPart:IsA("BasePart") then
                        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end)
            end
            task.wait(0.03)
        end
    end)

    pcall(fireQ)
    task.wait(0.2)

    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
    if HumanoidRootPart then
        pcall(function()
            HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(60), 0, 0)
        end)
    end

    local layDuration = 0.2
    local endTime = tick() + layDuration

    while tick() < endTime do
        local success, newCFrame = pcall(function()
            return CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(60), 0, 0)
        end)
        if success and newCFrame and HumanoidRootPart then
            pcall(function() HumanoidRootPart.CFrame = newCFrame end)
        end
        task.wait(0.03)
    end

    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)

    pcall(function()
        if Humanoid then
            Humanoid.WalkSpeed = saved.WalkSpeed or 16
            Humanoid.JumpPower = saved.JumpPower or 50
            Humanoid.PlatformStand = saved.PlatformStand or false
            if saved.AutoRotate ~= nil then pcall(function() Humanoid.AutoRotate = saved.AutoRotate end) end
        end
        if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
            HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
            HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end
    end)
end

-- UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Merebennie_StickDashGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.Parent = playerGui

local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
Button.Size = UDim2.new(0, 140, 0, 25)
Button.Position = UDim2.new(0.4, 0, 0.8, 0)
Button.Text = "Supa V3 Tech: On"
Button.Font = Enum.Font.SourceSansBold
Button.TextScaled = true
Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.TextStrokeTransparency = 0
-- static stroke color (no animation on button)
Button.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
Button.AutoButtonColor = false
Button.ZIndex = 9999
Button.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = Button

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

-- dragging
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

Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        Button.Text = "Supa V3 Tech: On"
        Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Button.TextColor3 = Color3.fromRGB(255,255,255)
    else
        Button.Text = "Supa V3 Tech: Off"
        Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Button.TextColor3 = Color3.fromRGB(255,255,255)
    end
end)

local CreditFrame = Instance.new("Frame")
CreditFrame.Name = "CreditFrame"
CreditFrame.Size = UDim2.new(0, 220, 0, 80)
local basePos = UDim2.new(1, -230, 0.1, 0)
CreditFrame.Position = basePos
CreditFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CreditFrame.BackgroundTransparency = 0.25
CreditFrame.ZIndex = 9999
CreditFrame.Parent = ScreenGui

local creditCorner = Instance.new("UICorner")
creditCorner.CornerRadius = UDim.new(0, 6)
creditCorner.Parent = CreditFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -12, 0, 28)
TitleLabel.Position = UDim2.new(0, 6, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Made by Merebennie on YouTube"
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled = true
TitleLabel.TextStrokeTransparency = 0
TitleLabel.TextStrokeColor3 = Color3.fromRGB(0,255,0) -- initial color; animated below
TitleLabel.TextTransparency = 1
TitleLabel.Parent = CreditFrame

local DescLabel = Instance.new("TextLabel")
DescLabel.Size = UDim2.new(1, -12, 0, 18)
DescLabel.Position = UDim2.new(0, 6, 0, 36)
DescLabel.BackgroundTransparency = 1
DescLabel.Text = DISCORD_LINK
DescLabel.Font = Enum.Font.SourceSansBold
DescLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DescLabel.TextScaled = true
DescLabel.TextStrokeTransparency = 1
DescLabel.TextTransparency = 1
DescLabel.Parent = CreditFrame

DescLabel.Active = true
DescLabel.AutoButtonColor = false
DescLabel.MouseButton1Down:Connect(function()
    if setclipboard then
        pcall(function() setclipboard(DISCORD_LINK) end)
    end
end)

local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- fade-in Title and Desc (replace slide in/out with fade-in + bobbing)
TweenService:Create(TitleLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
TweenService:Create(DescLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
TweenService:Create(CreditFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.25}):Play()

-- Cooldown UI
local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Name = "CooldownLabel"
CooldownLabel.Size = UDim2.new(0, 140, 0, 30)
CooldownLabel.Position = UDim2.new(0, 10, 1, 0)
CooldownLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CooldownLabel.BackgroundTransparency = 0.35
CooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CooldownLabel.Text = "Cooldown: 4"
CooldownLabel.Font = Enum.Font.SourceSansBold
CooldownLabel.TextScaled = true
CooldownLabel.TextStrokeTransparency = 1
CooldownLabel.Visible = false
CooldownLabel.ZIndex = 9999
CooldownLabel.Parent = ScreenGui

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 8)
cooldownCorner.Parent = CooldownLabel

local connections = {}
local function clearConns()
    for _,c in pairs(connections) do
        if c and c.Disconnect then
            pcall(function() c:Disconnect() end)
        end
    end
    connections = {}
end

local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        uiOnCooldown = true
        task.spawn(function() pcall(stickDash) end)

        local hiddenPos = UDim2.new(0, 10, 1, 0)
        local visiblePos = UDim2.new(0, 10, 1, -40)
        CooldownLabel.Position = hiddenPos
        CooldownLabel.Visible = true
        local popUpTween = TweenService:Create(CooldownLabel, tweenInfo, {Position = visiblePos})
        popUpTween:Play()

        task.spawn(function()
            for i = COOLDOWN_DURATION, 1, -1 do
                CooldownLabel.Text = "Cooldown: " .. i
                task.wait(1)
            end
            uiOnCooldown = false
            local popDownTween = TweenService:Create(CooldownLabel, tweenInfo, {Position = hiddenPos})
            popDownTween:Play()
            popDownTween.Completed:Wait()
            CooldownLabel.Visible = false
        end)
    end
end

local function onAnim(track)
    local anim = track and track.Animation
    if anim then
        local idStr = tostring(anim.AnimationId or "")
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

-- Animated effects: ONLY watermark outline moves and CreditFrame bobs
task.spawn(function()
    while ScreenGui.Parent do
        -- Watermark green <-> blue pulsing outline (moving)
        local t = math.sin(tick()*2) * 0.5 + 0.5
        local blue = Color3.fromRGB(0, 120 + math.floor(120 * t), 255)
        local green = Color3.fromRGB(0, 255, 120 + math.floor(120 * (1-t)))
        local mix = Color3.new(blue.R*(1-t) + green.R*t, blue.G*(1-t) + green.G*t, blue.B*(1-t) + green.B*t)
        if TitleLabel and TitleLabel.Parent then
            pcall(function() TitleLabel.TextStrokeColor3 = mix end)
        end

        -- Bobbing motion (small vertical oscillation)
        if CreditFrame and CreditFrame.Parent then
            local yOffset = math.floor(math.sin(tick()*2) * 6)
            pcall(function()
                CreditFrame.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale, basePos.Y.Offset + yOffset)
            end)
        end

        task.wait(0.06)
    end
end)

Script = script or nil
if Script then
    Script.Destroying:Connect(function()
        clearConns()
    end)
end

