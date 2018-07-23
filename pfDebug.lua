-- pfDebug:
-- A little tool to monitor the memory usage, peaks and garbage collection.
-- I haven't put too much effort in this. Don't expect to see rocket science here.
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
pfDebug:SetBackdrop({
  bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
})

pfDebug:SetBackdropColor(0,0,0,.75)
pfDebug:SetBackdropBorderColor(.1,.1,.1,1)
pfDebug:RegisterEvent("PLAYER_ENTERING_WORLD")
pfDebug:SetScript("OnEvent", function() this:Show() end)
pfDebug:Hide()

pfDebug:SetMovable(true)
pfDebug:EnableMouse(true)
pfDebug:SetClampedToScreen(true)
pfDebug:SetScript("OnMouseDown",function() this:StartMoving() end)
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

local matches = {}
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

        if name and not matches[name] then
          if frame.GetFrameType and type(frame.GetFrameType) == "function" and frame:GetFrameType() then
            matches[name] = frame
          end

          ScanFrames(frame)
        end
      end
    end
  end
end

function pfDebug:Start()
  matches = {}
  ScanFrames(getfenv())

  local count = 0
  for name, frame in pairs(matches) do
    count = count + 1
  end
  message(count .. " Objects Found")
end
