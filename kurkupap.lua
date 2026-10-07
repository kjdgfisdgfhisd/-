-- я ебанат
-- не судите строго

local HIros = loadstring(game:HttpGet("https://raw.githubusercontent.com/kjdgfisdgfhisd/-/refs/heads/main/HIros%206.1"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

-- ============ хуйня ============
local state = {
    farmRunning = false,
    farmCounter = 0,
    infiniteFarm = true, -- бесконечный режим
    farmLimit = 50,
    selectedHole = nil,
    giveMeThreshold = 10,
    giveMeMethod = "Invoke",
    flySpeed = 30,
    returnSpeed = 80,
    dropDistance = 25,
    postThrowDelay = 0.05,
    noclipEnabled = false,
    noclipConn = nil,
    visualObjects = {},
    jumpActive = false,
    animating = false,
    saveWalkSpeed = 16,
    boostWalkSpeed = 100,
    restoreSpeedConn = nil,
    itemESPRefreshTime = 0,
    itemESPActive = false,
    conns = {},
    diedConn = nil,
    charAddedConn = nil,
    visuals = {
        holeESP = false, itemESP = false, highlight = false, trail = false,
        beam = false, billboard = false, circle = false, particles = false,
        glow = false, arrow = false, distance = false, rainbow = false,
        sphere = false, ring = false, lines = false, targetSound = false,
        hitboxESP = false, tracer = false, chams = false,
        soundESP = false, targetInfo = false, velocityLines = false,
        glowItems = false, pulseRing = false, autoColor = false,
    },
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ThrowItem = Remotes:WaitForChild("ThrowItem")
local HoleGiveMe = Remotes:WaitForChild("HoleGiveMe")
local LiftDumbbell = Remotes:WaitForChild("LiftDumbbell")

local function getChar()
    local char = plr.Character
    return char, char and char:FindFirstChild("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

-- ============ обирание говна ============
local function destroyVisual(prefix)
    for i = #state.visualObjects, 1, -1 do
        local obj = state.visualObjects[i]
        if obj then
            local name = obj.Name or ""
            if name == prefix or name:find("^" .. prefix) then
                pcall(function() obj:Destroy() end)
                table.remove(state.visualObjects, i)
            end
        end
    end
end

local function destroyConns(prefix)
    for i = #state.conns, 1, -1 do
        local c = state.conns[i]
        if c and c.tag == prefix then
            pcall(function() c.conn:Disconnect() end)
            table.remove(state.conns, i)
        end
    end
end

local function addConn(conn, tag)
    table.insert(state.conns, { conn = conn, tag = tag })
    return conn
end

local function track(obj)
    table.insert(state.visualObjects, obj)
    return obj
end

-- ============================================================
-- я хуй знает
-- ============================================================
local function bindAutoRespawn()
    -- при респавне — заново запускаем фарм
    if state.charAddedConn then state.charAddedConn:Disconnect() end
    state.charAddedConn = plr.CharacterAdded:Connect(function(char)
        task.wait(1.5) -- ждём загрузки персонажа
        if state.farmRunning then
            -- перезапускаем полёт и ноклип
            setNoclip(true)
            startJumpFly()
            print("[Farm] Респавн — фарм продолжается")
        end
    end)

    -- отслеживаем смерть
    local function watchChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        if state.diedConn then state.diedConn:Disconnect() end
        state.diedConn = hum.Died:Connect(function()
            print("[Farm] Умер — ждём респавн...")
            -- сбрасываем jumpActive, чтобы при респавне заново создался
            state.jumpActive = false
        end)
    end

    if plr.Character then watchChar(plr.Character) end
    plr.CharacterAdded:Connect(watchChar)
end

-- ============ хех ноуклипчик ============
local function setNoclip(on)
    state.noclipEnabled = on
    if on then
        if state.noclipConn then state.noclipConn:Disconnect() end
        state.noclipConn = RunService.Stepped:Connect(function()
            local char = plr.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if state.noclipConn then
            state.noclipConn:Disconnect()
            state.noclipConn = nil
        end
        local char = plr.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

-- ============ JUMP FLY ============
local function startJumpFly()
    local _, _, hrp = getChar()
    if not hrp then return false end
    if state.jumpActive then return true end
    state.jumpActive = true
    local oldBv = hrp:FindFirstChild("WalkFarm_BV")
    if oldBv then oldBv:Destroy() end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "WalkFarm_BV"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp
    local oldBg = hrp:FindFirstChild("WalkFarm_BG")
    if oldBg then oldBg:Destroy() end
    local bg = Instance.new("BodyGyro")
    bg.Name = "WalkFarm_BG"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    local _, hum = getChar()
    if hum then hum.PlatformStand = true end
    return true
end

local function stopJumpFly()
    state.jumpActive = false
    local _, _, hrp = getChar()
    if hrp then
        local bv = hrp:FindFirstChild("WalkFarm_BV"); if bv then bv:Destroy() end
        local bg = hrp:FindFirstChild("WalkFarm_BG"); if bg then bg:Destroy() end
    end
    local _, hum = getChar()
    if hum then hum.PlatformStand = false end
end

local function jumpFlyTo(targetPos, timeout, customSpeed)
    local _, _, hrp = getChar()
    if not hrp then return false end
    if not state.jumpActive then
        if not startJumpFly() then return false end
        task.wait(0.1)
    end
    timeout = timeout or 10
    local speedMax = customSpeed or state.flySpeed
    local start = tick()
    while tick() - start < timeout do
        if not state.farmRunning then return false end
        local _, _, hrp2 = getChar()
        if not hrp2 then return false end
        local dist = (hrp2.Position - targetPos).Magnitude
        if dist < 4 then
            local bv = hrp2:FindFirstChild("WalkFarm_BV")
            if bv then bv.Velocity = Vector3.new(0, 0, 0) end
            return true
        end
        local dir = (targetPos - hrp2.Position).Unit
        local speed = math.min(speedMax, dist * 2.5)
        local bv = hrp2:FindFirstChild("WalkFarm_BV")
        if bv then bv.Velocity = dir * speed end
        task.wait(0.02)
    end
    return false
end

-- ============ ПОИСК ============
local function collectHoles()
    local holes = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "HoleHitbox" then
            table.insert(holes, v)
        end
    end
    return holes
end

local function findMyBase()
    local _, _, hrp = getChar()
    if not hrp then return nil end
    local bestSpawn, bestDist = nil, math.huge
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("SpawnLocation") and v.Name == "BaseSpawn" then
            local dist = (v.Position - hrp.Position).Magnitude
            if dist < bestDist then bestSpawn, bestDist = v, dist end
        end
    end
    if not bestSpawn then return nil end
    local baseModel = bestSpawn.Parent
    if baseModel then
        local hole = baseModel:FindFirstChild("HoleHitbox")
        if hole then return hole end
    end
    return nil
end

local function findNearestPrompt()
    local _, _, hrp = getChar()
    if not hrp then return nil end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, v in ipairs(si:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            local part = v.Parent
            if part and part:IsA("BasePart") then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist < nearestDist then nearest, nearestDist = v, dist end
            end
        end
    end
    return nearest, nearestDist
end

-- ============ WALKSPEED ============
local function boostWalkSpeed(duration)
    local _, hum = getChar()
    if not hum then return end
    state.saveWalkSpeed = hum.WalkSpeed
    hum.WalkSpeed = state.boostWalkSpeed
    if state.restoreSpeedConn then task.cancel(state.restoreSpeedConn) end
    state.restoreSpeedConn = task.delay(duration, function()
        local _, hum2 = getChar()
        if hum2 then hum2.WalkSpeed = state.saveWalkSpeed end
    end)
end

-- ============ GIVEME ============
local function triggerGiveMe()
    state.animating = true
    boostWalkSpeed(5)
    if state.giveMeMethod == "Invoke" or state.giveMeMethod == "Both" then
        pcall(function() HoleGiveMe:InvokeServer() end)
    end
    if state.giveMeMethod == "Click" or state.giveMeMethod == "Both" then
        pcall(function()
            local pg = plr:FindFirstChild("PlayerGui")
            local hud = pg and pg:FindFirstChild("HUD")
            local top = hud and hud:FindFirstChild("TopButtons")
            local holder = top and top:FindFirstChild("GiveMeButtonHolder")
            local plate = holder and holder:FindFirstChild("GiveMePlate")
            local face = plate and plate:FindFirstChild("Face")
            if face then face.MouseButton1Click:Fire() end
        end)
    end
    task.wait(3.5)
    state.animating = false
    return true
end

-- ============ БРОСОК ============
local function simpleThrow()
    if not state.selectedHole then return false end
    local _, _, hrp = getChar()
    if not hrp then return false end
    local holePos = state.selectedHole.Position
    local dir = (hrp.Position - holePos).Unit
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
    dir = dir.Unit
    local standPos = holePos + dir * state.dropDistance
    standPos = Vector3.new(standPos.X, holePos.Y + 10, standPos.Z)
    jumpFlyTo(standPos, 15, state.flySpeed)
    task.wait(0.2)
    local cam = workspace.CurrentCamera
    if cam then cam.CFrame = CFrame.new(hrp.Position, holePos) end
    task.wait(0.15)
    local vp = cam.ViewportSize
    VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
    pcall(function() ThrowItem:FireServer() end)
    state.farmCounter = state.farmCounter + 1
    return true
end

local function doFarmCycle()
    if not state.selectedHole then return false end
    local prompt, dist = findNearestPrompt()
    if not prompt then return false end
    local part = prompt.Parent
    jumpFlyTo(part.Position, 15, state.returnSpeed)
    task.wait(0.15)
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        elseif prompt.InputHoldBegin then
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.1)
            prompt:InputHoldEnd()
        end
    end)
    task.wait(0.15)
    simpleThrow()
    task.wait(state.postThrowDelay)
    if state.farmCounter % state.giveMeThreshold == 0 then
        triggerGiveMe()
    end
    return true
end

local function startFarm()
    if state.farmRunning then return end
    state.farmRunning = true
    state.farmCounter = 0
    setNoclip(true)
    if not startJumpFly() then
        state.farmRunning = false
        return
    end
    task.spawn(function()
        while state.farmRunning do
            -- проверка лимита (если не бесконечный)
            if not state.infiniteFarm and state.farmCounter >= state.farmLimit then
                break
            end
            -- если умер — ждём респавн
            local char, hum = getChar()
            if not char or not hum or hum.Health <= 0 then
                task.wait(0.5)
            else
                doFarmCycle()
            end
            task.wait(0.05)
        end
        state.farmRunning = false
        stopJumpFly()
        setNoclip(false)
        print("[Farm] Остановлен. Всего:", state.farmCounter)
    end)
end

local function stopFarm()
    state.farmRunning = false
    stopJumpFly()
    setNoclip(false)
end

-- ============================================================
-- ВИЗУАЛЫ (сокращённо — те же что в v23)
-- ============================================================
local visuals = state.visuals

local function setHoleESP(on)
    visuals.holeESP = on
    destroyVisual("HoleESP")
    if not on then return end
    for _, hole in ipairs(collectHoles()) do
        local hl = Instance.new("Highlight")
        hl.Name = "HoleESP"
        hl.FillColor = Color3.fromRGB(138, 43, 226)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.6
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = hole
        track(hl)
    end
end

local function refreshItemESP()
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return end
    for i = #state.visualObjects, 1, -1 do
        local obj = state.visualObjects[i]
        if obj and obj.Name == "ItemESP" then
            local parent = obj.Parent
            if not parent or not parent:IsDescendantOf(si) then
                pcall(function() obj:Destroy() end)
                table.remove(state.visualObjects, i)
            end
        end
    end
    for _, v in ipairs(si:GetChildren()) do
        if v:IsA("Model") and not v:FindFirstChild("ItemESP") then
            local hl = Instance.new("Highlight")
            hl.Name = "ItemESP"
            hl.FillColor = Color3.fromRGB(255, 180, 60)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.5
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = v
            track(hl)
        end
    end
end

local function setItemESP(on)
    visuals.itemESP = on
    if not on then
        destroyVisual("ItemESP")
        state.itemESPActive = false
        return
    end
    destroyVisual("ItemESP")
    state.itemESPActive = true
    refreshItemESP()
    if not state.itemESPHeartbeat then
        state.itemESPHeartbeat = RunService.Heartbeat:Connect(function()
            if not state.itemESPActive then return end
            local now = tick()
            if now - state.itemESPRefreshTime >= 1 then
                state.itemESPRefreshTime = now
                pcall(refreshItemESP)
            end
        end)
    end
end

local function setHighlight(on)
    visuals.highlight = on
    destroyVisual("TargetHL")
    if not on then return end
    if not state.selectedHole then return end
    local hl = Instance.new("Highlight")
    hl.Name = "TargetHL"
    hl.FillColor = Color3.fromRGB(255, 80, 80)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = state.selectedHole
    track(hl)
end

local function setTrail(on)
    visuals.trail = on
    local _, _, hrp = getChar()
    if hrp then
        for _, name in ipairs({"HIrosTrail", "HIrosTrailAtt0", "HIrosTrailAtt1"}) do
            local c = hrp:FindFirstChild(name)
            if c then c:Destroy() end
        end
    end
    destroyVisual("HIrosTrail")
    if not on then return end
    if not hrp then return end
    local att0 = Instance.new("Attachment"); att0.Name = "HIrosTrailAtt0"; att0.Position = Vector3.new(0, -1.5, 0); att0.Parent = hrp
    local att1 = Instance.new("Attachment"); att1.Name = "HIrosTrailAtt1"; att1.Position = Vector3.new(0, 1.5, 0); att1.Parent = hrp
    local trail = Instance.new("Trail")
    trail.Name = "HIrosTrail"
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 0.6
    trail.MinLength = 0
    trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
    trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)), ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 170, 255))})
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
    trail.Parent = hrp
    track(trail); track(att0); track(att1)
end

local function setBeam(on)
    visuals.beam = on
    destroyVisual("TargetBeam")
    if not on then return end
    if not state.selectedHole then return end
    local _, _, hrp = getChar()
    if not hrp then return end
    local att0 = Instance.new("Attachment"); att0.Name = "TargetBeamAtt0"; att0.Parent = hrp
    local att1 = Instance.new("Attachment"); att1.Name = "TargetBeamAtt1"; att1.Parent = state.selectedHole
    local beam = Instance.new("Beam")
    beam.Name = "TargetBeam"
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Width0 = 0.3; beam.Width1 = 0.3
    beam.FaceCamera = true
    beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 100))})
    beam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.5)})
    beam.Parent = hrp
    track(beam); track(att0); track(att1)
end

local function setBillboard(on)
    visuals.billboard = on
    destroyVisual("InfoBillboard")
    destroyConns("billboard")
    if not on then return end
    if not state.selectedHole then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "InfoBillboard"
    bb.Size = UDim2.new(0, 220, 0, 60)
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = state.selectedHole
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = bb
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 22)
    title.BackgroundTransparency = 1
    title.Text = "🎯 ЦЕЛЬ"
    title.TextColor3 = Color3.fromRGB(255, 80, 80)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    local info = Instance.new("TextLabel")
    info.Name = "InfoText"
    info.Size = UDim2.new(1, 0, 0, 18)
    info.Position = UDim2.new(0, 0, 0, 22)
    info.BackgroundTransparency = 1
    info.Text = "Дистанция: --"
    info.TextColor3 = Color3.fromRGB(200, 200, 220)
    info.TextSize = 12
    info.Font = Enum.Font.Gotham
    info.Parent = frame
    local status = Instance.new("TextLabel")
    status.Name = "StatusText"
    status.Size = UDim2.new(1, 0, 0, 18)
    status.Position = UDim2.new(0, 0, 0, 40)
    status.BackgroundTransparency = 1
    status.Text = "Статус: ожидание"
    status.TextColor3 = Color3.fromRGB(150, 255, 150)
    status.TextSize = 12
    status.Font = Enum.Font.Gotham
    status.Parent = frame
    track(bb)
    local conn = RunService.Heartbeat:Connect(function()
        if not state.selectedHole or not state.selectedHole.Parent then return end
        local _, _, hrp = getChar()
        if not hrp then return end
        local dist = (hrp.Position - state.selectedHole.Position).Magnitude
        local infoLbl = bb:FindFirstChild("InfoText", true)
        if infoLbl then infoLbl.Text = string.format("Дистанция: %.0f studs", dist) end
        local statusLbl = bb:FindFirstChild("StatusText", true)
        if statusLbl then statusLbl.Text = state.farmRunning and ("Брошено: " .. state.farmCounter) or "Статус: ожидание" end
    end)
    addConn(conn, "billboard")
end

local function setCircle(on)
    visuals.circle = on
    destroyVisual("HoleCircle")
    destroyConns("circle")
    if not on then return end
    if not state.selectedHole then return end
    local ring = Instance.new("Part")
    ring.Name = "HoleCircle"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 30, 30)
    ring.CFrame = state.selectedHole.CFrame * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(138, 43, 226)
    ring.Transparency = 0.5
    ring.Parent = Workspace
    track(ring)
    local t = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not ring.Parent then return end
        t = t + dt
        local scale = 1 + math.sin(t * 2) * 0.1
        ring.Size = Vector3.new(0.2, 30 * scale, 30 * scale)
        ring.Transparency = 0.4 + math.sin(t * 3) * 0.2
    end)
    addConn(conn, "circle")
end

local function setParticles(on)
    visuals.particles = on
    destroyVisual("HoleParticles")
    if not on then return end
    if not state.selectedHole then return end
    local att = Instance.new("Attachment")
    att.Name = "HoleParticlesAtt"
    att.Parent = state.selectedHole
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "HoleParticles"
    emitter.Texture = "rbxassetid://243098098"
    emitter.Rate = 30
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Speed = NumberRange.new(5, 10)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
    emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
    emitter.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 255))})
    emitter.Parent = att
    track(emitter); track(att)
end

local function setGlow(on)
    visuals.glow = on
    destroyVisual("HoleGlow")
    destroyConns("glow")
    if not on then return end
    if not state.selectedHole then return end
    local light = Instance.new("PointLight")
    light.Name = "HoleGlow"
    light.Color = Color3.fromRGB(138, 43, 226)
    light.Range = 30
    light.Brightness = 3
    light.Parent = state.selectedHole
    track(light)
    local t = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not light.Parent then return end
        t = t + dt
        light.Brightness = 2 + math.sin(t * 3) * 1.5
        light.Range = 25 + math.sin(t * 2) * 10
    end)
    addConn(conn, "glow")
end

local function setArrow(on)
    visuals.arrow = on
    destroyVisual("TargetArrow")
    destroyVisual("ArrowLabel")
    destroyConns("arrow")
    if not on then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "TargetArrow"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.Parent = plr:WaitForChild("PlayerGui")
    local arrow = Instance.new("TextLabel")
    arrow.Name = "ArrowLabel"
    arrow.Size = UDim2.new(0, 60, 0, 60)
    arrow.BackgroundTransparency = 1
    arrow.Text = "⬆"
    arrow.TextColor3 = Color3.fromRGB(255, 80, 80)
    arrow.TextSize = 48
    arrow.Font = Enum.Font.GothamBold
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Parent = sg
    track(sg); track(arrow)
    local conn = RunService.RenderStepped:Connect(function()
        if not state.selectedHole or not state.selectedHole.Parent then arrow.Visible = false return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local screenPos, onScreen = cam:WorldToViewportPoint(state.selectedHole.Position)
        arrow.Visible = true
        if onScreen then
            arrow.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y - 80)
            arrow.Rotation = 0
        else
            local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
            local dir = Vector2.new(screenPos.X - center.X, screenPos.Y - center.Y)
            local angle = math.atan2(dir.Y, dir.X)
            local radius = math.min(cam.ViewportSize.X, cam.ViewportSize.Y) * 0.35
            local pos = center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
            arrow.Position = UDim2.new(0, pos.X, 0, pos.Y)
            arrow.Rotation = math.deg(angle) + 90
        end
    end)
    addConn(conn, "arrow")
end

local function setDistance(on)
    visuals.distance = on
    destroyVisual("DistBB")
    destroyConns("distance")
    if not on then return end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return end
    for _, v in ipairs(si:GetChildren()) do
        if v:IsA("Model") then
            local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local bb = Instance.new("BillboardGui")
                bb.Name = "DistBB"
                bb.Size = UDim2.new(0, 100, 0, 20)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.Parent = part
                local lbl = Instance.new("TextLabel")
                lbl.Name = "DistLabel"
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "---"
                lbl.TextColor3 = Color3.fromRGB(255, 220, 100)
                lbl.TextSize = 14
                lbl.Font = Enum.Font.GothamBold
                lbl.TextStrokeTransparency = 0.5
                lbl.Parent = bb
                track(bb)
            end
        end
    end
    local conn = RunService.Heartbeat:Connect(function()
        local _, _, hrp = getChar()
        if not hrp then return end
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "DistBB" and obj.Parent then
                local lbl = obj:FindFirstChild("DistLabel", true)
                if lbl then
                    local dist = (obj.Parent.Position - hrp.Position).Magnitude
                    lbl.Text = string.format("%.0f", dist)
                end
            end
        end
    end)
    addConn(conn, "distance")
end

local function setRainbow(on)
    visuals.rainbow = on
    destroyConns("rainbow")
    if not on then return end
    local hue = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        hue = (hue + dt * 0.15) % 1
        local col = Color3.fromHSV(hue, 0.85, 1)
        for _, obj in ipairs(state.visualObjects) do
            pcall(function()
                if obj:IsA("Highlight") then
                    obj.FillColor = col
                    obj.OutlineColor = Color3.fromHSV((hue + 0.5) % 1, 0.85, 1)
                elseif obj:IsA("PointLight") then
                    obj.Color = col
                elseif obj:IsA("ParticleEmitter") then
                    obj.Color = ColorSequence.new(col)
                elseif obj:IsA("Part") and obj.Material == Enum.Material.Neon then
                    obj.Color = col
                elseif obj:IsA("Beam") then
                    obj.Color = ColorSequence.new(col)
                end
            end)
        end
    end)
    addConn(conn, "rainbow")
end

local function setSphere(on)
    visuals.sphere = on
    destroyVisual("HoleSphere")
    destroyConns("sphere")
    if not on then return end
    if not state.selectedHole then return end
    local sphere = Instance.new("Part")
    sphere.Name = "HoleSphere"
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(20, 20, 20)
    sphere.CFrame = state.selectedHole.CFrame
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Material = Enum.Material.ForceField
    sphere.Color = Color3.fromRGB(138, 43, 226)
    sphere.Transparency = 0.7
    sphere.Parent = Workspace
    track(sphere)
    local t = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not sphere.Parent then return end
        t = t + dt
        local scale = 20 + math.sin(t * 2) * 3
        sphere.Size = Vector3.new(scale, scale, scale)
        sphere.CFrame = state.selectedHole.CFrame
        sphere.Transparency = 0.6 + math.sin(t * 3) * 0.2
    end)
    addConn(conn, "sphere")
end

local function setRings(on)
    visuals.ring = on
    destroyVisual("HoleRing")
    destroyConns("ring")
    if not on then return end
    if not state.selectedHole then return end
    local rings = {}
    for i = 1, 4 do
        local ring = Instance.new("Part")
        ring.Name = "HoleRing" .. i
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.2, 10 + i * 5, 10 + i * 5)
        ring.CFrame = state.selectedHole.CFrame * CFrame.Angles(math.rad(90), 0, 0)
        ring.Anchored = true
        ring.CanCollide = false
        ring.Material = Enum.Material.Neon
        ring.Color = Color3.fromHSV(i / 4, 0.8, 1)
        ring.Transparency = 0.5
        ring.Parent = Workspace
        track(ring)
        table.insert(rings, ring)
    end
    local t = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not state.selectedHole or not state.selectedHole.Parent then return end
        t = t + dt
        for i, ring in ipairs(rings) do
            if ring.Parent then
                local scale = 10 + i * 5 + math.sin(t * 2 + i) * 3
                ring.Size = Vector3.new(0.2, scale, scale)
                ring.CFrame = state.selectedHole.CFrame * CFrame.Angles(math.rad(90), t + i, 0)
                ring.Transparency = 0.4 + math.sin(t * 3 + i) * 0.2
            end
        end
    end)
    addConn(conn, "ring")
end

local function setLines(on)
    visuals.lines = on
    destroyVisual("ItemLine")
    destroyVisual("ItemLineAtt")
    if not on then return end
    if not state.selectedHole then return end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return end
    for _, v in ipairs(si:GetChildren()) do
        if v:IsA("Model") then
            local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local att0 = Instance.new("Attachment"); att0.Name = "ItemLineAtt0"; att0.Parent = part
                local att1 = Instance.new("Attachment"); att1.Name = "ItemLineAtt1"; att1.Parent = state.selectedHole
                local beam = Instance.new("Beam")
                beam.Name = "ItemLine"
                beam.Attachment0 = att0
                beam.Attachment1 = att1
                beam.Width0 = 0.1; beam.Width1 = 0.1
                beam.FaceCamera = true
                beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
                beam.Transparency = NumberSequence.new(0.7)
                beam.Parent = part
                track(beam); track(att0); track(att1)
            end
        end
    end
end

local function setTargetSound(on)
    visuals.targetSound = on
    destroyConns("targetSound")
    if not on then return end
    local lastDist = math.huge
    local conn = RunService.Heartbeat:Connect(function()
        if not state.selectedHole or not state.selectedHole.Parent then return end
        local _, _, hrp = getChar()
        if not hrp then return end
        local dist = (hrp.Position - state.selectedHole.Position).Magnitude
        if dist < 20 and lastDist >= 20 then
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://6895079853"
            s.Volume = 0.5
            s.Parent = hrp
            s:Play()
            task.delay(2, function() s:Destroy() end)
        end
        lastDist = dist
    end)
    addConn(conn, "targetSound")
end

local function setHitboxESP(on)
    visuals.hitboxESP = on
    destroyVisual("HitboxESP")
    if not on then return end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return end
    for _, v in ipairs(si:GetChildren()) do
        if v:IsA("Model") then
            local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local box = Instance.new("BoxHandleAdornment")
                box.Name = "HitboxESP"
                box.Adornee = part
                box.AlwaysOnTop = true
                box.ZIndex = 5
                box.Size = part.Size
                box.Transparency = 0.5
                box.Color3 = Color3.fromRGB(255, 80, 80)
                box.Parent = part
                track(box)
            end
        end
    end
end

local function setTracer(on)
    visuals.tracer = on
    destroyVisual("Tracer")
    destroyVisual("TracerLine")
    destroyConns("tracer")
    if not on then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "Tracer"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.Parent = plr:WaitForChild("PlayerGui")
    local line = Instance.new("Frame")
    line.Name = "TracerLine"
    line.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0.5, 1)
    line.Parent = sg
    track(sg); track(line)
    local conn = RunService.RenderStepped:Connect(function()
        if not state.selectedHole or not state.selectedHole.Parent then line.Visible = false return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local screenPos, onScreen = cam:WorldToViewportPoint(state.selectedHole.Position)
        if not onScreen then line.Visible = false return end
        line.Visible = true
        local originX = cam.ViewportSize.X / 2
        local originY = cam.ViewportSize.Y
        local dx = screenPos.X - originX
        local dy = screenPos.Y - originY
        local length = math.sqrt(dx*dx + dy*dy)
        local angle = math.deg(math.atan2(dy, dx)) + 90
        line.Position = UDim2.new(0, originX, 0, originY)
        line.Size = UDim2.new(0, 2, 0, length)
        line.Rotation = angle
    end)
    addConn(conn, "tracer")
end

local function setChams(on)
    visuals.chams = on
    destroyVisual("Chams")
    if not on then return end
    local char = plr.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local cham = Instance.new("Highlight")
            cham.Name = "Chams"
            cham.FillColor = Color3.fromRGB(80, 200, 255)
            cham.OutlineColor = Color3.fromRGB(255, 255, 255)
            cham.FillTransparency = 0.5
            cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            cham.Parent = part
            track(cham)
        end
    end
end

local function setSoundESP(on)
    visuals.soundESP = on
    destroyVisual("SoundESP")
    if not on then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head then
                local bb = Instance.new("BillboardGui")
                bb.Name = "SoundESP"
                bb.Size = UDim2.new(0, 30, 0, 30)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.Parent = head
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "🔊"
                lbl.TextColor3 = Color3.fromRGB(255, 220, 100)
                lbl.TextSize = 20
                lbl.Parent = bb
                track(bb)
            end
        end
    end
end

local function setTargetInfo(on)
    visuals.targetInfo = on
    destroyVisual("TargetInfo")
    destroyConns("targetInfo")
    if not on then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "TargetInfo"
    sg.ResetOnSpawn = false
    sg.Parent = plr:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame")
    frame.Name = "InfoFrame"
    frame.Size = UDim2.new(0, 200, 0, 80)
    frame.Position = UDim2.new(0, 20, 0.5, -40)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundTransparency = 1
    title.Text = "🎯 ИНФО О ЦЕЛИ"
    title.TextColor3 = Color3.fromRGB(255, 80, 80)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "DistLbl"
    distLbl.Size = UDim2.new(1, 0, 0, 18)
    distLbl.Position = UDim2.new(0, 0, 0, 24)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "Дистанция: --"
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    distLbl.TextSize = 12
    distLbl.Parent = frame
    local thrownLbl = Instance.new("TextLabel")
    thrownLbl.Name = "ThrownLbl"
    thrownLbl.Size = UDim2.new(1, 0, 0, 18)
    thrownLbl.Position = UDim2.new(0, 0, 0, 42)
    thrownLbl.BackgroundTransparency = 1
    thrownLbl.Text = "Брошено: 0"
    thrownLbl.TextColor3 = Color3.fromRGB(150, 255, 150)
    thrownLbl.TextSize = 12
    thrownLbl.Parent = frame
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name = "StatusLbl"
    statusLbl.Size = UDim2.new(1, 0, 0, 18)
    statusLbl.Position = UDim2.new(0, 0, 0, 60)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Статус: ожидание"
    statusLbl.TextColor3 = Color3.fromRGB(200, 200, 100)
    statusLbl.TextSize = 12
    statusLbl.Parent = frame
    track(sg)
    local conn = RunService.Heartbeat:Connect(function()
        if not state.selectedHole or not state.selectedHole.Parent then return end
        local _, _, hrp = getChar()
        if not hrp then return end
        local dist = (hrp.Position - state.selectedHole.Position).Magnitude
        distLbl.Text = string.format("Дистанция: %.0f studs", dist)
        thrownLbl.Text = "Брошено: " .. state.farmCounter
        statusLbl.Text = state.farmRunning and "Статус: ФАРМ" or "Статус: ожидание"
    end)
    addConn(conn, "targetInfo")
end

local function setVelocityLines(on)
    visuals.velocityLines = on
    destroyConns("velocity")
    if not on then return end
    local conn = RunService.Heartbeat:Connect(function()
        local _, _, hrp = getChar()
        if not hrp then return end
        local bv = hrp:FindFirstChild("WalkFarm_BV")
        if not bv or bv.Velocity.Magnitude < 5 then return end
        local line = Instance.new("Part")
        line.Name = "VelocityLine"
        line.Size = Vector3.new(0.1, 0.1, 2)
        line.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)
        line.Anchored = true
        line.CanCollide = false
        line.Material = Enum.Material.Neon
        line.Color = Color3.fromRGB(138, 43, 226)
        line.Transparency = 0.5
        line.Parent = Workspace
        track(line)
        task.delay(0.3, function() if line.Parent then line:Destroy() end end)
    end)
    addConn(conn, "velocity")
end

local function setGlowItems(on)
    visuals.glowItems = on
    destroyVisual("ItemGlow")
    if not on then return end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if not si then return end
    for _, v in ipairs(si:GetChildren()) do
        if v:IsA("Model") then
            local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local light = Instance.new("PointLight")
                light.Name = "ItemGlow"
                light.Color = Color3.fromRGB(255, 180, 60)
                light.Range = 15
                light.Brightness = 2
                light.Parent = part
                track(light)
            end
        end
    end
end

local function setPulseRing(on)
    visuals.pulseRing = on
    destroyVisual("PulseRing")
    destroyConns("pulseRing")
    if not on then return end
    local ring = Instance.new("Part")
    ring.Name = "PulseRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 10, 10)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(138, 43, 226)
    ring.Transparency = 0.5
    ring.Parent = Workspace
    track(ring)
    local t = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not ring.Parent then return end
        local _, _, hrp = getChar()
        if not hrp then return end
        t = t + dt
        local scale = 8 + math.sin(t * 3) * 4
        ring.Size = Vector3.new(0.2, scale, scale)
        ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Transparency = 0.4 + math.sin(t * 4) * 0.3
    end)
    addConn(conn, "pulseRing")
end

local function setAutoColor(on)
    visuals.autoColor = on
    destroyConns("autoColor")
    if not on then return end
    local hue = 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        hue = (hue + dt * 0.08) % 1
        local col = Color3.fromHSV(hue, 0.9, 1)
        for _, obj in ipairs(state.visualObjects) do
            pcall(function()
                if obj:IsA("Highlight") or obj:IsA("BoxHandleAdornment") then
                    obj.FillColor = col
                elseif obj:IsA("PointLight") then
                    obj.Color = col
                elseif obj:IsA("ParticleEmitter") then
                    obj.Color = ColorSequence.new(col)
                elseif obj:IsA("Part") and obj.Material == Enum.Material.Neon then
                    obj.Color = col
                end
            end)
        end
    end)
    addConn(conn, "autoColor")
end

-- ============ GUI ============
local Window = HIros:CreateWindow({
    Name = "Walk Farm v28",
    Theme = "Purple",
    GlowMode = "rainbow",
    Shoutout = false,
    ClickEffect = { Enabled = true, Style = "Rings", Color = "theme", Size = 90, Rings = 3 },
    Sounds = { Volume = 0.7 },
})

-- ФАРМ
local FarmTab = Window:CreateTab({ Name = "Фарм", Icon = "⚡" })

FarmTab:CreateSection({ Text = "База" })

local holes = collectHoles()
local holeOptions = {}
local holeMap = {}
for i, hole in ipairs(holes) do
    local name = hole:GetFullName()
    table.insert(holeOptions, name)
    holeMap[name] = hole
end
if #holeOptions == 0 then holeOptions = {"(нет дыр)"} end

FarmTab:CreateDropdown({
    Name = "Выбери базу",
    Options = holeOptions,
    CurrentOption = holeOptions[1],
    Callback = function(opt)
        state.selectedHole = holeMap[opt]
        if visuals.highlight then setHighlight(false); setHighlight(true) end
    end,
})

FarmTab:CreateButton({
    Name = "🎯 Определить мою базу",
    Callback = function()
        local hole = findMyBase()
        if hole then
            state.selectedHole = hole
            Window:Notify({ Title = "База найдена", Content = hole:GetFullName(), Kind = "success" })
        else
            Window:Notify({ Title = "Ошибка", Content = "База не найдена", Kind = "error" })
        end
    end,
})

FarmTab:CreateSection({ Text = "Скорости" })
FarmTab:CreateSlider({ Name = "Скорость к дыре", Min = 10, Max = 100, Increment = 5, CurrentValue = 30, Callback = function(v) state.flySpeed = v end })
FarmTab:CreateSlider({ Name = "Скорость к предмету", Min = 20, Max = 150, Increment = 5, CurrentValue = 80, Callback = function(v) state.returnSpeed = v end })
FarmTab:CreateSlider({ Name = "Дистанция от дыры", Min = 10, Max = 50, Increment = 1, CurrentValue = 25, Callback = function(v) state.dropDistance = v end })
FarmTab:CreateSlider({ Name = "Задержка после броска", Min = 0.01, Max = 1, Increment = 0.01, CurrentValue = 0.05, Callback = function(v) state.postThrowDelay = v end })

FarmTab:CreateSection({ Text = "WalkSpeed Boost" })
FarmTab:CreateSlider({ Name = "WalkSpeed во время GiveMe", Min = 20, Max = 100, Increment = 5, CurrentValue = 100, Callback = function(v) state.boostWalkSpeed = v end })

FarmTab:CreateSection({ Text = "Фарм" })

FarmTab:CreateToggle({
    Name = "♾ БЕСКОНЕЧНЫЙ РЕЖИМ",
    CurrentValue = true,
    Callback = function(v) state.infiniteFarm = v end,
})

FarmTab:CreateSlider({
    Name = "Лимит предметов (если не бесконечный)",
    Min = 1, Max = 500, Increment = 1,
    CurrentValue = 50,
    Callback = function(v) state.farmLimit = v end,
})

FarmTab:CreateSlider({ Name = "GiveMe после N", Min = 1, Max = 50, Increment = 1, CurrentValue = 10, Callback = function(v) state.giveMeThreshold = v end })

FarmTab:CreateDropdown({
    Name = "Способ GiveMe",
    Options = {"Invoke", "Click", "Both"},
    CurrentOption = "Invoke",
    Callback = function(opt) state.giveMeMethod = opt end,
})

FarmTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Callback = function(v) setNoclip(v) end })

FarmTab:CreateSection({ Text = "Управление" })

FarmTab:CreateButton({
    Name = "▶ START ФАРМ (бесконечный)",
    Callback = function()
        startFarm()
        Window:Notify({ Title = "Фарм", Content = "Бесконечный режим запущен", Kind = "success" })
    end,
})

FarmTab:CreateButton({
    Name = "■ STOP ФАРМ",
    Callback = function()
        stopFarm()
        Window:Notify({ Title = "Фарм", Content = "Остановлен (" .. state.farmCounter .. ")", Kind = "warning" })
    end,
})

-- ТРЕНИРОВКА
local TrainTab = Window:CreateTab({ Name = "Тренировка", Icon = "💪" })
local trainRunning = false
local trainCounter = 0
local spamRate = 0.1

TrainTab:CreateSection({ Text = "Настройки" })
TrainTab:CreateSlider({ Name = "Задержка между вызовами", Min = 0.01, Max = 1, Increment = 0.01, CurrentValue = 0.1, Callback = function(v) spamRate = v end })

local function equipDumbbell()
    local _, hum = getChar()
    if not hum then return false end
    local bp = plr:FindFirstChild("Backpack")
    local d = bp and bp:FindFirstChild("Dumbbell")
    if not d then
        local char = plr.Character
        d = char and char:FindFirstChild("Dumbbell")
    end
    if not d then return false end
    if d.Parent == plr.Character then return true end
    pcall(function() hum:EquipTool(d) end)
    task.wait(0.1)
    return d.Parent == plr.Character
end

local function doTrainCycle()
    if not equipDumbbell() then return false end
    pcall(function() LiftDumbbell:FireServer() end)
    trainCounter = trainCounter + 1
    return true
end

TrainTab:CreateButton({
    Name = "▶ START ТРЕНИРОВКА",
    Callback = function()
        if trainRunning then return end
        trainRunning = true
        trainCounter = 0
        task.spawn(function()
            while trainRunning do
                doTrainCycle()
                task.wait(spamRate)
            end
            equipDumbbell()
        end)
        Window:Notify({ Title = "Тренировка", Content = "Запущена", Kind = "success" })
    end,
})

TrainTab:CreateButton({
    Name = "■ STOP ТРЕНИРОВКА",
    Callback = function()
        trainRunning = false
        Window:Notify({ Title = "Тренировка", Content = "Остановлена (" .. trainCounter .. ")", Kind = "warning" })
    end,
})

-- ВИЗУАЛЫ
local VisualsTab = Window:CreateTab({ Name = "Визуалы", Icon = "🎨" })

VisualsTab:CreateSection({ Text = "ESP" })
VisualsTab:CreateToggle({ Name = "ESP дыры", CurrentValue = false, Callback = function(v) setHoleESP(v) end })
VisualsTab:CreateToggle({ Name = "ESP предметов (авто 1с)", CurrentValue = false, Callback = function(v) setItemESP(v) end })
VisualsTab:CreateToggle({ Name = "Подсветка цели", CurrentValue = false, Callback = function(v) setHighlight(v) end })
VisualsTab:CreateToggle({ Name = "Hitbox ESP", CurrentValue = false, Callback = function(v) setHitboxESP(v) end })
VisualsTab:CreateToggle({ Name = "Sound ESP", CurrentValue = false, Callback = function(v) setSoundESP(v) end })
VisualsTab:CreateToggle({ Name = "Chams", CurrentValue = false, Callback = function(v) setChams(v) end })

VisualsTab:CreateSection({ Text = "Эффекты" })
VisualsTab:CreateToggle({ Name = "Трейл", CurrentValue = false, Callback = function(v) setTrail(v) end })
VisualsTab:CreateToggle({ Name = "Луч к цели", CurrentValue = false, Callback = function(v) setBeam(v) end })
VisualsTab:CreateToggle({ Name = "Tracer", CurrentValue = false, Callback = function(v) setTracer(v) end })
VisualsTab:CreateToggle({ Name = "Биллборд", CurrentValue = false, Callback = function(v) setBillboard(v) end })
VisualsTab:CreateToggle({ Name = "Круг", CurrentValue = false, Callback = function(v) setCircle(v) end })
VisualsTab:CreateToggle({ Name = "Частицы", CurrentValue = false, Callback = function(v) setParticles(v) end })
VisualsTab:CreateToggle({ Name = "Свечение", CurrentValue = false, Callback = function(v) setGlow(v) end })
VisualsTab:CreateToggle({ Name = "Стрелка к цели", CurrentValue = false, Callback = function(v) setArrow(v) end })
VisualsTab:CreateToggle({ Name = "Дистанция над предметами", CurrentValue = false, Callback = function(v) setDistance(v) end })
VisualsTab:CreateToggle({ Name = "Pulse Ring", CurrentValue = false, Callback = function(v) setPulseRing(v) end })
VisualsTab:CreateToggle({ Name = "Velocity Lines", CurrentValue = false, Callback = function(v) setVelocityLines(v) end })

VisualsTab:CreateSection({ Text = "Продвинутые" })
VisualsTab:CreateToggle({ Name = "Сфера вокруг дыры", CurrentValue = false, Callback = function(v) setSphere(v) end })
VisualsTab:CreateToggle({ Name = "Кольца (4 шт)", CurrentValue = false, Callback = function(v) setRings(v) end })
VisualsTab:CreateToggle({ Name = "Линии к дыре", CurrentValue = false, Callback = function(v) setLines(v) end })
VisualsTab:CreateToggle({ Name = "Glow Items", CurrentValue = false, Callback = function(v) setGlowItems(v) end })
VisualsTab:CreateToggle({ Name = "Target Info", CurrentValue = false, Callback = function(v) setTargetInfo(v) end })
VisualsTab:CreateToggle({ Name = "Звук при приближении", CurrentValue = false, Callback = function(v) setTargetSound(v) end })

VisualsTab:CreateSection({ Text = "Цвета" })
VisualsTab:CreateToggle({ Name = "🌈 Радужный режим", CurrentValue = false, Callback = function(v) setRainbow(v) end })
VisualsTab:CreateToggle({ Name = "Auto Color", CurrentValue = false, Callback = function(v) setAutoColor(v) end })

VisualsTab:CreateSection({ Text = "Утилиты" })
VisualsTab:CreateButton({
    Name = "🔄 Обновить ESP предметов",
    Callback = function()
        refreshItemESP()
        Window:Notify({ Title = "ESP", Content = "Обновлено", Kind = "info" })
    end,
})
VisualsTab:CreateButton({
    Name = "🗑 Очистить все визуалы",
    Callback = function()
        destroyVisual("HoleESP")
        destroyVisual("ItemESP")
        destroyVisual("TargetHL")
        destroyVisual("HIrosTrail")
        destroyVisual("TargetBeam")
        destroyVisual("InfoBillboard")
        destroyVisual("HoleCircle")
        destroyVisual("HoleParticles")
        destroyVisual("HoleGlow")
        destroyVisual("TargetArrow")
        destroyVisual("ArrowLabel")
        destroyVisual("DistBB")
        destroyVisual("HoleSphere")
        destroyVisual("HoleRing")
        destroyVisual("ItemLine")
        destroyVisual("HitboxESP")
        destroyVisual("Tracer")
        destroyVisual("TracerLine")
        destroyVisual("Chams")
        destroyVisual("SoundESP")
        destroyVisual("TargetInfo")
        destroyVisual("PulseRing")
        destroyVisual("ItemGlow")
        for k, _ in pairs(visuals) do visuals[k] = false end
        Window:Notify({ Title = "Визуалы", Content = "Очищены", Kind = "warning" })
    end,
})

-- НАСТРОЙКИ
local SettingsTab = Window:CreateTab({ Name = "Настройки", Icon = "⚙" })

SettingsTab:CreateSection({ Text = "Внешний вид" })
SettingsTab:CreateSlider({
    Name = "Масштаб окна",
    Min = 0.5, Max = 1.5, Increment = 0.05,
    CurrentValue = 1,
    Callback = function(v) Window:SetScale(v) end,
})
SettingsTab:CreateToggle({
    Name = "Частицы фона",
    CurrentValue = true,
    Callback = function(v) Window:SetParticles(v) end,
})
SettingsTab:CreateDropdown({
    Name = "Тема",
    Options = {"Blue", "Red", "Yellow", "Green", "Purple"},
    CurrentOption = "Purple",
    Callback = function(opt) Window:SetTheme(opt) end,
})
SettingsTab:CreateDropdown({
    Name = "Режим свечения",
    Options = {"theme", "rainbow"},
    CurrentOption = "rainbow",
    Callback = function(opt) Window:SetGlowMode(opt) end,
})

SettingsTab:CreateSection({ Text = "Профили" })
Window:CreateConfigManager(SettingsTab)

SettingsTab:CreateSection({ Text = "Горячие клавиши" })
SettingsTab:CreateKeybind({
    Name = "Открыть/закрыть меню",
    CurrentKeybind = Enum.KeyCode.RightShift,
    Callback = function(kc) Window:SetHotkey(kc) end,
})

-- ИНФО
local InfoTab = Window:CreateTab({ Name = "Инфо", Icon = "ℹ" })
InfoTab:CreateParagraph({
    Title = "Walk Farm v28 — Auto-Respawn + Infinite",
    Content = "♾ Бесконечный фарм (не останавливается). 💀 При смерти — авто-респавн и фарм продолжается. Библиотека: HIros 6.1.",
})

-- ============ ИНИЦИАЛИЗАЦИЯ ============
bindAutoRespawn()

print("куркума😡")
