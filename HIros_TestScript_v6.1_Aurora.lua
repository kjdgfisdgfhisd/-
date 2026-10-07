-- HIros_TestScript_v6.1_Aurora (LocalScript)
-- Тест библиотеки HIros v6.1 "Aurora": все компоненты + вкладка "Автотест",
-- которая сама проверяет ключевые вещи и показывает PASS/FAIL.
--
-- КАК ПОДКЛЮЧИТЬ БИБЛИОТЕКУ (скрипт выберет способ сам):
--   A) Roblox Studio (локально): создай ModuleScript с именем "HIros" рядом
--      с этим LocalScript, вставь в него код HIros_v6.0_Aurora.lua
--      и поставь USE_MODULE = true.
--      (loadstring/HttpGet в обычной Studio не работают — только ModuleScript.)
--   B) Через GitHub (для эксплуатационных окружений с HttpGet):
--      USE_MODULE = false и впиши свою raw-ссылку в LIB_URL.
--
-- LocalScript кладётся в StarterPlayer > StarterPlayerScripts.
--
-- ОФЛАЙН-ПРОГОН (без Roblox): HIros_Aurora_Offline.lua в папке results —
-- поднимает заглушку API, подсовывает библиотеку через game:HttpGet и сам
-- нажимает кнопку «🧪 Запустить автотест».

-- Режим определяется сам: если у скрипта есть объект `script` (обычная Studio),
-- берём ModuleScript "HIros"; если `script` нет (запуск через загрузчик) — грузим по ссылке.
local HAS_SCRIPT = (typeof(script) == "Instance")
local USE_MODULE = HAS_SCRIPT  -- можно принудительно поставить false, чтобы всегда грузить по ссылке
local LIB_URL = "https://raw.githubusercontent.com/kjdgfisdgfhisd/-/refs/heads/main/HIros_v6.0_Aurora.lua"

local function loadFromUrl()
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(LIB_URL))()
	end)
	if not ok then
		warn("[HIros] Не удалось загрузить по ссылке. Проверь, что файл загружен на GitHub "
			.. "ровно с таким именем и ссылка открывается в браузере:\n" .. LIB_URL .. "\n" .. tostring(result))
		return nil
	end
	return result
end

local function loadFromModule()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local moduleScript = script:FindFirstChild("HIros")
		or (script.Parent and script.Parent:WaitForChild("HIros", 5))
		or ReplicatedStorage:FindFirstChild("HIros")

	if not moduleScript then
		warn("[HIros] Не найден ModuleScript с именем \"HIros\" (искал в самом скрипте, рядом с ним и в ReplicatedStorage).")
		return nil
	end
	if not moduleScript:IsA("ModuleScript") then
		warn("[HIros] Объект \"HIros\" имеет тип " .. moduleScript.ClassName .. ", а нужен именно ModuleScript.")
		return nil
	end

	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn("[HIros] Ошибка ВНУТРИ библиотеки при загрузке (пришли этот текст):\n" .. tostring(result))
		return nil
	end
	if type(result) ~= "table" or type(result.CreateWindow) ~= "function" then
		warn("[HIros] Модуль загрузился, но не вернул библиотеку. В ModuleScript должен быть весь код, "
			.. "последняя строка: return Library")
		return nil
	end
	return result
end

local function loadLibrary()
	if USE_MODULE and HAS_SCRIPT then
		local lib = loadFromModule()
		if lib then return lib end
		warn("[HIros] Модуль не подошёл, пробую загрузить по ссылке...")
	end
	return loadFromUrl()
end

local HIros = loadLibrary()
if not HIros then return end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- ОКНО
----------------------------------------------------------------
local Window = HIros:CreateWindow({
	Name = "HIros Test",
	Theme = "Blue",      -- Blue / Red / Yellow / Green / Purple
	GlowMode = "theme",  -- "theme" или "rainbow"
	Particles = true,    -- частицы на фоне
	Shoutout = false,    -- в тестах не спрашиваем про Discord; убери эту строку, чтобы проверить попап
	-- Sounds = false,   -- отключить звуки меню целиком
	-- Search = false,   -- убрать строку поиска в шапке
})

----------------------------------------------------------------
-- 1. ГЛАВНАЯ: кнопки, тултип, бейдж, хоткей на кнопке, confirm, уведомления, лоадер
----------------------------------------------------------------
local MainTab = Window:CreateTab({ Name = "Главная", Icon = "🏠", Group = "Компоненты" })

MainTab:CreateParagraph({
	Title = "Привет, " .. LocalPlayer.DisplayName .. "!",
	Content = "Тест HIros v6.0. Проверь: у окна все 4 угла скруглены, кнопки ➖ и ❌ круглые, у кнопки ⚡ в правом нижнем углу свечение идёт за ней при наведении.",
})

MainTab:CreateSection({ Text = "Кнопки" })

MainTab:CreateButton({
	Name = "🖱️ Наведи на меня (тултип)",
	Tooltip = "Подсказка появляется через ~0.5 сек наведения",
	Callback = function()
		Window:Notify({ Title = "Клик", Content = "Кнопка с тултипом сработала.", Duration = 3 })
	end,
})

MainTab:CreateButton({
	Name = "Кнопка с бейджем",
	Badge = "NEW",
	Callback = function()
		Window:Notify({ Title = "Бейдж", Content = "Бейдж на кнопке работает.", Duration = 3 })
	end,
})

MainTab:CreateButton({
	Name = "Кнопка с хоткеем (нажми G)",
	Keybind = Enum.KeyCode.G,
	Callback = function()
		Window:Notify({ Kind = "info", Title = "Хоткей", Content = "Сработало (клик или клавиша G).", Duration = 2 })
	end,
})

MainTab:CreateButton({
	Name = "⚠️ Опасное действие (Confirm)",
	Confirm = true,
	ConfirmText = "Фон должен затемниться, клик мимо попапа = отмена.",
	Callback = function()
		Window:Notify({ Kind = "success", Title = "Подтверждено", Content = "Действие выполнено.", Duration = 3 })
	end,
})

MainTab:CreateSection({ Text = "Уведомления (иконки + таймер)" })

for _, kind in ipairs({ "success", "error", "warning", "info" }) do
	MainTab:CreateButton({
		Name = "Notify: " .. kind,
		Callback = function()
			Window:Notify({ Kind = kind, Title = kind, Content = "Проверка уведомления типа " .. kind, Duration = 4 })
		end,
	})
end

MainTab:CreateButton({
	Name = "Стек из 3 уведомлений",
	Callback = function()
		Window:Notify({ Kind = "info", Title = "Первое", Content = "Живёт 3 сек", Duration = 3 })
		task.wait(0.25)
		Window:Notify({ Kind = "success", Title = "Второе", Content = "Живёт 6 сек", Duration = 6 })
		task.wait(0.25)
		Window:Notify({ Kind = "warning", Title = "Третье", Content = "Живёт 2 сек", Duration = 2 })
	end,
})

MainTab:CreateSection({ Text = "Лоадер" })

local loader = MainTab:CreateLoader({ Name = "Загрузка данных..." })
MainTab:CreateToggle({
	Name = "Крутить лоадер",
	CurrentValue = true,
	Callback = function(state) loader.SetActive(state) end,
})

----------------------------------------------------------------
-- 2. ВВОД
----------------------------------------------------------------
local InputTab = Window:CreateTab({ Name = "Ввод", Icon = "⌨️", Group = "Компоненты" })

InputTab:CreateSection({ Text = "Текст" })

InputTab:CreateInput({
	Name = "Никнейм",
	Placeholder = "Введи имя...",
	Flag = "TestNick",
	Callback = function(text)
		Window:Notify({ Title = "Input", Content = "Значение: " .. text, Duration = 2 })
	end,
})

InputTab:CreateTextBox({
	Name = "Заметка (многострочная)",
	Lines = 3,
	Placeholder = "Пиши сюда...",
	Flag = "TestNote",
	Callback = function(text)
		Window:Notify({ Title = "TextBox", Content = "Сохранено", Duration = 2 })
	end,
})

InputTab:CreateDividerText({ Text = "ВЫБОР" })

InputTab:CreateKeybind({
	Name = "Тестовая клавиша",
	CurrentKeybind = Enum.KeyCode.F,
	Flag = "TestKeybind",
	Callback = function(key)
		Window:Notify({ Title = "Keybind", Content = "Клавиша: " .. key.Name, Duration = 2 })
	end,
})

InputTab:CreateDropdown({
	Name = "Одиночный выбор",
	Options = { "Вариант А", "Вариант Б", "Вариант В" },
	CurrentOption = "Вариант А",
	Flag = "TestDropdown",
	Callback = function(opt)
		Window:Notify({ Title = "Dropdown", Content = opt, Duration = 2 })
	end,
})

InputTab:CreateMultiDropdown({
	Name = "Множественный выбор",
	Options = { "Огонь", "Вода", "Земля", "Воздух" },
	Default = { "Огонь" },
	Flag = "TestMulti",
	Callback = function(list)
		Window:Notify({ Title = "MultiDropdown", Content = table.concat(list, ", "), Duration = 2 })
	end,
})

InputTab:CreateRadioGroup({
	Name = "Сложность",
	Options = { "Лёгкая", "Средняя", "Сложная" },
	CurrentOption = "Средняя",
	Flag = "TestRadio",
	Callback = function(opt)
		Window:Notify({ Title = "RadioGroup", Content = opt, Duration = 2 })
	end,
})

----------------------------------------------------------------
-- 3. ЗНАЧЕНИЯ
----------------------------------------------------------------
local ValuesTab = Window:CreateTab({ Name = "Значения", Icon = "📊", Group = "Компоненты" })

local function makeQuickButton(parent, text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 90, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamMedium
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(235, 235, 240)
	btn.TextSize = 12
	btn.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	btn.MouseButton1Click:Connect(callback)
	return btn
end

ValuesTab:CreateSection({ Text = "Слайдер (кнопки проверяют плавный Set)" })

local speedSlider = ValuesTab:CreateSlider({
	Name = "WalkSpeed",
	Min = 16, Max = 100, Increment = 1, CurrentValue = 16,
	Flag = "TestSpeed",
	Callback = function(value)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = value end
	end,
})

local sliderRow = ValuesTab:CreateRow()
makeQuickButton(sliderRow, "Set → 16", function() speedSlider.Set(16) end)
makeQuickButton(sliderRow, "Set → 100", function() speedSlider.Set(100) end)

ValuesTab:CreateStepper({
	Name = "Количество попыток",
	Min = 1, Max = 10, Increment = 1, CurrentValue = 3,
	Flag = "TestStepper",
})

ValuesTab:CreateSection({ Text = "Прогресс-бар" })

local progress = ValuesTab:CreateProgressBar({ Name = "Загрузка ресурсов", Min = 0, Max = 100, CurrentValue = 0 })
local progressRow = ValuesTab:CreateRow()
makeQuickButton(progressRow, "0%", function() progress.Set(0) end)
makeQuickButton(progressRow, "50%", function() progress.Set(50) end)
makeQuickButton(progressRow, "100%", function() progress.Set(100) end)

ValuesTab:CreateDivider()

ValuesTab:CreateToggle({
	Name = "Тумблер с описанием",
	Description = "Вариант с доп. строкой текста",
	Tooltip = "У тумблеров тоже есть тултип",
	CurrentValue = false,
	Flag = "TestToggleDesc",
})

----------------------------------------------------------------
-- 3б. НОВОЕ В v6.1: графики, горячие клавиши, accordion
----------------------------------------------------------------
local NewTab = Window:CreateTab({ Name = "Новое", Icon = "🆕", Group = "Компоненты" })

NewTab:CreateParagraph({
	Title = "Что нового",
	Content = "🔍 Поиск в шапке ищет по всем вкладкам сразу.  ⌨️ Горячие клавиши на тумблерах, кнопках и списках (X / Z / C / V).  📈 Графики в реальном времени.  🗂 Сворачиваемые группы настроек.  🔊 Звуки меню.",
})

NewTab:CreateSection({ Text = "Графики (обновляются сами)" })

local RunService = game:GetService("RunService")
local frameCount, lastSample = 0, os.clock()
RunService.Heartbeat:Connect(function() frameCount = frameCount + 1 end)

local fpsChart = NewTab:CreateChart({
	Name = "FPS", Min = 0, Max = 144, Points = 50, Height = 70, Suffix = " fps", Interval = 0.25,
	Source = function()
		local now = os.clock()
		local fps = frameCount / math.max(now - lastSample, 0.001)
		frameCount, lastSample = 0, now
		return math.floor(fps + 0.5)
	end,
})

NewTab:CreateChart({
	Name = "Ping", Points = 50, Height = 70, Suffix = " ms", Interval = 1,
	Source = function()
		local item = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
		return math.floor(item:GetValue() + 0.5)
	end,
})

NewTab:CreateSection({ Text = "Горячие клавиши на любом элементе" })

local hotToggle = NewTab:CreateToggle({
	Name = "⚡ Быстрый режим",
	Description = "Переключается клавишей X — даже при закрытом меню",
	Tooltip = "Клавиша не срабатывает, пока ты печатаешь в текстовом поле",
	Hotkey = Enum.KeyCode.X,
	Callback = function(state)
		Window:Notify({ Kind = "info", Title = "Быстрый режим", Content = state and "включён" or "выключен", Duration = 2 })
	end,
})

NewTab:CreateButton({
	Name = "📍 Телепорт в (0, 5, 0)",
	Hotkey = Enum.KeyCode.Z,
	Callback = function()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CFrame = CFrame.new(0, 5, 0) end
	end,
})

NewTab:CreateDropdown({
	Name = "Режим (C — следующий)",
	Options = { "Обычный", "Быстрый", "Турбо" },
	CurrentOption = "Обычный",
	Hotkey = Enum.KeyCode.C,
	Callback = function(mode)
		Window:Notify({ Kind = "info", Title = "Режим", Content = mode, Duration = 2 })
	end,
})

NewTab:CreateSection({ Text = "Сворачиваемая группа (accordion)" })

local accDemo = NewTab:CreateAccordion({ Name = "🕊 Полёт (демо)", Open = true })
accDemo:CreateToggle({ Name = "Включить полёт", CurrentValue = false, Hotkey = Enum.KeyCode.V })
accDemo:CreateSlider({ Name = "Скорость полёта", Min = 10, Max = 200, Increment = 5, CurrentValue = 60 })
accDemo:CreateButton({
	Name = "Сбросить скорость",
	Callback = function() Window:Notify({ Title = "Полёт", Content = "Скорость сброшена", Duration = 2 }) end,
})
local accInner = accDemo:CreateAccordion({ Name = "Дополнительно", Open = false })
accInner:CreateToggle({ Name = "Плавное торможение", CurrentValue = true })
accInner:CreateStepper({ Name = "Рывков в секунду", Min = 1, Max = 10, Increment = 1, CurrentValue = 3 })

----------------------------------------------------------------
-- 4. ВИД
----------------------------------------------------------------
local StyleTab = Window:CreateTab({ Name = "Вид", Icon = "🎨", Group = "Настройки" })

StyleTab:CreateSection({ Text = "Тема и свечение" })

StyleTab:CreateDropdown({
	Name = "Цветовая тема",
	Options = { "Blue", "Red", "Yellow", "Green", "Purple" },
	CurrentOption = "Blue",
	Flag = "TestTheme",
	Callback = function(theme) Window:SetTheme(theme) end,
})

StyleTab:CreateToggle({
	Name = "🌈 Радужное свечение окна",
	CurrentValue = false,
	Callback = function(state) Window:SetGlowMode(state and "rainbow" or "theme") end,
})

StyleTab:CreateToggle({
	Name = "✨ Частицы на фоне",
	CurrentValue = true,
	Callback = function(state) Window:SetParticles(state) end,
})

StyleTab:CreateColorPicker({
	Name = "Свой акцентный цвет",
	CurrentValue = Color3.fromRGB(88, 101, 242),
	Flag = "TestAccent",
	Callback = function(color) Window:SetAccentColor(color) end,
})

StyleTab:CreateSection({ Text = "Эффект кликов (в игре)" })

StyleTab:CreateToggle({
	Name = "🖱️ Кружки при клике",
	Description = "3 анимированных кольца в месте клика, как в монтажах",
	CurrentValue = false,
	Flag = "TestClickFx",
	Callback = function(state) Window:SetClickEffect(state) end,
})

StyleTab:CreateDropdown({
	Name = "Стиль эффекта",
	Options = { "Rings", "Pulse", "Burst", "Focus" },
	CurrentOption = "Rings",
	Flag = "TestClickStyle",
	Callback = function(style) Window:SetClickEffect({ Style = style }) end,
})

StyleTab:CreateDropdown({
	Name = "Цвет эффекта",
	Options = { "theme", "rainbow" },
	CurrentOption = "theme",
	Flag = "TestClickColorMode",
	Callback = function(mode) Window:SetClickEffect({ Color = mode }) end,
})

StyleTab:CreateColorPicker({
	Name = "Свой цвет эффекта",
	CurrentValue = Color3.fromRGB(255, 255, 255),
	Callback = function(color) Window:SetClickEffect({ Color = color }) end,
})

StyleTab:CreateSlider({
	Name = "Размер эффекта",
	Min = 40, Max = 220, Increment = 10, CurrentValue = 80,
	Callback = function(v) Window:SetClickEffect({ Size = v }) end,
})

StyleTab:CreateStepper({
	Name = "Количество колец",
	Min = 1, Max = 6, Increment = 1, CurrentValue = 3,
	Callback = function(v) Window:SetClickEffect({ Rings = v }) end,
})

StyleTab:CreateToggle({
	Name = "Не показывать при кликах по меню",
	CurrentValue = false,
	Callback = function(state) Window:SetClickEffect({ IgnoreGui = state }) end,
})

StyleTab:CreateToggle({
	Name = "Также по правой кнопке мыши",
	CurrentValue = false,
	Callback = function(state) Window:SetClickEffect({ Right = state }) end,
})

StyleTab:CreateSection({ Text = "Окно" })

StyleTab:CreateSlider({
	Name = "Масштаб окна",
	Min = 70, Max = 130, Increment = 5, CurrentValue = 100, Suffix = "%",
	Callback = function(value) Window:SetScale(value / 100) end,
})

StyleTab:CreateKeybind({
	Name = "Клавиша открытия меню",
	CurrentKeybind = Window:GetHotkey(),
	Callback = function(key) Window:SetHotkey(key) end,
})

StyleTab:CreateSection({ Text = "Звуки интерфейса" })

StyleTab:CreateToggle({
	Name = "🔊 Звуки меню",
	CurrentValue = Window:GetSoundsEnabled(),
	Callback = function(state) Window:SetSoundsEnabled(state) end,
})

StyleTab:CreateSlider({
	Name = "Громкость",
	Min = 0, Max = 100, Increment = 5, CurrentValue = 100, Suffix = "%",
	Callback = function(v) Window:SetSoundVolume(v / 100) end,
})

local soundPick = "Click"
StyleTab:CreateDropdown({
	Name = "Проверить звук",
	Options = { "Hover", "Click", "ToggleOn", "ToggleOff", "Open", "Close", "Notify" },
	CurrentOption = "Click",
	Callback = function(name) soundPick = name end,
})

StyleTab:CreateButton({
	Name = "▶ Проиграть выбранный звук",
	Callback = function() Window:PlaySound(soundPick) end,
})

StyleTab:CreateSection({ Text = "Положение окна" })

StyleTab:CreateButton({
	Name = "↺ Вернуть окно в центр экрана",
	Tooltip = "Положение окна запоминается между запусками (если доступны файлы)",
	Callback = function() Window:ResetPosition() end,
})

Window:CreateConfigManager(StyleTab)

----------------------------------------------------------------
-- 5. ИГРОКИ
----------------------------------------------------------------
local PlayersTab = Window:CreateTab({ Name = "Игроки", Icon = "👥", Group = "Настройки" })

Window:AddPlayerList(PlayersTab, {
	Title = "Игроки на сервере",
	OnPlayer = function(plr)
		Window:Notify({ Title = "Игрок", Content = "Выбран: " .. plr.Name, Duration = 2 })
	end,
})

----------------------------------------------------------------
-- 6. АВТОТЕСТ — сам проверяет ключевые вещи и показывает PASS/FAIL
----------------------------------------------------------------
local TestTab = Window:CreateTab({ Name = "Автотест", Icon = "🧪", Group = "Диагностика" })

TestTab:CreateParagraph({
	Title = "Автоматическая проверка",
	Content = "Нажми кнопку ниже. Окно само свернётся/развернётся, прокрутит темы и значения, а результат покажет здесь и в Output.",
})

local resultLabel = TestTab:CreateLabel({ Text = "Результат: тест ещё не запускался" })
local running = false

local function runSelfTest()
	if running then return end
	running = true
	local results = {}
	local function check(name, fn)
		local ok, res = pcall(fn)
		local passed = ok and res == true
		table.insert(results, { name = name, passed = passed, err = (not ok) and tostring(res) or nil })
		print(string.format("[HIros автотест] %s %s%s", passed and "PASS" or "FAIL", name, (not ok) and (" — " .. tostring(res)) or ""))
	end

	resultLabel.Text = "Результат: выполняется..."

	-- 1. Базовая структура окна
	check("Окно создано и видно", function()
		return Window.Main ~= nil and Window.Main.Visible == true
	end)

	-- 2. Свечение кнопки ⚡ лежит в ОДНОМ контейнере с кнопкой (поэтому идёт за ней)
	check("Свечение кнопки ⚡ в одном контейнере с кнопкой", function()
		return Window.ToggleBtn ~= nil
			and Window.ToggleGlow ~= nil
			and Window.ToggleBtn.Parent == Window.ToggleGlow.Parent
			and Window.ToggleBtn.Parent == Window.FloatHolder
	end)

	-- 3. Круглые кнопки управления окном (не квадраты)
	check("Кнопки ➖/❌ круглые", function()
		local function isRound(btn)
			local c = btn:FindFirstChildOfClass("UICorner")
			return c ~= nil and c.CornerRadius.Scale >= 0.5 or (c ~= nil and c.CornerRadius.Offset >= 100)
		end
		return Window.MinBtn ~= nil and Window.CloseBtn ~= nil and isRound(Window.MinBtn) and isRound(Window.CloseBtn)
	end)

	-- 4. Сворачивание: остаётся только плашка, всё содержимое скрыто
	check("Сворачивание скрывает всё тело, остаётся плашка", function()
		Window:Minimize()
		task.wait(0.9)
		local layer = Window.GlowLayers[1]
		local gy = layer.instance.Size.Y.Offset
		local ok = Window.Body.Visible == false
			and Window.Main.Size.Y.Offset == 42
			and Window.TitleBar.Visible == true
			and Window.MinBtn.Visible == true
			-- свечение обнимает плашку, а не остаётся размером с окно
			and gy >= 42 and gy <= 42 + layer.config.padding * 2 + 1
		Window:Minimize()
		task.wait(0.9)
		return ok
	end)

	-- 5. Разворачивание возвращает всё обратно
	check("Разворачивание возвращает тело и размер свечения", function()
		local layer = Window.GlowLayers[1]
		local expected = Window.Main.Size.Y.Offset + layer.config.padding * 2
		return Window.Body.Visible == true
			and Window.Main.Size.Y.Offset == Window.WindowSize.Y
			and math.abs(layer.instance.Size.Y.Offset - expected) <= 1
	end)

	-- 6. Слайдер: плавный Set доходит до цели
	check("Slider.Set() доходит до значения", function()
		speedSlider.Set(70)
		task.wait(0.6)
		local v = speedSlider.Get()
		speedSlider.Set(16)
		task.wait(0.5)
		return math.abs(v - 70) < 0.5
	end)

	-- 7. Прогресс-бар
	check("ProgressBar.Set() доходит до значения", function()
		progress.Set(80)
		task.wait(0.6)
		local v = progress.Get()
		progress.Set(0)
		return math.abs(v - 80) < 0.5
	end)

	-- 8. Все темы переключаются без ошибок
	check("Все 5 тем применяются без ошибок", function()
		for _, name in ipairs({ "Red", "Yellow", "Green", "Purple", "Blue" }) do
			Window:SetTheme(name)
			task.wait(0.1)
		end
		return true
	end)

	-- 9. Режимы свечения
	check("SetGlowMode rainbow ↔ theme", function()
		Window:SetGlowMode("rainbow")
		task.wait(0.3)
		Window:SetGlowMode("theme")
		return true
	end)

	-- 10. Частицы
	check("SetParticles вкл/выкл", function()
		Window:SetParticles(false)
		Window:SetParticles(true)
		return true
	end)

	-- 11. Масштаб
	check("SetScale меняет масштаб", function()
		Window:SetScale(0.9)
		task.wait(0.1)
		local ok = math.abs(Window.Scale.Scale - 0.9) < 0.001
		Window:SetScale(1)
		return ok
	end)

	-- 11b. Эффект кликов: каждый стиль рисует круги и они сами исчезают
	check("Эффект кликов: все 4 стиля рисуются и очищаются", function()
		local prev = Window:GetClickEffect()
		Window:SetClickEffect({ Enabled = true, Duration = 0.4 })
		local ok = true
		for _, style in ipairs({ "Rings", "Pulse", "Burst", "Focus" }) do
			Window:SetClickEffect({ Style = style })
			local before = #Window.ClickGui:GetChildren()
			Window:_spawnClickFX(Vector2.new(300, 300))
			if #Window.ClickGui:GetChildren() <= before then ok = false end
		end
		task.wait(1.2)
		local left = #Window.ClickGui:GetChildren()
		Window:SetClickEffect(prev)
		return ok and left <= 3
	end)

	-- 12. Уведомления: все 4 типа создаются
	check("Notify: success/error/warning/info", function()
		for _, kind in ipairs({ "success", "error", "warning", "info" }) do
			Window:Notify({ Kind = kind, Title = "Автотест", Content = kind, Duration = 1.5, Sound = false })
			task.wait(0.15)
		end
		return true
	end)

	-- 12b. Порядок вкладок = порядку создания, группы идут блоками
	check("Вкладки идут в порядке создания", function()
		local function o(name) return Window.TabButtons[name].LayoutOrder end
		return o("Главная") < o("Ввод") and o("Ввод") < o("Значения") and o("Значения") < o("Новое")
			and o("Новое") < o("Вид") and o("Вид") < o("Игроки") and o("Игроки") < o("Автотест")
	end)

	-- 12c. Поиск по всем вкладкам
	check("Поиск: прячет лишнее, находит по другим вкладкам, очищается", function()
		Window:Search("запустить автотест")
		local ok = Window.TabButtons["Автотест"].Visible == true and Window.TabButtons["Главная"].Visible == false
		Window:Search("яяяяяя")
		ok = ok and Window._noResults.Visible == true
		Window:ClearSearch()
		return ok and Window._noResults.Visible == false and Window.TabButtons["Главная"].Visible == true
	end)

	-- 12d. Горячая клавиша на элементе
	check("Горячая клавиша тумблера читается и меняется", function()
		local before = hotToggle.GetHotkey()
		hotToggle.SetHotkey(Enum.KeyCode.B)
		local changed = hotToggle.GetHotkey() == Enum.KeyCode.B
		hotToggle.SetHotkey(before)
		return before == Enum.KeyCode.X and changed and hotToggle.GetHotkey() == Enum.KeyCode.X
	end)

	-- 12e. Accordion
	check("Accordion закрывается и открывается", function()
		accDemo.Close()
		task.wait(0.6)
		local closed = accDemo.Content.Visible == false and not accDemo.IsOpen()
		accDemo.Open()
		task.wait(0.7)
		return closed and accDemo.Content.Visible == true and accDemo.IsOpen()
	end)

	-- 12f. График
	check("График принимает значения", function()
		fpsChart.Push(60)
		return fpsChart.Get() == 60
	end)

	-- 12g. Звуки
	check("Звуки: громкость и замена звука", function()
		local before = Window._soundVolume
		Window:SetSoundVolume(0.5)
		local expected = Window._soundDefs.Click.Volume * 0.5
		local ok = math.abs(Window._soundObjs.Click.Volume - expected) < 1e-6
		Window:SetSoundVolume(before)
		local replaced = Window:SetSound("Hover", Window._soundDefs.Hover.Id)
		return ok and replaced == true and Window._soundObjs.Hover.SoundId ~= ""
	end)

	-- 13. Вкладки: переключение туда-обратно
	check("Переключение вкладок", function()
		Window:SelectTab("Ввод")
		task.wait(0.15)
		Window:SelectTab("Автотест")
		return Window.CurrentTab == "Автотест"
	end)

	local passed = 0
	for _, r in ipairs(results) do
		if r.passed then passed = passed + 1 end
	end
	local total = #results
	resultLabel.Text = string.format("Результат: %d / %d пройдено%s", passed, total, passed == total and " ✅" or " ❌ (детали в Output)")
	Window:Notify({
		Kind = (passed == total) and "success" or "error",
		Title = "Автотест завершён",
		Content = string.format("Пройдено %d из %d", passed, total),
		Duration = 5,
	})
	running = false
end

TestTab:CreateButton({
	Name = "🧪 Запустить автотест",
	Badge = "AUTO",
	Callback = function() task.spawn(runSelfTest) end,
})

----------------------------------------------------------------
-- ПРИВЕТСТВИЕ
----------------------------------------------------------------
task.wait(1)
local info = HIros:GetInfo()
Window:Notify({
	Title = "HIros v" .. info.Version .. " загружен",
	Content = "RightShift — открыть/закрыть меню. Вкладка «Автотест» проверит всё сама.",
	Duration = 6,
})
