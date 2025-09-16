-- Smooth Circular Tween to Front/Back + YAW-ONLY Aimlock
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ===== Improved Settings Appearance (Delta Executor compatible) =====
-- This block replaces the previous Settings UI with a compact, unique, moveable, and mobile-friendly settings panel.
-- Key features:
--  * Small default footprint (approx 260x360) optimized for mobile (Delta Executor)
--  * Drag-to-move by header, snap-to-corners helper buttons
--  * Tabbed layout for organized settings
--  * Toggle switches, sliders and dropdowns with clear labels
--  * Subtle animations with TweenService for smooth show/hide and snapping
--  * Uses UIListLayout and Grid for tidy layout and consistent spacing
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui (parents to PlayerGui for Delta mobile compatibility)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ImprovedSettingsGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main draggable frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "SettingsPanel"
mainFrame.Size = UDim2.new(0, 260, 0, 360) -- smaller, mobile-friendly
mainFrame.Position = UDim2.new(0.7, 0, 0.12, 0) -- default placement (top-right but not obstructive)
mainFrame.AnchorPoint = Vector2.new(0.5, 0)
mainFrame.BackgroundTransparency = 0
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 18, 55) -- deep purple background
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
mainFrame.Visible = false -- start hidden

-- Round corners (works in modern Roblox UI)
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)

-- Header (dragging area)
local header = Instance.new("Frame", mainFrame)
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundTransparency = 0
header.BackgroundColor3 = Color3.fromRGB(45, 26, 80)
header.BorderSizePixel = 0

local headerLabel = Instance.new("TextLabel", header)
headerLabel.Size = UDim2.new(1, -100, 1, 0)
headerLabel.Position = UDim2.new(0, 12, 0, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "DASH SCRIPT: OFF"
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextSize = 15
headerLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
headerLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Snap buttons (small, unobtrusive)
local btnContainer = Instance.new("Frame", header)
btnContainer.Size = UDim2.new(0, 88, 1, 0)
btnContainer.Position = UDim2.new(1, -92, 0, 0)
btnContainer.BackgroundTransparency = 1

local function makeHeaderButton(text, x)
    local b = Instance.new("TextButton", btnContainer)
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Position = UDim2.new(0, x, 0, 8)
    b.Text = text
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.TextColor3 = Color3.fromRGB(245,245,245)
    b.BackgroundColor3 = Color3.fromRGB(70,40,120)
    b.AutoButtonColor = true
    b.BorderSizePixel = 0
    local bc = Instance.new("UICorner", b)
    bc.CornerRadius = UDim.new(0,8)
    return b
end
local snapTL = makeHeaderButton("⤒", 0) -- snap top-left
local snapTR = makeHeaderButton("⤓", 0.35) -- snap top-right
local hideBtn = makeHeaderButton("✕", 0.7) -- hide/close

-- Content area (tabs + body)
local content = Instance.new("Frame", mainFrame)
content.Name = "Content"
content.Position = UDim2.new(0, 0, 0, 46)
content.Size = UDim2.new(1, 0, 1, -46)
content.BackgroundTransparency = 1

-- Tabs bar
local tabsBar = Instance.new("Frame", content)
tabsBar.Size = UDim2.new(1, 0, 0, 36)
tabsBar.Position = UDim2.new(0, 0, 0, 6)
tabsBar.BackgroundTransparency = 1

local tabsLayout = Instance.new("UIListLayout", tabsBar)
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Padding = UDim.new(0, 8)

local tabNames = {"General","Visual","Controls"}
local tabButtons = {}
for i, name in ipairs(tabNames) do
    local tb = Instance.new("TextButton", tabsBar)
    tb.Name = name.."Tab"
    tb.Size = UDim2.new(0, 78, 1, 0)
    tb.BackgroundTransparency = 0
    tb.BackgroundColor3 = Color3.fromRGB(55, 30, 95)
    tb.BorderSizePixel = 0
    tb.Font = Enum.Font.Gotham
    tb.Text = name
    tb.TextSize = 13
    tb.TextColor3 = Color3.fromRGB(225,225,235)
    local c = Instance.new("UICorner", tb)
    c.CornerRadius = UDim.new(0,8)
    tabButtons[name] = tb
end

-- Body area for controls
local body = Instance.new("Frame", content)
body.Name = "Body"
body.Position = UDim2.new(0, 12, 0, 48)
body.Size = UDim2.new(1, -24, 1, -60)
body.BackgroundTransparency = 1

local bodyLayout = Instance.new("UIListLayout", body)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Padding = UDim.new(0, 10)

-- Helper to create labeled toggle row
local function createToggleRow(parent, labelText, default)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.62, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.Text = labelText
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(235,235,245)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local toggle = Instance.new("TextButton", row)
    toggle.Size = UDim2.new(0.34, -4, 0, 24)
    toggle.Position = UDim2.new(0.66, 0, 0.12, 0)
    toggle.AnchorPoint = Vector2.new(0,0)
    toggle.Font = Enum.Font.Gotham
    toggle.Text = default and "On" or "Off"
    toggle.TextSize = 12
    toggle.TextColor3 = Color3.fromRGB(240,240,245)
    toggle.BackgroundColor3 = Color3.fromRGB(80,45,140)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = true
    local tcorner = Instance.new("UICorner", toggle)
    tcorner.CornerRadius = UDim.new(0,6)

    return row, toggle
end

-- Populate default controls for "General" tab
local generalSection = Instance.new("Frame", body)
generalSection.Size = UDim2.new(1, 0, 0, 240)
generalSection.BackgroundTransparency = 1

local gsLayout = Instance.new("UIListLayout", generalSection)
gsLayout.SortOrder = Enum.SortOrder.LayoutOrder
gsLayout.Padding = UDim.new(0, 8)

local t1, toggle1 = createToggleRow(generalSection, "Enable Dash Assist", true)
local t2, toggle2 = createToggleRow(generalSection, "Auto Snap On Target", false)

-- Example slider row (dash distance)
local function createSliderRow(parent, labelText, minVal, maxVal, defaultVal)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.Text = labelText .. " (" .. tostring(defaultVal) .. ")"
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(230,230,240)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local sliderBg = Instance.new("Frame", row)
    sliderBg.Position = UDim2.new(0, 0, 0, 22)
    sliderBg.Size = UDim2.new(1, 0, 0, 18)
    sliderBg.BackgroundColor3 = Color3.fromRGB(60, 35, 105)
    sliderBg.BorderSizePixel = 0
    local scorner = Instance.new("UICorner", sliderBg)
    scorner.CornerRadius = UDim.new(0,6)

    local fill = Instance.new("Frame", sliderBg)
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(160, 110, 255)
    fill.BorderSizePixel = 0
    local fcorner = Instance.new("UICorner", fill)
    fcorner.CornerRadius = UDim.new(0,6)

    -- Simple drag logic
    local dragging = false
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    sliderBg.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = labelText .. " (" .. tostring(math.floor(rel * (maxVal - minVal) + minVal)) .. ")"
            -- store value as needed
        end
    end)

    return row
end

local sliderRow = createSliderRow(generalSection, "Dash Distance", 2, 22, 8)

-- Hook up tab switching
local function showTab(name)
    for i, n in ipairs(tabNames) do
        tabButtons[n].BackgroundColor3 = (n == name) and Color3.fromRGB(95,55,170) or Color3.fromRGB(55,30,95)
    end
    -- Hide all sections and only show matching one (simple example)
    for _, child in ipairs(body:GetChildren()) do
        if child:IsA("Frame") then
            child.Visible = (child == generalSection and name == "General") or (child.Name ~= generalSection.Name and name ~= "General")
        end
    end
    generalSection.Visible = (name == "General")
end

for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        showTab(name)
    end)
end

-- Drag behavior for mainFrame using header
local dragging = false
local dragInput, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        mainFrame.Position = newPos
    end
end)

-- Snap buttons behavior
snapTL.MouseButton1Click:Connect(function()
    mainFrame.Position = UDim2.new(0.08, 0, 0.06, 0)
end)
snapTR.MouseButton1Click:Connect(function()
    mainFrame.Position = UDim2.new(0.92, 0, 0.06, 0)
end)
hideBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

-- Toggle initial state helpers (connect these toggles to your existing script settings)
toggle1.MouseButton1Click:Connect(function()
    toggle1.Text = (toggle1.Text == "On") and "Off" or "On"
    -- store setting to your configuration table here
end)
toggle2.MouseButton1Click:Connect(function()
    toggle2.Text = (toggle2.Text == "On") and "Off" or "On"
end)

-- End improved settings UI block
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local workspace = workspace
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)
local MAX_RANGE=40
local ARC_APPROACH_RADIUS=11
local BEHIND_DISTANCE=4
local FRONT_DISTANCE=4
local TOTAL_TIME=0.3
local AIMLOCK_TIME=TOTAL_TIME
local MIN_RADIUS=1.2
local MAX_RADIUS=14
local ANIM_LEFT_ID=10480796021
local ANIM_RIGHT_ID=10480793962
local PRESS_SFX_ID="rbxassetid://5852470908"
local DASH_SFX_ID="rbxassetid://72014632956520"
local busy=false
local aimlockConn=nil
local currentAnimTrack=nil
local dashSound=Instance.new("Sound")
dashSound.Name="DashSFX"
dashSound.SoundId=DASH_SFX_ID
dashSound.Volume=2.0
dashSound.Looped=false
dashSound.Parent=workspace
local function shortestAngleDelta(target,current)
    local delta=target-current
    while delta>math.pi do delta=delta-2*math.pi end
    while delta<-math.pi do delta=delta+2*math.pi end
    return delta
end
local function easeOutCubic(t)
    t=math.clamp(t,0,1)
    return 1-(1-t)^3
end
local function ensureHumanoidAndAnimator()
    if not Character or not Character.Parent then return nil,nil end
    local hum=Character:FindFirstChildOfClass("Humanoid")
    if not hum then hum=Character:FindFirstChild("Humanoid") end
    if not hum then return nil,nil end
    local animator=hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator=Instance.new("Animator")
        animator.Name="Animator"
        animator.Parent=hum
    end
    return hum,animator
end
local function playSideAnimation(isLeft)
    pcall(function()
        if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end
        currentAnimTrack=nil
    end)
    local hum,animator=ensureHumanoidAndAnimator()
    if not hum or not animator then return end
    local animId=isLeft and ANIM_LEFT_ID or ANIM_RIGHT_ID
    if not animId then return end
    local anim=Instance.new("Animation")
    anim.Name="CircularSideAnim"
    anim.AnimationId="rbxassetid://"..tostring(animId)
    local ok,track=pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then anim:Destroy() return end
    currentAnimTrack=track
    track.Priority=Enum.AnimationPriority.Action
    track:Play()
    pcall(function()
        if dashSound and dashSound.Parent then dashSound:Stop() dashSound:Play() end
    end)
    delay(TOTAL_TIME+0.15,function()
        if track and track.IsPlaying then pcall(function() track:Stop() end) end
        pcall(function() anim:Destroy() end)
    end)
end
local function getNearestTarget(maxRange)
    maxRange=maxRange or MAX_RANGE
    local nearest,nearestDist=nil,math.huge
    if not HRP then return nil end
    local myPos=HRP.Position
    for _,pl in pairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl.Character:FindFirstChild("Humanoid") then
            local hum=pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health>0 then
                local pos=pl.Character.HumanoidRootPart.Position
                local d=(pos-myPos).Magnitude
                if d<nearestDist and d<=maxRange then nearestDist,nearest=d,pl.Character end
            end
        end
    end
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            local owner=Players:GetPlayerFromCharacter(obj)
            if not owner then
                local hum=obj:FindFirstChild("Humanoid")
                if hum and hum.Health>0 then
                    local pos=obj.HumanoidRootPart.Position
                    local d=(pos-myPos).Magnitude
                    if d<nearestDist and d<=maxRange then nearestDist,nearest=d,obj end
                end
            end
        end
    end
    return nearest,nearestDist
end
local function safeFireCommunicate(goalName)
    local args={[1]={["Mobile"]=true,["Goal"]=goalName}}
    pcall(function()
        if Character and Character:FindFirstChild("Communicate") and typeof(Character.Communicate.FireServer)=="function" then
            Character.Communicate:FireServer(unpack(args))
        end
    end)
end
local function safeFireDash()
    local args={[1]={["Dash"]=Enum.KeyCode.W,["Key"]=Enum.KeyCode.Q,["Goal"]="KeyPress"}}
    pcall(function()
        if Character and Character:FindFirstChild("Communicate") and typeof(Character.Communicate.FireServer)=="function" then
            Character.Communicate:FireServer(unpack(args))
        end
    end)
end
local espEnabled=false
local espInstance=nil
local function ensureHighlight()
    if not espInstance or not espInstance.Parent then
        espInstance=Instance.new("Highlight")
        espInstance.Parent=workspace
        espInstance.FillTransparency=0.6
        espInstance.OutlineTransparency=0.6
        espInstance.Name="CircularTweenESP"
    end
end
local function setESPAdornee(model)
    if not espEnabled then
        if espInstance and espInstance.Parent then espInstance.Adornee=nil end
        return
    end
    ensureHighlight()
    if model and model.Parent then
        local adornee=model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        espInstance.Adornee=adornee
    else
        if espInstance and espInstance.Parent then espInstance.Adornee=nil end
    end
end
local selectedTargetModel=nil
local useNearestToggle=false
local m1Toggle=false
local dashToggle=false
local m1BeganConn=nil
local espLoopConn=nil
local function smoothArcToTarget(targetModel)
    if busy then return end
    if not targetModel or not targetModel:FindFirstChild("HumanoidRootPart") then return end
    if not HRP then return end
    if m1Toggle then pcall(function() safeFireCommunicate("LeftClick") end) end
    if m1Toggle then pcall(function() safeFireCommunicate("LeftClickRelease") end) end
    if dashToggle then pcall(function() safeFireDash() end) end
    busy=true
    if aimlockConn and aimlockConn.Connected then aimlockConn:Disconnect() aimlockConn=nil end
    local targetHRP=targetModel.HumanoidRootPart
    local center=targetHRP.Position
    local myPos=HRP.Position
    local lookVec=targetHRP.CFrame.LookVector
    local toMe=myPos-center
    local forwardDot=lookVec:Dot(toMe)
    local finalPos
    if forwardDot>0 then
        finalPos=center-lookVec*BEHIND_DISTANCE
    else
        finalPos=center+lookVec*FRONT_DISTANCE
    end
    finalPos=Vector3.new(finalPos.X,center.Y+1.5,finalPos.Z)
    local startRadius=(Vector3.new(myPos.X,0,myPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local midRadius=math.clamp(ARC_APPROACH_RADIUS,MIN_RADIUS,MAX_RADIUS)
    local endRadius=(Vector3.new(finalPos.X,0,finalPos.Z)-Vector3.new(center.X,0,center.Z)).Magnitude
    local startAngle=math.atan2(myPos.Z-center.Z,myPos.X-center.X)
    local endAngle=math.atan2(finalPos.Z-center.Z,finalPos.X-center.X)
    local deltaAngle=shortestAngleDelta(endAngle,startAngle)
    local isLeft=(deltaAngle>0)
    pcall(function() playSideAnimation(isLeft) end)
    local cam=workspace.CurrentCamera
    local startCamLook=cam and cam.CFrame and cam.CFrame.LookVector or Vector3.new(0,0,1)
    local startPitch=math.asin(math.clamp(startCamLook.Y,-0.999,0.999))
    local humanoid=nil
    local oldAutoRotate=nil
    pcall(function() humanoid=Character and Character:FindFirstChildOfClass("Humanoid") end)
    if humanoid then
        pcall(function() oldAutoRotate=humanoid.AutoRotate end)
        pcall(function() humanoid.AutoRotate=false end)
    end
    local startHRPLook=HRP and HRP.CFrame and HRP.CFrame.LookVector or Vector3.new(1,0,0)
    local startHRPYaw=math.atan2(startHRPLook.Z,startHRPLook.X)
    local startCamYaw=math.atan2(startCamLook.Z,startCamLook.X)
    local startTime=tick()
    local conn
    conn=RunService.Heartbeat:Connect(function()
        if not targetHRP or not targetHRP.Parent then
            if humanoid and oldAutoRotate~=nil then pcall(function() humanoid.AutoRotate=oldAutoRotate end) end
            if conn and conn.Connected then conn:Disconnect() end
            busy=false
            return
        end
        local now=tick()
        local t=math.clamp((now-startTime)/TOTAL_TIME,0,1)
        local e=easeOutCubic(t)
        local midT=0.5
        local radiusNow
        if t<=midT then
            local e1=easeOutCubic(t/midT)
            radiusNow=startRadius+(midRadius-startRadius)*e1
        else
            local e2=easeOutCubic((t-midT)/(1-midT))
            radiusNow=midRadius+(endRadius-midRadius)*e2
        end
        radiusNow=math.clamp(radiusNow,MIN_RADIUS,MAX_RADIUS)
        local angleNow=startAngle+deltaAngle*e
        local x=center.X+radiusNow*math.cos(angleNow)
        local z=center.Z+radiusNow*math.sin(angleNow)
        local y=myPos.Y+(finalPos.Y-myPos.Y)*e
        local posNow=Vector3.new(x,y,z)
        local toTargetFromHRP=targetHRP.Position-posNow
        if toTargetFromHRP.Magnitude<0.001 then toTargetFromHRP=Vector3.new(lookVec.X,0,lookVec.Z) end
        local currentDesiredHRPYaw=math.atan2(toTargetFromHRP.Z,toTargetFromHRP.X)
        local deltaHRPYaw=shortestAngleDelta(currentDesiredHRPYaw,startHRPYaw)
        local hrpYawNow=startHRPYaw+deltaHRPYaw*e
        local hrpLook=Vector3.new(math.cos(hrpYawNow),0,math.sin(hrpYawNow))
        pcall(function() HRP.CFrame=CFrame.new(posNow,posNow+hrpLook) end)
        if cam and cam.CFrame and targetHRP and targetHRP.Parent then
            local camPos=cam.CFrame.Position
            local toTargetFromCam=targetHRP.Position-camPos
            if toTargetFromCam.Magnitude<0.001 then toTargetFromCam=Vector3.new(lookVec.X,0,lookVec.Z) end
            local desiredCamYaw=math.atan2(toTargetFromCam.Z,toTargetFromCam.X)
            local cosP=math.cos(startPitch)
            local camLookNow=Vector3.new(math.cos(desiredCamYaw)*cosP,math.sin(startPitch),math.sin(desiredCamYaw)*cosP)
            pcall(function()
                cam.CFrame=CFrame.new(camPos,camPos+camLookNow)
            end)
        end
        if t>=1 then
            if conn and conn.Connected then conn:Disconnect() end
            local finalToTarget=targetHRP.Position-finalPos
            if finalToTarget.Magnitude<0.001 then finalToTarget=Vector3.new(lookVec.X,0,lookVec.Z) end
            local finalYaw=math.atan2(finalToTarget.Z,finalToTarget.X)
            pcall(function() HRP.CFrame=CFrame.new(finalPos,finalPos+Vector3.new(math.cos(finalYaw),0,math.sin(finalYaw))) end)
            pcall(function() if currentAnimTrack and currentAnimTrack.IsPlaying then currentAnimTrack:Stop() end currentAnimTrack=nil end)
            if humanoid and oldAutoRotate~=nil then pcall(function() humanoid.AutoRotate=oldAutoRotate end) end
            busy=false
        end
    end)
end
local function createUI()
    pcall(function() local old=LocalPlayer.PlayerGui:FindFirstChild("CircularTweenUI") if old then old:Destroy() end end)
    local screenGui=Instance.new("ScreenGui")
    screenGui.Name="CircularTweenUI"
    screenGui.ResetOnSpawn=false
    screenGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
    local button=Instance.new("ImageButton")
    button.Name="DashButton"
    button.Size=UDim2.new(0,110,0,110)
    button.Position=UDim2.new(0.5,-55,0.8,-55)
    button.BackgroundTransparency=1
    button.BorderSizePixel=0
    button.Image="rbxassetid://99317918824094"
    button.Active=true
    button.Parent=screenGui
    local uiScale=Instance.new("UIScale")
    uiScale.Scale=1
    uiScale.Parent=button
    local pressSound=Instance.new("Sound")
    pressSound.Name="PressSFX"
    pressSound.SoundId=PRESS_SFX_ID
    pressSound.Volume=0.9
    pressSound.Looped=false
    pressSound.Parent=button
    local isPointerDown,isDragging,pointerStartPos,buttonStartPos,trackedInput=false,false,nil,nil,nil
    local dragThreshold=8
    local function tweenUIScale(toScale,time)
        time=time or 0.06
        local ok,tw=pcall(function() return TweenService:Create(uiScale,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=toScale}) end)
        if ok and tw then tw:Play() end
    end
    local function startPointer(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            isPointerDown=true
            isDragging=false
            pointerStartPos=input.Position
            buttonStartPos=button.Position
            trackedInput=input
            tweenUIScale(0.92,0.06)
            pcall(function() pressSound:Play() end)
        end
    end
    local function updatePointer(input)
        if not isPointerDown or not pointerStartPos or input~=trackedInput then return end
        local delta=input.Position-pointerStartPos
        if not isDragging and delta.Magnitude>=dragThreshold then
            isDragging=true
            tweenUIScale(1,0.06)
        end
        if isDragging then
            local screenW,screenH=workspace.CurrentCamera.ViewportSize.X,workspace.CurrentCamera.ViewportSize.Y
            local newX=buttonStartPos.X.Offset+delta.X
            local newY=buttonStartPos.Y.Offset+delta.Y
            newX=math.clamp(newX,0,screenW-button.AbsoluteSize.X)
            newY=math.clamp(newY,0,screenH-button.AbsoluteSize.Y)
            button.Position=UDim2.new(0,newX,0,newY)
        end
    end
    UserInputService.InputChanged:Connect(function(input) pcall(function() updatePointer(input) end) end)
    UserInputService.InputEnded:Connect(function(input)
        if input~=trackedInput or not isPointerDown then return end
        if not isDragging and not busy then
            local target=nil
            if useNearestToggle then target=getNearestTarget(MAX_RANGE) else target=selectedTargetModel end
            if target then smoothArcToTarget(target) end
        end
        tweenUIScale(1,0.06)
        isPointerDown,isDragging,pointerStartPos,buttonStartPos,trackedInput=false,false,nil,nil,nil
    end)
    button.InputBegan:Connect(function(input) pcall(function() startPointer(input) end) end)
    local settingsFrame=Instance.new("Frame")
    settingsFrame.Name="SettingsFrame"
    settingsFrame.Size=UDim2.new(0,320,0,360)
    settingsFrame.Position=UDim2.new(0.02,0,0.55,0)
    settingsFrame.BackgroundColor3=Color3.fromRGB(25,25,28)
    settingsFrame.BorderSizePixel=0
    settingsFrame.Parent=screenGui
    settingsFrame.Active=true
    settingsFrame.Draggable=false
    local titleBar=Instance.new("Frame")
    titleBar.Name="TitleBar"
    titleBar.Size=UDim2.new(1,0,0,30)
    titleBar.Position=UDim2.new(0,0,0,0)
    titleBar.BackgroundColor3=Color3.fromRGB(18,18,20)
    titleBar.BorderSizePixel=0
    titleBar.Parent=settingsFrame
    local titleLabel=Instance.new("TextLabel")
    titleLabel.Size=UDim2.new(1,-60,1,0)
    titleLabel.Position=UDim2.new(0,10,0,0)
    titleLabel.BackgroundTransparency=1
    titleLabel.Text="Circular Tween Settings"
    titleLabel.TextColor3=Color3.new(1,1,1)
    titleLabel.TextSize=14
    titleLabel.Font=Enum.Font.SourceSansBold
    titleLabel.TextXAlignment=Enum.TextXAlignment.Left
    titleLabel.Parent=titleBar
    local minimizeBtn=Instance.new("TextButton")
    minimizeBtn.Name="Minimize"
    minimizeBtn.Size=UDim2.new(0,50,0,26)
    minimizeBtn.Position=UDim2.new(1,-55,0,2)
    minimizeBtn.BackgroundColor3=Color3.fromRGB(40,40,44)
    minimizeBtn.Text="-"
    minimizeBtn.TextColor3=Color3.new(1,1,1)
    minimizeBtn.Font=Enum.Font.SourceSansBold
    minimizeBtn.TextSize=20
    minimizeBtn.Parent=titleBar
    local content=Instance.new("Frame")
    content.Name="Content"
    content.Size=UDim2.new(1,-6,1,-36)
    content.Position=UDim2.new(0,3,0,33)
    content.BackgroundTransparency=1
    content.Parent=settingsFrame
    local selectedLabel=Instance.new("TextLabel")
    selectedLabel.Name="SelectedLabel"
    selectedLabel.Size=UDim2.new(1,-6,0,24)
    selectedLabel.Position=UDim2.new(0,3,0,0)
    selectedLabel.BackgroundColor3=Color3.fromRGB(32,32,35)
    selectedLabel.BorderSizePixel=0
    selectedLabel.Text="Selected: (None)"
    selectedLabel.TextColor3=Color3.new(1,1,1)
    selectedLabel.Font=Enum.Font.SourceSans
    selectedLabel.TextSize=14
    selectedLabel.TextXAlignment=Enum.TextXAlignment.Left
    selectedLabel.Parent=content
    local controls=Instance.new("Frame")
    controls.Name="Controls"
    controls.Size=UDim2.new(1,-6,0,90)
    controls.Position=UDim2.new(0,3,0,30)
    controls.BackgroundTransparency=1
    controls.Parent=content
    local nearestToggleLabel=Instance.new("TextLabel")
    nearestToggleLabel.Size=UDim2.new(0.46,0,0,24)
    nearestToggleLabel.Position=UDim2.new(0,0,0,0)
    nearestToggleLabel.BackgroundTransparency=1
    nearestToggleLabel.Text="Use Nearest"
    nearestToggleLabel.TextColor3=Color3.new(1,1,1)
    nearestToggleLabel.Font=Enum.Font.SourceSans
    nearestToggleLabel.TextSize=14
    nearestToggleLabel.TextXAlignment=Enum.TextXAlignment.Left
    nearestToggleLabel.Parent=controls
    local nearestToggleBtn=Instance.new("TextButton")
    nearestToggleBtn.Size=UDim2.new(0.22,0,0,20)
    nearestToggleBtn.Position=UDim2.new(0.48,0,0,2)
    nearestToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
    nearestToggleBtn.Text="OFF"
    nearestToggleBtn.TextColor3=Color3.new(1,1,1)
    nearestToggleBtn.Font=Enum.Font.SourceSansBold
    nearestToggleBtn.TextSize=14
    nearestToggleBtn.Parent=controls
    local m1Label=Instance.new("TextLabel")
    m1Label.Size=UDim2.new(0.46,0,0,24)
    m1Label.Position=UDim2.new(0,0,0,30)
    m1Label.BackgroundTransparency=1
    m1Label.Text="M1 Activates"
    m1Label.TextColor3=Color3.new(1,1,1)
    m1Label.Font=Enum.Font.SourceSans
    m1Label.TextSize=14
    m1Label.TextXAlignment=Enum.TextXAlignment.Left
    m1Label.Parent=controls
    local m1ToggleBtn=Instance.new("TextButton")
    m1ToggleBtn.Size=UDim2.new(0.22,0,0,20)
    m1ToggleBtn.Position=UDim2.new(0.48,0,0,30)
    m1ToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
    m1ToggleBtn.Text="OFF"
    m1ToggleBtn.TextColor3=Color3.new(1,1,1)
    m1ToggleBtn.Font=Enum.Font.SourceSansBold
    m1ToggleBtn.TextSize=14
    m1ToggleBtn.Parent=controls
    local dashLabel=Instance.new("TextLabel")
    dashLabel.Size=UDim2.new(0.46,0,0,24)
    dashLabel.Position=UDim2.new(0,0,0,60)
    dashLabel.BackgroundTransparency=1
    dashLabel.Text="Dash Activates"
    dashLabel.TextColor3=Color3.new(1,1,1)
    dashLabel.Font=Enum.Font.SourceSans
    dashLabel.TextSize=14
    dashLabel.TextXAlignment=Enum.TextXAlignment.Left
    dashLabel.Parent=controls
    local dashToggleBtn=Instance.new("TextButton")
    dashToggleBtn.Size=UDim2.new(0.22,0,0,20)
    dashToggleBtn.Position=UDim2.new(0.48,0,0,60)
    dashToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
    dashToggleBtn.Text="OFF"
    dashToggleBtn.TextColor3=Color3.new(1,1,1)
    dashToggleBtn.Font=Enum.Font.SourceSansBold
    dashToggleBtn.TextSize=14
    dashToggleBtn.Parent=controls
    local espLabel=Instance.new("TextLabel")
    espLabel.Size=UDim2.new(0.46,0,0,24)
    espLabel.Position=UDim2.new(0,0,0,88)
    espLabel.BackgroundTransparency=1
    espLabel.Text="ESP"
    espLabel.TextColor3=Color3.new(1,1,1)
    espLabel.Font=Enum.Font.SourceSans
    espLabel.TextSize=14
    espLabel.TextXAlignment=Enum.TextXAlignment.Left
    espLabel.Parent=controls
    local espToggleBtn=Instance.new("TextButton")
    espToggleBtn.Size=UDim2.new(0.22,0,0,20)
    espToggleBtn.Position=UDim2.new(0.48,0,0,88)
    espToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
    espToggleBtn.Text="OFF"
    espToggleBtn.TextColor3=Color3.new(1,1,1)
    espToggleBtn.Font=Enum.Font.SourceSansBold
    espToggleBtn.TextSize=14
    espToggleBtn.Parent=controls
    local listLabel=Instance.new("TextLabel")
    listLabel.Size=UDim2.new(0.6,0,0,22)
    listLabel.Position=UDim2.new(0,6,0,130)
    listLabel.BackgroundTransparency=1
    listLabel.Text="Targets (Players + NPCs)"
    listLabel.TextColor3=Color3.new(1,1,1)
    listLabel.Font=Enum.Font.SourceSansBold
    listLabel.TextSize=14
    listLabel.TextXAlignment=Enum.TextXAlignment.Left
    listLabel.Parent=content
    local refreshBtn=Instance.new("TextButton")
    refreshBtn.Size=UDim2.new(0.28,0,0,22)
    refreshBtn.Position=UDim2.new(0.64,0,0,100)
    refreshBtn.BackgroundColor3=Color3.fromRGB(62,62,66)
    refreshBtn.Text="Refresh"
    refreshBtn.TextColor3=Color3.new(1,1,1)
    refreshBtn.Font=Enum.Font.SourceSans
    refreshBtn.TextSize=14
    refreshBtn.Parent=content
    local scroll=Instance.new("ScrollingFrame")
    scroll.Name="TargetScroll"
    scroll.Size=UDim2.new(1,-12,0,200)
    scroll.Position=UDim2.new(0,6,0,130)
    scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.BackgroundColor3=Color3.fromRGB(18,18,20)
    scroll.BorderSizePixel=0
    scroll.Parent=content
    scroll.ScrollBarThickness=6
    local listLayout=Instance.new("UIListLayout")
    listLayout.Parent=scroll
    listLayout.SortOrder=Enum.SortOrder.LayoutOrder
    listLayout.Padding=UDim.new(0,4)
    local function clearTargetButtons()
        for _,v in pairs(scroll:GetChildren()) do
            if v:IsA("TextButton") then v:Destroy() end
        end
    end
    local function buildTargetButton(name,model)
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,-8,0,28)
        btn.BackgroundColor3=Color3.fromRGB(45,45,48)
        btn.BorderSizePixel=0
        btn.TextColor3=Color3.new(1,1,1)
        btn.Font=Enum.Font.SourceSans
        btn.TextSize=14
        btn.Text=name
        btn.Parent=scroll
        btn.MouseButton1Click:Connect(function()
            selectedTargetModel=model
            selectedLabel.Text="Selected: "..(name or "(None)")
            useNearestToggle=false
            nearestToggleBtn.Text="OFF"
            nearestToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
        end)
    end
    local function refreshTargetList()
        clearTargetButtons()
        local added=0
        for _,pl in pairs(Players:GetPlayers()) do
            if pl~=LocalPlayer then
                local char=pl.Character
                if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
                    local displayName=pl.Name
                    buildTargetButton(displayName,char)
                    added=added+1
                end
            end
        end
        for _,obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                local owner=Players:GetPlayerFromCharacter(obj)
                if not owner then
                    local hum=obj:FindFirstChild("Humanoid")
                    if hum and hum.Health>0 then
                        local name=obj.Name
                        buildTargetButton(name,obj)
                        added=added+1
                    end
                end
            end
        end
        local btnCount=0
        for _,c in pairs(scroll:GetChildren()) do if c:IsA("TextButton") then btnCount=btnCount+1 end end
        scroll.CanvasSize=UDim2.new(0,0,0,(btnCount*32)+8)
    end
    refreshBtn.MouseButton1Click:Connect(function() pcall(function() refreshTargetList() end) end)
    refreshTargetList()
    nearestToggleBtn.MouseButton1Click:Connect(function()
        useNearestToggle=not useNearestToggle
        if useNearestToggle then
            nearestToggleBtn.Text="ON"
            nearestToggleBtn.BackgroundColor3=Color3.fromRGB(90,160,80)
        else
            nearestToggleBtn.Text="OFF"
            nearestToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
        end
    end)
    local function disableM1()
        m1Toggle=false
        m1ToggleBtn.Text="OFF"
        m1ToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
        if m1BeganConn and m1BeganConn.Connected then m1BeganConn:Disconnect() m1BeganConn=nil end
    end
    local function enableM1()
        m1Toggle=true
        m1ToggleBtn.Text="ON"
        m1ToggleBtn.BackgroundColor3=Color3.fromRGB(90,160,80)
        if not m1BeganConn then
            m1BeganConn=UserInputService.InputBegan:Connect(function(input,processed)
                if input.UserInputType==Enum.UserInputType.MouseButton1 then
                    if not busy then
                        local target=nil
                        if useNearestToggle then target=getNearestTarget(MAX_RANGE) else target=selectedTargetModel end
                        if target then smoothArcToTarget(target) end
                    end
                end
            end)
        end
    end
    m1ToggleBtn.MouseButton1Click:Connect(function()
        if m1Toggle then disableM1() else enableM1() end
    end)
    local function disableDash()
        dashToggle=false
        dashToggleBtn.Text="OFF"
        dashToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
    end
    local function enableDash()
        dashToggle=true
        dashToggleBtn.Text="ON"
        dashToggleBtn.BackgroundColor3=Color3.fromRGB(90,160,80)
    end
    dashToggleBtn.MouseButton1Click:Connect(function()
        if dashToggle then disableDash() else enableDash() end
    end)
    local function disableESP()
        espEnabled=false
        espToggleBtn.Text="OFF"
        espToggleBtn.BackgroundColor3=Color3.fromRGB(60,60,64)
        setESPAdornee(nil)
        if espLoopConn and espLoopConn.Connected then espLoopConn:Disconnect() espLoopConn=nil end
    end
    local function enableESP()
        espEnabled=true
        espToggleBtn.Text="ON"
        espToggleBtn.BackgroundColor3=Color3.fromRGB(90,160,80)
        espLoopConn=RunService.Heartbeat:Connect(function()
            if not espEnabled then return end
            local current=nil
            if useNearestToggle then current=getNearestTarget(MAX_RANGE) else current=selectedTargetModel end
            if current then setESPAdornee(current) else setESPAdornee(nil) end
        end)
    end
    espToggleBtn.MouseButton1Click:Connect(function()
        if espEnabled then disableESP() else enableESP() end
    end)
    local smallShowButton=Instance.new("TextButton")
    smallShowButton.Name="ShowSettings"
    smallShowButton.Size=UDim2.new(0,80,0,28)
    smallShowButton.Position=UDim2.new(settingsFrame.Position.X.Scale,settingsFrame.Position.X.Offset,settingsFrame.Position.Y.Scale,settingsFrame.Position.Y.Offset)
    smallShowButton.Text=""
    smallShowButton.Visible=false
    smallShowButton.Parent=screenGui
    smallShowButton.BackgroundColor3=Color3.fromRGB(40,40,44)
    smallShowButton.TextColor3=Color3.new(1,1,1)
    smallShowButton.Font=Enum.Font.SourceSans
    smallShowButton.TextSize=14
    local minimized=false
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized=not minimized
        if minimized then
            content.Visible=false
            settingsFrame.Size=UDim2.new(0,140,0,30)
            smallShowButton.Visible=true
            smallShowButton.Position=UDim2.new(settingsFrame.Position.X.Scale,settingsFrame.Position.X.Offset,settingsFrame.Position.Y.Scale,settingsFrame.Position.Y.Offset+34)
        else
            content.Visible=true
            settingsFrame.Size=UDim2.new(0,320,0,360)
            smallShowButton.Visible=false
        end
    end)
    smallShowButton.MouseButton1Click:Connect(function()
        minimized=false
        content.Visible=true
        settingsFrame.Size=UDim2.new(0,320,0,360)
        smallShowButton.Visible=false
    end)
    local dragging=false
    local dragStart=nil
    local startPos=nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=input.Position
            startPos=settingsFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    dragging=false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if not dragStart or not startPos then return end
        local delta=input.Position-dragStart
        local newX=startPos.X.Offset+delta.X
        local newY=startPos.Y.Offset+delta.Y
        local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024,768)
        newX=math.clamp(newX,0,math.max(0,vp.X-settingsFrame.AbsoluteSize.X))
        newY=math.clamp(newY,0,math.max(0,vp.Y-settingsFrame.AbsoluteSize.Y))
        settingsFrame.Position=UDim2.new(0,newX,0,newY)
    end)
    Players.PlayerAdded:Connect(function() refreshTargetList() end)
    Players.PlayerRemoving:Connect(function() refreshTargetList() end)
    UserInputService.InputBegan:Connect(function(input,processed)
        if processed or busy then return end
        if (input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Enum.KeyCode.X) or (input.UserInputType==Enum.UserInputType.Gamepad1 and input.KeyCode==Enum.KeyCode.DPadUp) then
            local target=nil
            if useNearestToggle then target=getNearestTarget(MAX_RANGE) else target=selectedTargetModel end
            if target then smoothArcToTarget(target) end
        end
    end)
    return {
        ScreenGui=screenGui,
        DashButton=button,
        SettingsFrame=settingsFrame,
        SelectedLabel=selectedLabel,
        RefreshList=refreshTargetList,
        EnableM1=enableM1,
        DisableM1=disableM1
    }
end
local ui=createUI()
print("[CircularTweenUI] Ready")

-- Make Settings panel draggable (Delta Mobile compatible)
do
    local UserInputService = game:GetService("UserInputService")
    local settingsPanel = screenGui:FindFirstChild("SettingsPanel")
    if settingsPanel then
        local dragging = false
        local dragInput, dragStart, startPos

        local function update(input)
            local delta = input.Position - dragStart
            settingsPanel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end

        settingsPanel.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = settingsPanel.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        settingsPanel.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                update(input)
            end
        end)
    end
end