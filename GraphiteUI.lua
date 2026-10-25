local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Touch = UserInputService.TouchEnabled
local RowHeight = Touch and 40 or 36
local TopHeight = Touch and 40 or 34

local Graphite = {Version = "1.1"}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local DefaultBase = C(40, 40, 43)

local NoteColors = {
	Success = C(80, 200, 120),
	Warning = C(240, 190, 70),
	Error = C(230, 85, 85)
}

local function Luma(color)
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function Shift(color, amount)
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

local function BuildTheme(base, text, accent)
	local dark = Luma(base) < 0.5
	local theme = {Main = base}
	if dark then
		theme.Top = Shift(base, -0.24)
		theme.Side = Shift(base, -0.12)
		theme.Element = Shift(base, 0.08)
		theme.Hover = Shift(base, 0.16)
		theme.Stroke = Shift(base, 0.24)
	else
		theme.Top = Shift(base, -0.08)
		theme.Side = Shift(base, -0.04)
		theme.Element = Shift(base, 0.55)
		theme.Hover = Shift(base, 0.25)
		theme.Stroke = Shift(base, -0.2)
	end
	theme.Text = text or (dark and C(235, 235, 238) or C(28, 28, 32))
	theme.Sub = theme.Text:Lerp(base, 0.42)
	theme.Accent = accent or (dark and Shift(base, 0.6) or Shift(base, -0.55))
	return theme
end

local function Create(class, props)
	local inst = Instance.new(class)
	local parent
	for key, value in pairs(props) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	inst.Parent = parent
	return inst
end

local function Round(parent, radius)
	return Create("UICorner", {CornerRadius = UDim.new(0, radius or 6), Parent = parent})
end

local function Pad(parent, left, top, right, bottom)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		Parent = parent
	})
end

local function Animate(inst, props, time, style, direction)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

local function ParseImage(id)
	if id == nil or id == "" then
		return nil
	end
	if type(id) == "number" or tonumber(id) then
		return "rbxassetid://" .. tostring(id)
	end
	return id
end

local function IsPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function Fire(callback, ...)
	if type(callback) == "function" then
		task.spawn(callback, ...)
	end
end

local function ViewSize(gui)
	local size = gui.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return Workspace.CurrentCamera.ViewportSize
	end
	return size
end

local function Encode(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return {t = "c", r = value.R, g = value.G, b = value.B}
	end
	if kind == "EnumItem" then
		return {t = "k", n = value.Name}
	end
	return value
end

local function Decode(value)
	if type(value) == "table" then
		if value.t == "c" then
			return Color3.new(value.r, value.g, value.b)
		end
		if value.t == "k" then
			return Enum.KeyCode[value.n] or Enum.KeyCode.Unknown
		end
	end
	return value
end

function Window:Connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function Window:Bind(callback)
	table.insert(self.Hooks, callback)
	callback()
end

function Window:RunHooks()
	for _, hook in ipairs(self.Hooks) do
		pcall(hook)
	end
end

function Window:Paint(inst, property, key)
	self:Bind(function()
		inst[property] = self.Theme[key]
	end)
	return inst
end

function Window:Make(class, props, paints)
	local inst = Create(class, props)
	for property, key in pairs(paints or {}) do
		self:Paint(inst, property, key)
	end
	return inst
end

function Window:Stroke(parent, key, transparency)
	local stroke = Create("UIStroke", {
		Thickness = 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent
	})
	self:Paint(stroke, "Color", key or "Stroke")
	return stroke
end

local function Hover(win, inst, base, over)
	inst.MouseEnter:Connect(function()
		Animate(inst, {BackgroundColor3 = win.Theme[over or "Hover"]}, 0.1)
	end)
	inst.MouseLeave:Connect(function()
		Animate(inst, {BackgroundColor3 = win.Theme[base or "Element"]}, 0.1)
	end)
end

function Window:Pointer(handle, onBegin, onMove, onEnd)
	local active
	self:Connect(handle.InputBegan, function(input)
		if not IsPointer(input) then
			return
		end
		if active and active.UserInputState ~= Enum.UserInputState.End then
			return
		end
		active = input
		if onBegin then
			onBegin(input)
		end
	end)
	self:Connect(UserInputService.InputChanged, function(input)
		if not active then
			return
		end
		local match
		if active.UserInputType == Enum.UserInputType.Touch then
			match = input == active
		else
			match = input.UserInputType == Enum.UserInputType.MouseMovement
		end
		if match and onMove then
			onMove(input)
		end
	end)
	self:Connect(UserInputService.InputEnded, function(input)
		if active and input == active then
			active = nil
			if onEnd then
				onEnd(input)
			end
		end
	end)
end

function Window:Slide(hit, onMove, scroller, onBegin, onEnd)
	self:Pointer(hit, function(input)
		if scroller then
			scroller.ScrollingEnabled = false
		end
		if onBegin then
			onBegin()
		end
		onMove(input.Position)
	end, function(input)
		onMove(input.Position)
	end, function()
		if scroller then
			scroller.ScrollingEnabled = true
		end
		if onEnd then
			onEnd()
		end
	end)
end

function Window:Rebuild()
	self.Theme = BuildTheme(self.Base, self.TextColor, self.AccentColor)
	self:RunHooks()
end

function Window:SyncPickers()
	if self.MenuPicker then
		self.MenuPicker:Set(self.Base, true)
	end
	if self.TextPicker then
		self.TextPicker:Set(self.Theme.Text, true)
	end
	if self.AccentPicker then
		self.AccentPicker:Set(self.Theme.Accent, true)
	end
end

function Window:SetMenuColor(color)
	self.Base = color
	self:Rebuild()
	if not self.TextColor and self.TextPicker then
		self.TextPicker:Set(self.Theme.Text, true)
	end
	if not self.AccentColor and self.AccentPicker then
		self.AccentPicker:Set(self.Theme.Accent, true)
	end
end

function Window:SetTextColor(color)
	self.TextColor = color
	self:Rebuild()
end

function Window:SetAccent(color)
	self.AccentColor = color
	self:Rebuild()
end

function Window:ResetColors()
	self.Base = DefaultBase
	self.TextColor = nil
	self.AccentColor = nil
	self:Rebuild()
	self:SyncPickers()
end

function Window:SetTitle(text)
	self.Name = text
	self.TitleLabel.Text = text
	self.BarLabel.Text = text
end

function Window:Clamp()
	local view = ViewSize(self.Gui)
	local scale = self.TargetScale
	local size = self.Main.Size
	local halfWidth = size.X.Offset * scale / 2
	local halfHeight = size.Y.Offset * scale / 2
	local margin = Touch and 110 or 90
	local cx = self.Main.Position.X.Scale * view.X
	local cy = self.Main.Position.Y.Scale * view.Y
	local minX = margin - halfWidth
	local maxX = math.max(minX, view.X - margin + halfWidth)
	local minY = halfHeight
	local maxY = math.max(minY, view.Y - 44 + halfHeight)
	cx = math.clamp(cx, minX, maxX)
	cy = math.clamp(cy, minY, maxY)
	self.Main.Position = UDim2.fromScale(cx / view.X, cy / view.Y)
end

function Window:ClampRestore()
	local view = ViewSize(self.Gui)
	local bar = self.Restore
	local width = bar.AbsoluteSize.X
	local height = bar.AbsoluteSize.Y
	local position = bar.Position
	local cx = position.X.Scale * view.X + position.X.Offset
	local cy = position.Y.Scale * view.Y + position.Y.Offset
	cx = math.clamp(cx, width / 2, math.max(width / 2, view.X - width / 2))
	cy = math.clamp(cy, 0, math.max(0, view.Y - height))
	bar.Position = UDim2.new(cx / view.X, 0, cy / view.Y, 0)
end

function Window:OnViewport()
	local view = ViewSize(self.Gui)
	local size = self.Main.Size
	local fit = math.min((view.X - 20) / size.X.Offset, (view.Y - 20) / size.Y.Offset)
	self.AutoScale = math.clamp(math.min(view.X / (self.BaseSize.X + 40), view.Y / (self.BaseSize.Y + 40), 1), 0.5, 1)
	if self.TargetScale > fit then
		self:SetScale(math.max(fit, 0.5))
	end
	self:Clamp()
	self:ClampRestore()
end

function Window:SetScale(value, fromSlider)
	value = math.clamp(value, 0.5, 1.6)
	self.TargetScale = value
	if not self.Hidden then
		self.UIScale.Scale = value
	end
	if self.ZoomSlider and not fromSlider then
		self.ZoomSlider:Set(math.floor(value * 100 + 0.5), true)
	end
	self:Clamp()
end

function Window:GetScale()
	return self.TargetScale
end

function Window:SetOpacity(percent)
	self.Fade = 1 - math.clamp(percent, 20, 100) / 100
	if not self.Hidden then
		self.Main.GroupTransparency = self.Fade
	end
end

function Window:ResetLayout()
	self.Main.Size = UDim2.fromOffset(self.BaseSize.X, self.BaseSize.Y)
	self.Main.Position = UDim2.fromScale(0.5, 0.5)
	self:SetScale(self.AutoScale)
end

function Window:SetHidden(state)
	if self.Closed or self.Hidden == state then
		return
	end
	self:CloseDialog()
	self.Hidden = state
	self.Token = self.Token + 1
	local token = self.Token
	if state then
		Animate(self.UIScale, {Scale = self.TargetScale * 0.85}, 0.18)
		local tween = Animate(self.Main, {GroupTransparency = 1}, 0.18)
		tween.Completed:Connect(function()
			if self.Token == token and self.Hidden then
				self.Main.Visible = false
			end
		end)
		self.Restore.Visible = true
		self.RestoreScale.Scale = 0.6
		Animate(self.RestoreScale, {Scale = 1}, 0.28, Enum.EasingStyle.Back)
		self:ClampRestore()
	else
		self.Restore.Visible = false
		self.Main.Visible = true
		self.Main.GroupTransparency = 1
		self.UIScale.Scale = self.TargetScale * 0.85
		Animate(self.UIScale, {Scale = self.TargetScale}, 0.32, Enum.EasingStyle.Back)
		Animate(self.Main, {GroupTransparency = self.Fade}, 0.22)
		self:Clamp()
	end
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

function Window:CloseDialog()
	local overlay = self.ActiveDialog
	if overlay then
		self.ActiveDialog = nil
		overlay:Destroy()
	end
end

function Window:Dialog(config)
	config = config or {}
	self:CloseDialog()
	local inside = not self.Hidden
	local overlay = Create("Frame", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 100,
		Parent = inside and self.Main or self.Gui
	})
	self.ActiveDialog = overlay
	if inside then
		Animate(overlay, {BackgroundTransparency = 0.45}, 0.18)
	end

	local box = self:Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Parent = overlay
	}, {BackgroundColor3 = "Top"})
	Round(box, 8)
	self:Stroke(box)
	Pad(box, 14, 14, 14, 14)
	Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box})
	local boxScale = Create("UIScale", {Scale = 0.85, Parent = box})
	Animate(boxScale, {Scale = 1}, 0.24, Enum.EasingStyle.Back)

	if config.Title then
		self:Make("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = config.Title,
			Parent = box
		}, {TextColor3 = "Text"})
	end
	if config.Content then
		self:Make("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = config.Content,
			Parent = box
		}, {TextColor3 = "Text"})
	end

	local row = Create("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Touch and 38 or 32),
		BackgroundTransparency = 1,
		Parent = box
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row
	})

	local buttons = config.Buttons or {{Name = "OK"}}
	local count = #buttons
	for index, spec in ipairs(buttons) do
		local button = self:Make("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Text = spec.Name,
			Parent = row
		}, {BackgroundColor3 = "Element", TextColor3 = "Text"})
		Round(button, 6)
		Hover(self, button)
		button.MouseButton1Click:Connect(function()
			self:CloseDialog()
			Fire(spec.Callback)
		end)
	end
end

function Window:Confirm(content, callback)
	self:Dialog({
		Content = content,
		Buttons = {
			{Name = "No"},
			{Name = "Yes", Callback = callback}
		}
	})
end

function Window:RequestClose()
	self:Confirm("Do you want to close the menu?", function()
		self:Destroy()
	end)
end

function Window:Destroy()
	if self.Closed then
		return
	end
	self.Closed = true
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Restore.Visible = false
	self:CloseDialog()
	Animate(self.UIScale, {Scale = self.UIScale.Scale * 0.85}, 0.2)
	Animate(self.Main, {GroupTransparency = 1}, 0.2)
	local gui = self.Gui
	task.delay(0.3, function()
		gui:Destroy()
	end)
	Fire(self.OnClose)
end

function Window:Notify(config)
	config = config or {}
	local theme = self.Theme
	local holder = Create("Frame", {
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Notes
	})
	local card = Create("Frame", {
		Position = UDim2.fromOffset(280, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Top,
		BorderSizePixel = 0,
		Parent = holder
	})
	Round(card, 8)
	Create("UIStroke", {Color = theme.Stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card})
	local bar = Create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = NoteColors[config.Type] or theme.Accent,
		BorderSizePixel = 0,
		Parent = card
	})
	Round(bar, 2)
	local body = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card
	})
	Pad(body, 14, 9, 12, 9)
	Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})
	Create("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Title or "Notice",
		Parent = body
	})
	if config.Content then
		Create("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = theme.Sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = config.Content,
			Parent = body
		})
	end
	Animate(card, {Position = UDim2.fromOffset(0, 0)}, 0.3, Enum.EasingStyle.Back)
	task.delay(config.Duration or 4, function()
		if card.Parent then
			local tween = Animate(card, {Position = UDim2.fromOffset(280, 0)}, 0.25)
			tween.Completed:Wait()
			holder:Destroy()
		end
	end)
end

function Window:CreateWatermark(config)
	config = config or {}
	local label = self:Make("TextLabel", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = config.Text or self.Name,
		Visible = config.Visible ~= false,
		Parent = self.Gui
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(label, 5)
	self:Stroke(label)
	Pad(label, 10, 0, 10, 0)

	local frames = 0
	local last = os.clock()
	self:Connect(RunService.RenderStepped, function()
		frames = frames + 1
		local now = os.clock()
		if now - last >= 1 then
			local fps = math.floor(frames / (now - last) + 0.5)
			frames = 0
			last = now
			local parts = {config.Text or self.Name}
			if config.ShowFPS ~= false then
				table.insert(parts, fps .. " FPS")
			end
			if config.ShowPing then
				local ok, ping = pcall(function()
					return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
				end)
				if ok then
					table.insert(parts, ping .. " ms")
				end
			end
			label.Text = table.concat(parts, "  |  ")
		end
	end)

	local object = {}
	function object:SetVisible(state)
		label.Visible = state
	end
	function object:Destroy()
		label:Destroy()
	end
	return object
end

function Window:SaveConfig(name)
	if type(writefile) ~= "function" then
		return false, "File access is not supported by this executor"
	end
	local data = {}
	for flag, object in pairs(self.Elements) do
		data[flag] = Encode(object:Get())
	end
	pcall(function()
		if type(isfolder) == "function" and not isfolder(self.Folder) then
			makefolder(self.Folder)
		end
	end)
	local ok, err = pcall(function()
		writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
	end)
	return ok, err
end

function Window:LoadConfig(name)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false, "File access is not supported by this executor"
	end
	local path = self.Folder .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "Config not found"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok then
		return false, data
	end
	for flag, raw in pairs(data) do
		local object = self.Elements[flag]
		if object then
			object:Set(Decode(raw))
		end
	end
	return true
end

function Window:SelectTab(tab)
	local previous = self.CurrentTab
	for _, other in ipairs(self.Tabs) do
		other.Active = other == tab
		other.Page.Visible = other.Active
		other.Render(0.12)
	end
	self.CurrentTab = tab
	if previous ~= tab then
		tab.Page.Position = UDim2.fromOffset(0, 14)
		Animate(tab.Page, {Position = UDim2.fromOffset(0, 0)}, 0.2)
	end
end

function Window:CreateTab(name, icon)
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = name or "Tab"
	tab.Order = 0
	tab.Active = false

	local button = self:Make("TextButton", {
		Name = tab.Name,
		Size = UDim2.new(1, 0, 0, Touch and 36 or 30),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = #self.Tabs + 1,
		Parent = self.TabList
	}, {BackgroundColor3 = "Element"})
	Round(button, 6)

	local indicator = self:Make("Frame", {
		Position = UDim2.new(0, 0, 0.5, -8),
		Size = UDim2.fromOffset(3, 16),
		BorderSizePixel = 0,
		Visible = false,
		Parent = button
	}, {BackgroundColor3 = "Accent"})
	Round(indicator, 2)

	local textOffset = 12
	local iconLabel
	local image = ParseImage(icon)
	if image then
		iconLabel = Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = image,
			Parent = button
		})
		textOffset = 34
	end

	local label = Create("TextLabel", {
		Position = UDim2.fromOffset(textOffset, 0),
		Size = UDim2.new(1, -textOffset - 6, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tab.Name,
		Parent = button
	})

	local page = self:Make("ScrollingFrame", {
		Name = tab.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Content
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page})
	Pad(page, 10, 10, 12, 10)

	tab.Button = button
	tab.Page = page
	tab.Scroller = page

	function tab.Render(time)
		local theme = self.Theme
		Animate(button, {BackgroundTransparency = tab.Active and 0 or 1}, time)
		Animate(label, {TextColor3 = tab.Active and theme.Text or theme.Sub}, time)
		if iconLabel then
			Animate(iconLabel, {ImageColor3 = tab.Active and theme.Text or theme.Sub}, time)
		end
		indicator.Visible = tab.Active
	end

	self:Bind(function()
		tab.Render(0)
	end)

	button.MouseEnter:Connect(function()
		if not tab.Active then
			Animate(button, {BackgroundTransparency = 0.6}, 0.1)
		end
	end)
	button.MouseLeave:Connect(function()
		if not tab.Active then
			Animate(button, {BackgroundTransparency = 1}, 0.1)
		end
	end)
	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

local function NewRow(tab, height, class)
	tab.Order = tab.Order + 1
	local row = tab.Window:Make(class or "Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder = tab.Order,
		Parent = tab.Page
	}, {BackgroundColor3 = "Element"})
	if class == "TextButton" then
		row.Text = ""
		row.AutoButtonColor = false
	end
	Round(row, 6)
	tab.Window:Stroke(row, "Stroke", 0.6)
	return row
end

local function RowLabel(win, row, text, reserve, icon, desc, keepColor)
	local offset = 12
	local image = ParseImage(icon)
	if image then
		local paints = nil
		if not keepColor then
			paints = {ImageColor3 = "Text"}
		end
		win:Make("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0, row.Size.Y.Offset / 2),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Image = image,
			Parent = row
		}, paints)
		offset = 38
	end
	local width = -(offset + (reserve or 24) - 12)
	local label = win:Make("TextLabel", {
		Position = UDim2.fromOffset(offset, desc and 5 or 0),
		Size = UDim2.new(1, width, 0, desc and 20 or RowHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		Parent = row
	}, {TextColor3 = "Text"})
	local note
	if desc then
		note = win:Make("TextLabel", {
			Position = UDim2.fromOffset(offset, 25),
			Size = UDim2.new(1, width, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = desc,
			Parent = row
		}, {TextColor3 = "Sub"})
	end
	return label, note
end

local function Register(win, flag, object)
	if flag then
		win.Elements[flag] = object
	end
end

function Tab:CreateGroup(config)
	config = config or {}
	local win = self.Window
	self.Order = self.Order + 1
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self.Order,
		Parent = self.Page
	})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})

	local header = win:Make("TextButton", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, RowHeight - 4),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = holder
	}, {BackgroundColor3 = "Element"})
	Round(header, 6)
	win:Stroke(header, "Stroke", 0.6)
	Hover(win, header)
	local title = win:Make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = config.Name or "Group",
		Parent = header
	}, {TextColor3 = "Text"})
	local mark = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(18, RowHeight - 4),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "-",
		Parent = header
	}, {TextColor3 = "Sub"})

	local body = Create("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder
	})
	Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})
	Pad(body, 8, 0, 0, 0)

	local open = config.Open ~= false
	body.Visible = open
	mark.Text = open and "-" or "+"
	header.MouseButton1Click:Connect(function()
		open = not open
		body.Visible = open
		mark.Text = open and "-" or "+"
	end)

	local group = setmetatable({}, Tab)
	group.Window = win
	group.Page = body
	group.Scroller = self.Scroller
	group.Order = 0
	group.Title = title
	return group
end

function Tab:CreateSection(text)
	self.Order = self.Order + 1
	return self.Window:Make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(text or "Section"),
		LayoutOrder = self.Order,
		Parent = self.Page
	}, {TextColor3 = "Sub"})
end

function Tab:CreateDivider()
	self.Order = self.Order + 1
	return self.Window:Make("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		LayoutOrder = self.Order,
		Parent = self.Page
	}, {BackgroundColor3 = "Stroke"})
end

function Tab:CreateLabel(text)
	local win = self.Window
	local row = NewRow(self, 30)
	local label = RowLabel(win, row, text or "Label")
	label.Size = UDim2.new(1, -24, 1, 0)
	win:Paint(label, "TextColor3", "Sub")
	local object = {}
	function object:SetText(value)
		label.Text = value
	end
	return object
end

function Tab:CreateParagraph(config)
	config = config or {}
	local win = self.Window
	self.Order = self.Order + 1
	local row = win:Make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		LayoutOrder = self.Order,
		Parent = self.Page
	}, {BackgroundColor3 = "Element"})
	Round(row, 6)
	win:Stroke(row, "Stroke", 0.6)
	Pad(row, 12, 9, 12, 9)
	Create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})
	local title = win:Make("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Title or "Title",
		Parent = row
	}, {TextColor3 = "Text"})
	local content = win:Make("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = config.Content or "",
		Parent = row
	}, {TextColor3 = "Sub"})
	local object = {}
	function object:SetTitle(value)
		title.Text = value
	end
	function object:SetContent(value)
		content.Text = value
	end
	return object
end

function Tab:CreateImage(config)
	config = config or {}
	local row = NewRow(self, config.Height or 120)
	row.ClipsDescendants = true
	local image = Create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = ParseImage(config.Image) or "",
		ScaleType = config.Crop and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
		Parent = row
	})
	Round(image, 6)
	local object = {}
	function object:SetImage(id)
		image.Image = ParseImage(id) or ""
	end
	return object
end

function Tab:CreateGallery(config)
	config = config or {}
	local win = self.Window
	local titled = config.Name ~= nil
	local top = titled and 24 or 0
	local row = NewRow(self, top + 90)
	if titled then
		local title = RowLabel(win, row, config.Name)
		title.Size = UDim2.new(1, -24, 0, 24)
	end
	local scroller = win:Make("ScrollingFrame", {
		Position = UDim2.fromOffset(6, top + 2),
		Size = UDim2.new(1, -12, 1, -(top + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = row
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller
	})
	Pad(scroller, 2, 2, 2, 8)

	local count = 0
	local object = {}
	function object:Add(spec)
		count = count + 1
		local item = win:Make("TextButton", {
			LayoutOrder = count,
			Size = UDim2.fromOffset(76, 72),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = scroller
		}, {BackgroundColor3 = "Hover"})
		Round(item, 6)
		Create("ImageLabel", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(64, 44),
			BackgroundTransparency = 1,
			Image = ParseImage(spec.Image) or "",
			ScaleType = Enum.ScaleType.Fit,
			Parent = item
		})
		win:Make("TextLabel", {
			Position = UDim2.fromOffset(2, 53),
			Size = UDim2.new(1, -4, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = spec.Name or "",
			Parent = item
		}, {TextColor3 = "Sub"})
		item.MouseButton1Click:Connect(function()
			Fire(spec.Callback or config.Callback, spec)
		end)
	end
	function object:Clear()
		for _, child in ipairs(scroller:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		count = 0
	end
	for _, spec in ipairs(config.Items or {}) do
		object:Add(spec)
	end
	return object
end

function Tab:CreateButton(config)
	config = config or {}
	local win = self.Window
	local row = NewRow(self, config.Description and (RowHeight + 14) or RowHeight, "TextButton")
	local label = RowLabel(win, row, config.Name or "Button", 24, config.Icon, config.Description, config.KeepIconColor)
	Hover(win, row)
	row.MouseButton1Click:Connect(function()
		row.BackgroundColor3 = win.Theme.Accent
		Animate(row, {BackgroundColor3 = win.Theme.Element}, 0.3)
		Fire(config.Callback)
	end)
	local object = {}
	function object:SetText(value)
		label.Text = value
	end
	return object
end

function Tab:CreateToggle(config)
	config = config or {}
	local win = self.Window
	local state = config.Default == true
	local row = NewRow(self, config.Description and (RowHeight + 14) or RowHeight, "TextButton")
	RowLabel(win, row, config.Name or "Toggle", 70, config.Icon, config.Description, config.KeepIconColor)
	Hover(win, row)

	local track = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BorderSizePixel = 0,
		Parent = row
	})
	Round(track, 11)
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track
	})
	Round(knob, 8)

	local function Render(time)
		Animate(track, {BackgroundColor3 = state and win.Theme.Accent or win.Theme.Stroke}, time)
		Animate(knob, {Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)}, time, Enum.EasingStyle.Back)
	end

	win:Bind(function()
		Render(0)
	end)

	local object = {}
	function object:Set(value, silent)
		state = value == true
		Render(0.18)
		if not silent then
			Fire(config.Callback, state)
		end
	end
	function object:Get()
		return state
	end
	Register(win, config.Flag, object)

	row.MouseButton1Click:Connect(function()
		object:Set(not state)
	end)
	return object
end

function Tab:CreateSlider(config)
	config = config or {}
	local win = self.Window
	local min = config.Min or 0
	local max = config.Max or 100
	local step = config.Increment or 1
	local suffix = config.Suffix
	if suffix == nil then
		suffix = "%"
	end
	local value = math.clamp(config.Default or min, min, max)
	local row = NewRow(self, RowHeight + 24)

	local title = RowLabel(win, row, config.Name or "Slider", 24, config.Icon, nil, config.KeepIconColor)
	title.Size = UDim2.new(1, -(title.Position.X.Offset + 86), 0, 34)

	local box = win:Make("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(70, 24),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		ClearTextOnFocus = false,
		Text = "",
		Parent = row
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(box, 6)
	win:Stroke(box)

	local track = win:Make("Frame", {
		Position = UDim2.new(0, 14, 0, RowHeight + 6),
		Size = UDim2.new(1, -28, 0, 8),
		BorderSizePixel = 0,
		Parent = row
	}, {BackgroundColor3 = "Stroke"})
	Round(track, 4)
	local fill = win:Make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = track
	}, {BackgroundColor3 = "Accent"})
	Round(fill, 4)
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		Rotation = 90,
		Parent = fill
	})
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track
	})
	Round(knob, 9)
	win:Make("UIStroke", {Thickness = 2, Parent = knob}, {Color = "Accent"})
	local hit = Create("TextButton", {
		Position = UDim2.new(0, 6, 0, RowHeight - 6),
		Size = UDim2.new(1, -12, 0, 30),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row
	})

	local object = {}
	function object:Set(newValue, silent)
		newValue = math.clamp(newValue, min, max)
		newValue = math.floor(newValue / step + 0.5) * step
		newValue = tonumber(string.format("%.4f", newValue))
		value = math.clamp(newValue, min, max)
		local alpha = max == min and 0 or (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		box.Text = tostring(value) .. suffix
		if not silent then
			Fire(config.Callback, value)
		end
	end
	function object:Get()
		return value
	end
	object:Set(value, true)
	Register(win, config.Flag, object)

	box.Focused:Connect(function()
		box.Text = tostring(value)
	end)
	box.FocusLost:Connect(function()
		local parsed = tonumber(string.match(box.Text, "-?%d+%.?%d*"))
		if parsed then
			object:Set(parsed)
		else
			object:Set(value, true)
		end
	end)

	win:Slide(hit, function(position)
		local alpha = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		object:Set(min + (max - min) * alpha)
	end, self.Scroller, function()
		Animate(knob, {Size = UDim2.fromOffset(22, 22)}, 0.12, Enum.EasingStyle.Back)
	end, function()
		Animate(knob, {Size = UDim2.fromOffset(18, 18)}, 0.12)
	end)
	return object
end

function Tab:CreateProgress(config)
	config = config or {}
	local win = self.Window
	local value = math.clamp(config.Default or 0, 0, 100)
	local row = NewRow(self, 46)
	local title = RowLabel(win, row, config.Name or "Progress", 24, config.Icon, nil, config.KeepIconColor)
	title.Size = UDim2.new(1, -(title.Position.X.Offset + 70), 0, 28)
	local readout = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.fromOffset(60, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row
	}, {TextColor3 = "Sub"})
	local track = win:Make("Frame", {
		Position = UDim2.new(0, 12, 0, 32),
		Size = UDim2.new(1, -24, 0, 6),
		BorderSizePixel = 0,
		Parent = row
	}, {BackgroundColor3 = "Stroke"})
	Round(track, 3)
	local fill = win:Make("Frame", {
		Size = UDim2.fromScale(value / 100, 1),
		BorderSizePixel = 0,
		Parent = track
	}, {BackgroundColor3 = "Accent"})
	Round(fill, 3)
	local object = {}
	function object:Set(newValue)
		value = math.clamp(newValue, 0, 100)
		Animate(fill, {Size = UDim2.fromScale(value / 100, 1)}, 0.2)
		readout.Text = string.format("%d%%", math.floor(value + 0.5))
	end
	function object:Get()
		return value
	end
	object:Set(value)
	return object
end

function Tab:CreateInput(config)
	config = config or {}
	local win = self.Window
	local row = NewRow(self, RowHeight)
	RowLabel(win, row, config.Name or "Input", 170, config.Icon, nil, config.KeepIconColor)
	local box = win:Make("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(140, RowHeight - 12),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		PlaceholderText = config.Placeholder or "Type here",
		ClearTextOnFocus = config.ClearOnFocus == true,
		Text = config.Default or "",
		Parent = row
	}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
	Round(box, 5)
	win:Stroke(box)
	box.FocusLost:Connect(function(enter)
		Fire(config.Callback, box.Text, enter)
	end)
	local object = {}
	function object:Set(value, silent)
		box.Text = tostring(value)
		if not silent then
			Fire(config.Callback, box.Text, true)
		end
	end
	function object:Get()
		return box.Text
	end
	Register(win, config.Flag, object)
	return object
end

function Tab:CreateKeybind(config)
	config = config or {}
	local win = self.Window
	local key = config.Default or Enum.KeyCode.Unknown
	local listening = false
	local row = NewRow(self, RowHeight)
	RowLabel(win, row, config.Name or "Keybind", 110, config.Icon, nil, config.KeepIconColor)
	local button = win:Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(84, RowHeight - 12),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Parent = row
	}, {BackgroundColor3 = "Top", TextColor3 = "Text"})
	Round(button, 5)
	win:Stroke(button)

	local function Render()
		button.Text = key == Enum.KeyCode.Unknown and "None" or key.Name
	end
	Render()

	button.MouseButton1Click:Connect(function()
		listening = true
		button.Text = "..."
	end)

	win:Connect(UserInputService.InputBegan, function(input, processed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				key = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
				Render()
				Fire(config.Changed, key)
			end
			return
		end
		if not processed and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
			Fire(config.Callback, key)
		end
	end)

	local object = {}
	function object:Set(value)
		key = value
		Render()
		Fire(config.Changed, key)
	end
	function object:Get()
		return key
	end
	Register(win, config.Flag, object)
	return object
end

function Tab:CreateDropdown(config)
	config = config or {}
	local win = self.Window
	local multi = config.Multi == true
	local options = config.Options or {}
	local single
	local chosen = {}
	local open = false
	local buttons = {}
	local optionHeight = RowHeight - 10

	local row = NewRow(self, RowHeight)
	row.ClipsDescendants = true
	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, RowHeight),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row
	})
	local title = RowLabel(win, row, config.Name or "Dropdown", 24, config.Icon, nil, config.KeepIconColor)
	title.Size = UDim2.new(0.5, -title.Position.X.Offset, 0, RowHeight)
	local readout = win:Make("TextLabel", {
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.5, -34, 0, RowHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "None",
		Parent = row
	}, {TextColor3 = "Sub"})
	local mark = win:Make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(18, RowHeight),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "+",
		Parent = row
	}, {TextColor3 = "Sub"})
	local list = win:Make("ScrollingFrame", {
		Position = UDim2.fromOffset(8, RowHeight + 4),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = row
	}, {ScrollBarImageColor3 = "Stroke"})
	Create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})

	local function ListHeight()
		return math.min(#options * (optionHeight + 3), 150)
	end

	local function Resize()
		list.Size = UDim2.new(1, -16, 0, ListHeight())
		Animate(row, {Size = UDim2.new(1, 0, 0, open and (RowHeight + 4 + ListHeight() + 8) or RowHeight)}, 0.2)
		mark.Text = open and "-" or "+"
	end

	local function Collect()
		local names = {}
		for _, option in ipairs(options) do
			if chosen[option] then
				table.insert(names, option)
			end
		end
		return names
	end

	local function Render()
		for option, button in pairs(buttons) do
			local active = multi and chosen[option] or (not multi and single == option)
			button.TextColor3 = active and win.Theme.Accent or win.Theme.Text
			button.BackgroundColor3 = win.Theme.Hover
			button.BackgroundTransparency = active and 0.35 or 1
		end
		if multi then
			local names = Collect()
			readout.Text = #names > 0 and table.concat(names, ", ") or "None"
		else
			readout.Text = single ~= nil and tostring(single) or "None"
		end
	end

	win:Bind(Render)

	local object = {}

	local function Commit(silent)
		Render()
		if not silent then
			Fire(config.Callback, multi and Collect() or single)
		end
	end

	local function Build()
		for _, button in pairs(buttons) do
			button:Destroy()
		end
		buttons = {}
		for index, option in ipairs(options) do
			local button = Create("TextButton", {
				LayoutOrder = index,
				Size = UDim2.new(1, -6, 0, optionHeight),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				Text = tostring(option),
				Parent = list
			})
			Round(button, 5)
			button.MouseButton1Click:Connect(function()
				if multi then
					chosen[option] = not chosen[option] or nil
				else
					single = option
					open = false
					Resize()
				end
				Commit(false)
			end)
			buttons[option] = button
		end
		Render()
	end

	function object:Refresh(newOptions)
		options = newOptions or {}
		chosen = {}
		single = nil
		Build()
		Resize()
		Commit(true)
	end
	function object:Set(value, silent)
		if multi then
			chosen = {}
			for _, option in ipairs(value or {}) do
				chosen[option] = true
			end
		else
			single = value
		end
		Commit(silent)
	end
	function object:Get()
		return multi and Collect() or single
	end
	Register(win, config.Flag, object)

	Build()
	if config.Default ~= nil then
		object:Set(config.Default, true)
	end

	header.MouseButton1Click:Connect(function()
		open = not open
		Resize()
	end)
	return object
end

function Tab:CreateColorPicker(config)
	config = config or {}
	local win = self.Window
	local original = config.Default or Color3.fromRGB(255, 255, 255)
	local color = original
	local hue, sat, val = color:ToHSV()
	local open = false
	local panelTop = RowHeight + 4

	local row = NewRow(self, RowHeight)
	row.ClipsDescendants = true
	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, RowHeight),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row
	})
	RowLabel(win, row, config.Name or "Color", 70, config.Icon, nil, config.KeepIconColor)
	local preview = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, RowHeight / 2),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = row
	})
	Round(preview, 4)
	win:Stroke(preview)

	local panel = Create("Frame", {
		Position = UDim2.fromOffset(0, panelTop),
		Size = UDim2.new(1, 0, 0, 166),
		BackgroundTransparency = 1,
		Parent = row
	})

	local field = Create("Frame", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -40, 0, 100),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		Parent = panel
	})
	Round(field, 4)
	local white = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = field
	})
	Round(white, 4)
	Create("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = white})
	local black = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = field
	})
	Round(black, 4)
	Create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black})
	local fieldCursor = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = field
	})
	Round(fieldCursor, 6)
	Create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Parent = fieldCursor})

	local bar = Create("Frame", {
		Position = UDim2.new(1, -24, 0, 0),
		Size = UDim2.fromOffset(16, 100),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = panel
	})
	Round(bar, 4)
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
		}),
		Parent = bar
	})
	local barCursor = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = bar
	})
	Round(barCursor, 2)
	Create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Parent = barCursor})

	local rgbRow = Create("Frame", {
		Position = UDim2.fromOffset(8, 108),
		Size = UDim2.new(1, -16, 0, 24),
		BackgroundTransparency = 1,
		Parent = panel
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rgbRow
	})
	local channels = {}
	for index, letter in ipairs({"R", "G", "B"}) do
		local channel = win:Make("TextBox", {
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			PlaceholderText = letter,
			ClearTextOnFocus = false,
			Text = "",
			Parent = rgbRow
		}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
		Round(channel, 5)
		win:Stroke(channel)
		channels[index] = channel
	end

	local hex = win:Make("TextBox", {
		Position = UDim2.fromOffset(8, 138),
		Size = UDim2.new(1, -100, 0, 24),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		PlaceholderText = "#RRGGBB",
		ClearTextOnFocus = false,
		Text = "",
		Parent = panel
	}, {BackgroundColor3 = "Top", TextColor3 = "Text", PlaceholderColor3 = "Sub"})
	Round(hex, 5)
	win:Stroke(hex)

	local reset = win:Make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 138),
		Size = UDim2.fromOffset(80, 24),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = "Reset",
		Parent = panel
	}, {BackgroundColor3 = "Hover", TextColor3 = "Text"})
	Round(reset, 5)
	Hover(win, reset, "Hover", "Stroke")

	local function Apply(silent)
		color = Color3.fromHSV(hue, sat, val)
		preview.BackgroundColor3 = color
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		fieldCursor.Position = UDim2.fromScale(sat, 1 - val)
		barCursor.Position = UDim2.fromScale(0.5, hue)
		hex.Text = "#" .. color:ToHex()
		channels[1].Text = tostring(math.floor(color.R * 255 + 0.5))
		channels[2].Text = tostring(math.floor(color.G * 255 + 0.5))
		channels[3].Text = tostring(math.floor(color.B * 255 + 0.5))
		if not silent then
			Fire(config.Callback, color)
		end
	end

	win:Slide(field, function(position)
		sat = math.clamp((position.X - field.AbsolutePosition.X) / field.AbsoluteSize.X, 0, 1)
		val = 1 - math.clamp((position.Y - field.AbsolutePosition.Y) / field.AbsoluteSize.Y, 0, 1)
		Apply(false)
	end, self.Scroller)

	win:Slide(bar, function(position)
		hue = math.clamp((position.Y - bar.AbsolutePosition.Y) / bar.AbsoluteSize.Y, 0, 1)
		Apply(false)
	end, self.Scroller)

	local function ReadChannels()
		local values = {}
		for index, channel in ipairs(channels) do
			local parsed = tonumber(channel.Text) or 0
			values[index] = math.clamp(math.floor(parsed + 0.5), 0, 255)
		end
		hue, sat, val = Color3.fromRGB(values[1], values[2], values[3]):ToHSV()
		Apply(false)
	end
	for _, channel in ipairs(channels) do
		channel.FocusLost:Connect(ReadChannels)
	end

	hex.FocusLost:Connect(function()
		local ok, parsed = pcall(Color3.fromHex, hex.Text)
		if ok and parsed then
			hue, sat, val = parsed:ToHSV()
		end
		Apply(false)
	end)

	local object = {}

	reset.MouseButton1Click:Connect(function()
		win:Confirm("Do you want to reset this color to default?", function()
			if config.OnReset then
				config.OnReset(object)
			else
				object:Set(original, false)
			end
		end)
	end)

	header.MouseButton1Click:Connect(function()
		open = not open
		Animate(row, {Size = UDim2.new(1, 0, 0, open and (panelTop + 170) or RowHeight)}, 0.2)
	end)

	Apply(true)

	function object:Set(value, silent)
		hue, sat, val = value:ToHSV()
		Apply(silent)
	end
	function object:Get()
		return color
	end
	Register(win, config.Flag, object)
	return object
end

function Window:CreateSettingsTab(name, icon)
	local tab = self:CreateTab(name or "Settings", icon)

	tab:CreateSection("Colors")
	self.MenuPicker = tab:CreateColorPicker({
		Name = "Menu Color",
		Default = self.Base,
		Flag = "GraphiteMenuColor",
		Callback = function(color)
			self:SetMenuColor(color)
		end,
		OnReset = function(picker)
			self:SetMenuColor(DefaultBase)
			picker:Set(DefaultBase, true)
		end
	})
	self.TextPicker = tab:CreateColorPicker({
		Name = "Text Color",
		Default = self.Theme.Text,
		Flag = "GraphiteTextColor",
		Callback = function(color)
			self:SetTextColor(color)
		end,
		OnReset = function(picker)
			self.TextColor = nil
			self:Rebuild()
			picker:Set(self.Theme.Text, true)
		end
	})
	self.AccentPicker = tab:CreateColorPicker({
		Name = "Accent Color",
		Default = self.Theme.Accent,
		Flag = "GraphiteAccentColor",
		Callback = function(color)
			self:SetAccent(color)
		end,
		OnReset = function(picker)
			self.AccentColor = nil
			self:Rebuild()
			picker:Set(self.Theme.Accent, true)
		end
	})
	tab:CreateButton({
		Name = "Reset All Colors",
		Callback = function()
			self:Confirm("Do you want to reset all colors to default?", function()
				self:ResetColors()
			end)
		end
	})

	tab:CreateSection("Window")
	self.ZoomSlider = tab:CreateSlider({
		Name = "Menu Zoom",
		Min = 50,
		Max = 160,
		Increment = 1,
		Default = math.floor(self.TargetScale * 100 + 0.5),
		Suffix = "%",
		Callback = function(value)
			self:SetScale(value / 100, true)
		end
	})
	tab:CreateSlider({
		Name = "Menu Opacity",
		Min = 40,
		Max = 100,
		Increment = 1,
		Default = 100,
		Suffix = "%",
		Callback = function(value)
			self:SetOpacity(value)
		end
	})
	tab:CreateToggle({
		Name = "Pinch To Zoom",
		Description = "Two fingers on the menu resize it",
		Default = false,
		Callback = function(state)
			self.PinchEnabled = state
		end
	})
	tab:CreateToggle({
		Name = "Show FPS And Ping",
		Default = false,
		Callback = function(state)
			if state and not self.Watermark then
				self.Watermark = self:CreateWatermark({ShowPing = true})
			elseif self.Watermark then
				self.Watermark:SetVisible(state)
			end
		end
	})
	tab:CreateKeybind({
		Name = "Toggle Key",
		Default = self.ToggleKey,
		Changed = function(key)
			self:SetToggleKey(key)
		end
	})

	tab:CreateSection("Config")
	local configName = "default"
	tab:CreateInput({
		Name = "Config Name",
		Default = configName,
		Callback = function(text)
			if text ~= "" then
				configName = text
			end
		end
	})
	tab:CreateButton({
		Name = "Save Config",
		Callback = function()
			local ok, err = self:SaveConfig(configName)
			self:Notify({
				Title = ok and "Config saved" or "Save failed",
				Content = ok and configName or tostring(err),
				Type = ok and "Success" or "Error"
			})
		end
	})
	tab:CreateButton({
		Name = "Load Config",
		Callback = function()
			local ok, err = self:LoadConfig(configName)
			self:Notify({
				Title = ok and "Config loaded" or "Load failed",
				Content = ok and configName or tostring(err),
				Type = ok and "Success" or "Error"
			})
		end
	})

	tab:CreateSection("Menu")
	tab:CreateButton({
		Name = "Reset Size And Position",
		Callback = function()
			self:ResetLayout()
		end
	})
	tab:CreateButton({
		Name = "Close Menu",
		Callback = function()
			self:RequestClose()
		end
	})
	return tab
end

function Graphite:CreateWindow(config)
	config = config or {}
	local self = setmetatable({}, Window)
	self.Name = config.Name or "Graphite"
	self.Flags = {}
	self.Elements = {}
	self.Tabs = {}
	self.Hooks = {}
	self.Connections = {}
	self.Folder = config.ConfigFolder or "Graphite"
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift
	self.OnClose = config.OnClose
	self.Hidden = false
	self.Closed = false
	self.PinchEnabled = false
	self.Token = 0
	self.Fade = 0
	self.MinSize = Vector2.new(380, 250)
	self.MaxSize = Vector2.new(900, 620)

	local base = config.Size or Vector2.new(480, 320)
	self.BaseSize = Vector2.new(math.max(base.X, self.MinSize.X), math.max(base.Y, self.MinSize.Y))

	self.Base = config.MenuColor or DefaultBase
	self.TextColor = config.TextColor
	self.AccentColor = config.AccentColor or config.Accent
	self.Theme = BuildTheme(self.Base, self.TextColor, self.AccentColor)

	local gui = Create("ScreenGui", {
		Name = "Graphite" .. math.random(1000, 9999),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999
	})
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	local parented = false
	if type(gethui) == "function" then
		parented = pcall(function()
			gui.Parent = gethui()
		end)
	end
	if not parented or not gui.Parent then
		pcall(function()
			gui.Parent = CoreGui
		end)
	end
	if not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	self.Gui = gui

	local view = ViewSize(gui)
	self.AutoScale = math.clamp(math.min(view.X / (self.BaseSize.X + 40), view.Y / (self.BaseSize.Y + 40), 1), 0.5, 1)
	self.TargetScale = config.Scale or self.AutoScale

	local main = self:Make("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.BaseSize.X, self.BaseSize.Y),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = gui
	}, {BackgroundColor3 = "Main"})
	Round(main, 10)
	self.Main = main
	self.UIScale = Create("UIScale", {Scale = self.TargetScale * 0.85, Parent = main})
	Animate(self.UIScale, {Scale = self.TargetScale}, 0.35, Enum.EasingStyle.Back)
	Animate(main, {GroupTransparency = 0}, 0.25)

	local top = self:Make("Frame", {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, TopHeight),
		BorderSizePixel = 0,
		Parent = main
	}, {BackgroundColor3 = "Top"})

	local titleOffset = 14
	local windowIcon = ParseImage(config.Icon)
	if windowIcon then
		Create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Image = windowIcon,
			Parent = top
		})
		titleOffset = 38
	end
	self.TitleLabel = self:Make("TextLabel", {
		Position = UDim2.fromOffset(titleOffset, 0),
		Size = UDim2.new(1, -titleOffset - 90, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Name,
		Parent = top
	}, {TextColor3 = "Text"})

	local buttonWidth = Touch and 38 or 32
	local buttonHeight = Touch and 30 or 26

	local function GlyphButton(parent, text, props)
		props.Size = props.Size or UDim2.fromOffset(buttonWidth, buttonHeight)
		props.BackgroundTransparency = 1
		props.AutoButtonColor = false
		props.Font = Enum.Font.GothamBold
		props.TextSize = 14
		props.Text = text
		props.Parent = parent
		local button = self:Make("TextButton", props, {BackgroundColor3 = "Hover", TextColor3 = "Sub"})
		Round(button, 5)
		button.MouseEnter:Connect(function()
			Animate(button, {BackgroundTransparency = 0, TextColor3 = self.Theme.Text}, 0.1)
		end)
		button.MouseLeave:Connect(function()
			Animate(button, {BackgroundTransparency = 1, TextColor3 = self.Theme.Sub}, 0.1)
		end)
		return button
	end

	local hideButton = GlyphButton(top, "-", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -(buttonWidth * 2 + 10), 0.5, 0)
	})
	local closeButton = GlyphButton(top, "X", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -(buttonWidth + 6), 0.5, 0)
	})

	local side = self:Make("Frame", {
		Position = UDim2.fromOffset(0, TopHeight),
		Size = UDim2.new(0, 124, 1, -TopHeight),
		BorderSizePixel = 0,
		Parent = main
	}, {BackgroundColor3 = "Side"})
	self:Make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BorderSizePixel = 0,
		Parent = side
	}, {BackgroundColor3 = "Stroke"})
	local tabList = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = side
	})
	Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList})
	Pad(tabList, 8, 8, 9, 8)
	self.TabList = tabList

	local content = Create("Frame", {
		Position = UDim2.fromOffset(124, TopHeight),
		Size = UDim2.new(1, -124, 1, -TopHeight),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main
	})
	self.Content = content

	local edge = Create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 200,
		Parent = main
	})
	Round(edge, 9)
	self:Stroke(edge)

	local gripSize = Touch and 30 or 20
	local grip = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(gripSize, gripSize),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 20,
		Parent = main
	})
	for _, offset in ipairs({Vector2.new(-6, -6), Vector2.new(-6, -11), Vector2.new(-11, -6)}) do
		local dot = self:Make("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, offset.X, 1, offset.Y),
			Size = UDim2.fromOffset(3, 3),
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = grip
		}, {BackgroundColor3 = "Sub"})
		Round(dot, 2)
	end

	local resizeOrigin
	local resizeStart
	local resizeCorner
	self:Pointer(grip, function(input)
		resizeOrigin = input.Position
		resizeStart = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)
		resizeCorner = main.AbsolutePosition
	end, function(input)
		local scale = self.UIScale.Scale
		local delta = (input.Position - resizeOrigin) / scale
		local width = math.clamp(resizeStart.X + delta.X, self.MinSize.X, self.MaxSize.X)
		local height = math.clamp(resizeStart.Y + delta.Y, self.MinSize.Y, self.MaxSize.Y)
		local current = ViewSize(gui)
		main.Size = UDim2.fromOffset(width, height)
		main.Position = UDim2.fromScale(
			(resizeCorner.X + width * scale / 2) / current.X,
			(resizeCorner.Y + height * scale / 2) / current.Y
		)
		self:Clamp()
	end)

	local function AttachDrag(handle)
		local origin
		local startCenter
		self:Pointer(handle, function(input)
			local current = ViewSize(gui)
			origin = input.Position
			startCenter = Vector2.new(main.Position.X.Scale * current.X, main.Position.Y.Scale * current.Y)
		end, function(input)
			local current = ViewSize(gui)
			local delta = input.Position - origin
			main.Position = UDim2.fromScale((startCenter.X + delta.X) / current.X, (startCenter.Y + delta.Y) / current.Y)
			self:Clamp()
		end)
	end
	AttachDrag(top)
	AttachDrag(side)

	local barHeight = Touch and 36 or 30
	local restore = self:Make("Frame", {
		Name = "Restore",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, barHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		Parent = gui
	}, {BackgroundColor3 = "Top"})
	Round(restore, 5)
	self:Stroke(restore)
	Pad(restore, 12, 0, 5, 0)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = restore
	})
	self.Restore = restore
	self.RestoreScale = Create("UIScale", {Scale = 1, Parent = restore})
	self.BarLabel = self:Make("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, barHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = self.Name,
		Parent = restore
	}, {TextColor3 = "Text"})
	local plusButton = GlyphButton(restore, "+", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(buttonWidth, barHeight - 8)
	})
	local barCloseButton = GlyphButton(restore, "X", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(buttonWidth, barHeight - 8)
	})

	local barOrigin
	local barStart
	self:Pointer(restore, function(input)
		local current = ViewSize(gui)
		local position = restore.Position
		barOrigin = input.Position
		barStart = Vector2.new(
			position.X.Scale * current.X + position.X.Offset,
			position.Y.Scale * current.Y + position.Y.Offset
		)
	end, function(input)
		local current = ViewSize(gui)
		local delta = input.Position - barOrigin
		restore.Position = UDim2.new(
			(barStart.X + delta.X) / current.X, 0,
			(barStart.Y + delta.Y) / current.Y, 0
		)
		self:ClampRestore()
	end)

	local notes = Create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 250, 1, -24),
		BackgroundTransparency = 1,
		Parent = gui
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = notes
	})
	self.Notes = notes

	hideButton.MouseButton1Click:Connect(function()
		self:SetHidden(true)
	end)
	plusButton.MouseButton1Click:Connect(function()
		self:SetHidden(false)
	end)
	closeButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end)
	barCloseButton.MouseButton1Click:Connect(function()
		self:RequestClose()
	end)

	self:Connect(UserInputService.InputBegan, function(input, processed)
		if processed or self.Closed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.ToggleKey then
			self:SetHidden(not self.Hidden)
		end
	end)

	local function BothOnMenu(positions)
		local origin = main.AbsolutePosition
		local size = main.AbsoluteSize
		for _, point in ipairs(positions) do
			if point.X < origin.X or point.X > origin.X + size.X or point.Y < origin.Y or point.Y > origin.Y + size.Y then
				return false
			end
		end
		return #positions > 1
	end

	local pinchBase
	self:Connect(UserInputService.TouchPinch, function(positions, pinchScale, _, state)
		if self.Hidden or self.Closed or not self.PinchEnabled then
			pinchBase = nil
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchBase = BothOnMenu(positions) and self.TargetScale or nil
		elseif state == Enum.UserInputState.Change then
			if pinchBase and BothOnMenu(positions) then
				self:SetScale(pinchBase * pinchScale)
			end
		else
			pinchBase = nil
		end
	end)

	self:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:OnViewport()
	end)

	return self
end

return Graphite