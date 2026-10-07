local HIros = loadstring(game:HttpGet("https://raw.githubusercontent.com/kjdgfisdgfhisd/-/refs/heads/main/HIros%206.0"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

-- ============ СОСТОЯНИЕ ============
local state = {
    farmRunning = false,
    farmCounter = 0,
    farmLimit = 50,
    selectedHole = nil,
    giveMeThreshold = 10,
    giveMeMethod = "Invoke",
    flySpeed = 30,
    dropHeight = 18,
    noclipEnabled = false,
    noclipConn = nil,
    visualObjects = {},
    jumpActive = false,
    animating = false,
    saveWalkSpeed = 16,
    boostWalkSpeed = 100,
    restoreSpeedConn = nil,
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ThrowItem = Remotes:WaitForChild("ThrowItem")
local HoleGiveMe = Remotes:WaitForChild("HoleGiveMe")

local function getChar()
    local char = plr.Character
    return char, char and char:FindFirstChild("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

-- ============ NOCLIP ============
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
    if not hrp then return end
    if state.jumpActive then return end
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
    if hum then
        hum.PlatformStand = true
    end

    print("[WalkFarm] JumpFly ВКЛ")
end

local function stopJumpFly()
    state.jumpActive = false
    local _, _, hrp = getChar()
    if hrp then
        local bv = hrp:FindFirstChild("WalkFarm_BV")
        if bv then bv:Destroy() end
        local bg = hrp:FindFirstChild("WalkFarm_BG")
        if bg then bg:Destroy() end
    end
    local _, hum = getChar()
    if hum then
        hum.PlatformStand = false
    end
    print("[WalkFarm] JumpFly ВЫКЛ")
end

local function jumpFlyTo(targetPos, timeout)
    local _, _, hrp = getChar()
    if not hrp then return false end
    if not state.jumpActive then startJumpFly() end

    timeout = timeout or 10
    local start = tick()

    while tick() - start < timeout do
        if not state.farmRunning then return false end
        local _, _, hrp2 = getChar()
        if not hrp2 then return false end

        local dist = (hrp2.Position - targetPos).Magnitude
        if dist < 3 then
            local bv = hrp2:FindFirstChild("WalkFarm_BV")
            if bv then bv.Velocity = Vector3.new(0, 0, 0) end
            return true
        end

        local dir = (targetPos - hrp2.Position).Unit
        local speed = math.min(state.flySpeed, dist * 2)

        local bv = hrp2:FindFirstChild("WalkFarm_BV")
        if bv then
            bv.Velocity = dir * speed
        end

        task.wait(0.03)
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

-- ============ WALKSPEED BOOST (до 100) ============
local function boostWalkSpeed(duration)
    local _, hum = getChar()
    if not hum then return end
    state.saveWalkSpeed = hum.WalkSpeed
    hum.WalkSpeed = state.boostWalkSpeed
    print("[WalkFarm] WalkSpeed -> " .. state.boostWalkSpeed)

    if state.restoreSpeedConn then
        task.cancel(state.restoreSpeedConn)
    end
    state.restoreSpeedConn = task.delay(duration, function()
        local _, hum2 = getChar()
        if hum2 then
            hum2.WalkSpeed = state.saveWalkSpeed
            print("[WalkFarm] WalkSpeed -> " .. state.saveWalkSpeed)
        end
    end)
end

-- ============ GIVEME ============
local function triggerGiveMe()
    print("[WalkFarm] GiveMe...")
    state.animating = true

    -- WalkSpeed boost перед GiveMe
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

    print("[WalkFarm] Ждём 3.5 сек (WalkSpeed " .. state.boostWalkSpeed .. ")...")
    task.wait(3.5)
    state.animating = false
    print("[WalkFarm] Анимация завершена")
    return true
end

-- ============ БРОСОК СВЕРХУ ============
local function topDrop()
    if not state.selectedHole then return false end
    local _, _, hrp = getChar()
    if not hrp then return false end

    local abovePos = state.selectedHole.Position + Vector3.new(0, state.dropHeight, 0)
    print("[WalkFarm] Летим над дырой (Y+" .. state.dropHeight .. ")")
    jumpFlyTo(abovePos, 15)
    task.wait(0.2)

    local cam = workspace.CurrentCamera
    if cam then
        cam.CFrame = CFrame.new(hrp.Position, state.selectedHole.Position)
    end
    task.wait(0.15)

    print("[WalkFarm] Кидаем сверху вниз")
    local vp = workspace.CurrentCamera.ViewportSize
    VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
    pcall(function() ThrowItem:FireServer() end)

    state.farmCounter = state.farmCounter + 1
    print("[WalkFarm] Брошено! Всего: " .. state.farmCounter)
    return true
end

-- ============ ФАРМ ЦИКЛ ============
local function doFarmCycle()
    if not state.selectedHole then return false end

    local prompt, dist = findNearestPrompt()
    if not prompt then
        print("[WalkFarm] Предмет не найден")
        return false
    end
    local part = prompt.Parent
    print("[WalkFarm] Летим к предмету")
    jumpFlyTo(part.Position, 15)
    task.wait(0.2)

    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        elseif prompt.InputHoldBegin then
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.1)
            prompt:InputHoldEnd()
        end
    end)
    task.wait(0.3)

    topDrop()
    task.wait(0.3)

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
    startJumpFly()
    task.spawn(function()
        while state.farmRunning and state.farmCounter < state.farmLimit do
            doFarmCycle()
            task.wait(0.3)
        end
        state.farmRunning = false
        stopJumpFly()
        setNoclip(false)
    end)
end

local function stopFarm()
    state.farmRunning = false
    stopJumpFly()
    setNoclip(false)
end

-- ============ ВИЗУАЛЫ ============
local visuals = { holeESP = false, itemESP = false, highlight = false }

local function setHoleESP(on)
    visuals.holeESP = on
    if not on then
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "HoleESP" then obj:Destroy() end
        end
        local new = {}
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name ~= "HoleESP" then table.insert(new, obj) end
        end
        state.visualObjects = new
        return
    end
    for _, hole in ipairs(collectHoles()) do
        if not hole:FindFirstChild("HoleESP") then
            local hl = Instance.new("Highlight")
            hl.Name = "HoleESP"
            hl.FillColor = Color3.fromRGB(138, 43, 226)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.6
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = hole
            table.insert(state.visualObjects, hl)
        end
    end
end

local function setItemESP(on)
    visuals.itemESP = on
    if not on then
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "ItemESP" then obj:Destroy() end
        end
        local new = {}
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name ~= "ItemESP" then table.insert(new, obj) end
        end
        state.visualObjects = new
        return
    end
    local si = Workspace:FindFirstChild("SpawnedItems")
    if si then
        for _, v in ipairs(si:GetChildren()) do
            if v:IsA("Model") and not v:FindFirstChild("ItemESP") then
                local hl = Instance.new("Highlight")
                hl.Name = "ItemESP"
                hl.FillColor = Color3.fromRGB(255, 180, 60)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = v
                table.insert(state.visualObjects, hl)
            end
        end
    end
end

local function setHighlight(on)
    visuals.highlight = on
    if not on then
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name == "TargetHL" then obj:Destroy() end
        end
        local new = {}
        for _, obj in ipairs(state.visualObjects) do
            if obj.Name ~= "TargetHL" then table.insert(new, obj) end
        end
        state.visualObjects = new
        return
    end
    if not state.selectedHole then return end
    local hl = Instance.new("Highlight")
    hl.Name = "TargetHL"
    hl.FillColor = Color3.fromRGB(255, 80, 80)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = state.selectedHole
    table.insert(state.visualObjects, hl)
end

-- ============ GUI ============
local Window = HIros:CreateWindow({
    Name = "Walk Farm v17",
    Theme = "Purple",
    GlowMode = "rainbow",
})

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

FarmTab:CreateSection({ Text = "Настройки полёта" })

FarmTab:CreateSlider({
    Name = "Скорость полёта",
    Min = 10, Max = 100, Increment = 5,
    CurrentValue = 30,
    Callback = function(v) state.flySpeed = v end,
})

FarmTab:CreateSlider({
    Name = "Высота сброса (studs)",
    Min = 5, Max = 50, Increment = 1,
    CurrentValue = 18,
    Callback = function(v) state.dropHeight = v end,
})

FarmTab:CreateSection({ Text = "WalkSpeed Boost" })

FarmTab:CreateSlider({
    Name = "WalkSpeed во время GiveMe (до 100)",
    Min = 20, Max = 100, Increment = 5,
    CurrentValue = 100,
    Callback = function(v) state.boostWalkSpeed = v end,
})

FarmTab:CreateSection({ Text = "Фарм" })

FarmTab:CreateSlider({
    Name = "Лимит предметов",
    Min = 1, Max = 500, Increment = 1,
    CurrentValue = 50,
    Callback = function(v) state.farmLimit = v end,
})

FarmTab:CreateSlider({
    Name = "GiveMe после N",
    Min = 1, Max = 50, Increment = 1,
    CurrentValue = 10,
    Callback = function(v) state.giveMeThreshold = v end,
})

FarmTab:CreateDropdown({
    Name = "Способ GiveMe",
    Options = {"Invoke", "Click", "Both"},
    CurrentOption = "Invoke",
    Callback = function(opt) state.giveMeMethod = opt end,
})

FarmTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(v) setNoclip(v) end,
})

FarmTab:CreateSection({ Text = "Управление" })

FarmTab:CreateButton({
    Name = "▶ START ФАРМ (TopDrop)",
    Callback = function()
        startFarm()
        Window:Notify({ Title = "Фарм", Content = "TopDrop запущен", Kind = "success" })
    end,
})

FarmTab:CreateButton({
    Name = "■ STOP ФАРМ",
    Callback = function()
        stopFarm()
        Window:Notify({ Title = "Фарм", Content = "Остановлен", Kind = "warning" })
    end,
})

FarmTab:CreateButton({
    Name = "🛫 ТЕСТ полёта",
    Callback = function()
        task.spawn(function()
            startJumpFly()
            local _, _, hrp = getChar()
            if hrp then
                local startPos = hrp.Position
                jumpFlyTo(startPos + Vector3.new(0, 50, 0), 5)
                task.wait(1)
                jumpFlyTo(startPos, 5)
            end
            stopJumpFly()
            Window:Notify({ Title = "Полёт", Content = "Тест завершён", Kind = "info" })
        end)
    end,
})

FarmTab:CreateButton({
    Name = "⚡ GiveMe вручную (WalkSpeed boost)",
    Callback = function()
        task.spawn(function()
            triggerGiveMe()
            Window:Notify({ Title = "GiveMe", Content = "Отправлено", Kind = "info" })
        end)
    end,
})

FarmTab:CreateButton({
    Name = "🗑 TopDrop вручную",
    Callback = function()
        task.spawn(function()
            startJumpFly()
            topDrop()
            task.wait(0.5)
            stopJumpFly()
            Window:Notify({ Title = "TopDrop", Content = "Брошено", Kind = "info" })
        end)
    end,
})

-- ============ ТРЕНИРОВКА ============
local TrainTab = Window:CreateTab({ Name = "Тренировка", Icon = "💪" })

local trainRunning = false
local trainCounter = 0
local spamRate = 0.1

TrainTab:CreateSection({ Text = "Настройки" })

TrainTab:CreateSlider({
    Name = "Задержка между вызовами",
    Min = 0.01, Max = 1, Increment = 0.01,
    CurrentValue = 0.1,
    Callback = function(v) spamRate = v end,
})

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

-- ============ ВИЗУАЛЫ ============
local VisualsTab = Window:CreateTab({ Name = "Визуалы", Icon = "🎨" })
VisualsTab:CreateSection({ Text = "ESP" })
VisualsTab:CreateToggle({ Name = "ESP дыры", CurrentValue = false, Callback = function(v) setHoleESP(v) end })
VisualsTab:CreateToggle({ Name = "ESP предметов", CurrentValue = false, Callback = function(v) setItemESP(v) end })
VisualsTab:CreateToggle({ Name = "Подсветка цели", CurrentValue = false, Callback = function(v) setHighlight(v) end })

-- ============ ИНФО ============
local InfoTab = Window:CreateTab({ Name = "Инфо", Icon = "ℹ" })
InfoTab:CreateParagraph({
    Title = "Walk Farm v17",
    Content = "WalkSpeed boost до 100. JumpFly + TopDrop. Библиотека: HIros 6.0.",
})

print("куркума😡")
