-- я ебанат
-- не судите строго

-- хотьба 37,333
-- я ФИКСИРУЮ

local HIros = loadstring(game:HttpGet("https://raw.githubusercontent.com/kjdgfisdgfhisd/-/refs/heads/main/HIros%206.1"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

local state = {
    farmRunning = false, farmCounter = 0, infiniteFarm = true, farmLimit = 50,
    selectedHole = nil, mainBaseHole = nil, mainBaseName = nil,
    giveMeThreshold = 10, giveMeMethod = "Invoke",
    flySpeed = 30, returnSpeed = 80, dropDistance = 25, postThrowDelay = 0.05,
    noclipEnabled = false, noclipConn = nil,
    jumpActive = false, animating = false,
    saveWalkSpeed = 16, boostWalkSpeed = 100, restoreSpeedConn = nil,
    diedConn = nil, charAddedConn = nil,
    autoRespawnEnabled = true, respawnDelay = 1.5,
    bigItemEvent = false, bigItemSpeed = 16, bigItemConn = nil,
    bigItemZone = nil,
    bigItemName = "BigItem",
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ThrowItem = Remotes:WaitForChild("ThrowItem")
local HoleGiveMe = Remotes:WaitForChild("HoleGiveMe")
local LiftDumbbell = Remotes:WaitForChild("LiftDumbbell")

local function getChar()
    local char = plr.Character
    return char, char and char:FindFirstChild("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

-- окак
-- твои 
-- данные улетают сюда
local holeNameToObject = {}

local function scanHoles()
    local names = {}
    holeNameToObject = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "HoleHitbox" then
            local name = v:GetFullName()
            table.insert(names, name)
            holeNameToObject[name] = v
        end
    end
    table.sort(names)
    if #names == 0 then table.insert(names, "(нет HoleHitbox)") end
    return names
end

-- 444
-- 333
-- 222
local function findMainBase()
    local _, _, hrp = getChar()
    if not hrp then return nil, nil end
    local bestSpawn, bestDist = nil, math.huge
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("SpawnLocation") and v.Name == "BaseSpawn" then
            local dist = (v.Position - hrp.Position).Magnitude
            if dist < bestDist then bestSpawn, bestDist = v, dist end
        end
    end
    if not bestSpawn then return nil, nil end
    local baseModel = bestSpawn.Parent
    if baseModel then
        local hole = baseModel:FindFirstChild("HoleHitbox")
        if hole then return hole, baseModel.Name end
    end
    return nil, nil
end

-- 333
-- 333
-- 333
local function findBigItemSpawn()
    local bis = Workspace:FindFirstChild("BigItemSpawns")
    if bis then return bis end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "BigItemSpawns" then return v end
    end
    return nil
end

local function startBigItemEvent()
    state.bigItemEvent = true
    if state.bigItemConn then state.bigItemConn:Disconnect() end

    state.bigItemConn = RunService.Heartbeat:Connect(function()
        if not state.bigItemEvent then return end
        if not state.bigItemZone then return end
        local target = holeNameToObject[state.bigItemZone]
        if not target then return end

        local bis = findBigItemSpawn()
        if not bis then return end

        local bigItem = nil
        for _, v in ipairs(bis:GetDescendants()) do
            if (v:IsA("Model") or v:IsA("BasePart")) and (v.Name:lower():find("big") or v.Name == state.bigItemName) then
                bigItem = v break
            end
        end
        if not bigItem then return end

        print("[BigItem] Найден:", bigItem.Name)
        local part = bigItem:IsA("BasePart") and bigItem or (bigItem.PrimaryPart or bigItem:FindFirstChildWhichIsA("BasePart", true))
        if not part then return end

        jumpFlyTo(part.Position, 15, state.bigItemSpeed)
        task.wait(0.2)

        local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function()
                if fireproximityprompt then fireproximityprompt(prompt)
                elseif prompt.InputHoldBegin then
                    prompt:InputHoldBegin(); task.wait(prompt.HoldDuration or 0.1); prompt:InputHoldEnd()
                end
            end)
            print("[BigItem] Взяли")
            task.wait(0.3)
        end

        print("[BigItem] Летим в", state.bigItemZone)
        jumpFlyTo(target.Position, 30, state.bigItemSpeed)
        task.wait(0.3)

        local cam = workspace.CurrentCamera
        local _, _, hrp = getChar()
        if cam and hrp then cam.CFrame = CFrame.new(hrp.Position, target.Position) end
        task.wait(0.15)
        local vp = cam.ViewportSize
        VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
        pcall(function() ThrowItem:FireServer() end)
        print("[BigItem] Кинули в", state.bigItemZone)
    end)
end

local function stopBigItemEvent()
    state.bigItemEvent = false
    if state.bigItemConn then state.bigItemConn:Disconnect(); state.bigItemConn = nil end
end

-- хз
local function onCharacterAdded(char)
    task.wait(state.respawnDelay)
    if state.farmRunning then
        state.jumpActive = false
        setNoclip(true); startJumpFly()
    end
end
local function bindAutoRespawn()
    if state.charAddedConn then state.charAddedConn:Disconnect() end
    state.charAddedConn = plr.CharacterAdded:Connect(onCharacterAdded)
    local function watchChar(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        if state.diedConn then state.diedConn:Disconnect() end
        state.diedConn = hum.Died:Connect(function() state.jumpActive = false end)
    end
    if plr.Character then watchChar(plr.Character) end
    plr.CharacterAdded:Connect(watchChar)
end

-- хуй
local function setNoclip(on)
    state.noclipEnabled = on
    if on then
        if state.noclipConn then state.noclipConn:Disconnect() end
        state.noclipConn = RunService.Stepped:Connect(function()
            local char = plr.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end)
    else
        if state.noclipConn then state.noclipConn:Disconnect(); state.noclipConn = nil end
        local char = plr.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

-- флу
local function startJumpFly()
    local _, _, hrp = getChar()
    if not hrp then return false end
    if state.jumpActive then return true end
    state.jumpActive = true
    local oldBv = hrp:FindFirstChild("WalkFarm_BV"); if oldBv then oldBv:Destroy() end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "WalkFarm_BV"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp
    local oldBg = hrp:FindFirstChild("WalkFarm_BG"); if oldBg then oldBg:Destroy() end
    local bg = Instance.new("BodyGyro")
    bg.Name = "WalkFarm_BG"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000; bg.D = 500; bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    local _, hum = getChar(); if hum then hum.PlatformStand = true end
    return true
end

local function stopJumpFly()
    state.jumpActive = false
    local _, _, hrp = getChar()
    if hrp then
        local bv = hrp:FindFirstChild("WalkFarm_BV"); if bv then bv:Destroy() end
        local bg = hrp:FindFirstChild("WalkFarm_BG"); if bg then bg:Destroy() end
    end
    local _, hum = getChar(); if hum then hum.PlatformStand = false end
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
        if not state.farmRunning and not state.bigItemEvent then return false end
        local _, _, hrp2 = getChar()
        if not hrp2 then return false end
        local dist = (hrp2.Position - targetPos).Magnitude
        if dist < 4 then
            local bv = hrp2:FindFirstChild("WalkFarm_BV"); if bv then bv.Velocity = Vector3.new(0, 0, 0) end
            return true
        end
        local dir = (targetPos - hrp2.Position).Unit
        local speed = math.min(speedMax, dist * 2.5)
        local bv = hrp2:FindFirstChild("WalkFarm_BV"); if bv then bv.Velocity = dir * speed end
        task.wait(0.02)
    end
    return false
end

-- попа
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

-- хотьбааа
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

-- ебаааа
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

-- 67 клик
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
        if fireproximityprompt then fireproximityprompt(prompt)
        elseif prompt.InputHoldBegin then
            prompt:InputHoldBegin(); task.wait(prompt.HoldDuration or 0.1); prompt:InputHoldEnd()
        end
    end)
    task.wait(0.15)
    simpleThrow()
    task.wait(state.postThrowDelay)
    if state.farmCounter % state.giveMeThreshold == 0 then triggerGiveMe() end
    return true
end

local function startFarm()
    if state.farmRunning then return end
    state.farmRunning = true
    state.farmCounter = 0
    setNoclip(true)
    if not startJumpFly() then state.farmRunning = false return end
    task.spawn(function()
        while state.farmRunning do
            if not state.infiniteFarm and state.farmCounter >= state.farmLimit then break end
            local char, hum = getChar()
            if not char or not hum or hum.Health <= 0 then task.wait(0.5)
            else doFarmCycle() end
            task.wait(0.05)
        end
        state.farmRunning = false
        stopJumpFly(); setNoclip(false)
    end)
end

local function stopFarm()
    state.farmRunning = false
    stopJumpFly(); setNoclip(false)
end

-- гйу
local Window = HIros:CreateWindow({
    Name = "Walk Farm v37",
    Theme = "Purple",
    GlowMode = "rainbow",
    Shoutout = false,
    ClickEffect = { Enabled = true, Style = "Rings", Color = "theme", Size = 90, Rings = 3 },
    Sounds = { Volume = 0.7 },
})

-- сканик
local holesList = scanHoles()

-- BIG ГОВНО
local BigItemTab = Window:CreateTab({ Name = "🎁 BIG ITEM", Icon = "🎁" })

BigItemTab:CreateSection({ Text = "Основная база" })
BigItemTab:CreateButton({
    Name = "🎯 Определить основную базу",
    Callback = function()
        local hole, name = findMainBase()
        if hole then
            state.mainBaseHole = hole
            state.mainBaseName = name
            Window:Notify({ Title = "Основная база", Content = hole:GetFullName(), Kind = "success" })
        else
            Window:Notify({ Title = "Ошибка", Content = "База не найдена", Kind = "error" })
        end
    end,
})

BigItemTab:CreateSection({ Text = "🎁 BIG ITEM Event" })

BigItemTab:CreateDropdown({
    Name = "Зона",
    Options = holesList,
    CurrentOption = holesList[1],
    Callback = function(opt)
        state.bigItemZone = opt
        print("[BigItem] Зона:", opt)
    end,
})
state.bigItemZone = holesList[1]

BigItemTab:CreateInput({
    Name = "Имя Big Item",
    Placeholder = "BigItem",
    CurrentValue = "BigItem",
    Callback = function(v) state.bigItemName = v end,
})

BigItemTab:CreateSlider({
    Name = "Скорость полёта (studs/s)",
    Min = 16, Max = 100, Increment = 1,
    CurrentValue = 16,
    Callback = function(v) state.bigItemSpeed = v end,
})

BigItemTab:CreateToggle({
    Name = "🎁 Авто-BIG ITEM",
    CurrentValue = false,
    Callback = function(v)
        if v then startBigItemEvent() else stopBigItemEvent() end
    end,
})

-- дилдо в дырку
local FarmTab = Window:CreateTab({ Name = "Фарм", Icon = "⚡" })

FarmTab:CreateSection({ Text = "База (для фарма)" })

FarmTab:CreateDropdown({
    Name = "Выбери базу",
    Options = holesList,
    CurrentOption = holesList[1],
    Callback = function(opt)
        state.selectedHole = holeNameToObject[opt]
    end,
})
state.selectedHole = holeNameToObject[holesList[1]]

FarmTab:CreateButton({
    Name = "🎯 Использовать основную базу",
    Callback = function()
        if state.mainBaseHole then
            state.selectedHole = state.mainBaseHole
            Window:Notify({ Title = "Фарм", Content = "Основная база", Kind = "success" })
        else
            Window:Notify({ Title = "Ошибка", Content = "Определи основную базу", Kind = "error" })
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
FarmTab:CreateToggle({ Name = "♾ БЕСКОНЕЧНЫЙ РЕЖИМ", CurrentValue = true, Callback = function(v) state.infiniteFarm = v end })
FarmTab:CreateSlider({ Name = "Лимит предметов", Min = 1, Max = 500, Increment = 1, CurrentValue = 50, Callback = function(v) state.farmLimit = v end })
FarmTab:CreateSlider({ Name = "GiveMe после N", Min = 1, Max = 50, Increment = 1, CurrentValue = 10, Callback = function(v) state.giveMeThreshold = v end })
FarmTab:CreateDropdown({ Name = "Способ GiveMe", Options = {"Invoke", "Click", "Both"}, CurrentOption = "Invoke", Callback = function(opt) state.giveMeMethod = opt end })
FarmTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Callback = function(v) setNoclip(v) end })

FarmTab:CreateSection({ Text = "💀 Auto-Respawn" })
FarmTab:CreateToggle({ Name = "💀 Продолжать фарм после смерти", CurrentValue = true, Callback = function(v) state.autoRespawnEnabled = v end })
FarmTab:CreateSlider({ Name = "Задержка респавна (сек)", Min = 0.5, Max = 5, Increment = 0.1, CurrentValue = 1.5, Callback = function(v) state.respawnDelay = v end })

FarmTab:CreateSection({ Text = "Управление" })
FarmTab:CreateButton({
    Name = "▶ START ФАРМ",
    Callback = function()
        startFarm()
        Window:Notify({ Title = "Фарм", Content = "Запущен", Kind = "success" })
    end,
})
FarmTab:CreateButton({
    Name = "■ STOP ФАРМ",
    Callback = function()
        stopFarm()
        Window:Notify({ Title = "Фарм", Content = "Остановлен (" .. state.farmCounter .. ")", Kind = "warning" })
    end,
})

-- стать геем
local TrainTab = Window:CreateTab({ Name = "Тренировка", Icon = "💪" })
local trainRunning = false
local trainCounter = 0
local spamRate = 0.1
TrainTab:CreateSection({ Text = "Настройки" })
TrainTab:CreateSlider({ Name = "Задержка", Min = 0.01, Max = 1, Increment = 0.01, CurrentValue = 0.1, Callback = function(v) spamRate = v end })

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
        trainRunning = true; trainCounter = 0
        task.spawn(function()
            while trainRunning do doTrainCycle(); task.wait(spamRate) end
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

-- хуй знает
local SettingsTab = Window:CreateTab({ Name = "Настройки", Icon = "⚙" })
SettingsTab:CreateSection({ Text = "Внешний вид" })
SettingsTab:CreateSlider({ Name = "Масштаб окна", Min = 0.5, Max = 1.5, Increment = 0.05, CurrentValue = 1, Callback = function(v) Window:SetScale(v) end })
SettingsTab:CreateToggle({ Name = "Частицы фона", CurrentValue = true, Callback = function(v) Window:SetParticles(v) end })
SettingsTab:CreateDropdown({ Name = "Тема", Options = {"Blue", "Red", "Yellow", "Green", "Purple"}, CurrentOption = "Purple", Callback = function(opt) Window:SetTheme(opt) end })
SettingsTab:CreateSection({ Text = "Профили" })
Window:CreateConfigManager(SettingsTab)
SettingsTab:CreateSection({ Text = "Горячие клавиши" })
SettingsTab:CreateKeybind({ Name = "Открыть/закрыть меню", CurrentKeybind = Enum.KeyCode.RightShift, Callback = function(kc) Window:SetHotkey(kc) end })

-- смок
local InfoTab = Window:CreateTab({ Name = "Инфо", Icon = "ℹ" })
InfoTab:CreateParagraph({
    Title = "Walk Farm v37",
    Content = "🎁 Зоны сканируются 1 раз при старте. Скорость 16. +100к и мифик.",
})

-- ИНИЦИАЛИЗАЦИЯ
bindAutoRespawn()
task.spawn(function()
    task.wait(1)
    local hole, name = findMainBase()
    if hole then
        state.mainBaseHole = hole
        state.mainBaseName = name
        print("[BigItem] Основная база:", hole:GetFullName())
    end
end)

print("куркума😡")
