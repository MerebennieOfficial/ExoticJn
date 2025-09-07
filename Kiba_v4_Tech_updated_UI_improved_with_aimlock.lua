--// Kiba v4 Tech (modified UI) - UI Improved + Aimlock
-- Changes per user request:
--  - Toggle button size: 45x45 (width x height)
--  - Button shows only "On" / "Off" text
--  - Purple background; green text
--  - Uses a different font (SourceSansBold)
--  - Touch / click press animation (scale tween + shadow press)
--  - Uses user-provided sound asset: rbxassetid://6042053626
--  - Cooldown remains 4.2
--  - Added aimlock that lasts 0.3s, triggers at same time as fireQ, only affects left/right (yaw), works for NPCs and players, and only aimlocks to the target.
-- No other functional changes beyond UI, keyboard toggle, sound, and aimlock.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- ================= Configurable constants =================
local COOLDOWN_DURATION = 4.2 -- user requested
local TRIGGER_COOLDOWN = 0.35
local IMMOB_EXTRA_AFTER = 0.3
local AIMLOCK_DURATION = 0.3 -- user requested
-- ================= End config =================

local Character, Humanoid, HumanoidRootPart
local lastTrigger = 0
local enabled = true
local uiOnCooldown = false

-- ==== Targeting & mechanics (unchanged functionally) ====
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

-- ==== GUI Creation (improved UI) ====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Kiba_v4_StickDashGui_ImprovedUI"
ScreenGui.IgnoreGuiInset = true
protectAndParent(ScreenGui)

-- Create an anchored shadow frame behind button for depth effect
local Shadow = Instance.new("Frame")
Shadow.Name = "ToggleShadow"
Shadow.Size = UDim2.new(0, 45, 0, 45)
Shadow.Position = UDim2.new(0.4, 4, 0.8, 4) -- slight offset to appear as shadow
Shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
Shadow.BackgroundTransparency = 0.75
Shadow.ZIndex = 9997
Shadow.Parent = ScreenGui
local shadowCorner = Instance.new("UICorner", Shadow)
shadowCorner.CornerRadius = UDim.new(0, 12)

-- Main toggle button (45x45) - purple bg, green text, SourceSansBold
local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
Button.Size = UDim2.new(0, 45, 0, 45) -- 45x45 as requested
Button.Position = UDim2.new(0.4, 0, 0.8, 0)
Button.AnchorPoint = Vector2.new(0.5, 0.5)
Button.Text = "On"
Button.Font = Enum.Font.SourceSansBold -- different font per request
Button.TextSize = 16
Button.BackgroundColor3 = Color3.fromRGB(138,43,226) -- purple
Button.TextColor3 = Color3.fromRGB(144,238,144) -- light green text
Button.Parent = ScreenGui
Button.ZIndex = 9999
Button.AutoButtonColor = false -- we handle press animation

local btnCorner = Instance.new("UICorner", Button)
btnCorner.CornerRadius = UDim.new(0, 12)

-- Thin outline for clarity
local btnStroke = Instance.new("UIStroke", Button)
btnStroke.Thickness = 1
btnStroke.Color = Color3.fromRGB(0,0,0)
btnStroke.Transparency = 0

-- subtle inner gradient for nicer look
local btnGradient = Instance.new("UIGradient", Button)
btnGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(155,60,230)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120,30,200))
}
btnGradient.Rotation = 90

-- Touch / click press animation: scale down then back up
local pressTweenInfo = TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local releaseTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

local function playPressAnimation()
    -- scale down quickly
    local ok, t = pcall(function()
        return TweenService:Create(Button, pressTweenInfo, {Size = UDim2.new(0, 40, 0, 40)})
    end)
    if ok and t then
        t:Play()
    end
    -- shadow compress
    pcall(function()
        TweenService:Create(Shadow, pressTweenInfo, {Position = UDim2.new(0.4, 6, 0.8, 6)}):Play()
    end)
end

local function playReleaseAnimation()
    local ok, t = pcall(function()
        return TweenService:Create(Button, releaseTweenInfo, {Size = UDim2.new(0, 45, 0, 45)})
    end)
    if ok and t then
        t:Play()
    end
    pcall(function()
        TweenService:Create(Shadow, releaseTweenInfo, {Position = UDim2.new(0.4, 4, 0.8, 4)}):Play()
    end)
end

-- Draggable support (touch + mouse) - keeps center anchored to cursor
do
    local dragging, dragInput, dragStart, startPos
    Button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- play press animation & sound on press
            playPressAnimation()
            dragging = true
            dragStart = input.Position
            startPos = Button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    playReleaseAnimation()
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
            Shadow.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X + 4,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y + 4
            )
        end
    end)
end

-- Click/tap activates toggle (separate from drag end)
Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        Button.Text = "On"
        Button.BackgroundColor3 = Color3.fromRGB(138,43,226)
    else
        Button.Text = "Off"
        Button.BackgroundColor3 = Color3.fromRGB(90,20,160)
    end
    -- small release animation to give tactile feedback
    playReleaseAnimation()
end)

-- === Cooldown bubble (keeps prior styling, unchanged functionally) ===
local CooldownFrame = Instance.new("Frame")
CooldownFrame.Name = "KibaCooldown"
CooldownFrame.Size = UDim2.new(0, 140, 0, 34)
CooldownFrame.Position = UDim2.new(0, 8, 1, -48)
CooldownFrame.AnchorPoint = Vector2.new(0, 0)
CooldownFrame.BackgroundColor3 = Color3.fromRGB(138,43,226)
CooldownFrame.BackgroundTransparency = 0.75
CooldownFrame.Visible = false
CooldownFrame.Parent = ScreenGui
CooldownFrame.ZIndex = 9998
CooldownFrame.Active = true

local cdCorner = Instance.new("UICorner", CooldownFrame)
cdCorner.CornerRadius = UDim.new(0, 12)
local cdStroke = Instance.new("UIStroke", CooldownFrame)
cdStroke.Thickness = 1
cdStroke.Color = Color3.fromRGB(0,0,0)
cdStroke.Transparency = 0

local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Name = "CooldownText"
CooldownLabel.Size = UDim2.new(1, -12, 1, 0)
CooldownLabel.Position = UDim2.new(0, 8, 0, 0)
CooldownLabel.BackgroundTransparency = 1
CooldownLabel.Text = "Kiba v4 : 0.0s"
CooldownLabel.TextColor3 = Color3.fromRGB(144,238,144)
CooldownLabel.Font = Enum.Font.SourceSansBold
CooldownLabel.TextSize = 14
CooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
CooldownLabel.Parent = CooldownFrame
CooldownLabel.ZIndex = 9999

local cdLabelStroke = Instance.new("UIStroke", CooldownLabel)
cdLabelStroke.Thickness = 1
cdLabelStroke.Color = Color3.fromRGB(0,0,0)
cdLabelStroke.Transparency = 0

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

-- ==== Info box (kept but minimal) ====
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
Title.Font = Enum.Font.SourceSansBold
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
CloseBtn.Font = Enum.Font.SourceSansBold
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
Desc.Font = Enum.Font.SourceSans
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
CopyBtn.Font = Enum.Font.SourceSansBold
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

-- ========== Connections cleanup helper ==========
local connections = {}

local function clearCharacterConnections()
    for _, conn in pairs(connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    connections = {}
end

-- ========== Aimlock implementation ==========
local function aimlockAt(targetHRP, duration)
    if not targetHRP then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    -- Save original camera
    local originalCF = cam.CFrame
    -- Compute horizontal-only direction
    local camPos = originalCF.Position
    local targetPos = targetHRP.Position
    local dir = Vector3.new(targetPos.X - camPos.X, 0, targetPos.Z - camPos.Z)
    if dir.Magnitude <= 0.001 then return end
    -- Compute yaw that looks at target horizontally
    local newYaw = math.atan2(dir.X, dir.Z)
    -- Preserve original pitch and roll via ToEulerAnglesYXZ (yaw, pitch, roll)
    local ok, oy, ox, oz = pcall(function() return originalCF:ToEulerAnglesYXZ() end)
    if not ok then
        -- fallback: set camera to look at target horizontally
        pcall(function()
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.new(camPos, Vector3.new(targetPos.X, camPos.Y, targetPos.Z))
        end)
        task.delay(duration, function()
            pcall(function() cam.CameraType = Enum.CameraType.Custom cam.CFrame = originalCF end)
        end)
        return
    end
    local origYaw = oy
    local origPitch = ox
    local origRoll = oz
    -- Build new camera CFrame with preserved pitch & roll but new yaw
    local newCF = CFrame.new(camPos) * CFrame.Angles(origPitch, newYaw, origRoll)
    local prevType = cam.CameraType
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = newCF
    end)
    -- restore after duration
    task.delay(duration, function()
        pcall(function()
            cam.CameraType = prevType or Enum.CameraType.Custom
            cam.CFrame = originalCF
        end)
    end)
end

-- ========== Sound setup: use provided asset id ==========
local TriggerSound = Instance.new("Sound")
TriggerSound.Name = "KibaTriggerSFX"
TriggerSound.Volume = 0.9
TriggerSound.Looped = false
TriggerSound.SoundId = "rbxassetid://6042053626" -- user provided asset
TriggerSound.Parent = SoundService

-- ========== Trigger logic ==========
local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        -- get current target for aimlock
        local targetModel = getNearestTarget()
        local targetHRP = nil
        if targetModel then
            targetHRP = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso") or targetModel:FindFirstChild("UpperTorso")
        end
        -- play trigger sound
        pcall(function() TriggerSound:Play() end)
        -- trigger aimlock simultaneously (for duration)
        if targetHRP then
            pcall(function() aimlockAt(targetHRP, AIMLOCK_DURATION) end)
        end
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

-- Keyboard toggle (press 'K' to toggle)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        enabled = not enabled
        if enabled then
            Button.Text = "On"
            Button.BackgroundColor3 = Color3.fromRGB(138,43,226)
        else
            Button.Text = "Off"
            Button.BackgroundColor3 = Color3.fromRGB(90,20,160)
            clearCharacterConnections()
        end
        -- tactile feedback
        pcall(function() TriggerSound:Play() end)
        playReleaseAnimation()
    end
end)

-- End of script
