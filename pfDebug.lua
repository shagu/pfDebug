local pfDebug = CreateFrame("Frame", "pfDebug", UIParent)
pfDebug.lastTime = GetTime()
pfDebug.lastMem = 999999999
pfDebug.curMem = 999999999

pfDebug.lastTimeMS = GetTime()
pfDebug.lastMemMS = 999999999
pfDebug.curMemMS = 999999999

pfDebug.gc = 0

pfDebug:SetPoint("CENTER", 0, 0)
pfDebug:SetHeight(100)
pfDebug:SetWidth(200)
pfDebug:SetBackdrop({
  bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
})

pfDebug:SetBackdropColor(.1,.1,.1,1)
pfDebug:SetBackdropBorderColor(.2,.2,.2,1)

pfDebug:SetMovable(true)
pfDebug:EnableMouse(true)
pfDebug:SetScript("OnMouseDown",function() this:StartMoving() end)
pfDebug:SetScript("OnMouseUp",function() this:StopMovingOrSizing() end)

pfDebug.rate = pfDebug:CreateFontString("pfDebugMemRate", "LOW", "NumberFontNormalSmall")
pfDebug.rate:SetPoint("TOPLEFT", 5, -5)

pfDebug.curmax = pfDebug:CreateFontString("pfDebugMemCurMax", "LOW", "NumberFontNormalSmall")
pfDebug.curmax:SetPoint("TOPLEFT", 5, -25)
pfDebug.last = pfDebug:CreateFontString("pfDebugMemLast", "LOW", "NumberFontNormalSmall")
pfDebug.last:SetPoint("TOPLEFT", 5, -50)

pfDebug.bar = CreateFrame("StatusBar", nil, pfDebug)
pfDebug.bar:SetHeight(20)
pfDebug.bar:SetWidth(200)
pfDebug.bar:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
pfDebug.bar:SetStatusBarColor(1,.3,.3,1)
pfDebug.bar:SetPoint("BOTTOM", 0, 0)
pfDebug.bar:SetMinMaxValues(0, 0)
pfDebug.bar:SetValue(20)
pfDebug.barcap = pfDebug.bar:CreateFontString("pfDebugMemBarCap", "OVERLAY", "NumberFontNormalSmall")
pfDebug.barcap:SetPoint("LEFT", 5, 0)
pfDebug.barcap:SetTextColor(1,1,1)

pfDebug:RegisterEvent("PLAYER_ENTERING_WORLD")
pfDebug:SetScript("OnEvent", function() this:Show() end)
pfDebug:Hide()

pfDebug:SetScript("OnUpdate", function()
  if this.lastTimeMS + .1 < GetTime() and GetTime() > 2 then
    this.lastTimeMS = GetTime()
    this.lastMemMS = this.curMemMS
    this.curMemMS, this.gc = gcinfo()

    if this.lastMemMS > this.curMemMS then
      pfDebug.last:SetText("|cff33ffccLast Cleanup:|cffffffff " .. date("%H:%M"))
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
