--// Merebennie Custom Stick Dash (Delta Mobile Compatible)
-- Activation flow EXACT:
-- 1) Detect animation -> 2) wait 0.3s -> 3) stick to nearest target -> 4) immobilize (plus +0.2s after finish)
-- 5) fire Q instantly -> 6) wait 0.2s -> 7) lay down for 0.3s -> 8) stand up -> restore control

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Protect / parent UI appropriately for various executors (Delta, Synapse, etc.)
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

-- runtime vars
local Character, Humanoid, HumanoidRootPart
local lastTrigger = 0
local TRIGGER_COOLDOWN = 0.35
local enabled = true
local uiOnCooldown = false
local COOLDOWN_DURATION = 7
local IMMOB_EXTRA_AFTER = 0.2 -- extra immobilize after full sequence
local STICK_HEARTBEAT_CONN -- holds stick movement connection
local IMMOB_HEARTBEAT_CONN -- holds immobilize zero-velocity connection

-- === Utility: find nearest player or npc ===
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

-- === FireServer Q logic (instant) ===
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

    -- try to clear moveme BodyVelocity if an executor helper exists
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

-- === Main stick dash sequence ===
local function stickDash()
    if not (Character and Humanoid and HumanoidRootPart) then return end

    local target = getNearestTarget()
    if not target then return end
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- Save movement state
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

    -- start immobilize function (keeps you from moving/interacting)
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

        -- remove common movers
        for _, v in pairs(Character:GetDescendants()) do
            local class = v.ClassName
            if class == "BodyVelocity" or class == "BodyPosition" or class == "BodyGyro" or class == "VectorForce" or class == "AlignPosition" or class == "AlignOrientation" or class == "LinearVelocity" or class == "AngularVelocity" then
                pcall(function() v:Destroy() end)
            end
        end

        -- heartbeat zeroing
        IMMOB_HEARTBEAT_CONN = RunService.Heartbeat:Connect(function()
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
        if IMMOB_HEARTBEAT_CONN and IMMOB_HEARTBEAT_CONN.Disconnect then
            pcall(function() IMMOB_HEARTBEAT_CONN:Disconnect() end)
            IMMOB_HEARTBEAT_CONN = nil
        end
        if STICK_HEARTBEAT_CONN and STICK_HEARTBEAT_CONN.Disconnect then
            pcall(function() STICK_HEARTBEAT_CONN:Disconnect() end)
            STICK_HEARTBEAT_CONN = nil
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

    -- Step 3: Stick to target (heartbeat maintains position)
    STICK_HEARTBEAT_CONN = RunService.Heartbeat:Connect(function()
        if not (HumanoidRootPart and targetHRP and targetHRP.Parent) then return end
        pcall(function()
            local desired = CFrame.new(targetHRP.Position - targetHRP.CFrame.LookVector * 0.3) * CFrame.Angles(math.rad(85), 0, 0)
            HumanoidRootPart.CFrame = desired
        end)
    end)

    -- Step 4: Immobilize character (keep this until final stop)
    startImmobilize()

    -- ensure Physics state to prevent immediate animation ragdoll
    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)

    -- Step 5: Fire Q instantly
    pcall(fireQ)

    -- Step 6: Wait 0.2s then Step 7: Lay down for 0.3s
    task.delay(0.2, function()
        pcall(function()
            if Humanoid and Humanoid.Parent then
                Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
            end
        end)

        task.delay(0.3, function()
            pcall(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
            -- After standing up, wait IMMOB_EXTRA_AFTER then restore controls
            task.delay(IMMOB_EXTRA_AFTER, function()
                pcall(stopImmobilize)
            end)
        end)
    end)
end

-- === Character setup & animation detection ===
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
    -- Block if OFF or currently on cooldown
    if not enabled or uiOnCooldown then return end
    if tick() - lastTrigger >= TRIGGER_COOLDOWN then
        lastTrigger = tick()
        -- WAIT 0.3s first (step 2), then run the full stickDash sequence
        task.spawn(function()
            task.wait(0.3)
            pcall(stickDash)
        end)
    end
end

-- Animation detection
local function onAnimationPlayed(track)
    if not track then return end
    local anim = track.Animation
    if not anim then return end
    local animId = tostring(anim.AnimationId or "")
    if string.find(animId, "10503381238", 1, true) then
        -- attempt to stop the track immediately (prevent auto-laydown)
        pcall(function()
            if track and typeof(track.Stop) == "function" then
                track:Stop()
            end
        end)
        -- force physics state to prevent immediate ragdoll, then trigger our controlled sequence
        pcall(function()
            if Humanoid then
                Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end
        end)
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
end

Players.LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    pcall(setupCharacter, char)
end)

if Players.LocalPlayer.Character then
    pcall(setupCharacter, Players.LocalPlayer.Character)
end



-- === UI Setup ===
local ScreenGui = Instance.new("ScreenGui")
protectAndParent(ScreenGui)

-- Cooldown UI
local CooldownFrame = Instance.new("Frame")
CooldownFrame.Size = UDim2.new(0, 150, 0, 40)
CooldownFrame.Position = UDim2.new(0.5, -75, 0.9, 0)
CooldownFrame.BackgroundColor3 = Color3.fromRGB(128, 0, 128) -- Purple
CooldownFrame.BackgroundTransparency = 0.3 -- 70% opacity
CooldownFrame.Parent = ScreenGui

local CooldownLabel = Instance.new("TextLabel")
CooldownLabel.Size = UDim2.new(1, 0, 1, 0)
CooldownLabel.BackgroundTransparency = 1
CooldownLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green text
CooldownLabel.Font = Enum.Font.Cartoon
CooldownLabel.Text = "Cooldown Ready"
CooldownLabel.Parent = CooldownFrame

-- On/Off UI
local ToggleFrame = Instance.new("Frame")
ToggleFrame.Size = UDim2.new(0, 85, 0, 50)
ToggleFrame.Position = UDim2.new(0.5, -42, 0.8, 0)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(128, 128, 128) -- Gray
ToggleFrame.Parent = ScreenGui

local ToggleLabel = Instance.new("TextLabel")
ToggleLabel.Size = UDim2.new(1, 0, 1, 0)
ToggleLabel.BackgroundTransparency = 1
ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text
ToggleLabel.Font = Enum.Font.FredokaOne
ToggleLabel.Text = "Kiba Tech V4:On"
ToggleLabel.Parent = ToggleFrame
