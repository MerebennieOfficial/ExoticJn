-- Full Circular Tween UI With Ads + Aimlock + Side Animations + Keybinds (PC X, Controller X & Square)
-- All-in-one raw script for executor (drop into executor as-is)

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace

-- REBIND ON RESPAWN
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

-- CONFIG (adjustable)
local MAX_RANGE            = 80      -- search range
local ARC_APPROACH_RADIUS  = 6       -- arc mid radius
local BEHIND_DISTANCE      = 4       -- final landing gap behind target
local TOTAL_TIME           = 0.22    -- full arc time (seconds)
local MIN_RADIUS           = 1.2
local MAX_RADIUS           = 14

-- Keybinds
local KEYBIND_KEYCODE      = Enum.KeyCode.X        -- keyboard PC key
local CONTROLLER_KEYCODE_X = Enum.KeyCode.ButtonX  -- controller X button
local CONTROLLER_KEYCODE_SQ = Enum.KeyCode.ButtonSquare -- controller Square (if supported)

-- ANIMATIONS (explicit mapping)
local ANIM_LEFT_ID  = 10480796021
local ANIM_RIGHT_ID = 10480793962

-- SFX IDs (press + dash)
local PRESS_SFX_ID = "rbxassetid://5852470908"
local DASH_SFX_ID  = "rbxassetid://72014632956520"

-- DISCORD LINK (for copy)
local DISCORD_LINK = "https://discord.gg/eJjXhEbmUD"

-- STATE
local busy = false
local aimlockConn = nil
local currentAnimTrack = nil
local uiOpen = true -- controls whether the UI is active

-- create dash SFX (global)
local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SFX_ID
dashSound.Volume = 2.0
dashSound.Looped = false
dashSound.Parent = workspace

-- create press SFX (global, used by UI/keybinds)
local pressSound = Instance.new("Sound")
pressSound.Name = "PressSFX_Global"
pressSound.SoundId = PRESS_SFX_ID
pressSound.Volume = 0.9
pressSound.Looped = false
pressSound.Parent = workspace

-- pointer to UI button (so keybinds can flash/scale it)
local circularButton = nil

-- HELPERS
local function shortestAngleDelta(target, current)
    local delta = target - current
    while delta > math.pi do delta = delta - 2*math.pi end
    while delta < -math.pi do delta = delta + 2*math.pi end
    return delta
end

local function easeOutCubic(t)
    t = math.clamp(t, 0, 1)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function ensureHumanoidAndAnimator()
    if not Character or not Character.Parent then return nil, nil end
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then
        hum = Character:FindFirstChild("Humanoid") or nil
        if not hum then return nil, nil end
    end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Name = "Animator"
        animator.Parent = hum
    end
    return hum, animator
end

local function playSideAnimation(isLeft)
    pcall(function()
        if currentAnimTrack and currentAnimTrack.IsPlaying then
            currentAnimTrack:Stop()
        end
        currentAnimTrack = nil
    end)

    local hum, animator = ensureHumanoidAndAnimator()
    if not hum or not animator then return end

    local animId = isLeft and ANIM_LEFT_ID or ANIM_RIGHT_ID
    if not animId then return end

    local anim = Instance.new("Animation")
    anim.Name = "CircularSideAnim"
    anim.AnimationId = "rbxassetid://" .. tostring(animId)

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then
        anim:Destroy()
        return
    end

    currentAnimTrack = track
    track.Priority = Enum.AnimationPriority.Action
    track:Play()

    -- play dash SFX when animation starts
    pcall(function()
        if dashSound and dashSound.Parent then
            dashSound:Stop()
            dashSound:Play()
        end
    end)

    delay(TOTAL_TIME + 0.15, function()
        if track and track.IsPlaying then
            pcall(function() track:Stop() end)
        end
        pcall(function() anim:Destroy() end)
    end)
end

-- Choose best aim part on target (Head -> HumanoidRootPart -> PrimaryPart -> any BasePart)
local function getAimPart(target)
    if not target then return nil end
    if target:FindFirstChild("Head") and target.Head:IsA("BasePart") then
        return target.Head
    end
    if target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart:IsA("BasePart") then
        return target.HumanoidRootPart
    end
    if target.PrimaryPart and target.PrimaryPart:IsA("BasePart") then
        return target.PrimaryPart
    end
    for _, v in pairs(target:GetChildren()) do
        if v:IsA("BasePart") then return v end
    end
    return nil
end

-- Get nearest player or NPC within maxRange
local function getNearestTarget(maxRange)
    maxRange = maxRange or MAX_RANGE
    local nearest, nearestDist = nil, math.huge
    if not HRP then return nil end
    local myPos = HRP.Position

    -- players
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") then
            local hum = pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos = pl.Character.HumanoidRootPart.Position
                local d = (pos - myPos).Magnitude
                if d < nearestDist and d <= maxRange then
                    nearestDist, nearest = d, pl.Character
                end
            end
        end
    end

    -- NPCs
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            local owner = Players:GetPlayerFromCharacter(obj)
            if not owner then
                local hum = obj:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local pos = obj.HumanoidRootPart.Position
                    local d = (pos - myPos).Magnitude
                    if d < nearestDist and d <= maxRange then
                        nearestDist, nearest = d, obj
                    end
                end
            end
        end
    end

    return nearest, nearestDist
end

-- Smooth circular arc tween that approaches ARC_APPROACH_RADIUS then lands BEHIND_DISTANCE behind target
-- Aimlock: yaw-only. Keeps pitch unchanged.
local function smoothArcToBack(targetModel)
    if busy then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end
    busy = true

    -- clear any leftover aimlock
    if aimlockConn and aimlockConn.Connected then
        aimlockConn:Disconnect()
        aimlockConn = nil
    end

    local targetHRP = targetModel.HumanoidRootPart
    local center = targetHRP.Position
    local myPos = HRP.Position

    -- final position behind target
    local lookVec = targetHRP.CFrame.LookVector -- target's forward facing direction
    local finalPos = center - lookVec * BEHIND_DISTANCE
    finalPos = Vector3.new(finalPos.X, center.Y + 1.5, finalPos.Z)

    -- radii & angles
    local startRadius = (Vector3.new(myPos.X, 0, myPos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
    local midRadius   = math.clamp(ARC_APPROACH_RADIUS, MIN_RADIUS, MAX_RADIUS)
    local endRadius   = (Vector3.new(finalPos.X, 0, finalPos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude

    local startAngle = math.atan2(myPos.Z - center.Z, myPos.X - center.X)
    local endAngle   = math.atan2(finalPos.Z - center.Z, finalPos.X - center.X)
    local deltaAngle = shortestAngleDelta(endAngle, startAngle)

    -- explicit mapping: positive deltaAngle => counter-clockwise (left)
    local isLeft = (deltaAngle > 0)

    -- debug (remove if you don't need it)
    -- print(string.format("[CircularTweenUI] deltaAngle: %.3f -> playing %s", deltaAngle, isLeft and "LEFT" or "RIGHT"))

    -- start side animation
    pcall(function()
        playSideAnimation(isLeft)
    end)

    -- Prepare yaw-only aimlock interpolation:
    local cam = workspace.CurrentCamera
    local startLook = Vector3.new(0,0,1)
    if cam and cam.CFrame then
        startLook = cam.CFrame.LookVector
    end

    -- Preserve camera pitch (do NOT change up/down)
    local startPitch = math.asin(math.clamp(startLook.Y, -0.999, 0.999))
    local startYaw   = math.atan2(startLook.Z, startLook.X)

    -- Desired yaw is the horizontal facing of the target's LookVector (ignore its Y)
    local desiredYaw = math.atan2(lookVec.Z, lookVec.X)

    -- heartbeat-driven tween (movement + yaw-only aimlock together)
    local startY = myPos.Y
    local endY = finalPos.Y

    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local now = tick()
        local elapsed = now - startTime
        local t = math.clamp(elapsed / TOTAL_TIME, 0, 1)
        local e = easeOutCubic(t)

        -- two-phase radius interpolation for positional arc:
        local midT = 0.5
        local radiusNow
        if t <= midT then
            local e1 = easeOutCubic(t / midT)
            radiusNow = startRadius + (midRadius - startRadius) * e1
        else
            local e2 = easeOutCubic((t - midT) / (1 - midT))
            radiusNow = midRadius + (endRadius - midRadius) * e2
        end
        radiusNow = math.clamp(radiusNow, MIN_RADIUS, MAX_RADIUS)

        local angleNow = startAngle + deltaAngle * e
        local x = center.X + radiusNow * math.cos(angleNow)
        local z = center.Z + radiusNow * math.sin(angleNow)
        local y = startY + (endY - startY) * e

        local posNow = Vector3.new(x, y, z)

        -- interpolate yaw only
        local deltaYaw = shortestAngleDelta(desiredYaw, startYaw)
        local yawNow = startYaw + deltaYaw * e
        local pitchNow = startPitch -- preserved

        -- build look vector using preserved pitch and interpolated yaw
        local cosP = math.cos(pitchNow)
        local lx = math.cos(yawNow) * cosP
        local ly = math.sin(pitchNow)
        local lz = math.sin(yawNow) * cosP
        local lookNow = Vector3.new(lx, ly, lz)

        -- HRP should face horizontally according to yawNow (no vertical tilt)
        local hrpLook = Vector3.new(math.cos(yawNow), 0, math.sin(yawNow))

        pcall(function()
            HRP.CFrame = CFrame.new(posNow, posNow + hrpLook)
        end)

        -- Apply camera yaw-only rotation while preserving pitch and position
        pcall(function()
            if cam and cam.CFrame then
                local camPos = cam.CFrame.Position
                cam.CFrame = CFrame.new(camPos, camPos + lookNow)
            end
        end)

        if t >= 1 then
            conn:Disconnect()
            pcall(function()
                -- ensure final snap aligns to target's horizontal facing (yaw only)
                HRP.CFrame = CFrame.new(finalPos, finalPos + Vector3.new(lookVec.X, 0, lookVec.Z))
            end)
            -- stop animation track if still playing
            pcall(function()
                if currentAnimTrack and currentAnimTrack.IsPlaying then
                    currentAnimTrack:Stop()
                end
                currentAnimTrack = nil
            end)
            busy = false
        end
    end)
end

-- Create Ads box (smooth edges, title, description, copy link, close round button)
local function createAdsBox(parent)
    local frame = Instance.new("Frame")
    frame.Name = "MerebennieAdBox"
    frame.Size = UDim2.new(0, 320, 0, 132)
    frame.Position = UDim2.new(0.02, 0, 0.72, 0)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    -- smooth corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    -- subtle stroke
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.7
    stroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "AdTitle"
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Made by Merebennie"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Parent = frame

    -- Description
    local desc = Instance.new("TextLabel")
    desc.Name = "AdDesc"
    desc.Size = UDim2.new(1, -20, 0, 40)
    desc.Position = UDim2.new(0, 12, 0, 36)
    desc.BackgroundTransparency = 1
    desc.Text = "This is Merebennie ads. Join our discord for more scripts!"
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Font = Enum.Font.SourceSans
    desc.TextSize = 14
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.RichText = false
    desc.Parent = frame

    -- Copy Link Button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Name = "CopyLinkButton"
    copyBtn.Size = UDim2.new(0, 150, 0, 36)
    copyBtn.Position = UDim2.new(0, 12, 0, 80)
    copyBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    copyBtn.BorderSizePixel = 0
    copyBtn.Font = Enum.Font.SourceSansBold
    copyBtn.Text = "Copy Link"
    copyBtn.TextSize = 15
    copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
    copyBtn.Parent = frame

    local ccorner = Instance.new("UICorner")
    ccorner.CornerRadius = UDim.new(0, 8)
    ccorner.Parent = copyBtn

    -- Feedback label
    local feedback = Instance.new("TextLabel")
    feedback.Name = "CopyFeedback"
    feedback.Size = UDim2.new(0, 150, 0, 22)
    feedback.Position = UDim2.new(0, 170, 0, 86)
    feedback.BackgroundTransparency = 1
    feedback.Text = ""
    feedback.Font = Enum.Font.SourceSans
    feedback.TextSize = 14
    feedback.TextColor3 = Color3.fromRGB(170,170,170)
    feedback.TextXAlignment = Enum.TextXAlignment.Left
    feedback.Parent = frame

    -- Close round button (top-right of frame, circular)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseUI"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0, 8)
    closeBtn.AnchorPoint = Vector2.new(0,0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.Text = "✕"
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(240,240,240)
    closeBtn.Parent = frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 14)
    closeCorner.Parent = closeBtn

    -- Copy action logic
    copyBtn.MouseButton1Click:Connect(function()
        local ok = false
        local success, err = pcall(function()
            if setclipboard then
                setclipboard(DISCORD_LINK)
            elseif syn and syn.set_clipboard then
                syn.set_clipboard(DISCORD_LINK)
            elseif set_clipboard then
                set_clipboard(DISCORD_LINK)
            else
                error(\"no clipboard available\")
            end
        end)

        if success then
            ok = true
        else
            ok = false
        end

        if ok then
            feedback.Text = "Copied!"
            feedback.TextColor3 = Color3.fromRGB(120,255,140)
            delay(1.5, function()
                if feedback and feedback.Parent then
                    feedback.Text = ""
                end
            end)
        else
            feedback.Text = "Unable to auto-copy. Link shown on button."
            feedback.TextColor3 = Color3.fromRGB(255,160,120)
            copyBtn.Text = DISCORD_LINK
            delay(3, function()
                if copyBtn and copyBtn.Parent then
                    copyBtn.Text = "Copy Link"
                end
                if feedback and feedback.Parent then
                    feedback.Text = ""
                end
            end)
        end
    end)

    -- Close action: destroy UI and disable keybinds
    closeBtn.MouseButton1Click:Connect(function()
        uiOpen = false
        local root = parent:FindFirstChild("CircularTweenUI")
        if root then
            pcall(function() root:Destroy() end)
        end
        circularButton = nil
        print("[CircularTweenUI] UI closed by user.")
    end)

    return frame
end

-- UI: movable 110x110 image button, mobile-friendly — tap to activate, hold+drag to move
local function createUI()
    pcall(function()
        local old = game:GetService("CoreGui"):FindFirstChild("CircularTweenUI")
        if old then old:Destroy() end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CircularTweenUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")

    local button = Instance.new("ImageButton")
    button.Name = "DashButton"
    button.Size = UDim2.new(0, 110, 0, 110)
    button.Position = UDim2.new(0.5, -55, 0.8, -55)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = "rbxassetid://99317918824094"
    button.Active = true
    button.Parent = screenGui

    -- expose to outer scope so keyboard/controller can flash/scale it
    circularButton = button

    -- press animation scale
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = button

    -- local press sound (kept for button-local playback if desired)
    local localPress = Instance.new("Sound")
    localPress.Name = "PressSFX"
    localPress.SoundId = PRESS_SFX_ID
    localPress.Volume = 0.9
    localPress.Looped = false
    localPress.Parent = button

    -- drag + click system (per-input tracking)
    local isPointerDown = false
    local isDragging = false
    local pointerStartPos = nil
    local buttonStartPos = nil
    local dragThreshold = 8
    local trackedInput = nil

    local function tweenUIScale(toScale, time)
        time = time or 0.06
        local ok, tw = pcall(function()
            return TweenService:Create(uiScale, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = toScale})
        end)
        if ok and tw then tw:Play() end
    end

    local function startPointer(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPointerDown = true
            isDragging = false
            pointerStartPos = input.Position
            buttonStartPos = button.Position
            trackedInput = input

            -- immediate feedback
            tweenUIScale(0.92, 0.06)
            pcall(function() localPress:Play() end)

            -- fallback end handler on the input itself
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    -- handled by InputEnded global; no-op here
                end
            end)
        end
    end

    local function updatePointer(input)
        if not isPointerDown or not pointerStartPos then return end
        if input ~= trackedInput then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local delta = input.Position - pointerStartPos
        if not isDragging and delta.Magnitude >= dragThreshold then
            isDragging = true
            tweenUIScale(1, 0.06)
        end

        if isDragging then
            local screenW = workspace.CurrentCamera.ViewportSize.X
            local screenH = workspace.CurrentCamera.ViewportSize.Y
            local newX = buttonStartPos.X.Offset + delta.X
            local newY = buttonStartPos.Y.Offset + delta.Y
            newX = math.clamp(newX, 0, screenW - button.AbsoluteSize.X)
            newY = math.clamp(newY, 0, screenH - button.AbsoluteSize.Y)
            button.Position = UDim2.new(0, newX, 0, newY)
        end
    end

    UserInputService.InputChanged:Connect(function(input)
        pcall(function() updatePointer(input) end)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input ~= trackedInput then return end
        if not isPointerDown then return end

        -- tap: activate tween+aimlock
        if not isDragging then
            if not busy and uiOpen then
                local target = getNearestTarget(MAX_RANGE)
                if not target then
                    pcall(function() button.ImageTransparency = 0.5 end)
                    delay(0.5, function() pcall(function() button.ImageTransparency = 0 end) end)
                else
                    pcall(function() button.ImageTransparency = 0.5 end)
                    -- start combined aimlock + tween (now handles yaw-only aimlock)
                    smoothArcToBack(target)
                    spawn(function()
                        while busy do RunService.Heartbeat:Wait() end
                        if button then pcall(function() button.ImageTransparency = 0 end) end
                    end)
                end
            end
        end

        tweenUIScale(1, 0.06)

      -- reset
        isPointerDown = false
        isDragging = false
        pointerStartPos = nil
        buttonStartPos = nil
        trackedInput = nil
    end)

    button.InputBegan:Connect(function(input)
        pcall(function() startPointer(input) end)
    end)

    -- Add the ads box to the screen GUI
    createAdsBox(screenGui)
end

-- Try activation helper used by keybinds (keeps same UX as button)
local function tryActivateFromKeybind()
    if busy or not uiOpen then return end
    -- if the user is typing in a TextBox, don't trigger
    if UserInputService:GetFocusedTextBox() then return end

    local target = getNearestTarget(MAX_RANGE)
    if not target then
        -- flash UI button if present
        if circularButton then
            pcall(function() circularButton.ImageTransparency = 0.5 end)
            delay(0.5, function() pcall(function() circularButton.ImageTransparency = 0 end) end)
        end
        pcall(function()
            pressSound:Stop()
            pressSound:Play()
        end)
        return
    end

    -- play small feedback on UI button if available
    if circularButton then
        -- scale briefly
        local uiScale = circularButton:FindFirstChildOfClass("UIScale")
        if uiScale then
            local ok, tw = pcall(function()
                return TweenService:Create(uiScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.92})
            end)
            if ok and tw then
                tw:Play()
                delay(0.06, function()
                    pcall(function()
                        local ok2, tw2 = pcall(function()
                            return TweenService:Create(uiScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
                        end)
                        if ok2 and tw2 then tw2:Play() end
                    end)
                end)
            end
        end
        pcall(function() circularButton.ImageTransparency = 0.5 end)
    end

    pcall(function()
        pressSound:Stop()
        pressSound:Play()
    end)

    -- start aimlock + tween
    smoothArcToBack(target)

    -- restore button transparency after busy
    spawn(function()
        while busy do RunService.Heartbeat:Wait() end
        if circularButton then pcall(function() circularButton.ImageTransparency = 0 end) end
    end)
end

-- Input handling for keyboard & controller (X button and Square)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    -- ignore if UI/game consumed it
    if gameProcessedEvent then return end
    -- avoid triggering while typing
    if UserInputService:GetFocusedTextBox() then return end

    if not uiOpen then return end

    -- Keyboard X
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == KEYBIND_KEYCODE then
        tryActivateFromKeybind()
    end

    -- Controller (Gamepad) X button
    if (input.UserInputType == Enum.UserInputType.Gamepad1 or
        input.UserInputType == Enum.UserInputType.Gamepad2 or
        input.UserInputType == Enum.UserInputType.Gamepad3 or
        input.UserInputType == Enum.UserInputType.Gamepad4)
        and (input.KeyCode == CONTROLLER_KEYCODE_X or input.KeyCode == CONTROLLER_KEYCODE_SQ) then
        tryActivateFromKeybind()
    end
end)

-- INIT
createUI()
print("[CircularTweenUI] Ready - drag or tap the DashButton. Press 'X' on keyboard or controller (or Square) to activate.")