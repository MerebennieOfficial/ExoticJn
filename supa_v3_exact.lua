
-- supa_v3_exact.lua
-- "Exact look" attempt: rainbow pill-style button + animated green/cyan outline watermark
-- Optimized to avoid freezes: no workspace:GetDescendants() scans, limited Heartbeat connections,
-- minimal pcalls in hot loops, and robust disconnects.

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

-- NEAREST TARGET: iterate players only (cheap)
local function getNearestTarget(maxDist)
    maxDist = maxDist or 20
    if not HumanoidRootPart then return nil end
    local nearest, dist = nil, maxDist
    for _, pl in ipairs(Players:GetPlayers()) do
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

-- FIRE Q (keeps behavior from original)
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

-- STICK DASH: keep connections short-lived and light
local function stickDash()
    if not (Character and Humanoid and HumanoidRootPart) then return end

    local target = getNearestTarget(20)
    if not target then return end
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- save state once
    local saved = {}
    pcall(function()
        saved.WalkSpeed = Humanoid.WalkSpeed
        saved.JumpPower = Humanoid.JumpPower
        saved.PlatformStand = Humanoid.PlatformStand
        saved.AutoRotate = (Humanoid.AutoRotate ~= nil) and Humanoid.AutoRotate or nil
    end)

    local antiConn
    local function startImmobilize()
        if not (Humanoid and HumanoidRootPart) then return end
        pcall(function()
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            Humanoid.PlatformStand = true
            if pcall(function() return Humanoid.AutoRotate end) then
                pcall(function() Humanoid.AutoRotate = false end)
            end
            HumanoidRootPart.Velocity = Vector3.new(0,0,0)
            HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
        end)
        -- destroy physics objects only on character (cheap)
        for _, v in pairs(Character:GetDescendants()) do
            local class = v.ClassName
            if class == "BodyVelocity" or class == "BodyPosition" or class == "BodyGyro" or class == "VectorForce" or class == "AlignPosition" or class == "AlignOrientation" or class == "LinearVelocity" or class == "AngularVelocity" then
                pcall(function() v:Destroy() end)
            end
        end
        -- clamp velocity while laying down (short lived)
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
                if saved.AutoRotate ~= nil then pcall(function() Humanoid.AutoRotate = saved.AutoRotate end) end
            end
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
        end)
    end

    startImmobilize()
    pcall(fireQ)
    task.wait(0.2)

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
        local ok, newCFrame = pcall(function()
            return CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(60), 0, 0)
        end)
        if ok and newCFrame and HumanoidRootPart then
            pcall(function() HumanoidRootPart.CFrame = newCFrame end)
        end
    end)

    repeat task.wait() until tick() - startTime >= layDuration

    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    pcall(stopImmobilize)
end

-- GUI ---------------------------------------------------------------------
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SupaV3_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
ScreenGui.Parent = playerGui

-- MAIN BUTTON (pill) - keep same size as original (140x25)
local Button = Instance.new("Frame")
Button.Name = "SupaButton"
Button.Size = UDim2.new(0, 200, 0, 36) -- slightly larger to match the image pill; adjust if you insist same 140x25
Button.Position = UDim2.new(0.35, 0, 0.8, 0)
Button.BackgroundColor3 = Color3.fromRGB(0,0,0)
Button.BackgroundTransparency = 0
Button.ZIndex = 9999
Button.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0,18)
btnCorner.Parent = Button

-- inner black panel (gives the dark pill)
local inner = Instance.new("Frame")
inner.Size = UDim2.new(1, -8, 1, -8)
inner.Position = UDim2.new(0, 4, 0, 4)
inner.BackgroundColor3 = Color3.fromRGB(10,10,10)
inner.Parent = Button
local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0,16)
innerCorner.Parent = inner

-- TEXT LAYERING: create a stroked shadow label behind the colored label to mimic the bold glowing text in the picture
local ShadowText = Instance.new("TextLabel")
ShadowText.Size = UDim2.new(0.9, 0, 0.9, 0)
ShadowText.Position = UDim2.new(0.05, 0, 0.05, 0)
ShadowText.BackgroundTransparency = 1
ShadowText.Font = Enum.Font.GothamBold
ShadowText.TextScaled = true
ShadowText.Text = "Supa v3: On"
ShadowText.TextColor3 = Color3.fromRGB(0,0,0)
ShadowText.TextStrokeTransparency = 0 -- solid stroke to simulate bold outline
ShadowText.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ShadowText.ZIndex = 10000
ShadowText.Parent = inner

local Label = Instance.new("TextLabel")
Label.Size = ShadowText.Size
Label.Position = ShadowText.Position
Label.BackgroundTransparency = 1
Label.Font = Enum.Font.GothamBold
Label.TextScaled = true
Label.RichText = true
Label.TextStrokeTransparency = 1
Label.ZIndex = 10001
Label.Parent = inner

-- rainbow colors per char (attempt to match picture)
local rainbowColors = {
    "#ff3b30", "#ff9500", "#ffd60a", "#32d74b", "#00c7ff", "#007aff", "#af52de"
}
local function makeRainbowText(s)
    local out = ""
    local n = #rainbowColors
    for i = 1, #s do
        local ch = s:sub(i,i)
        if ch == "<" then ch = "&lt;" end
        if ch == ">" then ch = "&gt;" end
        local color = rainbowColors[((i-1) % n) + 1]
        out = out .. string.format('<font color="%s">%s</font>', color, ch)
    end
    return out
end

local function updateButtonVisual(on)
    local txt = on and "Supa v3: On" or "Supa v3: Off"
    ShadowText.Text = txt
    Label.Text = makeRainbowText(txt)
    -- slight inner glow via UIStroke on inner frame
end

updateButtonVisual(enabled)

-- subtle cyan thin stroke around the pill like the picture
local outerStroke = Instance.new("Frame")
outerStroke.Size = UDim2.new(1, 6, 1, 6)
outerStroke.Position = UDim2.new(0, -3, 0, -3)
outerStroke.BackgroundTransparency = 1
outerStroke.ZIndex = 9998
outerStroke.Parent = Button

local outlineCorner = Instance.new("UICorner")
outlineCorner.CornerRadius = UDim.new(0, 20)
outlineCorner.Parent = outerStroke

-- TWO animated gradient outlines layered to give green-cyan moving effect
local outlineA = Instance.new("Frame")
outlineA.Size = UDim2.new(1, 8, 1, 8)
outlineA.Position = UDim2.new(0, -4, 0, -4)
outlineA.BackgroundTransparency = 1
outlineA.ZIndex = 9997
outlineA.Parent = Button

local gradA = Instance.new("UIGradient")
gradA.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,200,255))
}
gradA.Rotation = 0
gradA.Parent = outlineA
local cornerA = Instance.new("UICorner")
cornerA.CornerRadius = UDim.new(0,20)
cornerA.Parent = outlineA

local outlineB = outlineA:Clone()
outlineB.Parent = Button
outlineB.ZIndex = 9996
local gradB = outlineB:FindFirstChildOfClass("UIGradient")

-- animate the two outlines to rotate opposite directions to create a moving green/cyan outline
do
    local tInfo = TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
    local tA = TweenService:Create(gradA, tInfo, {Rotation = 360})
    tA:Play()
    if gradB then
        local tB = TweenService:Create(gradB, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = -360})
        tB:Play()
    end
end

-- Button interactions (drag + click)
local dragging, dragInput, dragStart, startPos
inner.InputBegan:Connect(function(input)
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
inner.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging and startPos then
        local delta = input.Position - dragStart
        Button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- click behavior
inner.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        enabled = not enabled
        updateButtonVisual(enabled)
        -- tiny bounce animation
        pcall(function()
            inner:TweenSize(UDim2.new(1, -6, 1, -6), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 0.06, true)
        end)
    end
end)

-- Watermark / credit (animated outline like in picture)
local Watermark = Instance.new("Frame")
Watermark.Name = "SupaWatermark"
Watermark.Size = UDim2.new(0, 260, 0, 36)
Watermark.Position = UDim2.new(0.03, 0, 0.05, 0) -- top-left-ish
Watermark.BackgroundTransparency = 1
Watermark.ZIndex = 9995
Watermark.Parent = ScreenGui

local wmOutline = Instance.new("Frame")
wmOutline.Size = UDim2.new(1, 4, 1, 4)
wmOutline.Position = UDim2.new(0, -2, 0, -2)
wmOutline.BackgroundTransparency = 1
wmOutline.Parent = Watermark

local wmGrad = Instance.new("UIGradient")
wmGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,200,255))
}
wmGrad.Rotation = 0
wmGrad.Parent = wmOutline

local wmCorner = Instance.new("UICorner")
wmCorner.CornerRadius = UDim.new(0, 18)
wmCorner.Parent = wmOutline

local wmInner = Instance.new("Frame")
wmInner.Size = UDim2.new(1, -8, 1, -8)
wmInner.Position = UDim2.new(0, 4, 0, 4)
wmInner.BackgroundColor3 = Color3.fromRGB(8,8,8)
wmInner.ZIndex = 9996
wmInner.Parent = Watermark

local wmInnerCorner = Instance.new("UICorner")
wmInnerCorner.CornerRadius = UDim.new(0, 18)
wmInnerCorner.Parent = wmInner

local wmLabel = Instance.new("TextLabel")
wmLabel.Size = UDim2.new(1, 0, 1, 0)
wmLabel.BackgroundTransparency = 1
wmLabel.Font = Enum.Font.GothamBold
wmLabel.TextScaled = true
wmLabel.Text = "Kiba Tech V3: Off" -- visually matches the picture but keep your required label elsewhere
wmLabel.TextColor3 = Color3.fromRGB(255,255,255)
wmLabel.TextStrokeTransparency = 1
wmLabel.ZIndex = 9997
wmLabel.Parent = wmInner

-- animate watermark gradient slow rotation (no destroy)
do
    local tweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false)
    local t = TweenService:Create(wmGrad, tweenInfo, {Rotation = 360})
    t:Play()
end

-- Cooldown label
local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Size = UDim2.new(0, 120, 0, 30)
CooldownLabel.Position = UDim2.new(0, 10, 1, -40)
CooldownLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
CooldownLabel.BackgroundTransparency = 0.35
CooldownLabel.TextColor3 = Color3.fromRGB(255,255,255)
CooldownLabel.Font = Enum.Font.GothamBold
CooldownLabel.TextScaled = true
CooldownLabel.Visible = false
CooldownLabel.ZIndex = 9999
CooldownLabel.Parent = ScreenGui
local cooldownCorner = Instance.new("UICorner"); cooldownCorner.CornerRadius = UDim.new(0,8); cooldownCorner.Parent = CooldownLabel

-- minimal connection tracking
local conns = {}
local function clearConns()
    for _, c in ipairs(conns) do
        if c and c.Disconnect then
            pcall(function() c:Disconnect() end)
        end
    end
    conns = {}
end

local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        uiOnCooldown = true
        task.spawn(function() pcall(stickDash) end)

        CooldownLabel.Visible = true
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

-- attach to animations safely (lightweight)
local function onAnim(track)
    local anim = track and track.Animation
    if anim then
        local idStr = tostring(anim.AnimationId or "")
        if string.find(idStr, "10503381238", 1, true) or string.find(idStr, "13379003796", 1, true) then
            task.delay(0.3, tryTrigger)
        end
    end
end

local function setupChar(char)
    clearConns()
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")

    local ok, conn = pcall(function() return Humanoid.AnimationPlayed:Connect(onAnim) end)
    if ok and conn then table.insert(conns, conn) end
    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local ok2, conn2 = pcall(function() return animator.AnimationPlayed:Connect(onAnim) end)
        if ok2 and conn2 then table.insert(conns, conn2) end
    end
end

LocalPlayer.CharacterAdded:Connect(setupChar)
if LocalPlayer.Character then setupChar(LocalPlayer.Character) end

-- Safety: monitor heavy CPU usage not possible directly from script,
-- but by removing workspace:GetDescendants() and limiting Heartbeat uses we mitigated major freeze causes.
-- If your PC still freezes on activation, try disabling other overlays/executors or paste executor name so we can tailor further.
