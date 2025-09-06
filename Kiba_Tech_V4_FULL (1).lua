
--// Merebennie Custom Stick Dash (Delta Mobile Compatible)
-- Version: Kiba Tech V4
-- Activation flow:
-- 1) Detect animation -> 2) wait 0.3s -> 3) stick to nearest target -> 4) immobilize (+0.2s after finish)
-- 5) fire Q instantly -> 6) wait 0.2s -> 7) lay down for 0.3s -> 8) stand up -> restore control

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Runtime vars
local Character, Humanoid, HumanoidRootPart
local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.35
local enabled = true
local uiOnCooldown = false
local COOLDOWN_DURATION = 7
local IMMOB_EXTRA_AFTER = 0.2
local STICK_HEARTBEAT_CONN
local IMMOB_HEARTBEAT_CONN

-- === Utility: find nearest target ===
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

-- === FireServer Q logic ===
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
end

-- === Main stick dash sequence ===
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
        saved.AutoRotate = Humanoid.AutoRotate
    end)

    local function startImmobilize()
        if not Humanoid or not HumanoidRootPart then return end
        pcall(function()
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            Humanoid.PlatformStand = true
            Humanoid.AutoRotate = false
            HumanoidRootPart.Velocity = Vector3.new(0,0,0)
            HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
        end)

        IMMOB_HEARTBEAT_CONN = RunService.Heartbeat:Connect(function()
            if HumanoidRootPart then
                HumanoidRootPart.Velocity = Vector3.new(0,0,0)
                HumanoidRootPart.RotVelocity = Vector3.new(0,0,0)
            end
            Humanoid.WalkSpeed = 0
        end)
    end

    local function stopImmobilize()
        if IMMOB_HEARTBEAT_CONN then pcall(function() IMMOB_HEARTBEAT_CONN:Disconnect() end) end
        if STICK_HEARTBEAT_CONN then pcall(function() STICK_HEARTBEAT_CONN:Disconnect() end) end
        pcall(function()
            Humanoid.WalkSpeed = saved.WalkSpeed or 16
            Humanoid.JumpPower = saved.JumpPower or 50
            Humanoid.PlatformStand = saved.PlatformStand or false
            Humanoid.AutoRotate = saved.AutoRotate
        end)
    end

    STICK_HEARTBEAT_CONN = RunService.Heartbeat:Connect(function()
        if HumanoidRootPart and targetHRP then
            HumanoidRootPart.CFrame = CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(85),0,0)
        end
    end)

    startImmobilize()
    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)

    fireQ()

    task.delay(0.2, function()
        pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll) end)
        task.delay(0.3, function()
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.delay(IMMOB_EXTRA_AFTER, function()
                stopImmobilize()
            end)
        end)
    end)
end

-- === GUI ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KibaTechV4Gui"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

-- Toggle Button
local Button = Instance.new("TextButton")
Button.Size = UDim2.new(0, 160, 0, 36)
Button.Position = UDim2.new(0.35, 0, 0.8, 0)
Button.Text = "Kiba Tech V4:On"
Button.Font = Enum.Font.FredokaOne
Button.TextSize = 16
Button.BackgroundColor3 = Color3.fromRGB(100,100,100)
Button.TextColor3 = Color3.new(1,1,1)
Button.Parent = ScreenGui
local btnCorner = Instance.new("UICorner", Button)
btnCorner.CornerRadius = UDim.new(0, 10)

Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    Button.Text = enabled and "Kiba Tech V4:On" or "Kiba Tech V4:Off"
end)

-- Cooldown UI
local CooldownFrame = Instance.new("Frame")
CooldownFrame.Size = UDim2.new(0, 160, 0, 36)
CooldownFrame.Position = UDim2.new(0, 10, 1, -50)
CooldownFrame.BackgroundColor3 = Color3.fromRGB(128,0,128)
CooldownFrame.BackgroundTransparency = 0.3
CooldownFrame.Visible = false
CooldownFrame.Parent = ScreenGui
local cdCorner = Instance.new("UICorner", CooldownFrame)
cdCorner.CornerRadius = UDim.new(0, 12)

local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Size = UDim2.new(1, -10, 1, 0)
CooldownLabel.Position = UDim2.new(0, 5, 0, 0)
CooldownLabel.BackgroundTransparency = 1
CooldownLabel.Text = "Cooldown: 0.0s"
CooldownLabel.TextColor3 = Color3.fromRGB(0,255,0)
CooldownLabel.Font = Enum.Font.FredokaOne
CooldownLabel.TextSize = 14
CooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
CooldownLabel.Parent = CooldownFrame

-- Cooldown Function
local function startUICooldown(duration)
    if uiOnCooldown then return end
    uiOnCooldown = true
    CooldownFrame.Visible = true
    local startTime = tick()
    local remaining = duration
    while remaining > 0 do
        remaining = duration - (tick() - startTime)
        if remaining < 0 then remaining = 0 end
        CooldownLabel.Text = string.format("Cooldown: %.1fs", remaining)
        task.wait(0.1)
    end
    uiOnCooldown = false
    CooldownFrame.Visible = false
end

-- Character + anim detect
local connections = {}
local function clearCharacterConnections()
    for _, conn in pairs(connections) do
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end
    connections = {}
end

local function tryTrigger()
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        task.spawn(function()
            task.wait(0.3)
            stickDash()
        end)
        task.spawn(function() startUICooldown(COOLDOWN_DURATION) end)
    end
end

local function onAnimationPlayed(track)
    if not track then return end
    local anim = track.Animation
    if not anim then return end
    local animId = tostring(anim.AnimationId or "")
    if string.find(animId, "10503381238", 1, true) then
        pcall(function() track:Stop() end)
        pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
        tryTrigger()
    end
end

local function setupCharacter(char)
    clearCharacterConnections()
    Character = char
    Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart", 5)
    if not Humanoid or not HumanoidRootPart then return end
    table.insert(connections, Humanoid.AnimationPlayed:Connect(onAnimationPlayed))
    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then table.insert(connections, animator.AnimationPlayed:Connect(onAnimationPlayed)) end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    setupCharacter(char)
end)
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
