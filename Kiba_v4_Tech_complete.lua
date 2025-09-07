-- Kiba v4 Tech (UI + Aimlock + Touch animation + Click sound) - Delta Mobile Friendly
-- Language: Lua (Delta mobile executor compatible)
-- Made for Merebennie

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

-- protect GUI helper (Delta / Synapse friendly)
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

-- core variables
local Character, Humanoid, HumanoidRootPart
local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.35
local enabled = true
local uiOnCooldown = false
local COOLDOWN_DURATION = 4.2
local IMMOB_EXTRA_AFTER = 0.3

local connections = {}
local aimlockConn = nil
local aimlockActive = false

-- audio assets
local ToggleClickSound = Instance.new("Sound")
ToggleClickSound.Name = "ToggleClick"
ToggleClickSound.SoundId = "rbxassetid://6042053626" -- provided by user
ToggleClickSound.Volume = 0.9
ToggleClickSound.Parent = SoundService

local TriggerSound = Instance.new("Sound")
TriggerSound.Name = "KibaTriggerSFX"
TriggerSound.Volume = 0.7
TriggerSound.Looped = false
TriggerSound.SoundId = "rbxassetid://183763515" -- existing trigger sound id (change if desired)
TriggerSound.Parent = SoundService

-- helper: nearest target search (players & NPCs)
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

-- aimlock: smoothly rotate camera to target for `duration` seconds (works for NPCs & players)
local function aimlockToTarget(targetHRP, duration)
    if not targetHRP or aimlockActive then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    aimlockActive = true
    local originalCamType = camera.CameraType
    -- switch to Scriptable so we can control camera reliably
    camera.CameraType = Enum.CameraType.Scriptable

    local startTime = tick()
    local function step()
        if not aimlockActive then return end
        if not targetHRP.Parent then return end
        local now = tick()
        local elapsed = now - startTime
        if elapsed >= duration then
            -- finish
            aimlockActive = false
            if aimlockConn then
                aimlockConn:Disconnect()
                aimlockConn = nil
            end
            pcall(function() camera.CameraType = originalCamType end)
            return
        end
        -- compute desired look CFrame that keeps camera position but looks at target
        local currentCFrame = camera.CFrame
        local desired = CFrame.lookAt(currentCFrame.Position, targetHRP.Position)
        -- smooth interpolation factor (tweak for smoothness)
        local alpha = 0.35
        camera.CFrame = currentCFrame:Lerp(desired, alpha)
    end

    -- connect to RenderStepped for per-frame smoothness
    aimlockConn = RunService.RenderStepped:Connect(step)
end

-- fire Q (existing behavior kept)
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

-- stickDash (unchanged core but now triggers aimlock at same time as fireQ)
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

    -- fireQ + aimlock triggered at the same moment (0.18s delay preserved)
    task.delay(0.18, function()
        pcall(fireQ)
        -- activate aimlock to this target for 0.5s
        pcall(function() aimlockToTarget(targetHRP, 0.5) end)
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

-- UI creation: small 50x50 toggle button (light black background, rainbow text outline)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Kiba_v4_StickDashGui"
ScreenGui.IgnoreGuiInset = true
protectAndParent(ScreenGui)

local Button = Instance.new("TextButton")
Button.Name = "StickDashToggle"
Button.Size = UDim2.new(0, 50, 0, 50) -- 50x50 as requested
Button.Position = UDim2.new(0.45, 0, 0.82, 0)
Button.Text = "On"
Button.Font = Enum.Font.GothamBold
Button.TextSize = 18
Button.BackgroundColor3 = Color3.fromRGB(30,30,30) -- light black per request
Button.TextColor3 = Color3.new(1,1,1)
Button.Parent = ScreenGui
Button.ZIndex = 9999
Button.Active = true
Button.AutoButtonColor = false -- we handle press animation

local btnCorner = Instance.new("UICorner", Button)
btnCorner.CornerRadius = UDim.new(0, 10)

-- rounded border (thin)
local btnStroke = Instance.new("UIStroke", Button)
btnStroke.Thickness = 2
btnStroke.Color = Color3.fromRGB(0,0,0)
btnStroke.Transparency = 0

-- text stroke (rainbow outline) -> use TextStroke properties on button
Button.TextStrokeTransparency = 0
Button.TextStrokeColor3 = Color3.fromHSV(0,1,1) -- will be animated

-- small press animation using TweenService
local pressTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local releaseTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local pressedSize = UDim2.new(0, 46, 0, 46)
local normalSize = UDim2.new(0, 50, 0, 50)

local function animatePress()
    pcall(function()
        TweenService:Create(Button, pressTweenInfo, {Size = pressedSize}):Play()
    end)
end
local function animateRelease()
    pcall(function()
        TweenService:Create(Button, releaseTweenInfo, {Size = normalSize}):Play()
    end)
end

-- make button draggable (touch + mouse)
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

-- toggle logic (handle both click and keyboard K)
local function setEnabled(val)
    enabled = val
    if enabled then
        Button.Text = "On"
        Button.BackgroundColor3 = Color3.fromRGB(30,30,30)
    else
        Button.Text = "Off"
        Button.BackgroundColor3 = Color3.fromRGB(20,20,20)
        -- cleanup character connections if disabling
        for _, conn in pairs(connections) do
            if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
        end
        connections = {}
    end
end

Button.MouseButton1Click:Connect(function()
    -- press animation + click sound
    animatePress()
    task.delay(0.08, animateRelease)
    pcall(function() ToggleClickSound:Play() end)

    setEnabled(not enabled)
end)

-- also respond to InputBegan for touch (to animate more responsively)
Button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        animatePress()
    end
end)
Button.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        animateRelease()
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.K then
        setEnabled(not enabled)
        pcall(function() ToggleClickSound:Play() end)
    end
end)

-- Cooldown UI (bottom-left small compact)
local CooldownFrame = Instance.new("Frame")
CooldownFrame.Name = "KibaCooldown"
CooldownFrame.Size = UDim2.new(0, 140, 0, 34)
CooldownFrame.Position = UDim2.new(0, 8, 1, -48)
CooldownFrame.AnchorPoint = Vector2.new(0,0)
CooldownFrame.BackgroundColor3 = Color3.fromRGB(138,43,226)
CooldownFrame.BackgroundTransparency = 0.75
CooldownFrame.Visible = false
CooldownFrame.Parent = ScreenGui
CooldownFrame.ZIndex = 9998

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
CooldownLabel.Font = Enum.Font.GothamBold
CooldownLabel.TextSize = 14
CooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
CooldownLabel.Parent = CooldownFrame
CooldownLabel.ZIndex = 9999

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
        task.wait(0.05)
    end

    uiOnCooldown = false
    CooldownFrame.Visible = false
    pcall(function() pulseTween:Cancel() end)
    pulseActive = false
end

-- Info box kept minimal
local InfoFrame = Instance.new("Frame")
InfoFrame.Name = "MerebennieInfoBox"
InfoFrame.Size = UDim2.new(0, 200, 0, 92)
InfoFrame.Position = UDim2.new(0.05, 0, 0.12, 0)
InfoFrame.BackgroundColor3 = Color3.fromRGB(240,240,240)
InfoFrame.Parent = ScreenGui
InfoFrame.ZIndex = 10000

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

-- connection clearing helper
local function clearCharacterConnections()
    for _, conn in pairs(connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    connections = {}
end

-- tryTrigger: plays trigger sound, handles cooldown and spawns stickDash
local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        pcall(function() TriggerSound:Play() end)
        task.spawn(function() pcall(stickDash) end)
        task.spawn(function() startUICooldown(COOLDOWN_DURATION) end)
    end
end

-- animation detection based triggers
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

-- Rainbow text stroke animation (cycles hue)
spawn(function()
    local hue = 0
    while task.wait(0.03) do
        hue = hue + 0.0045
        if hue > 1 then hue = 0 end
        local rgb = Color3.fromHSV(hue, 1, 1)
        pcall(function() Button.TextStrokeColor3 = rgb end)
    end
end)
