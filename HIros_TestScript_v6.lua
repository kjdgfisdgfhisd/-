--[[
================================================================================
 HIros — скрипт самопроверки (Self-Test)
 Проверяет новую функциональность библиотеки прямо в Roblox: таблицу, выбор
 иконки, хоткеи, HUD-виджеты, уведомления и настройки доступности.

 ЗАПУСК
   1) Studio: положи этот скрипт рядом с ModuleScript «HIros» (внутри которого
      лежит код библиотеки) и запусти. Скрипт найдёт модуль и загрузит его.
   2) Вне Studio (executor): библиотека обычно уже загружена в этом же процессе.
      Сделай так, чтобы скрипт её увидел — любой из вариантов:
         getgenv().HIros = HIros            -- если библиотека уже загружена рядом
         _G.HIros = HIros
         CONFIG.Library = HIros             -- прямо в этом файле
         CONFIG.LibraryUrl = "https://..."  -- если нужно скачать по ссылке
      Если ничего не найдено, тест остановится и напишет, чего не хватило.

 ЧТО ПРОВЕРЯЕТСЯ
   Автоматически: программный API (методы Get/Set/Sort/Filter/SetMode/...),
   отсутствие ошибок при создании элементов, порядок LayoutOrder, темы, поиск,
   очередь уведомлений, настройки доступности, конфликты клавиш.
   Вручную (клики скрипт эмулировать не может): список шагов печатается в конце.

 ВАЖНО
   Окно создаётся с Shoutout = false, то есть попап согласия на Discord-шатаут
   не показывается и в сеть ничего не уходит. Настройка CONFIG.UseSounds = false
   отключает звуки интерфейса, чтобы прогон был тихим.

 Отчёт печатается в Output (Studio) и, если доступен writefile, сохраняется в файл.
================================================================================
]]

local CONFIG = {
    -- Откуда взять библиотеку (порядок поиска: Library -> getgenv/_G -> script -> URL)
    Library = nil,
    LibraryUrl = "",                       -- пример: "https://raw.githubusercontent.com/user/repo/main/library.lua"
    -- Настройки прогона
    WindowName = "HIros Self-Test",
    Theme = nil,                           -- nil = тема по умолчанию, иначе "Blue"/"Red"/...
    UseSounds = false,
    Particles = false,
    CloseWindow = false,                   -- true = закрыть окно после отчёта
    ReportFile = "hiros_selftest_report.txt",
    PrintManualSteps = true,
}

-- ============================================================================
-- 1. ПОИСК БИБЛИОТЕКИ
-- ============================================================================
local function looksLikeLibrary(value)
    return type(value) == "table" and type(value.CreateWindow) == "function" and type(value.CreateTab) == "function"
end

local function tryRequire(instance)
    if not instance then return nil end
    local ok, result = pcall(function() return require(instance) end)
    if ok and looksLikeLibrary(result) then return result end
    return nil
end

local function resolveLibrary()
    if looksLikeLibrary(CONFIG.Library) then return CONFIG.Library, "CONFIG.Library" end

    local environment
    local okEnv, env = pcall(function() return getgenv and getgenv() end)
    if okEnv and type(env) == "table" and looksLikeLibrary(env.HIros) then return env.HIros, "getgenv().HIros" end
    if type(_G) == "table" and looksLikeLibrary(_G.HIros) then return _G.HIros, "_G.HIros" end

    local testScript = script
    if testScript then
        local names = { "HIros", "HIros 6.0", "HIros 6.1", "HIros_6", "Library" }
        local parents = { testScript.Parent, testScript }
        if testScript.Parent then parents[#parents + 1] = testScript.Parent.Parent end
        for _, parent in ipairs(parents) do
            if parent then
                for _, childName in ipairs(names) do
                    local found = tryRequire(parent:FindFirstChild(childName))
                    if found then return found, "ModuleScript " .. childName end
                end
            end
        end
        -- сам скрипт может быть модулем библиотеки
        local selfModule = tryRequire(testScript)
        if selfModule then return selfModule, "require(script)" end
    end

    if CONFIG.LibraryUrl ~= "" and type(game.HttpGet) == "function" then
        local okFetch, source = pcall(function() return game:HttpGet(CONFIG.LibraryUrl) end)
        if okFetch and type(source) == "string" and #source > 0 then
            local chunk = loadstring or load
            local okLoad, loaded = pcall(chunk, source)
            if okLoad and looksLikeLibrary(loaded) then return loaded, CONFIG.LibraryUrl end
        end
    end

    return nil, "не найдена (задай CONFIG.Library, getgenv().HIros или CONFIG.LibraryUrl)"
end

local HIros, librarySource = resolveLibrary()
if not looksLikeLibrary(HIros) then
    warn("[HIros self-test] Библиотека " .. tostring(librarySource))
    return
end

-- ============================================================================
-- 2. МИНИ-ФРЕЙМВОРК ТЕСТОВ
-- ============================================================================
local report = {
    passed = 0,
    failed = 0,
    skipped = 0,
    entries = {},
}

local function record(status, name, detail)
    local line = string.format("%s | %s%s", status, name, detail and (" | " .. tostring(detail)) or "")
    report.entries[#report.entries + 1] = line
    if status == "PASS" then report.passed = report.passed + 1
    elseif status == "FAIL" then report.failed = report.failed + 1
    else report.skipped = report.skipped + 1 end
    if status == "FAIL" then warn("[self-test] " .. line) else print("[self-test] " .. line) end
end

local function check(name, ok, detail)
    if ok then record("PASS", name, detail) else record("FAIL", name, detail) end
    return ok and true or false
end

local function skip(name, reason)
    record("SKIP", name, reason)
end

local function section(title)
    report.entries[#report.entries + 1] = ""
    report.entries[#report.entries + 1] = "== " .. title .. " =="
    print("[self-test] ---- " .. title .. " ----")
end

-- Выполняет шаг и превращает ошибку в проваленную проверку, не роняя весь прогон.
local function step(name, fn)
    local ok, err = pcall(fn)
    check(name, ok, not ok and tostring(err) or nil)
    return ok
end

local function findChild(root, name)
    if not root then return nil end
    local ok, child = pcall(function() return root:FindFirstChild(name) end)
    if ok then return child end
    return nil
end

local function findFirstOfClass(root, className)
    if not root then return nil end
    for _, child in ipairs(root:GetChildren()) do
        if child.ClassName == className then return child end
    end
    return nil
end

local function findDescendantOfClass(root, className)
    if not root then return nil end
    for _, child in ipairs(root:GetDescendants()) do
        if child.ClassName == className then return child end
    end
    return nil
end

local function countNamed(root, pattern)
    if not root then return 0 end
    local count = 0
    for _, child in ipairs(root:GetDescendants()) do
        if child.Name and child.Name:match(pattern) then count = count + 1 end
    end
    return count
end

local function joined(rows, key)
    local parts = {}
    for _, row in ipairs(rows or {}) do parts[#parts + 1] = tostring(row[key]) end
    return table.concat(parts, ",")
end

local function isCallable(target, key)
    return type(target) == "table" and type(target[key]) == "function"
end

print(string.format("[HIros self-test] библиотека загружена (%s)", tostring(librarySource)))

-- ============================================================================
-- 3. API БИБЛИОТЕКИ
-- ============================================================================
section("1. API библиотеки")
local apiFunctions = {
    "CreateWindow", "CreateTab", "CreateTabGroup", "Notify", "SetTheme", "SetGlowMode",
    "SetAccessibility", "SetReduceMotion", "SetUIScale", "SetHighContrast",
    "CreateHUD", "GetHUDWidgets", "SetHUDVisible", "DestroyHUDWidgets",
    "GetKeybinds", "GetKeybindConflicts", "RefreshKeybindConflicts",
    "SaveConfig", "LoadConfig", "DeleteConfig", "GetConfigs",
    "Search", "ClearSearch", "Minimize", "SetHotkey", "GetHotkey", "Confirm", "GetInfo",
}
local missingApi = {}
for _, key in ipairs(apiFunctions) do
    if not isCallable(HIros, key) then missingApi[#missingApi + 1] = key end
end
check("публичный API на месте (" .. #apiFunctions .. " функций)", #missingApi == 0, #missingApi > 0 and table.concat(missingApi, ", ") or nil)
step("GetInfo() выполняется", function() HIros:GetInfo() end)

-- ============================================================================
-- 4. ОКНО И БАЗОВАЯ РАЗМЕТКА
-- ============================================================================
section("2. Окно и разметка")
local window
step("CreateWindow()", function()
    window = HIros:CreateWindow({
        Name = CONFIG.WindowName,
        Shoutout = false,          -- никаких попапов согласия и сетевых отправок
        Sounds = CONFIG.UseSounds,
        Particles = CONFIG.Particles,
        Theme = CONFIG.Theme,
    })
end)
check("CreateWindow вернул объект", type(window) == "table")
check("методы окна доступны на Window", isCallable(window, "Notify") and isCallable(window, "CreateTab")
    and isCallable(window, "Search") and isCallable(window, "SetTheme") and isCallable(window, "CreateHUD"))
if type(window) ~= "table" then
    -- без окна остальные проверки бессмысленны: подводим итог и выходим
    warn("[HIros self-test] окно не создано — прогон остановлен")
    print(string.format("[self-test] %s", table.concat(report.entries, "\n")))
    return
end
check("ScreenGui создан и виден", window and window.ScreenGui and window.ScreenGui.Parent ~= nil)
check("окно показано после создания", window and window.Main and window.Main.Visible == true)

local tab
step("CreateTab()", function() tab = window:CreateTab({ Name = "🧪 Self-Test", Icon = "🧪" }) end)
check("вкладка с рабочей областью", tab ~= nil and tab.Content ~= nil)
check("вкладка стала текущей", window ~= nil and window.CurrentTab ~= nil and window.Tabs[window.CurrentTab] ~= nil)

local pageLayout = findFirstOfClass(tab and tab.Content, "UIListLayout")
check("UIListLayout сортирует по LayoutOrder", pageLayout ~= nil and pageLayout.SortOrder == Enum.SortOrder.LayoutOrder)
local pagePadding = findFirstOfClass(tab and tab.Content, "UIPadding")
check("UIPadding принимает UDim", pagePadding ~= nil and typeof(pagePadding.PaddingRight) == "UDim")

local ordered = {}
step("элементы без Order создаются", function()
    ordered[1] = tab:CreateLabel({ Text = "Блок самопроверки №1" })
    ordered[2] = tab:CreateDivider({})
    ordered[3] = tab:CreateLabel({ Text = "Блок самопроверки №2" })
end)
check("LayoutOrder расставлен по возрастанию", ordered[1] ~= nil and ordered[3] ~= nil
    and ordered[1].LayoutOrder < ordered[2].LayoutOrder and ordered[2].LayoutOrder < ordered[3].LayoutOrder,
    ordered[1] and string.format("%d < %d < %d", ordered[1].LayoutOrder, ordered[2].LayoutOrder, ordered[3].LayoutOrder) or nil)

-- ============================================================================
-- 5. ТАБЛИЦА
-- ============================================================================
section("3. Таблица: сортировка, фильтр, мультивыбор, действия")
local actionHits, rowClicks = 0, 0
local view
step("CreateTable()", function()
    view = tab:CreateTable({
        Name = "Игроки",
        Height = 140,
        MultiSelect = true,
        Searchable = true,
        Columns = {
            { Key = "Name", Name = "Игрок", Width = 2 },
            { Key = "Ping", Name = "Пинг", Width = 1 },
        },
        Rows = {
            { Name = "Alice", Ping = 40 },
            { Name = "Bob", Ping = 20 },
            { Name = "Alina", Ping = 60 },
        },
        Actions = {
            { Name = "Профиль", Text = "↗", Callback = function() actionHits = actionHits + 1 end },
        },
        Callback = function() rowClicks = rowClicks + 1 end,
    })
end)
check("таблица создана", view ~= nil and view.Instance ~= nil)
check("Get() вернул все строки", view ~= nil and #view:Get() == 3)
check("Sort() по возрастанию", view ~= nil and view.Sort("Ping") and joined(view:Get(), "Name") == "Bob,Alice,Alina", view and joined(view:Get(), "Name") or nil)
local sortKey, sortAscending
if view then sortKey, sortAscending = view:GetSort() end
check("GetSort() сообщает колонку и направление", sortKey == "Ping" and sortAscending == true,
    string.format("%s/%s", tostring(sortKey), tostring(sortAscending)))
check("повторный Sort() переворачивает порядок", view ~= nil and view:Sort("Ping") and joined(view.Get(view), "Name") == "Alina,Alice,Bob", view and joined(view:Get(), "Name") or nil)
check("в заголовке есть стрелка сортировки", (function()
    if not view then return false end
    for _, child in ipairs(view.Instance:GetDescendants()) do
        if child.ClassName == "TextButton" and (child.Text:find("▲") or child.Text:find("▼")) then return true end
    end
    return false
end)())
check("Filter() фильтрует без потери данных", view ~= nil and view:Filter("ali") and #view:GetVisible() == 2 and #view:Get() == 3,
    view and tostring(#view:GetVisible()) or nil)
local tableEmpty = findChild(view and view.Instance, "TableEmptyState")
check("при найденных строках пустое состояние скрыто", tableEmpty ~= nil and tableEmpty.Visible == false)
check("пустое состояние показывается", view ~= nil and view.Filter("нет-такого") and #view:GetVisible() == 0
    and tableEmpty.Visible == true and tableEmpty.Text == "Ничего не найдено", tableEmpty and tableEmpty.Text or nil)
check("снятие фильтра возвращает строки", view ~= nil and view.Filter("") and #view:GetVisible() == 3 and tableEmpty.Visible == false)
check("строки отрисованы", view ~= nil and countNamed(view.Instance, "^TableRow$") == 3, view and tostring(countNamed(view.Instance, "^TableRow$")) or nil)
check("кнопки действий в строках", view ~= nil and countNamed(view.Instance, "^TableAction_1$") == 3)
step("сортировка по возрастанию перед AddRow", function() view:Sort("Ping", true) end)
step("AddRow()", function() view:AddRow({ Name = "Aaron", Ping = 10 }) end)
check("AddRow встаёт на своё место в сортировке", view ~= nil and joined(view:Get(), "Name") == "Aaron,Bob,Alice,Alina", view and joined(view:Get(), "Name") or nil)
check("строка без ключа сортировки уходит в конец", (function()
    if not view then return false end
    view:AddRow({ Name = "Без пинга" })
    local rows = view:Get()
    return rows[#rows].Name == "Без пинга"
end)())
check("Clear() очищает таблицу", view ~= nil and (view.Clear() or true) and #view:Get() == 0 and tableEmpty.Text == "Нет записей")
check("Set() заменяет строки", view ~= nil and view:Set({ { Name = "Zoe", Ping = 1 } }) and #view:Get() == 1)
local bodyLayout
if view then
    local bodyScroller
    for _, child in ipairs(view.Instance:GetChildren()) do
        if child.ClassName == "ScrollingFrame" then bodyScroller = child end
    end
    bodyLayout = findFirstOfClass(bodyScroller, "UIListLayout")
end
check("тело таблицы сортируется по LayoutOrder", bodyLayout ~= nil and bodyLayout.SortOrder == Enum.SortOrder.LayoutOrder)

local fixedView = tab:CreateTable({
    Searchable = false,
    Columns = { { Key = "Name", Sortable = false } },
    Rows = { { Name = "B" }, { Name = "A" } },
})
check("несортируемая колонка отклоняет Sort()", fixedView ~= nil and fixedView.Sort(fixedView, "Name") == false)
check("UpdateTheme() таблицы без ошибок", view ~= nil and pcall(view.UpdateTheme))

-- ============================================================================
-- 6. ВЫБОР ИКОНКИ
-- ============================================================================
section("4. Выбор иконки/картинки")
local picker
step("CreateIconPicker()", function()
    picker = tab:CreateIconPicker({
        Name = "Иконка игрока",
        Flag = "selftest_icon",
        Height = 110,
        Items = {
            "⚡",
            { Name = "Синий", Value = "blue", Icon = "🔵", Search = "azure" },
            { Name = "Значок", Image = 12345, Favorite = true },
        },
        Favorites = { "⚡" },
        CurrentValue = "⚡",
    })
end)
check("иконка выбрана по умолчанию", picker ~= nil and picker:Get() == "⚡", picker and tostring(picker:Get()) or nil)
check("избранное подхвачено из конфига", picker ~= nil and #picker:GetFavorites() == 2, picker and tostring(#picker:GetFavorites()) or nil)
check("поиск регистронезависимый (в т.ч. по Search)", picker ~= nil and picker:Search("AZURE") and countNamed(picker.Instance, "^Icon_") == 1,
    picker and tostring(countNamed(picker.Instance, "^Icon_")) or nil)
step("сброс поиска", function() picker:Search("") end)
check("фильтр «Избранное»", picker ~= nil and picker:SetFilter("favorites") and countNamed(picker.Instance, "^Icon_") == 2)
step("вернуть фильтр «Все»", function() picker:SetFilter("all") end)
check("звёздочка снимает избранное", picker ~= nil and picker:ToggleFavorite("⚡") == false and #picker:GetFavorites() == 1)
check("звёздочка возвращает избранное", picker ~= nil and picker:ToggleFavorite("⚡") == true and #picker:GetFavorites() == 2)
check("числовой ID превращается в rbxassetid", picker ~= nil and picker:Set(98765) == true and picker:Get() == "rbxassetid://98765", picker and tostring(picker:Get()) or nil)
check("значение записано в Flag", window.Flags.selftest_icon == "rbxassetid://98765")
check("история недавних пополнилась", picker ~= nil and picker:GetRecent()[1] == "rbxassetid://98765")
check("невалидное значение отклонено", picker ~= nil and picker:Set({}) == false)
local previewFrame = findChild(picker and picker.Instance, "IconPreview")
local previewImage = previewFrame and findFirstOfClass(previewFrame, "ImageLabel")
check("превью показывает картинку", previewImage ~= nil and previewImage.Visible == true and previewImage.Image == "rbxassetid://98765")
check("UpdateTheme() выбора иконки без ошибок", picker ~= nil and pcall(picker.UpdateTheme))

-- ============================================================================
-- 7. ХОТКЕИ
-- ============================================================================
section("5. Менеджер хоткеев")
local bindA, bindB
step("CreateKeybind() x2 с одной клавишей", function()
    bindA = tab:CreateKeybind({ Name = "ESP", Flag = "selftest_esp", Mode = "Toggle", CurrentKeybind = Enum.KeyCode.F })
    bindB = tab:CreateKeybind({ Name = "Fly", Flag = "selftest_fly", CurrentKeybind = Enum.KeyCode.F })
end)
check("хоткеи зарегистрированы", #window:GetKeybinds() == 2, tostring(#window:GetKeybinds()))
local conflicts = window:GetKeybindConflicts()
check("конфликт клавиш найден", conflicts ~= nil and conflicts.F ~= nil and #conflicts.F == 2,
    conflicts and (conflicts.F and table.concat(conflicts.F, ",") or "нет") or nil)
check("бинды видят конфликт", bindA ~= nil and #bindA:GetConflict() == 1 and #bindB:GetConflict() == 1)
local conflictLabel = findChild(bindA and bindA.Instance, "KeybindConflict")
check("конфликт показан подписью", conflictLabel ~= nil and conflictLabel.Text:find("⚠") ~= nil, conflictLabel and conflictLabel.Text or nil)
check("Set() меняет клавишу", bindA ~= nil and bindA:Set(Enum.KeyCode.H) and bindA.Get(bindA) == Enum.KeyCode.H)
check("конфликт исчез после смены клавиши", next(window:GetKeybindConflicts()) == nil and conflictLabel.Text == "")
check("режим Hold включается", bindA ~= nil and bindA:SetMode("Hold") and bindA:GetMode() == "Hold")
check("неизвестный режим отклонён", bindA ~= nil and bindA:SetMode("Turbo") == false)
check("состояние читается и меняется", (function()
    if not bindA then return false end
    bindA:SetState(true)
    local isOn = bindA:GetState() == true
    bindA:SetState(false)
    return isOn and bindA:GetState() == false
end)())
check("ключ и режим сохранены в Flags", window.Flags.selftest_esp == "H" and window.Flags.selftest_esp_mode == "Hold")
local keyBadge = findChild(bindA and bindA.Instance, "KeybindKey")
local keyStroke = keyBadge and findFirstOfClass(keyBadge, "UIStroke")
check("UIStroke на плашке — Border", keyStroke ~= nil and keyStroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border)
check("UpdateTheme() хоткея без ошибок", bindA ~= nil and pcall(bindA.UpdateTheme))

-- ============================================================================
-- 8. HUD-ВИДЖЕТЫ
-- ============================================================================
section("6. HUD-виджеты")
local hud, hudSecond
step("CreateHUD()", function()
    hud = window:CreateHUD({ Name = "FPS", Text = "60 FPS", Icon = "🎯", Position = "top-left", Flag = "selftest_hud" })
end)
check("виджет создан в HUD-слое", hud ~= nil and hud.Instance ~= nil and hud.Instance.Parent ~= nil and hud.Instance.Parent.Name == "HUDLayer")
check("угол по умолчанию", hud ~= nil and hud:GetPosition().Side == "top-left")
check("текст виджета меняется", hud ~= nil and hud:SetText("120 FPS") and hud:GetText() == "120 FPS")
check("смена угла", hud ~= nil and hud:SetPosition("bottom-right") and hud:GetPosition().Side == "bottom-right")
check("позиция записана в Flag", type(window.Flags.selftest_hud) == "table" and window.Flags.selftest_hud.Side == "bottom-right")
check("неизвестный угол отклонён", hud ~= nil and hud:SetPosition("center") == false)
check("скрытие и показ виджета", hud ~= nil and hud:SetVisible(false) and hud:GetVisible() == false and hud:SetVisible(true) and hud:GetVisible() == true)
step("второй виджет", function() hudSecond = window:CreateHUD({ Name = "Ping", Text = "24 ms" }) end)
check("виджеты перечисляются", #window:GetHUDWidgets() == 2)
check("Snap() возвращает угол", hud ~= nil and type(hud:Snap()) == "string")
check("слой HUD скрывается и показывается", window:SetHUDVisible(false) and window._hudLayer.Visible == false and window:SetHUDVisible(true))
step("DestroyHUDWidgets()", function() window:DestroyHUDWidgets() end)
check("все виджеты удалены", #window:GetHUDWidgets() == 0)
step("виджет заново (для ручной проверки перетаскивания)", function()
    hud = window:CreateHUD({ Name = "Перетащи меня", Text = "HUD", Icon = "🤚", Position = "top-right", Flag = "selftest_hud_drag" })
end)

-- ============================================================================
-- 9. УВЕДОМЛЕНИЯ
-- ============================================================================
section("7. Уведомления: очередь, прогресс, кнопки")
local noteA = window:Notify({ Title = "Очередь 1", Content = "первое", Duration = 30, MaxVisible = 2 })
local noteB = window:Notify({ Title = "Очередь 2", Content = "второе", Duration = 30, MaxVisible = 2 })
local noteC = window:Notify({ Title = "Очередь 3", Content = "третье", Duration = 30, MaxVisible = 2 })
check("уведомление создано как CanvasGroup", noteA ~= nil and noteA.Instance ~= nil and noteA.Instance.ClassName == "CanvasGroup")
check("видимых не больше лимита", #window:GetNotifications() == 3 and noteC.Queued == true and #window:GetQueuedNotifications() == 1)
check("третье ждёт в очереди", noteC.Instance == nil and noteC.IsVisible() == false)
noteA:Close()
check("после закрытия очередь продвигается", noteC.Queued == false and noteC.Instance ~= nil and noteC.IsVisible() == true)
check("закрытое уведомление убрано из списка", #window:GetNotifications() == 2)
noteB:Close()
noteC:Close()

local slotNote = window:Notify({ Title = "Слот", Sticky = true, MaxVisible = 1 })
local lowNote = window:Notify({ Title = "Низкий приоритет", Sticky = true, Priority = 1, MaxVisible = 1 })
local highNote = window:Notify({ Title = "Высокий приоритет", Sticky = true, Priority = 9, MaxVisible = 1 })
check("оба лишних уведомления в очереди", lowNote.Queued == true and highNote.Queued == true)
slotNote:Close()
check("первым показывается приоритетное", highNote.Queued == false and highNote.Instance ~= nil and lowNote.Queued == true)
highNote:Close()
check("следом идёт обычное", lowNote.Queued == false and lowNote.Instance ~= nil)
lowNote:Close()
check("очередь пуста", #window:GetNotifications() == 0)

local progressNote = window:Notify({ Title = "Загрузка", Content = "качаем файлы", Progress = 0, Sticky = true })
check("плавающий прогресс-бар создан", findChild(progressNote.Instance, "NotifyProgress") ~= nil and findChild(progressNote.Instance, "NotifyTimer") == nil)
progressNote:SetProgress(0.42)
check("проценты обновляются", findChild(progressNote.Instance, "NotifyPercent").Text == "42%")
check("SetProgress() ограничен 0..1", progressNote:SetProgress(4) and progressNote.Progress == 1)
check("SetTitle() меняет заголовок", progressNote.SetTitle("Почти готово") and findChild(progressNote.Instance, "NotifyTitle").Text == "Почти готово")
progressNote:Close()

local actionNote = window:Notify({
    Title = "Кнопки действий",
    Content = "нажми любую (ручная проверка)",
    Sticky = true,
    Actions = {
        { Name = "Да", Primary = true, Callback = function() end },
        { Name = "Нет", Close = false, Callback = function() end },
    },
})
check("кнопки действий созданы", findChild(actionNote.Instance, "NotifyAction_1") ~= nil and findChild(actionNote.Instance, "NotifyAction_2") ~= nil)
check("у липкого нет обратного отсчёта", (function()
    local bar = findChild(actionNote.Instance, "NotifyTimer")
    return bar ~= nil and bar.Visible == false
end)())
actionNote:Close()
check("ClearNotifications() очищает всё", (function()
    window:Notify({ Title = "Мусор", Duration = 20 })
    window:ClearNotifications()
    return #window:GetNotifications() == 0 and #window:GetQueuedNotifications() == 0
end)())

-- ============================================================================
-- 10. ДОСТУПНОСТЬ
-- ============================================================================
section("8. Доступность")
window:SetReduceMotion(true)
check("уменьшение анимаций включается", window:GetAccessibility().ReduceMotion == true)
window:SetReduceMotion(false)
check("уменьшение анимаций выключается", window:GetAccessibility().ReduceMotion == false)
check("масштаб интерфейса применяется", window:SetUIScale(1.25).Scale == 1.25 and window._uiScale.Scale == 1.25)
check("масштаб ограничен сверху", window:SetUIScale(4).Scale == 1.6)
window:SetUIScale(1)
local hudText = findChild(hud and hud.Instance, "HUDText")
window:SetHighContrast(true)
check("высокий контраст делает текст белым", hudText ~= nil and hudText.TextColor3.R == 1 and hudText.TextColor3.G == 1)
window:SetHighContrast(false)
check("высокий контраст отключается", window:GetAccessibility().HighContrast == false)
check("панели возвращают тему", hud ~= nil and hud.Instance.BackgroundColor3.R > 0.05)
check("настройки сохранены в Flag", type(window.Flags.accessibility) == "table")

-- ============================================================================
-- 11. ТЕМЫ, ПОИСК, КОНФИГИ, ПРОЧЕЕ
-- ============================================================================
section("9. Темы, поиск, конфиги, свернуть")
local themeFails = {}
for _, themeKey in ipairs({ "Blue", "Red", "Yellow", "Green", "Purple" }) do
    local ok = pcall(function() window:SetTheme(themeKey) end)
    if not ok then themeFails[#themeFails + 1] = themeKey end
end
check("все темы применяются без ошибок", #themeFails == 0, #themeFails > 0 and table.concat(themeFails, ", ") or nil)
step("радужное свечение", function() window:SetGlowMode("rainbow") end)
step("свечение обратно в тему", function() window:SetGlowMode("theme") end)
check("поиск находит русский текст", (function()
    local ok = pcall(function() window:Search("игроки") end)
    return ok and window._noResults ~= nil and window._noResults.Visible == false
end)())
step("поиск сброшен", function() window:ClearSearch() end)
step("свернуть и развернуть окно", function() window:Minimize() window:Minimize() end)
check("окно снова развёрнуто", window._minimized ~= true)
check("звуки переключаются", (function()
    local before = window:GetSoundsEnabled()
    window:SetSoundsEnabled(not before)
    local afterToggle = window:GetSoundsEnabled()
    window:SetSoundsEnabled(before)
    return afterToggle == (not before)
end)())

if type(writefile) == "function" and type(listfiles) == "function" and type(isfile) == "function" then
    local slot = "hiros_selftest"
    check("конфиг сохраняется", pcall(function() window:SaveConfig(slot) end))
    local found = false
    for _, name in ipairs(window:GetConfigs() or {}) do
        if name == slot then found = true end
    end
    check("конфиг виден в списке", found)
    check("конфиг загружается", pcall(function() window:LoadConfig(slot) end))
    check("конфиг удаляется", window:DeleteConfig(slot) == true)
else
    skip("профили конфигов (сохранение/загрузка/удаление)", "нет writefile/listfiles — Studio или низкий уровень доступа")
end

-- ============================================================================
-- 12. ОТЧЁТ
-- ============================================================================
section("10. Отчёт")
local elapsed = os.clock()
local summary = string.format("Пройдено: %d | Провалено: %d | Пропущено: %d", report.passed, report.failed, report.skipped)
print("[self-test] " .. summary)

local failureLines = {}
for _, line in ipairs(report.entries) do
    if line:sub(1, 4) == "FAIL" then failureLines[#failureLines + 1] = line end
end

if tab then
    step("отчёт выведен в окно", function()
        tab:CreateParagraph({
            Title = "Результат самопроверки",
            Content = summary .. "\n" .. (#failureLines > 0 and table.concat(failureLines, "\n") or "Провалов нет — все проверки прошли."),
        })
    end)
end

window:Notify({
    Kind = report.failed == 0 and "success" or "error",
    Title = report.failed == 0 and "Самопроверка пройдена" or "Самопроверка: есть ошибки",
    Content = summary,
    Duration = 10,
    Priority = 5,
})

if type(writefile) == "function" then
    local text = table.concat(report.entries, "\n") .. "\n\n" .. summary .. "\n"
    local ok = pcall(function() writefile(CONFIG.ReportFile, text) end)
    if ok then print("[self-test] отчёт сохранён в файл: " .. CONFIG.ReportFile) end
end

if CONFIG.PrintManualSteps then
    print([[
[self-test] РУЧНАЯ ПРОВЕРКА (то, что нельзя нажать из скрипта):
  1. Таблица: клик по заголовку — сортировка ▲/▼, клик по строке — подсветка (мультивыбор: Ctrl-подобного нет, просто кликай несколько строк), ввод в поле фильтра.
  2. Кнопка «↗» в строке — должна сработать без изменения выделения.
  3. Иконки: клик по плитке — выбор, ★ — избранное, вкладки «Все/Избранное/Недавние», ручной ввод rbxassetid в поле ниже.
  4. Хоткей: клик по плашке клавиши, затем нажми новую клавишу; переключи режим кликом по Press/Hold/Toggle.
  5. HUD: перетащи виджет мышью — он должен прилипнуть к ближайшему углу.
  6. Уведомления: нажми кнопки «Да»/«Нет» в уведомлении.
  7. Доступность: HIros:SetReduceMotion(true) и HIros:SetHighContrast(true) — окно должно моментально перестроиться.
]])
end

if CONFIG.CloseWindow then
    step("окно закрыто", function()
        if window.Main then window.Main.Visible = false end
        if window.ScreenGui then window.ScreenGui:Destroy() end
    end)
end

print(string.format("[self-test] готово за %.2f с: %s", elapsed, summary))
