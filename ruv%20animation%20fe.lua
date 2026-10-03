local plrs = game:GetService("Players")
local as = game:GetService("AssetService")
local aes = game:GetService("AvatarEditorService")
local rs = game:GetService("RunService")
local hs = game:GetService("HttpService")
local cp = game:GetService("ContentProvider")
local ts = game:GetService("TweenService")
local lp = plrs.LocalPlayer

local m = {
	["runanimation"]      = "run",
	["climbanimation"]    = "climb",
	["jumpanimation"]     = "jump",
	["fallanimation"]     = "fall",
	["idleanimation"]     = "idle",
	["swimidleanimation"] = "swimidle",
	["swimanimation"]     = "swim",
	["walkanimation"]     = "walk"
}

local shortNames = {
	["idleanimation"]     = "Idle",
	["walkanimation"]     = "Walk",
	["runanimation"]      = "Run",
	["jumpanimation"]     = "Jump",
	["fallanimation"]     = "Fall",
	["climbanimation"]    = "Climb",
	["swimidleanimation"] = "S.Idle",
	["swimanimation"]     = "Swim"
}

local buttonOrder = {
	"idleanimation",
	"walkanimation",
	"runanimation",
	"jumpanimation",
	"fallanimation",
	"climbanimation",
	"swimidleanimation",
	"swimanimation"
}

local CACHE_FILE_NAME = "animation_bundle_data_cache.json"
local ANIM_CACHE_URL = "https://raw.githubusercontent.com/TribalFootball/TuffTeto/main/animation_bundle_data_cache.json"
local SEEN_BUNDLES_FILE = "seen_anim_bundles_cache.json"
local EQUIPPED_FILE = "FeUgcAnim.json"
local SAVED_BUNDLES_FILE = "FeUgcAnim_Bookmarks.json"

local assetCache, fileCache, seenBundles, equippedAnims = {}, {}, {}, {}
local savedBookmarks = {}

local function loadJSON(file)
	local ok, content = pcall(function()
		if isfile and not isfile(file) then return nil end
		return readfile(file)
	end)
	if ok and content then
		local suc, decoded = pcall(function() return hs:JSONDecode(content) end)
		return suc and decoded or {}
	end
	return {}
end

local function saveJSON(file, data)
	pcall(function() writefile(file, hs:JSONEncode(data)) end)
end

fileCache = loadJSON(CACHE_FILE_NAME)
seenBundles = loadJSON(SEEN_BUNDLES_FILE)
equippedAnims = loadJSON(EQUIPPED_FILE)
savedBookmarks = loadJSON(SAVED_BUNDLES_FILE)

task.spawn(function()
	local ok, onlineContent = pcall(function() return game:HttpGet(ANIM_CACHE_URL) end)
	if ok and onlineContent then
		pcall(function()
			local onlineData = hs:JSONDecode(onlineContent)
			for k, v in pairs(onlineData) do if not fileCache[k] then fileCache[k] = v end end
			saveJSON(CACHE_FILE_NAME, fileCache)
		end)
	end
end)

local function applySavedAnimations(char)
	if not char then return end
	local animate = char:WaitForChild("Animate", 5)
	local human = char:WaitForChild("Humanoid", 5)
	if not animate or not human then return end

	for _, tr in ipairs(human:GetPlayingAnimationTracks()) do 
		pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end) 
	end

	animate.Disabled = true

	for slotType, animList in pairs(equippedAnims) do
		local fId = m[string.lower(slotType)]
		if fId then
			local folder = animate:FindFirstChild(fId)
			if folder then
				for _, o in ipairs(folder:GetChildren()) do 
					if o:IsA("Animation") then o:Destroy() end 
				end
				for _, animData in ipairs(animList) do
					local newAnim = Instance.new("Animation", folder)
					newAnim.Name = animData.Name
					newAnim.AnimationId = animData.AnimationId
				end
			end
		end
	end

	task.wait(0.05)
	animate.Disabled = false
end

local function initAutoEquip(char)
	if not char then return end
	task.spawn(function()
		local animate = char:WaitForChild("Animate", 5)
		local human = char:WaitForChild("Humanoid", 5)

		if animate and human then
			local idleFolder = animate:WaitForChild("idle", 5)
			if idleFolder then
				idleFolder:WaitForChild("Animation1", 3) 
			end

			task.wait(0.1)
			applySavedAnimations(char)
		end
	end)
end

if lp.Character then
	initAutoEquip(lp.Character)
end

lp.CharacterAdded:Connect(initAutoEquip)

local function get(id, bundleId, assetType)
	local stringId = tostring(id)
	if assetCache[stringId] then return assetCache[stringId] end
	if fileCache[stringId] then
		local reconstructed = {}
		for _, data in ipairs(fileCache[stringId]) do
			local anim = Instance.new("Animation")
			anim.Name, anim.AnimationId = data.Name, data.AnimationId
			table.insert(reconstructed, anim)
		end
		assetCache[stringId] = reconstructed
		return reconstructed
	end

	local t, serializableData = {}, {}
	local descProp = "IdleAnimation"
	local lowerType = assetType and string.lower(assetType) or ""

	if lowerType:find("idle") and not lowerType:find("swim") then descProp = "IdleAnimation"
	elseif lowerType:find("walk") then descProp = "WalkAnimation"
	elseif lowerType:find("run") then descProp = "RunAnimation"
	elseif lowerType:find("jump") then descProp = "JumpAnimation"
	elseif lowerType:find("fall") then descProp = "FallAnimation"
	elseif lowerType:find("climb") then descProp = "ClimbAnimation"
	elseif lowerType:find("swim") then descProp = "SwimAnimation"
	end

	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc[descProp] = tonumber(id)
		local dummy = plrs:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		local animate = dummy:FindFirstChild("Animate")
		if animate then
			local targetFolders = (descProp == "SwimAnimation") and {"swim", "swimidle"} or {string.lower(string.gsub(descProp, "Animation", ""))}
			for _, folderName in ipairs(targetFolders) do
				local folder = animate:FindFirstChild(folderName)
				if folder then
					for _, child in ipairs(folder:GetChildren()) do
						if child:IsA("Animation") and child.AnimationId ~= "" then
							local clone = child:Clone()
							table.insert(t, clone)
							table.insert(serializableData, { Name = clone.Name, AnimationId = clone.AnimationId, BundleId = tostring(bundleId) })
						end
					end
				end
			end
		end
		dummy:Destroy()
	end)

	if #t == 0 then
		pcall(function() 
			local objs = game:GetObjects("rbxassetid://" .. stringId) 
			if objs and #objs > 0 then
				local function processItem(item)
					if item:IsA("Animation") then
						table.insert(t, item:Clone())
						table.insert(serializableData, { Name = item.Name, AnimationId = item.AnimationId, BundleId = tostring(bundleId) })
					end
				end
				processItem(objs[1])
				for _, c in ipairs(objs[1]:GetDescendants()) do processItem(c) end
			end
		end)
	end

	assetCache[stringId] = t
	fileCache[stringId] = serializableData
	saveJSON(CACHE_FILE_NAME, fileCache)
	return t
end

local function clearAssetCache(id)
	local stringId = tostring(id)
	assetCache[stringId], fileCache[stringId] = nil, nil
	saveJSON(CACHE_FILE_NAME, fileCache)
end

local vp = workspace.CurrentCamera.ViewportSize
local scale = math.clamp(math.min(vp.X / 1920, vp.Y / 1080), 0.55, 3.0) * 1.45
local function s(n) return math.round(n * scale) end

local C = {
	bg = Color3.fromRGB(35, 40, 45), panel = Color3.fromRGB(45, 50, 55),
	surface = Color3.fromRGB(55, 60, 65), surfaceHi = Color3.fromRGB(75, 80, 85),
	accent = Color3.fromRGB(130, 140, 150), green = Color3.fromRGB(110, 120, 130), 
	purple = Color3.fromRGB(95, 105, 115), text = Color3.fromRGB(220, 225, 230),
	textDim = Color3.fromRGB(160, 165, 170), textMuted = Color3.fromRGB(110, 115, 120),
	overlay = Color3.fromRGB(20, 25, 30), fav = Color3.fromRGB(255, 215, 0)
}

local PAD_TOP = s(26) 
local PAD_SIDES = s(12)
local W, H = s(510), s(350) 
local INNER_W = W - (PAD_SIDES * 2)
local LEFT_W = s(260)
local RIGHT_W = INNER_W - LEFT_W - s(1)

local scrollW = s(4)
local FOOT_H = s(28)
local VP_H = s(140)
local MIN_BTN_SIZE = s(60)
local UI_BUSY = false
local TOGGLE_COOLDOWN = 0.15

local function stroke(parent, color, thickness)
	local st = Instance.new("UIStroke", parent)
	st.Color = color or Color3.fromRGB(65, 70, 75)
	st.Thickness = thickness or 1
	return st
end

local function corner(parent, radius)
	local cr = Instance.new("UICorner", parent)
	cr.CornerRadius = UDim.new(0, radius or s(6))
	return cr
end

local function applyCoolGradient(parent)
	local grad = Instance.new("UIGradient", parent)
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 170, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 110, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 55, 60))
	})
	grad.Rotation = 45
end

local function applyShimmer(obj, colorStart, colorMid)
	if obj:FindFirstChild("ShimmerGrad") then return end
	local grad = Instance.new("UIGradient", obj)
	grad.Name = "ShimmerGrad"
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colorStart),
		ColorSequenceKeypoint.new(0.5, colorMid),
		ColorSequenceKeypoint.new(1, colorStart)
	})
	grad.Rotation = 35
	grad.Offset = Vector2.new(-1, 0)

	local tw = ts:Create(grad, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Offset = Vector2.new(1, 0)})
	tw:Play()
end

local function removeShimmer(obj)
	local g = obj:FindFirstChild("ShimmerGrad")
	if g then g:Destroy() end
end

local gp = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
if gp:FindFirstChild("StudioAnimStudio") then gp.StudioAnimStudio:Destroy() end

local g = Instance.new("ScreenGui", gp)
g.Name = "StudioAnimStudio"
g.ResetOnSpawn = false
if not g.Parent then g.Parent = lp:WaitForChild("PlayerGui") end

local mf = Instance.new("CanvasGroup", g)
mf.Size, mf.Position, mf.AnchorPoint = UDim2.new(0, 0, 0, 0), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5)
mf.BackgroundColor3, mf.BackgroundTransparency = C.bg, 0.15
mf.GroupTransparency = 1 
mf.Active, mf.Draggable = true, true
corner(mf, s(10)); applyCoolGradient(mf); stroke(mf, Color3.fromRGB(80, 85, 90), 1)

local mfPad = Instance.new("UIPadding", mf)
mfPad.PaddingTop = UDim.new(0, PAD_TOP)
mfPad.PaddingBottom = UDim.new(0, PAD_SIDES)
mfPad.PaddingLeft = UDim.new(0, PAD_SIDES)
mfPad.PaddingRight = UDim.new(0, PAD_SIDES)

task.delay(0.1, function()
	ts:Create(mf, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, W, 0, H), GroupTransparency = 0}):Play()
end)

local minBtn = Instance.new("CanvasGroup", g)
minBtn.Size, minBtn.Position, minBtn.AnchorPoint = UDim2.new(0, 0, 0, 0), UDim2.new(1, -s(40), 0, s(30)), Vector2.new(0.5, 0.5)
minBtn.BackgroundTransparency = 1
minBtn.GroupTransparency = 1
minBtn.Visible = false
minBtn.Active, minBtn.Draggable, minBtn.ClipsDescendants = true, true, true

local minBtnBg = Instance.new("Frame", minBtn)
minBtnBg.Size, minBtnBg.BackgroundColor3, minBtnBg.BorderSizePixel = UDim2.new(1, 0, 1, 0), C.panel, 0
local minBtnCorner = Instance.new("UICorner", minBtnBg)
minBtnCorner.CornerRadius = UDim.new(0.5, 0)
local minBtnStroke = stroke(minBtnBg, C.accent, 1)
applyCoolGradient(minBtnBg)

local minBtnLabel = Instance.new("TextLabel", minBtn)
minBtnLabel.Size, minBtnLabel.BackgroundTransparency = UDim2.new(1, 0, 1, 0), 1
minBtnLabel.Text, minBtnLabel.TextColor3, minBtnLabel.Font, minBtnLabel.TextSize = "UGC", C.text, Enum.Font.GothamBlack, s(14)
minBtnLabel.ClipsDescendants = true

local minBtnHit = Instance.new("TextButton", minBtn)
minBtnHit.Size, minBtnHit.BackgroundTransparency, minBtnHit.Text, minBtnHit.ClipsDescendants = UDim2.new(1, 0, 1, 0), 1, "", true

minBtnHit.MouseButton1Click:Connect(function()
	if UI_BUSY then return end
	UI_BUSY = true

	minBtn.Visible = false
	minBtn.GroupTransparency = 1
	minBtn.Size = UDim2.new(0, 0, 0, 0)

	mf.Size = UDim2.new(0, W, 0, H)
	mf.GroupTransparency = 0
	mf.Visible = true

	task.wait(TOGGLE_COOLDOWN)
	UI_BUSY = false
end)

local lp_frame = Instance.new("Frame", mf)
lp_frame.Size, lp_frame.Position, lp_frame.BackgroundTransparency = UDim2.new(0, LEFT_W, 1, 0), UDim2.new(0, 0, 0, 0), 1

local titleLbl = Instance.new("TextLabel", lp_frame)
titleLbl.Size, titleLbl.Position, titleLbl.BackgroundTransparency = UDim2.new(1, 0, 0, s(22)), UDim2.new(0, s(4), 0, 0), 1
titleLbl.Text, titleLbl.TextColor3, titleLbl.Font, titleLbl.TextSize = "Fe Ugc Animations", C.text, Enum.Font.GothamBlack, s(15)
titleLbl.TextXAlignment, titleLbl.ClipsDescendants = Enum.TextXAlignment.Left, true

local header = Instance.new("Frame", lp_frame)
header.Size, header.Position, header.BackgroundTransparency = UDim2.new(1, -s(8), 0, s(26)), UDim2.new(0, s(4), 0, s(28)), 1

local tabDiscoverBtn = Instance.new("TextButton", header)
tabDiscoverBtn.Size, tabDiscoverBtn.Position = UDim2.new(0.48, 0, 1, 0), UDim2.new(0, 0, 0, 0)
tabDiscoverBtn.Text, tabDiscoverBtn.Font, tabDiscoverBtn.TextSize = "Discover", Enum.Font.GothamBold, s(12)
tabDiscoverBtn.BackgroundColor3, tabDiscoverBtn.TextColor3, tabDiscoverBtn.ClipsDescendants = C.surfaceHi, C.text, true
corner(tabDiscoverBtn, s(4))

local tabSavedBtn = Instance.new("TextButton", header)
tabSavedBtn.Size, tabSavedBtn.Position = UDim2.new(0.48, 0, 1, 0), UDim2.new(0.52, 0, 0, 0)
tabSavedBtn.Text, tabSavedBtn.Font, tabSavedBtn.TextSize = "Saved", Enum.Font.GothamBold, s(12)
tabSavedBtn.BackgroundColor3, tabSavedBtn.TextColor3, tabSavedBtn.ClipsDescendants = C.surface, C.textMuted, true
corner(tabSavedBtn, s(4))

local minWindowBtn = Instance.new("TextButton", mf)
minWindowBtn.Size, minWindowBtn.Position, minWindowBtn.AnchorPoint = UDim2.new(0, s(30), 0, s(30)), UDim2.new(1, PAD_SIDES - s(4), 0, -PAD_TOP + s(4)), Vector2.new(1, 0)
minWindowBtn.BackgroundColor3, minWindowBtn.BackgroundTransparency = C.surfaceHi, 0.5
minWindowBtn.Text, minWindowBtn.TextColor3, minWindowBtn.Font, minWindowBtn.TextSize, minWindowBtn.ClipsDescendants = "-", C.textDim, Enum.Font.GothamBold, s(20), true
corner(minWindowBtn, s(5))

minWindowBtn.MouseButton1Click:Connect(function() 
	if UI_BUSY then return end
	UI_BUSY = true

	mf.Visible = false
	mf.GroupTransparency = 1
	mf.Size = UDim2.new(0, 0, 0, 0)

	minBtn.Size = UDim2.new(0, MIN_BTN_SIZE, 0, MIN_BTN_SIZE)
	minBtn.GroupTransparency = 0
	minBtn.Visible = true

	task.wait(TOGGLE_COOLDOWN)
	UI_BUSY = false
end)

local searchRow = Instance.new("Frame", lp_frame)
searchRow.Size, searchRow.Position, searchRow.BackgroundTransparency = UDim2.new(1, -s(8), 0, s(26)), UDim2.new(0, s(4), 0, s(60)), 1

local sb = Instance.new("TextBox", searchRow)
sb.Size, sb.PlaceholderText, sb.Text = UDim2.new(1, -s(58), 1, 0), "Search...", ""
sb.BackgroundColor3, sb.BackgroundTransparency, sb.TextColor3, sb.ClipsDescendants = C.surface, 0.4, C.text, true
sb.Font, sb.TextSize = Enum.Font.Gotham, s(11)
corner(sb, s(4)); stroke(sb, C.surfaceHi, 1)
local sbPad = Instance.new("UIPadding", sb) sbPad.PaddingLeft = UDim.new(0, s(8))

local searchBtn = Instance.new("TextButton", searchRow)
searchBtn.Size, searchBtn.Position = UDim2.new(0, s(52), 1, 0), UDim2.new(1, -s(52), 0, 0)
searchBtn.Text, searchBtn.BackgroundColor3, searchBtn.TextColor3, searchBtn.ClipsDescendants = "Search", C.accent, Color3.new(1,1,1), true
searchBtn.Font, searchBtn.TextSize = Enum.Font.GothamBold, s(11)
corner(searchBtn, s(4))

local gridScroller = Instance.new("ScrollingFrame", lp_frame)
gridScroller.Size, gridScroller.Position = UDim2.new(1, -s(8), 1, -s(126)), UDim2.new(0, s(4), 0, s(92))
gridScroller.BackgroundColor3, gridScroller.BackgroundTransparency, gridScroller.BorderSizePixel = C.surface, 0.7, 0
gridScroller.ScrollBarThickness = scrollW
corner(gridScroller, s(6))

local loadingOverlay = Instance.new("TextLabel", lp_frame)
loadingOverlay.Size, loadingOverlay.Position = gridScroller.Size, gridScroller.Position
loadingOverlay.BackgroundColor3, loadingOverlay.BackgroundTransparency, loadingOverlay.ZIndex = C.bg, 0.3, 10
loadingOverlay.Text, loadingOverlay.TextColor3, loadingOverlay.Font, loadingOverlay.ClipsDescendants = "Loading...", C.text, Enum.Font.GothamBold, true
loadingOverlay.Visible = false; corner(loadingOverlay, s(6))
applyShimmer(loadingOverlay, C.surface, C.surfaceHi)

local footer = Instance.new("Frame", lp_frame)
footer.Size, footer.Position, footer.BackgroundTransparency = UDim2.new(1, -s(8), 0, FOOT_H), UDim2.new(0, s(4), 1, -FOOT_H), 1

local prevBtn = Instance.new("TextButton", footer)
prevBtn.Size, prevBtn.Text, prevBtn.BackgroundColor3, prevBtn.ClipsDescendants = UDim2.new(0, s(52), 1, 0), "← Back", C.surfaceHi, true
prevBtn.Font, prevBtn.TextSize, prevBtn.TextColor3 = Enum.Font.GothamBold, s(10), C.textDim
corner(prevBtn, s(4))

local pageLbl = Instance.new("TextLabel", footer)
pageLbl.Size, pageLbl.Position, pageLbl.Text, pageLbl.ClipsDescendants = UDim2.new(1, -s(114), 1, 0), UDim2.new(0, s(57), 0, 0), "Page 1", true
pageLbl.BackgroundTransparency, pageLbl.TextColor3, pageLbl.Font = 1, C.textDim, Enum.Font.Gotham

local nextBtn = Instance.new("TextButton", footer)
nextBtn.Size, nextBtn.Position, nextBtn.Text, nextBtn.ClipsDescendants = UDim2.new(0, s(52), 1, 0), UDim2.new(1, -s(52), 0, 0), "Next →", true
nextBtn.BackgroundColor3, nextBtn.Font, nextBtn.TextSize = C.surfaceHi, Enum.Font.GothamBold, s(10)
corner(nextBtn, s(4))

local divider = Instance.new("Frame", mf)
divider.Size, divider.Position, divider.BackgroundColor3 = UDim2.new(0, 1, 1, 0), UDim2.new(0, LEFT_W, 0, 0), C.surfaceHi
divider.BorderSizePixel = 0

local rp = Instance.new("Frame", mf)
rp.Size, rp.Position, rp.BackgroundTransparency = UDim2.new(0, RIGHT_W, 1, 0), UDim2.new(0, LEFT_W + s(1), 0, 0), 1

local masterViewport = Instance.new("ViewportFrame", rp)
masterViewport.Size, masterViewport.Position = UDim2.new(1, -s(16), 0, VP_H), UDim2.new(0, s(8), 0, 0)
masterViewport.BackgroundColor3, masterViewport.BackgroundTransparency = C.overlay, 0.3
corner(masterViewport, s(6)); stroke(masterViewport, C.surfaceHi, 1)

local statusFrame = Instance.new("Frame", rp)
statusFrame.Size, statusFrame.Position = UDim2.new(1, -s(16), 0, s(28)), UDim2.new(0, s(8), 0, VP_H + s(8))
statusFrame.BackgroundColor3, statusFrame.BackgroundTransparency = C.surface, 0.6
corner(statusFrame, s(4))

local statusLabel = Instance.new("TextLabel", statusFrame)
statusLabel.Size, statusLabel.Position, statusLabel.BackgroundTransparency = UDim2.new(1, -s(12), 1, 0), UDim2.new(0, s(6), 0, 0), 1
statusLabel.Text, statusLabel.TextColor3, statusLabel.ClipsDescendants = "No bundle selected", C.textDim, true
statusLabel.Font, statusLabel.TextSize, statusLabel.TextXAlignment = Enum.Font.GothamSemibold, s(10), Enum.TextXAlignment.Left

local buttonContainer = Instance.new("Frame", rp)
buttonContainer.Size, buttonContainer.Position = UDim2.new(1, -s(16), 0, s(50)), UDim2.new(0, s(8), 0, VP_H + s(44))
buttonContainer.BackgroundTransparency = 1
local gridBtnLayout = Instance.new("UIGridLayout", buttonContainer)
local btnW = math.floor((RIGHT_W - s(16) - s(12)) / 4)
gridBtnLayout.CellSize, gridBtnLayout.CellPadding = UDim2.new(0, btnW, 0, s(22)), UDim2.new(0, s(4), 0, s(4))

local actRow = Instance.new("Frame", rp)
actRow.Size, actRow.Position, actRow.BackgroundTransparency = UDim2.new(1, -s(16), 0, s(60)), UDim2.new(0, s(8), 1, -s(60)), 1

local bookmarkBtn = Instance.new("TextButton", actRow)
bookmarkBtn.Size, bookmarkBtn.Position = UDim2.new(1, 0, 0, s(28)), UDim2.new(0, 0, 0, 0)
bookmarkBtn.BackgroundColor3, bookmarkBtn.Text = C.panel, "Save to Saved Tab"
bookmarkBtn.Font, bookmarkBtn.TextSize, bookmarkBtn.TextColor3 = Enum.Font.GothamBold, s(11), C.textMuted
bookmarkBtn.Visible, bookmarkBtn.ClipsDescendants = false, true
corner(bookmarkBtn, s(4))

local wearSelectedBtn = Instance.new("TextButton", actRow)
wearSelectedBtn.Size, wearSelectedBtn.Position, wearSelectedBtn.Text = UDim2.new(0.48, 0, 0, s(28)), UDim2.new(0, 0, 1, -s(28)), "Wear Selected"
wearSelectedBtn.BackgroundColor3, wearSelectedBtn.TextColor3, wearSelectedBtn.ClipsDescendants = C.green, Color3.new(1,1,1), true
wearSelectedBtn.Font, wearSelectedBtn.TextSize, wearSelectedBtn.Visible = Enum.Font.GothamBold, s(10), false
corner(wearSelectedBtn, s(4))

local wearAllBtn = Instance.new("TextButton", actRow)
wearAllBtn.Size, wearAllBtn.Position, wearAllBtn.Text = UDim2.new(0.48, 0, 0, s(28)), UDim2.new(0.52, 0, 1, -s(28)), "Wear All"
wearAllBtn.BackgroundColor3, wearAllBtn.TextColor3, wearAllBtn.ClipsDescendants = C.purple, Color3.new(1,1,1), true
wearAllBtn.Font, wearAllBtn.TextSize, wearAllBtn.Visible = Enum.Font.GothamBold, s(10), false
corner(wearAllBtn, s(4))

local activeGridThreads, currentBundleItems, animationButtons = {}, {}, {}
local targetBundleItems, activeMasterTrack, activeMasterType = nil, nil, nil
local activeBundleName, activeBundleId = "None", nil
local searchResults, savedTabList = {}, {}
local catalogCursor, currentPageIndex, itemsPerPage = nil, 1, 5 
local currentTab = "Discover"
local userSelectedAnimSlot = "idleanimation"

local function preloadAnimations(tracks)
	local i = {}
	for _, t in ipairs(tracks) do table.insert(i, t) end
	if #i > 0 then pcall(function() cp:PreloadAsync(i) end) end
end

local function buildViewportSkeleton(vpFrame)
	local wm = vpFrame:FindFirstChildOfClass("WorldModel")
	if not wm then wm = Instance.new("WorldModel", vpFrame) else for _,c in ipairs(wm:GetChildren()) do c:Destroy() end end
	local char = lp.Character or lp.CharacterAdded:Wait()
	char.Archivable = true
	local clone = char:Clone(); clone.Parent = wm
	local root, human = clone:WaitForChild("HumanoidRootPart"), clone:FindFirstChildOfClass("Humanoid")
	local anim = human:FindFirstChildOfClass("Animator") or Instance.new("Animator", human)
	if clone:FindFirstChild("Animate") then clone.Animate.Disabled = true end
	local cam = vpFrame:FindFirstChildOfClass("Camera") or Instance.new("Camera", vpFrame)
	vpFrame.CurrentCamera = cam
	cam.CFrame = CFrame.new(Vector3.new(0, 1.5, 6), Vector3.new(0, 0, 0))
	local angle = 0
	local conn = rs.RenderStepped:Connect(function(dt)
		if clone and root then angle = angle + math.rad(25*dt); clone:PivotTo(CFrame.new(0,0,0) * CFrame.Angles(0, angle, 0)) end
	end)
	return clone, anim, conn
end

local function applyAnimationToCharacter(character, targetAnimations, slotType)
	local animate = character:WaitForChild("Animate", 5)
	local human = character:FindFirstChildOfClass("Humanoid")
	if not animate or not human then return end
	for _, tr in ipairs(human:GetPlayingAnimationTracks()) do pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end) end
	animate.Disabled = true
	local cleanSlot = string.lower(slotType or "")
	local fId = m[cleanSlot]
	if fId then
		local folder = animate:FindFirstChild(fId)
		if folder then
			for _, o in ipairs(folder:GetChildren()) do if o:IsA("Animation") then o:Destroy() end end
			equippedAnims[cleanSlot] = {}
			for _, animAsset in ipairs(targetAnimations) do
				local newAnim = Instance.new("Animation", folder)
				newAnim.Name, newAnim.AnimationId = animAsset.Name, animAsset.AnimationId
				table.insert(equippedAnims[cleanSlot], {Name=newAnim.Name, AnimationId=newAnim.AnimationId})
			end
			saveJSON(EQUIPPED_FILE, equippedAnims)
		end
	end
	task.wait(0.05); animate.Disabled = false
end

local function getSpecificTrack(fetchedTracks, targetType)
	if #fetchedTracks == 0 then return nil end
	if targetType == "swimidleanimation" then
		for _, tr in ipairs(fetchedTracks) do if string.lower(tr.Name):find("idle") then return tr end end
		return fetchedTracks[2] or fetchedTracks[1]
	elseif targetType == "swimanimation" then
		for _, tr in ipairs(fetchedTracks) do if string.lower(tr.Name) == "swim" then return tr end end
	end
	return fetchedTracks[1]
end

local function truncate(str, maxLen) return #str > maxLen and str:sub(1, maxLen-1).."…" or str end

local function tryPlayTrack(animator, track, looped)
	local ok, pt = pcall(function() local tr = animator:LoadAnimation(track); tr.Looped=looped; tr:Play(); return tr end)
	if not ok or not pt then return false, nil end
	task.wait(0.15)
	if not pt.IsPlaying then pcall(function() pt:Stop() end); return false, nil end
	return true, pt
end

local function applyBundleItemsToCharacter(items)
	if not lp.Character then return end
	local tLoad, tApply = {}, {}
	for _, lt in ipairs(buttonOrder) do
		local pay = items[lt]
		if pay then
			local t = get(pay.Id, nil, pay.AssetType)
			if lt == "idleanimation" then
				tApply[lt] = t; for _,x in ipairs(t) do table.insert(tLoad, x) end
			else
				local spec = getSpecificTrack(t, lt)
				if spec then tApply[lt] = {spec}; table.insert(tLoad, spec) end
			end
		end
	end
	preloadAnimations(tLoad)
	for slot, tracks in pairs(tApply) do applyAnimationToCharacter(lp.Character, tracks, slot) end
end

local function wearBundleQuickly(bundleId, onDone)
	task.spawn(function()
		local ok, res = pcall(function() return as:GetBundleDetailsAsync(bundleId) end)
		if ok and res and res.Items and lp.Character then
			local items = {}
			for _, item in ipairs(res.Items) do
				local lt = string.lower(item.AssetType or "")
				if lt == "swimanimation" then
					items["swimanimation"] = item; items["swimidleanimation"] = item
				elseif shortNames[lt] then
					items[lt] = item
				end
			end
			applyBundleItemsToCharacter(items)
		end
		if onDone then onDone() end
	end)
end

local function toggleBookmark(bundleId, bundleName)
	local sId = tostring(bundleId)
	local nowSaved
	if savedBookmarks[sId] then
		savedBookmarks[sId] = nil
		nowSaved = false
	else
		savedBookmarks[sId] = {Id = bundleId, Name = bundleName, Fav = false, Time = tick()}
		nowSaved = true
	end
	saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
	return nowSaved
end

local masterRenderGen = 0 
local function renderMasterTrack(itemPayload, assetTypeName)
	if activeMasterTrack then activeMasterTrack:Stop() activeMasterTrack = nil end
	masterRenderGen = masterRenderGen + 1
	local myGen = masterRenderGen
	local dummy, animator = buildViewportSkeleton(masterViewport)
	local lowerType = string.lower(assetTypeName or "")
	local displayType = shortNames[lowerType] or "Track"

	statusLabel.Text = truncate(activeBundleName, 22) .. " • " .. displayType .. " (loading...)"
	applyShimmer(statusLabel, C.textDim, Color3.new(1,1,1))

	local vpShimmer = masterViewport:FindFirstChild("LoadingShimmer")
	if not vpShimmer then
		vpShimmer = Instance.new("Frame", masterViewport)
		vpShimmer.Name = "LoadingShimmer"
		vpShimmer.Size, vpShimmer.BackgroundColor3, vpShimmer.BorderSizePixel = UDim2.new(1,0,1,0), C.overlay, 0
		corner(vpShimmer, s(6))
		applyShimmer(vpShimmer, C.overlay, C.surfaceHi)
	end

	task.spawn(function()
		local attempt, fetchedTracks, trackToPlay = 0, nil, nil
		while myGen == masterRenderGen do
			fetchedTracks = get(itemPayload.Id, nil, itemPayload.AssetType)
			trackToPlay = (#fetchedTracks>0) and getSpecificTrack(fetchedTracks, lowerType) or nil
			if trackToPlay then break end
			attempt = attempt + 1
			statusLabel.Text = truncate(activeBundleName, 22) .. " • " .. displayType .. " (reloading..." .. attempt .. ")"
			clearAssetCache(itemPayload.Id)
			task.wait(math.min(0.5 + attempt * 0.3, 3))
		end

		if myGen ~= masterRenderGen then return end

		if trackToPlay then
			removeShimmer(statusLabel)
			if masterViewport:FindFirstChild("LoadingShimmer") then masterViewport.LoadingShimmer:Destroy() end
		end

		activeMasterType = assetTypeName
		statusLabel.Text = truncate(activeBundleName, 22) .. " • " .. displayType
		local isIdle = (lowerType == "idleanimation")
		if isIdle and fetchedTracks and #fetchedTracks > 1 then
			local pointer = 1
			while myGen == masterRenderGen and dummy and dummy.Parent do
				if activeMasterTrack then activeMasterTrack:Stop() end
				local ok, playedTrack = tryPlayTrack(animator, fetchedTracks[pointer], false)
				while not ok and myGen == masterRenderGen do
					clearAssetCache(itemPayload.Id)
					fetchedTracks = get(itemPayload.Id, nil, itemPayload.AssetType)
					pointer = pointer > #fetchedTracks and 1 or pointer
					task.wait(0.4); ok, playedTrack = tryPlayTrack(animator, fetchedTracks[pointer], false)
				end
				if myGen ~= masterRenderGen then return end
				activeMasterTrack = playedTrack; activeMasterTrack.Stopped:Wait()
				pointer = (pointer % #fetchedTracks) + 1
			end
		elseif trackToPlay then
			local ok, playedTrack = tryPlayTrack(animator, trackToPlay, true)
			while not ok and myGen == masterRenderGen do
				clearAssetCache(itemPayload.Id)
				task.wait(0.4)
				local reloaded = get(itemPayload.Id, nil, itemPayload.AssetType)
				trackToPlay = (#reloaded>0) and getSpecificTrack(reloaded, lowerType) or nil
				if trackToPlay then ok, playedTrack = tryPlayTrack(animator, trackToPlay, true) end
			end
			if myGen ~= masterRenderGen then return end
			activeMasterTrack = playedTrack
		end
	end)
end

for _, lowerType in ipairs(buttonOrder) do
	local btn = Instance.new("TextButton", buttonContainer)
	btn.BackgroundColor3, btn.BackgroundTransparency, btn.TextColor3 = C.surfaceHi, 0.4, C.textMuted
	btn.Text, btn.Font, btn.TextSize, btn.ClipsDescendants = shortNames[lowerType], Enum.Font.GothamBold, s(10), true
	corner(btn, s(4))

	btn.MouseButton1Click:Connect(function()
		userSelectedAnimSlot = lowerType
		local payload = currentBundleItems[lowerType]
		if payload then
			wearSelectedBtn.Visible = true
			renderMasterTrack(payload, lowerType)
			for slot, b in pairs(animationButtons) do
				b.BackgroundColor3 = (slot == lowerType) and C.accent or (currentBundleItems[slot] and C.green or C.surfaceHi)
				b.TextColor3 = (slot == lowerType or currentBundleItems[slot]) and C.text or C.textMuted
			end
		end
	end)
	animationButtons[lowerType] = btn
end

local function refreshBookmarkBtn()
	if not activeBundleId then bookmarkBtn.Visible = false return end
	bookmarkBtn.Visible = true
	if savedBookmarks[tostring(activeBundleId)] then
		bookmarkBtn.Text, bookmarkBtn.TextColor3 = "Saved to Saved Tab", C.fav
	else
		bookmarkBtn.Text, bookmarkBtn.TextColor3 = "Save to Saved Tab", C.textMuted
	end
end

bookmarkBtn.MouseButton1Click:Connect(function()
	toggleBookmark(activeBundleId, activeBundleName)
	refreshBookmarkBtn()
	if currentTab == "Saved" then searchBtn.MouseButton1Click:Fire() end
end)

local function inspectBundleDetails(bundleId, bundleName)
	table.clear(currentBundleItems)
	wearSelectedBtn.Visible, wearAllBtn.Visible = false, false
	activeBundleName, activeBundleId = bundleName or "Unknown", bundleId
	statusLabel.Text = truncate(activeBundleName, 22) .. " • Loading..."
	applyShimmer(statusLabel, C.textDim, Color3.new(1,1,1))
	refreshBookmarkBtn()
	for _, btn in pairs(animationButtons) do btn.BackgroundColor3, btn.TextColor3 = C.surfaceHi, C.textMuted end

	task.spawn(function()
		local ok, res = pcall(function() return as:GetBundleDetailsAsync(bundleId) end)
		if not ok or not res or not res.Items then 
			statusLabel.Text = truncate(activeBundleName, 22) .. " • Error" 
			removeShimmer(statusLabel)
			return 
		end
		targetBundleItems = res.Items
		wearAllBtn.Visible = true

		for _, item in ipairs(res.Items) do
			local lt = string.lower(item.AssetType or "")
			if lt == "swimanimation" then
				currentBundleItems["swimanimation"] = item; currentBundleItems["swimidleanimation"] = item
			elseif shortNames[lt] then
				currentBundleItems[lt] = item
			end
		end

		local slotToPlay = currentBundleItems[userSelectedAnimSlot] and userSelectedAnimSlot or "idleanimation"

		for slot, b in pairs(animationButtons) do
			if currentBundleItems[slot] then b.BackgroundColor3, b.TextColor3 = C.green, C.text end
		end

		if currentBundleItems[slotToPlay] then
			animationButtons[slotToPlay].BackgroundColor3 = C.accent
			wearSelectedBtn.Visible = true
			renderMasterTrack(currentBundleItems[slotToPlay], slotToPlay)
		else
			statusLabel.Text = truncate(activeBundleName, 22) .. " • Missing Anim"
			removeShimmer(statusLabel)
		end
	end)
end

local function clearActiveGridContext()
	for _, t in ipairs(activeGridThreads) do task.cancel(t) end
	activeGridThreads = {}
	for _, c in ipairs(gridScroller:GetChildren()) do if c:IsA("ViewportFrame") then c:Destroy() end end
end

local function drawGridPage(dataList)
	clearActiveGridContext()
	loadingOverlay.Visible = false
	local start = (currentPageIndex - 1) * itemsPerPage + 1
	local ending = math.min(currentPageIndex * itemsPerPage, #dataList)

	local usableWidth = LEFT_W - s(8) - scrollW 
	local boxHeight = s(96)
	local actionRowH = s(16)
	local nameRowH = s(14)

	local idx = 1
	for i = start, ending do
		local bundle = dataList[i]
		if not bundle then break end

		local box = Instance.new("ViewportFrame", gridScroller)
		box.BackgroundColor3, box.BackgroundTransparency = C.panel, 0.3
		corner(box, s(8)); stroke(box, C.surfaceHi, 1)

		local boxWidth, posX, posY = 0, 0, 0

		if idx <= 2 then
			boxWidth = math.floor((usableWidth - s(24)) / 2)
			posX = s(8) + (idx - 1) * (boxWidth + s(8))
			posY = s(8)
		else
			boxWidth = math.floor((usableWidth - s(32)) / 3)
			local col = idx - 3
			posX = s(8) + col * (boxWidth + s(8))
			posY = s(8) + boxHeight + s(8)
		end

		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.new(0, posX + boxWidth/2, 0, posY + boxHeight/2)
		box.Size = UDim2.new(0, 0, 0, 0)

		ts:Create(box, TweenInfo.new(0.3 + (idx * 0.05), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, boxWidth, 0, boxHeight)}):Play()

		local skeleton = Instance.new("Frame", box)
		skeleton.Size, skeleton.BackgroundColor3, skeleton.BorderSizePixel, skeleton.ZIndex = UDim2.new(1,0,1,0), C.panel, 0, 2
		corner(skeleton, s(8))
		applyShimmer(skeleton, C.panel, C.surfaceHi)

		local label = Instance.new("TextLabel", box)
		label.Size, label.Position, label.BackgroundColor3, label.BackgroundTransparency = UDim2.new(1, 0, 0, nameRowH), UDim2.new(0, 0, 1, -(nameRowH + actionRowH)), C.overlay, 0.4
		label.Text, label.TextColor3, label.Font, label.TextSize, label.ZIndex, label.ClipsDescendants = truncate(bundle.Name, 9), C.text, Enum.Font.GothamBold, s(8), 3, true

		local hitBtn = Instance.new("TextButton", box)
		hitBtn.Size, hitBtn.Position, hitBtn.BackgroundTransparency, hitBtn.Text, hitBtn.ZIndex, hitBtn.ClipsDescendants = UDim2.new(1, 0, 1, -actionRowH), UDim2.new(0,0,0,0), 1, "", 4, true
		hitBtn.MouseEnter:Connect(function() box.BackgroundColor3 = C.surfaceHi end)
		hitBtn.MouseLeave:Connect(function() box.BackgroundColor3 = C.panel end)
		hitBtn.MouseButton1Click:Connect(function() inspectBundleDetails(bundle.Id, bundle.Name) end)

		if currentTab == "Saved" then
			local favBtn = Instance.new("TextButton", box)
			favBtn.Size, favBtn.Position, favBtn.BackgroundTransparency = UDim2.new(0, s(20), 0, s(20)), UDim2.new(1, -s(22), 0, s(2)), 1
			favBtn.Text, favBtn.Font, favBtn.TextSize, favBtn.ZIndex, favBtn.ClipsDescendants = (bundle.Fav and "★" or "☆"), Enum.Font.GothamBold, s(14), 5, true
			favBtn.TextColor3 = bundle.Fav and C.fav or C.textMuted

			favBtn.MouseButton1Click:Connect(function()
				local sId = tostring(bundle.Id)
				if savedBookmarks[sId] then
					savedBookmarks[sId].Fav = not savedBookmarks[sId].Fav
					saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)

					bundle.Fav = savedBookmarks[sId].Fav
					favBtn.Text = bundle.Fav and "★" or "☆"
					favBtn.TextColor3 = bundle.Fav and C.fav or C.textMuted
				end
			end)
		end

		local cardActions = Instance.new("Frame", box)
		cardActions.Size, cardActions.Position, cardActions.BackgroundTransparency = UDim2.new(1, 0, 0, actionRowH), UDim2.new(0, 0, 1, -actionRowH), 1
		cardActions.ZIndex = 6

		local alreadySaved = savedBookmarks[tostring(bundle.Id)] ~= nil

		local saveCardBtn = Instance.new("TextButton", cardActions)
		saveCardBtn.Size, saveCardBtn.Position = UDim2.new(0.5, -s(1), 1, 0), UDim2.new(0, 0, 0, 0)
		saveCardBtn.BackgroundColor3, saveCardBtn.BackgroundTransparency = C.surface, 0.15
		saveCardBtn.Text = alreadySaved and "✓ Saved" or "+ Save"
		saveCardBtn.TextColor3 = alreadySaved and C.fav or C.textDim
		saveCardBtn.Font, saveCardBtn.TextSize, saveCardBtn.ZIndex, saveCardBtn.ClipsDescendants = Enum.Font.GothamBold, s(7), 6, true
		corner(saveCardBtn, s(3))

		local wearCardBtn = Instance.new("TextButton", cardActions)
		wearCardBtn.Size, wearCardBtn.Position = UDim2.new(0.5, -s(1), 1, 0), UDim2.new(0.5, s(2), 0, 0)
		wearCardBtn.BackgroundColor3, wearCardBtn.BackgroundTransparency = C.surface, 0.15
		wearCardBtn.Text, wearCardBtn.TextColor3 = "▶ Wear", C.green
		wearCardBtn.Font, wearCardBtn.TextSize, wearCardBtn.ZIndex, wearCardBtn.ClipsDescendants = Enum.Font.GothamBold, s(7), 6, true
		corner(wearCardBtn, s(3))

		saveCardBtn.MouseButton1Click:Connect(function()
			local nowSaved = toggleBookmark(bundle.Id, bundle.Name)
			saveCardBtn.Text = nowSaved and "✓ Saved" or "+ Save"
			saveCardBtn.TextColor3 = nowSaved and C.fav or C.textDim
			if activeBundleId == bundle.Id then refreshBookmarkBtn() end
			if currentTab == "Saved" and not nowSaved then
				searchBtn.MouseButton1Click:Fire()
			end
		end)

		wearCardBtn.MouseButton1Click:Connect(function()
			wearCardBtn.Text = "…"
			wearBundleQuickly(bundle.Id, function()
				if wearCardBtn and wearCardBtn.Parent then wearCardBtn.Text = "▶ Wear" end
			end)
		end)

		local dummy, animator, conn = buildViewportSkeleton(box)
		local loopThread = task.spawn(function()
			local ok, details = pcall(function() return as:GetBundleDetailsAsync(bundle.Id) end)
			if not ok or not details or not details.Items then return end
			local usableTracks = {}
			for _, subItem in ipairs(details.Items) do if m[string.lower(subItem.AssetType or "")] then table.insert(usableTracks, subItem) end end
			if #usableTracks == 0 then return end
			local tIdx, cellTrack = 1, nil
			while box and box.Parent do
				local subItem = usableTracks[tIdx]
				local assets = get(subItem.Id, bundle.Id, subItem.AssetType)
				if #assets > 0 then
					if cellTrack then cellTrack:Stop() end
					cellTrack = animator:LoadAnimation(assets[1]); cellTrack.Looped = true
					if skeleton.Parent then skeleton:Destroy() end
					cellTrack:Play()
				end
				task.wait(3.0); tIdx = (tIdx % #usableTracks) + 1
			end
		end)
		table.insert(activeGridThreads, loopThread)
		box.Destroying:Connect(function() task.cancel(loopThread); conn:Disconnect() end)

		idx = idx + 1
	end

	gridScroller.CanvasSize = UDim2.new(0, 0, 0, s(220))
	pageLbl.Text = "Page " .. tostring(currentPageIndex)
	prevBtn.BackgroundTransparency, prevBtn.TextColor3 = (currentPageIndex > 1) and 0.4 or 0.65, (currentPageIndex > 1) and C.text or C.textMuted
end

local function executeSearch(query)
	currentPageIndex = 1
	loadingOverlay.Visible, pageLbl.Text = true, "Loading..."

	if currentTab == "Saved" then
		savedTabList = {}
		local q = string.lower(query or "")
		for _, v in pairs(savedBookmarks) do
			if q == "" or string.lower(v.Name):find(q) then table.insert(savedTabList, v) end
		end
		table.sort(savedTabList, function(a, b)
			if a.Fav == b.Fav then return (a.Time or 0) > (b.Time or 0) end
			return a.Fav and not b.Fav
		end)
		drawGridPage(savedTabList)
	else
		searchResults, catalogCursor = {}, nil
		local p = CatalogSearchParams.new()
		p.SearchKeyword, p.BundleTypes, p.IncludeOffSale, p.Limit = query or "", {Enum.BundleType.Animations}, true, 120
		pcall(function() p.CreatorType = Enum.CreatorType.User end)
		pcall(function() p.SalesTypeFilter = Enum.SalesTypeFilter.All end)
		pcall(function() p.SortType = Enum.CatalogSortType.RecentlyCreated end)
		task.spawn(function()
			local ok, pages = pcall(function() return aes:SearchCatalog(p) end)
			if ok and pages then
				catalogCursor = pages
				searchResults = pages:GetCurrentPage()
				drawGridPage(searchResults)
			else
				pageLbl.Text, loadingOverlay.Text = "Error", "Search Error"
			end
		end)
	end
end

tabDiscoverBtn.MouseButton1Click:Connect(function()
	if currentTab == "Discover" then return end
	currentTab = "Discover"
	tabDiscoverBtn.BackgroundColor3, tabDiscoverBtn.TextColor3 = C.surfaceHi, C.text
	tabSavedBtn.BackgroundColor3, tabSavedBtn.TextColor3 = C.surface, C.textMuted
	executeSearch(sb.Text)
end)

tabSavedBtn.MouseButton1Click:Connect(function()
	if currentTab == "Saved" then return end
	currentTab = "Saved"
	tabSavedBtn.BackgroundColor3, tabSavedBtn.TextColor3 = C.surfaceHi, C.text
	tabDiscoverBtn.BackgroundColor3, tabDiscoverBtn.TextColor3 = C.surface, C.textMuted
	executeSearch(sb.Text)
end)

nextBtn.MouseButton1Click:Connect(function()
	local activeList = (currentTab == "Saved") and savedTabList or searchResults
	if (currentPageIndex * itemsPerPage < #activeList) then
		currentPageIndex = currentPageIndex + 1
		loadingOverlay.Visible = true; drawGridPage(activeList)
	elseif currentTab == "Discover" and catalogCursor and not catalogCursor.IsFinished then
		loadingOverlay.Visible, pageLbl.Text = true, "Loading..."
		task.spawn(function()
			local ok = pcall(function() catalogCursor:AdvanceToNextPageAsync() end)
			if ok then
				local nc = catalogCursor:GetCurrentPage()
				for _, v in ipairs(nc) do table.insert(searchResults, v) end
				currentPageIndex = currentPageIndex + 1; drawGridPage(searchResults)
			end
		end)
	end
end)

prevBtn.MouseButton1Click:Connect(function()
	if currentPageIndex > 1 then
		currentPageIndex = currentPageIndex - 1
		loadingOverlay.Visible = true; drawGridPage((currentTab == "Saved") and savedTabList or searchResults)
	end
end)

wearSelectedBtn.MouseButton1Click:Connect(function()
	if not activeMasterType or not lp.Character then return end
	wearSelectedBtn.Text = "Loading..."
	applyShimmer(wearSelectedBtn, C.green, Color3.new(1,1,1))
	local payload = currentBundleItems[string.lower(activeMasterType)]
	if payload then
		local tracks = get(payload.Id, nil, payload.AssetType)
		local tPlay = getSpecificTrack(tracks, string.lower(activeMasterType))
		if tPlay then preloadAnimations({tPlay}); applyAnimationToCharacter(lp.Character, {tPlay}, activeMasterType) end
	end
	wearSelectedBtn.Text = "Wear Selected"
	removeShimmer(wearSelectedBtn)
end)

wearAllBtn.MouseButton1Click:Connect(function()
	if not lp.Character then return end
	wearAllBtn.Text = "Loading..."
	applyShimmer(wearAllBtn, C.purple, Color3.new(1,1,1))
	applyBundleItemsToCharacter(currentBundleItems)
	wearAllBtn.Text = "Wear All"
	removeShimmer(wearAllBtn)
end)

searchBtn.MouseButton1Click:Connect(function() executeSearch(sb.Text) end)
sb.FocusLost:Connect(function(enterPressed) if enterPressed then executeSearch(sb.Text) end end)

executeSearch("")
