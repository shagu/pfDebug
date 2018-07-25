local scanned = {}
local frames = {}
local data = {}

-- search as many frames as possible that are children or subtree elements of
-- the given parent frame. all found frames are saved in the `frames`-table
local function ScanFrames(parent)
  -- find as many frames as possible by analyzer.scanning through the parent's childs.
  local scanqueue

  if parent.GetChildren and type(parent.GetChildren) == "function" and parent:GetChildren() then
    scanqueue = { parent, { parent:GetChildren() } }
  else
    scanqueue = { parent }
  end

  for _, queue in pairs(scanqueue) do
    for _, frame in pairs(queue) do
      if frame and type(frame) == "table" and frame ~= parent then
        local name = tostring(frame)
        if name and not scanned[name] then
          scanned[name] = true

          if frame.GetFrameType and type(frame.GetFrameType) == "function" and frame:GetFrameType() then
            frames[name] = frame
          end

          ScanFrames(frame)
        end
      end
    end
  end
end

-- add hooks to given functions to measure execution count, execution time
-- and memory footprint. values are saved in the `data`-table
local function MeasureFunction(func, name)
  -- measure time and memory before and after
  local mem = gcinfo()
  local time = GetTime()
  func()
  local runtime = GetTime() - time
  local runmem = gcinfo() - mem

  -- add to timing scoreboard
  if not data[name] then
    data[name] = { 1, runtime, runmem }
  else
    data[name][1] = data[name][1] + 1
    data[name][2] = data[name][2] + runtime
    data[name][3] = data[name][3] + runmem
  end
end

--A little helper function to iterate over sorted pairs using "in pairs"
local function spairs(t, index, reverse)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[table.getn(keys)+1] = k end

  local order
  if reverse then
    order = function(t,a,b) return t[b][index] < t[a][index] end
  else
    order = function(t,a,b) return t[b][index] > t[a][index] end
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

-- round values
local function round(input, places)
  if not places then places = 0 end
  if type(input) == "number" and type(places) == "number" then
    local pow = 1
    for i = 1, places do pow = pow * 10 end
    return floor(input * pow + 0.5) / pow
  end
end

-- [[ GUI Code ]]
local mainwidth = 500
local analyzer = CreateFrame("Frame", "pfDebugAnalyzer", UIParent)
pfDebug.CreateBackdrop(analyzer)
analyzer:SetPoint("CENTER", 0, 0)
analyzer:SetHeight(380)
analyzer:SetWidth(mainwidth)
analyzer:SetMovable(true)
analyzer:EnableMouse(true)
analyzer:SetClampedToScreen(true)
analyzer:SetScript("OnMouseDown",function() this:StartMoving() end)
analyzer:SetScript("OnMouseUp",function() this:StopMovingOrSizing() end)
analyzer:Hide()
analyzer:SetFrameStrata("FULLSCREEN_DIALOG")
analyzer:SetScript("OnUpdate", function()
  if not this.active then return end
  if ( this.tick or .5) > GetTime() then return else this.tick = GetTime() + .5 end

  -- event memory
  local i = 1
  local maxval = 0
  local sortby = this.sortby or 3 -- 1 = count, 2 = time, 3 = mem

  for frame, entry in spairs(data, sortby, true) do
    if i > 12 then break end
    if i == 1 then maxval = entry[sortby] end

    local count = entry[1]
    local time = round(entry[2]*100, 5) .. " ms"
    local mem = round(entry[3], 5) .. " kB"

    analyzer.bars[i].data = entry
    analyzer.bars[i].name = frame

    analyzer.bars[i]:SetMinMaxValues(0, maxval)
    analyzer.bars[i]:SetValue(entry[sortby])

    local text = gsub(frame, ":", "|cffaaaaaa:|r")
    text =  gsub(text, "OnEvent%(%)", "|cffaaaa00OnEvent|cffaaaaaa%(%)")
    text =  gsub(text, "OnUpdate%(%)", "|cff00aaaaOnUpdate|cffaaaaaa%(%)")
    analyzer.bars[i].left:SetText(text)

    if sortby == 1 then
      analyzer.bars[i].right:SetText(count)
    elseif sortby == 2 then
      analyzer.bars[i].right:SetText(time)
    elseif sortby == 3 then
      analyzer.bars[i].right:SetText(mem)
    end

    local perc = entry[sortby] / maxval
    local r1, g1, b1, r2, g2, b2
    if perc <= 0.5 then
      perc = perc * 2
      r1, g1, b1 = 0, 1, 0
      r2, g2, b2 = 1, 1, 0
    else
      perc = perc * 2 - 1
      r1, g1, b1 = 1, 1, 0
      r2, g2, b2 = 1, 0, 0
    end
    analyzer.bars[i]:SetStatusBarColor(r1 + (r2 - r1)*perc,g1 + (g2 - g1)*perc,b1 + (b2 - b1)*perc, .1)
    i = i + 1
  end
end)

analyzer.title = analyzer:CreateFontString(nil, "LOW", "GameFontWhite")
analyzer.title:SetFont(STANDARD_TEXT_FONT, 14)
analyzer.title:SetPoint("TOP", 0, -10)
analyzer.title:SetText("|cff33ffccpf|rDebug: |cffffcc00Analyzer")

analyzer.close = CreateFrame("Button", "pfDebugAnalyzerClose", analyzer, "UIPanelCloseButton")
analyzer.close:SetWidth(20)
analyzer.close:SetHeight(20)
analyzer.close:SetPoint("TOPRIGHT", 0,0)
analyzer.close:SetScript("OnClick", function()
  analyzer:Hide()
end)

analyzer.toolbar = CreateFrame("Frame", "pfDebugAnalyzerToolbar", analyzer)
pfDebug.CreateBackdrop(analyzer.toolbar)
analyzer.toolbar:SetWidth(mainwidth - 10)
analyzer.toolbar:SetHeight(25)
analyzer.toolbar:SetPoint("TOP", 0, -35)

analyzer.scan = CreateFrame("Button", "pfDebugAnalyzerAddHooks", analyzer.toolbar, "UIPanelButtonTemplate")
pfDebug.SkinButton(analyzer.scan)
analyzer.scan:SetHeight(20)
analyzer.scan:SetWidth(100)
analyzer.scan:SetPoint("LEFT", 3, 0)
analyzer.scan:SetText("Scan")
analyzer.scan:SetScript("OnClick", function()
  -- reset known frames
  frames = {}

  -- scan through all frames on _G
  ScanFrames(getfenv())

  -- calculate the findings
  local framecount = 0
  for _ in pairs(frames) do framecount = framecount + 1 end

  -- add hooks to functions
  local functioncount = 0
  for _, frame in pairs(frames) do
    if frame.GetScript and not frame.pfDEBUGHooked then
      frame.pfDEBUGHooked = true

      local name = (frame.GetName and type(frame.GetName) == "function" and frame:GetName()) and frame:GetName() or tostring(frame)

      local OnEvent = frame:GetScript("OnEvent")
      if OnEvent then
        functioncount = functioncount + 1
        frame:SetScript("OnEvent", function()
          MeasureFunction(OnEvent, name .. ":OnEvent()")
        end)
      end

      local OnUpdate = frame:GetScript("OnUpdate")
      if OnUpdate then
        functioncount = functioncount + 1
        frame:SetScript("OnUpdate", function()
          MeasureFunction(OnUpdate, name .. ":OnUpdate()")
        end)
      end
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffDebug: Found |cff33ffcc" .. framecount .. "|r frames and hooked |cff33ffcc" .. functioncount .. "|r new functions.")
  analyzer.autoupate:Enable()
  analyzer.autoupate:Click()
end)

analyzer.autoupate = CreateFrame("Button", "pfDebugAnalyzerAutoUpdate", analyzer.toolbar, "UIPanelButtonTemplate")
pfDebug.SkinButton(analyzer.autoupate)
analyzer.autoupate:SetHeight(20)
analyzer.autoupate:SetWidth(100)
analyzer.autoupate:SetPoint("LEFT", 106, 0)
analyzer.autoupate:SetText("Auto-Update (|cffffaaaaOFF|r)")
analyzer.autoupate:Disable()
analyzer.autoupate:SetScript("OnClick", function()
  if analyzer.active then
    analyzer.active = false
    analyzer.autoupate:SetText("Auto-Update (|cffffaaaaOFF|r)")
  else
    analyzer.active = true
    analyzer.autoupate:SetText("Auto-Update (|cffaaffaaON|r)")
  end
end)

analyzer.count = CreateFrame("Button", "pfDebugAnalyzerSortTime", analyzer.toolbar, "UIPanelButtonTemplate")
pfDebug.SkinButton(analyzer.count)
analyzer.count:SetHeight(20)
analyzer.count:SetWidth(50)
analyzer.count:SetPoint("RIGHT", -3, 0)
analyzer.count:SetText("Count")
analyzer.count:SetScript("OnClick", function() analyzer.sortby = 1 end)

analyzer.time = CreateFrame("Button", "pfDebugAnalyzerSortTime", analyzer.toolbar, "UIPanelButtonTemplate")
pfDebug.SkinButton(analyzer.time)
analyzer.time:SetHeight(20)
analyzer.time:SetWidth(50)
analyzer.time:SetPoint("RIGHT", -56, 0)
analyzer.time:SetText("Time")
analyzer.time:SetScript("OnClick", function() analyzer.sortby = 2 end)

analyzer.memory = CreateFrame("Button", "pfDebugAnalyzerSortTime", analyzer.toolbar, "UIPanelButtonTemplate")
pfDebug.SkinButton(analyzer.memory)
analyzer.memory:SetHeight(20)
analyzer.memory:SetWidth(50)
analyzer.memory:SetPoint("RIGHT", -109, 0)
analyzer.memory:SetText("Memory")
analyzer.memory:SetScript("OnClick", function() analyzer.sortby = 3 end)

analyzer.bars = {}
for i=1,12 do
  analyzer.bars[i] = CreateFrame("StatusBar", nil, analyzer)
  analyzer.bars[i]:SetPoint("TOP", 0, -i*26 -40)
  analyzer.bars[i]:SetWidth(mainwidth - 10)
  analyzer.bars[i]:SetHeight(22)
  analyzer.bars[i]:SetMinMaxValues(0,100)
  analyzer.bars[i]:SetValue(0)
  analyzer.bars[i]:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")

  analyzer.bars[i].left = analyzer.bars[i]:CreateFontString(nil, "HIGH", "GameFontWhite")
  analyzer.bars[i].left:SetPoint("LEFT", 0, 0)
  analyzer.bars[i].left:SetJustifyH("LEFT")

  analyzer.bars[i].right = analyzer.bars[i]:CreateFontString(nil, "HIGH", "GameFontWhite")
  analyzer.bars[i].right:SetPoint("RIGHT", 0, 0)
  analyzer.bars[i].right:SetJustifyH("RIGHT")

  pfDebug.CreateBackdrop(analyzer.bars[i])
end

-- add analyzer GUI to pfDebug table
pfDebug.analyzer = analyzer
