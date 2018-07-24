-- pfDebug:
-- A little tool to monitor the memory usage, peaks and garbage collection.
-- I haven't put too much effort in this. Don't expect to see rocket science here.

--A little helper function to iterate over sorted pairs using "in pairs"
local spairs = function(t, reverse)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[table.getn(keys)+1] = k end

  local order
  if reverse then
    order = function(t,a,b) return t[b] < t[a] end
  else
    order = function(t,a,b) return t[b] > t[a] end
  end
  table.sort(keys, function(a,b) return order(t, a, b) end)

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

local round = function(input, places)
  if not places then places = 0 end
  if type(input) == "number" and type(places) == "number" then
    local pow = 1
    for i = 1, places do pow = pow * 10 end
    return floor(input * pow + 0.5) / pow
  end
end

-- Small function to provide compatiblity to pfUI backdrops
local CreateBackdrop = pfUI and pfUI.api and pfUI.api.CreateBackdrop or function(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
    edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
    insets = {left = -1, right = -1, top = -1, bottom = -1},
  })
  frame:SetBackdropColor(0,0,0,.75)
  frame:SetBackdropBorderColor(.1,.1,.1,1)
end

local SkinButton = pfUI and pfUI.api and pfUI.api.SkinButton or function(frame)
  for i,v in ipairs({frame:GetRegions()}) do
    if v.SetVertexColor then
      v:SetVertexColor(.2,.2,.2,1)
    end
  end
end

local pfDebug = CreateFrame("Button", "pfDebug", UIParent)
pfDebug.lastTime = GetTime()
pfDebug.lastMem = 999999999
pfDebug.curMem = 999999999

pfDebug.lastTimeMS = GetTime()
pfDebug.lastMemMS = 999999999
pfDebug.curMemMS = 999999999

pfDebug.gc = 0

pfDebug:SetPoint("CENTER", 0, 0)
pfDebug:SetHeight(85)
pfDebug:SetWidth(200)
CreateBackdrop(pfDebug)
pfDebug:RegisterEvent("PLAYER_ENTERING_WORLD")
pfDebug:SetScript("OnEvent", function() this:Show() end)
pfDebug:Hide()

pfDebug:SetMovable(true)
pfDebug:EnableMouse(true)
pfDebug:SetClampedToScreen(true)
pfDebug:SetScript("OnMouseDown",function()
  if arg1 == "RightButton" then
    pfDebug.analyzer:Show()
  else
    this:StartMoving()
  end
end)
pfDebug:SetScript("OnMouseUp",function() this:StopMovingOrSizing() end)
pfDebug:SetScript("OnClick",function()
  pfDebug.bar:SetValue(0)
end)

pfDebug.rate = pfDebug:CreateFontString("pfDebugMemRate", "LOW", "GameFontWhite")
pfDebug.rate:SetPoint("TOPLEFT", 3, -3)

pfDebug.curmax = pfDebug:CreateFontString("pfDebugMemCurMax", "LOW", "GameFontWhite")
pfDebug.curmax:SetPoint("TOPLEFT", 3, -23)
pfDebug.last = pfDebug:CreateFontString("pfDebugMemLast", "LOW", "GameFontWhite")
pfDebug.last:SetPoint("TOPLEFT", 3, -43)

pfDebug.bar = CreateFrame("StatusBar", nil, pfDebug)
pfDebug.bar:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
pfDebug.bar:SetStatusBarColor(1,.3,.3,1)
pfDebug.bar:SetPoint("BOTTOMLEFT", pfDebug, "BOTTOMLEFT", 1, 1)
pfDebug.bar:SetPoint("BOTTOMRIGHT", pfDebug, "BOTTOMRIGHT", -1, 1)
pfDebug.bar:SetHeight(20)
pfDebug.bar:SetMinMaxValues(0, 0)
pfDebug.bar:SetValue(20)

pfDebug.barcap = pfDebug.bar:CreateFontString("pfDebugMemBarCap", "OVERLAY", "GameFontWhite")
pfDebug.barcap:SetPoint("LEFT", 2, 0)
pfDebug.barcap:SetTextColor(1,1,1)

pfDebug:SetScript("OnUpdate", function()
  if this.lastTimeMS + .1 < GetTime() and GetTime() > 2 then
    this.lastTimeMS = GetTime()
    this.lastMemMS = this.curMemMS
    this.curMemMS, this.gc = gcinfo()

    if this.lastMemMS > this.curMemMS then
      this.lastCleanUp = GetTime()
      this.lastCleanUpTime = date("%H:%M:%S")
    end

    local barval, newval = this.bar:GetValue(), ( this.curMemMS - this.lastMemMS )
    if newval > barval and newval > 0 then
      this.bar:SetMinMaxValues(0, newval)
      this.bar:SetValue(newval)
      this.barcap:SetText("|cff33ffccLast Peak (ms):|r " .. newval .. "|cffaaaaaa KB")
      pfDebug.bar:SetStatusBarColor(1,.3,.3, newval/10)
    else
      this.bar:SetValue(barval - .5)
      pfDebug.bar:SetStatusBarColor(1,.3,.3, barval/10)
    end
  end

  if this.lastTime + 1 < GetTime() then
    if this.lastCleanUp and this.lastCleanUpTime then
      pfDebug:SetWidth(pfDebug.last:GetStringWidth() + 10)
      pfDebug.last:SetText("|cff33ffccLast Cleanup:|cffffffff " .. this.lastCleanUpTime .. " |cffaaaaaa(" .. SecondsToTime(GetTime()-this.lastCleanUp) .. " ago)")
    end

    this.lastTime = GetTime()
    this.lastMem = this.curMem
    this.curMem, this.gc = gcinfo()

    if this.lastMem > this.curMem then
      pfDebug.last:SetText("|cff33ffccLast Cleanup:|cffffffff " .. date("%H:%M"))
    end

    this.curmax:SetText("|cff33ffccCurrent / Max:|cffffffff " .. floor(this.curMem/1024) .. " / " .. floor(this.gc/1024) .. "|cffaaaaaa MB")
    this.rate:SetText("|cff33ffccCurrent Rate:|cffffffff " .. this.curMem - this.lastMem .. "|cffaaaaaa kB/s")
  end
end)

local frames = {}
local function ScanFrames(parent)
  local scanqueue

  if parent.GetChildren and type(parent.GetChildren) == "function" and parent:GetChildren() then
    scanqueue = { parent, { parent:GetChildren() } }
  else
    scanqueue = { parent }
  end

  for _, queue in pairs(scanqueue) do
    for name, frame in pairs(queue) do
      if frame and type(frame) == "table" then
        local name = (frame.GetName and type(frame.GetName) == "function" and frame:GetName()) and frame:GetName() or tostring(frame)

        if name and not frames[name] then
          if frame.GetFrameType and type(frame.GetFrameType) == "function" and frame:GetFrameType() then
            frames[name] = frame
          end

          ScanFrames(frame)
        end
      end
    end
  end
end

function pfDebug:LukeFramewalker(reset)
  -- Walk through all frames, the global env tree, their parents
  -- and their subtrees to detect frames and adding them to the frames list.
  if reset then
    frames = {}
  end

  ScanFrames(getfenv())

  local count = 0
  for name, frame in pairs(frames) do
    count = count + 1
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffDebug: Luke Framewalker found |cff33ffcc" .. count .. "|r Active Frames")
end

local memlistEvent = {}
local runlistEvent = {}

local memlistUpdate = {}
local runlistUpdate = {}

function pfDebug:AddDebugHooks()
  local countUpdate = 0
  local countEvent = 0

  for name, frame in pairs(frames) do
    if frame.GetScript and not frame.pfDEBUGHooked then
      local name = name
      local OnEvent = frame:GetScript("OnEvent")
      if OnEvent then
        frame:SetScript("OnEvent", function()
          -- measure execution time
          local mem = gcinfo()
          local time = GetTime()
          OnEvent()
          local runtime = GetTime() - time
          local runmem = gcinfo() - mem

          -- add to timing scoreboard
          if not runlistEvent[name] or runlistEvent[name] < runtime then
            runlistEvent[name] = runtime
          end

          -- add to memory scoreboard
          if not memlistEvent[name] or memlistEvent[name] < runmem then
            memlistEvent[name] = runmem
          end
        end)
        countEvent = countEvent + 1
      end

      local OnUpdate = frame:GetScript("OnUpdate")
      if OnUpdate then
        frame:SetScript("OnUpdate", function()
          -- measure execution time
          local mem = gcinfo()
          local time = GetTime()
          OnUpdate()
          local runtime = GetTime() - time
          local runmem = gcinfo() - mem

          -- add to timing scoreboard
          if not runlistUpdate[name] or runlistUpdate[name] < runtime then
            runlistUpdate[name] = runtime
          end

          -- add to memory scoreboard
          if not memlistUpdate[name] or memlistUpdate[name] < runmem then
            memlistUpdate[name] = runmem
          end
        end)
        countUpdate = countUpdate + 1
      end

      frame.pfDEBUGHooked = true
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffDebug: Added |cff33ffcc" .. countUpdate .. "|r '|cffffcc00OnUpdate|r' Hooks")
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffDebug: Added |cff33ffcc" .. countEvent .. "|r '|cffffcc00OnEvent|r' Hooks")
end

local mainwidth = 800
local pane1 = -mainwidth/2/4*3
local pane2 = -mainwidth/2/4
local pane3 = mainwidth/2/4
local pane4 = mainwidth/2/4*3
local function CreateBar(parent)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetWidth(mainwidth/4 - 10)
  b:SetHeight(22)
  b:SetMinMaxValues(0,100)
  b:SetValue(0)
  b:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
  b:SetStatusBarColor(.2,.2,.2,1)

  b.left = b:CreateFontString(nil, "HIGH", "GameFontWhite")
  b.left:SetPoint("LEFT", 0, 0)
  b.left:SetJustifyH("LEFT")

  b.right = b:CreateFontString(nil, "HIGH", "GameFontWhite")
  b.right:SetPoint("RIGHT", 0, 0)
  b.right:SetJustifyH("RIGHT")

  CreateBackdrop(b)
  return b
end

pfDebug.analyzer = CreateFrame("Frame", "pfDebugAnalyzer", UIParent)
pfDebug.analyzer:SetPoint("CENTER", 0, 0)
pfDebug.analyzer:SetHeight(400)
pfDebug.analyzer:SetWidth(mainwidth)
pfDebug.analyzer:SetMovable(true)
pfDebug.analyzer:EnableMouse(true)
pfDebug.analyzer:SetClampedToScreen(true)
pfDebug.analyzer:SetScript("OnMouseDown",function() this:StartMoving() end)
pfDebug.analyzer:SetScript("OnMouseUp",function() this:StopMovingOrSizing() end)
pfDebug.analyzer:Hide()
pfDebug.analyzer:SetFrameStrata("FULLSCREEN_DIALOG")
CreateBackdrop(pfDebug.analyzer)

pfDebug.analyzer.toolbar = CreateFrame("Frame", "pfDebugAnalyzerToolbar", pfDebug.analyzer)
pfDebug.analyzer.toolbar:SetWidth(mainwidth - 10)
pfDebug.analyzer.toolbar:SetHeight(30)
pfDebug.analyzer.toolbar:SetPoint("BOTTOM", 0, 5)
CreateBackdrop(pfDebug.analyzer.toolbar)

local buttonFramewalker = CreateFrame("Button", "pfDebugAnalyzerFramewalker", pfDebug.analyzer.toolbar, "UIPanelButtonTemplate")
buttonFramewalker:SetHeight(20)
buttonFramewalker:SetWidth(mainwidth/4-50)
buttonFramewalker:SetPoint("BOTTOM", pane1, 5)
buttonFramewalker:SetText("(Re)Start Framewalker")
buttonFramewalker:SetScript("OnClick", function()
  pfDebug:LukeFramewalker(true)
  pfDebugAnalyzerAddHooks:Enable()
end)
SkinButton(buttonFramewalker)

local buttonAddHooks = CreateFrame("Button", "pfDebugAnalyzerAddHooks", pfDebug.analyzer.toolbar, "UIPanelButtonTemplate")
buttonAddHooks:SetHeight(20)
buttonAddHooks:SetWidth(mainwidth/4-50)
buttonAddHooks:SetPoint("BOTTOM", pane2, 5)
buttonAddHooks:SetText("(Re)Add Frame Hooks")
buttonAddHooks:Disable()
buttonAddHooks:SetScript("OnClick", function()
  pfDebug:AddDebugHooks()
  pfDebugAnalyzerRefresh:Enable()
  pfDebugAnalyzerAutoUpdate:Enable()
end)
SkinButton(buttonAddHooks)

local buttonRefresh = CreateFrame("Button", "pfDebugAnalyzerRefresh", pfDebug.analyzer.toolbar, "UIPanelButtonTemplate")
buttonRefresh:SetHeight(20)
buttonRefresh:SetWidth(mainwidth/4-50)
buttonRefresh:SetPoint("BOTTOM", pane3, 5)
buttonRefresh:SetText("Refresh Statistics")
buttonRefresh:Disable()
buttonRefresh:SetScript("OnClick", function()
  pfDebug.analyzer:UpdateUI()
end)
SkinButton(buttonRefresh)

local buttonAutoUpdate = CreateFrame("Button", "pfDebugAnalyzerAutoUpdate", pfDebug.analyzer.toolbar, "UIPanelButtonTemplate")
buttonAutoUpdate:SetHeight(20)
buttonAutoUpdate:SetWidth(mainwidth/4-50)
buttonAutoUpdate:SetPoint("BOTTOM", pane4, 5)
buttonAutoUpdate:SetText("Auto-Update (|cffffaaaaOFF|r)")
buttonAutoUpdate:Disable()
buttonAutoUpdate:SetScript("OnUpdate", function()
  if not this.active then return end
  if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + 1 end
  pfDebug.analyzer:UpdateUI()
end)
buttonAutoUpdate:SetScript("OnClick", function()
  if this.active then
    this.active = false
    buttonAutoUpdate:SetText("Auto-Update (|cffffaaaaOFF|r)")
  else
    this.active = true
    buttonAutoUpdate:SetText("Auto-Update (|cffaaffaaON|r)")
  end
end)
SkinButton(buttonAutoUpdate)

local buttonClose = CreateFrame("Button", "pfDebugAnalyzerClose", pfDebug.analyzer, "UIPanelCloseButton")
buttonClose:SetWidth(20)
buttonClose:SetHeight(20)
buttonClose:SetPoint("TOPRIGHT", 0,0)
buttonClose:SetScript("OnClick", function()
  pfDebug.analyzer:Hide()
end)

local titleEvents = pfDebug.analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
titleEvents:SetTextColor(.3, 1, .8, 1)
titleEvents:SetFont(STANDARD_TEXT_FONT, 18)
titleEvents:SetPoint("TOP", -mainwidth/4, -5)
titleEvents:SetText("OnEvent")
local titleEventsMem = pfDebug.analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
titleEventsMem:SetFont(STANDARD_TEXT_FONT, 14)
titleEventsMem:SetText("Memory Usage")
titleEventsMem:SetPoint("TOP", pane1, -30)
local titleEventsTime = pfDebug.analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
titleEventsTime:SetFont(STANDARD_TEXT_FONT, 14)
titleEventsTime:SetText("Execution Time")
titleEventsTime:SetPoint("TOP", pane2, -30)

local titleUpdates = pfDebug.analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
titleUpdates:SetTextColor(.3, 1, .8, 1)
titleUpdates:SetFont(STANDARD_TEXT_FONT, 18)
titleUpdates:SetPoint("TOP", mainwidth/4, -5)
titleUpdates:SetText("OnUpdate")
local titleUpdatesMem = pfDebug.analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
titleUpdatesMem:SetFont(STANDARD_TEXT_FONT, 14)
titleUpdatesMem:SetText("Memory Usage")
titleUpdatesMem:SetPoint("TOP", pane3 , -30)
local titleUpdatesTime = pfDebug.analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
titleUpdatesTime:SetFont(STANDARD_TEXT_FONT, 14)
titleUpdatesTime:SetText("Execution Time")
titleUpdatesTime:SetPoint("TOP", pane4, -30)

pfDebug.analyzer.barsEventMem = {}
pfDebug.analyzer.barsEventTime = {}
pfDebug.analyzer.barsUpdateMem = {}
pfDebug.analyzer.barsUpdateTime = {}
for i=1,12 do
  pfDebug.analyzer.barsEventMem[i] = CreateBar(pfDebug.analyzer)
  pfDebug.analyzer.barsEventMem[i]:SetPoint("TOP", pane1, -i*26 -26)

  pfDebug.analyzer.barsEventTime[i] = CreateBar(pfDebug.analyzer)
  pfDebug.analyzer.barsEventTime[i]:SetPoint("TOP", pane2, -i*26 -26)

  pfDebug.analyzer.barsUpdateMem[i] = CreateBar(pfDebug.analyzer)
  pfDebug.analyzer.barsUpdateMem[i]:SetPoint("TOP", pane3, -i*26 -26)

  pfDebug.analyzer.barsUpdateTime[i] = CreateBar(pfDebug.analyzer)
  pfDebug.analyzer.barsUpdateTime[i]:SetPoint("TOP", pane4, -i*26 -26)
end

function pfDebug.analyzer:UpdateUI()
  -- event memory
  local i = 1
  local maxval = 0
  for frame, val in spairs(memlistEvent, true) do
    if i > 12 then break end
    if i == 1 then maxval = val end
    pfDebug.analyzer.barsEventMem[i]:SetMinMaxValues(0, maxval)
    pfDebug.analyzer.barsEventMem[i]:SetValue(val)
    pfDebug.analyzer.barsEventMem[i].left:SetText(frame)
    pfDebug.analyzer.barsEventMem[i].right:SetText(val .. "|cffaaaaaa byte")
    i = i + 1
  end

  -- event runtime
  local i = 1
  local maxval = 0
  for frame, val in spairs(runlistEvent, true) do
    if i > 12 then break end
    if i == 1 then maxval = val end
    pfDebug.analyzer.barsEventTime[i]:SetMinMaxValues(0, maxval)
    pfDebug.analyzer.barsEventTime[i]:SetValue(val)
    pfDebug.analyzer.barsEventTime[i].left:SetText(frame)
    pfDebug.analyzer.barsEventTime[i].right:SetText(round(val * 100, 5) .. "|cffaaaaaa ms")
    i = i + 1
  end


  -- update memory
  local i = 1
  local maxval = 0
  for frame, val in spairs(memlistUpdate, true) do
    if i > 12 then break end
    if i == 1 then maxval = val end
    pfDebug.analyzer.barsUpdateMem[i]:SetMinMaxValues(0, maxval)
    pfDebug.analyzer.barsUpdateMem[i]:SetValue(val)
    pfDebug.analyzer.barsUpdateMem[i].left:SetText(frame)
    pfDebug.analyzer.barsUpdateMem[i].right:SetText(val .. "|cffaaaaaa byte")
    i = i + 1
  end

  -- update runtime
  local i = 1
  local maxval = 0
  for frame, val in spairs(runlistUpdate, true) do
    if i > 12 then break end
    if i == 1 then maxval = val end
    pfDebug.analyzer.barsUpdateTime[i]:SetMinMaxValues(0, maxval)
    pfDebug.analyzer.barsUpdateTime[i]:SetValue(val)
    pfDebug.analyzer.barsUpdateTime[i].left:SetText(frame)
    pfDebug.analyzer.barsUpdateTime[i].right:SetText(round(val * 100, 5) .. "|cffaaaaaa ms")
    i = i + 1
  end
end
