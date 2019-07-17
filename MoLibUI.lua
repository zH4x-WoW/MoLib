--[[
  MoLib (GUI part) -- (c) 2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
-- our name, our empty default (and unused) anonymous ns
local addonName, _ns = ...

local ML = _G[addonName]

-- use 2 or 4 for sizes so there are 1/2, 1/4 points
function ML:round(x, precision)
  precision = precision or 1
  local i, _f = math.modf(math.floor(x / precision + 0.5)) * precision
  return i
end

function ML:roundUp(x, precision) -- for sizes, don't shrink but also... 0.9 because floating pt math
  precision = precision or 1
  local i, _f = math.modf(math.ceil(x / precision - 0.1)) * precision
  return i
end

function ML:scale(x, s, precision)
  return ML:round(x * s, precision) / s
end

function ML:scaleUp(x, s, precision)
  return ML:roundUp(x * s, precision) / s
end

-- Makes sure the frame has the right pixel alignment and same padding with respect to
-- bottom right corner that it has on top left with its children objects.
-- returns a new scale to potentially be used if not recalculating the bottom right margins
function ML:SnapFrame(f)
  local s = f:GetEffectiveScale()
  local point, relTo, relativePoint, xOfs, yOfs = f:GetPoint()
  local x, y, w, h = f:GetRect()
  self:Debug(6, "Before: % % % %    % %   % %", x, y, w, h, point, relativePoint, xOfs, yOfs)
  local nw = self:scaleUp(w, s, 2)
  local nh = self:scaleUp(h, s, 2)
  self:Debug(6, "new WxH: % %", nw, nh)
  f:SetWidth(nw)
  f:SetHeight(nh)
  x, y, w, h = f:GetRect()
  self:Debug(6, "Mid: % % % % : %", x, y, w, h, f:GetScale())
  f:ClearAllPoints()
  local nx = self:scale(x, s)
  local ny = self:scale(y, s)
  local ns = nh / h
  local deltaX = nx - x
  local deltaY = ny - y
  f:SetPoint(point, relTo, relativePoint, xOfs + deltaX, yOfs + deltaY)
  self:Debug(5, "ns % : % % % % ( % % ): %", ns, x, y, nw, nh, deltaX, deltaY, f:GetScale())
  return f:GetScale() * ns
end

-- WARNING, Y axis is such as positive is down, unlike rest of the wow api which has + offset going up
-- but all the negative numbers all over, just for Y axis, got to me

function ML.Frame(addon, name, global) -- to not shadow self below but really call with Addon:Frame(name)
  local f = CreateFrame("Frame", global, UIParent)
  if addon.debug and addon.debug >= 8 then
    addon:Debug(8, "Debug level 8 is on, putting debug background on frame %", name)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetIgnoreParentAlpha(true)
    f.bg:SetAlpha(.2)
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(.1, .2, .7)
  end
  f.name = name
  f.children = {}
  f.numObjects = 0

  f.Snap = function(w)
    addon:SnapFrame(w)
    w:setSizeToChildren()
  end

  f.Scale = function(w, ...)
    w:setScale(...)
  end

  f.ChangeScale = function(w, newScale)
    addon:ChangeScale(w, newScale)
  end

  f.Init = function(self)
    addon:Debug("Calling Init() on all % children", #self.children)
    for _, v in ipairs(self.children) do
      v:Init()
    end
  end

  -- returns opposite corners 4 coordinates:
  -- BottomRight(x,y) , TopLeft(x,y)
  f.calcCorners = function(self)
    local minX = 99999999
    local maxX = 0
    local minY = 99999999
    local maxY = 0
    local numChildren = 0
    for _, v in ipairs(self.children) do
      local x = v:GetRight()
      local y = v:GetBottom()
      local l = v:GetLeft()
      local t = v:GetTop()
      maxX = math.max(maxX, x or 0)
      minX = math.min(minX, l or 0)
      maxY = math.max(maxY, t or 0)
      minY = math.min(minY, y or 0)
      numChildren = numChildren + 1
    end
    addon:Debug(6, "Found corners for % children to be topleft % , % to bottomright %, %", numChildren, maxX, minY,
                minX, maxY)
    return maxX, minY, minX, maxY
  end

  f.setSizeToChildren = function(self)
    local mx, my, l, t = self:calcCorners()
    local x = self:GetLeft()
    local y = self:GetTop()
    if not x or not y then
      addon:Debug("Frame has no left or top! % %", x, y)
    end
    local w = mx - l
    local h = t - my
    local paddingX = 2 * (l - x)
    local paddingY = 2 * (y - t)
    addon:Debug(7, "Calculated bottom right x % y % -> w % h % padding % x %", x, y, w, h, paddingX, paddingY)
    self:SetWidth(w + paddingX)
    self:SetHeight(h + paddingY)
  end

  -- Scales a frame so the children objects fill up the frame in width or height
  -- (aspect ratio isn't changed) while also keeping the snap to pixel effect of SnapFrame
  f.setScale = function(self, overridePadding)
    local mx, my, l, t = self:calcCorners()
    local x = self:GetLeft()
    local y = self:GetTop()
    if not x or not y then
      addon:Debug("Frame has no left or top! % % in setScale", x, y)
    end
    local w = mx - l
    local h = t - my
    local paddingX = 2 * (l - x)
    local paddingY = 2 * (y - t)
    addon:Debug(6, "setScale bottom right x % y % -> w % h % padding % x %", x, y, w, h, paddingX, paddingY)
    local nw = w
    local nh = h
    if overridePadding ~= nil then
      --[[       local firstChild = self.children[1]
      local pt1, _, pt2, x, y = firstChild:GetPoint()
      if pt1:match("TOP") then
        addon:Debug("Adjusting first child top y anchor from % to %", y, overridePadding)
        y = -overridePadding
        firstChild:SetPoint(pt1, self, pt2, x, y)
      end
      if pt1:match("LEFT") then
        addon:Debug("Adjusting first child left x anchor from % to %", x, overridePadding)
        firstChild:SetPoint(pt1, self, pt2, overridePadding, y) -- use the adjusted y for TOPLEFT
      end
 ]]
      paddingX = 2 * overridePadding
      paddingY = 2 * overridePadding
    end
    nw = nw + paddingX
    nh = nh + paddingY
    local cw = self:GetWidth() -- current
    local ch = self:GetHeight()
    local sX = cw / nw
    local sY = ch / nh
    local scale = math.min(sX, sY)
    self:ChangeScale(self:GetScale() * scale)
    addon:Debug(5, "calculated scale x % scale y % for nw % nh % -> % -> %", sX, sY, nw, nh, scale, self:GetScale())
  end

  -- Used instead of SetPoint directly to move 2 linked object (eg textures for animation group) together
  local setPoint = function(sf, pt, ...)
    addon:Debug(8, "setting point %", pt)
    sf:SetPoint(pt, ...)
    if sf.linked then
      sf.linked:SetPoint(pt, ...)
    end
  end

  -- place inside the parent at offset x,y from corner of parent
  local placeInside = function(sf, x, y, point)
    point = point or "TOPLEFT"
    x = x or 16
    y = y or 16
    sf:setPoint(point, x, -y)
    return sf
  end
  -- place below (previously placed item typically)
  local placeBelow = function(sf, below, x, y, point1, point2)
    x = x or 0
    y = y or 8
    sf:setPoint(point1 or "TOPLEFT", below, point2 or "BOTTOMLEFT", x, -y)
    return sf
  end
  -- place to the right of last widget
  local placeRight = function(sf, nextTo, x, y)
    x = x or 16
    y = y or 0
    sf:setPoint("TOPLEFT", nextTo, "TOPRIGHT", x, -y)
    return sf
  end
  -- place to the left of last widget
  local placeLeft = function(sf, nextTo, x, y)
    x = x or -16
    y = y or 0
    sf:setPoint("TOPRIGHT", nextTo, "TOPLEFT", x, -y)
    return sf
  end

  -- Place (below) relative to previous one. optOffsetX is relative to the left margin
  -- established by first widget placed (placeInside)
  -- such as changing the order of widgets doesn't change the left/right offset
  -- in other words, offsetX is absolute to the left margin instead of relative to the previously placed object
  f.Place = function(self, object, optOffsetX, optOffsetY, point1, point2)
    self.numObjects = self.numObjects + 1
    addon:Debug(7, "called Place % n % o %", self.name, self.numObjects, self.leftMargin)
    if self.numObjects == 1 then
      -- first object: place inside
      object:placeInside(optOffsetX, optOffsetY, point1)
      self.leftMargin = 0
    else
      optOffsetX = optOffsetX or 0
      -- subsequent, place after the previous one but relative to initial left margin
      object:placeBelow(self.lastAdded, optOffsetX - self.leftMargin, optOffsetY, point1, point2)
      self.leftMargin = optOffsetX
    end
    self.lastAdded = object
    self.lastLeft = object
    return object
  end

  f.PlaceRight = function(self, object, optOffsetX, optOffsetY)
    self.numObjects = self.numObjects + 1
    if self.numObjects == 1 then
      addon:ErrorAndThrow("PlaceRight() should not be the first call, Place() should")
    end
    -- place to the right of previous one on the left
    -- if the previous widget has text, add the text length (eg for check buttons)
    local x = (optOffsetX or 16) + (self.lastLeft.extraWidth or 0)
    object:placeRight(self.lastLeft, x, optOffsetY)
    self.lastLeft = object
    return object
  end

  -- doesn't change lastLeft, meant to be called to put 1 thing to the left of a centered object atm
  f.PlaceLeft = function(self, object, optOffsetX, optOffsetY)
    self.numObjects = self.numObjects + 1
    if self.numObjects == 1 then
      addon:ErrorAndThrow("PlaceLeft() should not be the first call, Place() should")
    end
    -- place to the left of previous one
    -- if the previous widget has text, add the text length (eg for check buttons)
    local x = (optOffsetX or -16)
    object:placeLeft(self.lastLeft, x, optOffsetY)
    -- self.lastLeft = object
    return object
  end

  -- To be used by the various factories/sub widget creation to add common methods to them
  -- (learned after coming up with this pattern on my own that that this seems to be
  -- called Mixins in blizzard code, though that doesn't cover forwarding or children tracking)
  function f:addMethods(widget)
    widget.setPoint = setPoint
    widget.placeInside = placeInside
    widget.placeBelow = placeBelow
    widget.placeRight = placeRight
    widget.placeLeft = placeLeft
    widget.parent = self
    widget.Place = function(...)
      -- add missing parent as first arg
      widget.parent:Place(...)
      return widget -- because :Place is typically last, so don't return parent/self but the widget
    end
    widget.PlaceRight = function(...)
      widget.parent:PlaceRight(...)
      return widget
    end
    widget.PlaceLeft = function(...)
      widget.parent:PlaceLeft(...)
      return widget
    end
    if not widget.Init then
      widget.Init = function(w)
        addon:Debug(7, "Nothing special to init in %", w:GetObjectType())
      end
    end
    -- piggy back on 1 to decide both as it doesn't make sense to only define one of the two
    if not widget.DoDisable then
      widget.DoDisable = widget.Disable
      widget.DoEnable = widget.Enable
    end
    widget.Snap = function(w)
      addon:SnapFrame(w)
      w:setSizeToChildren()
    end
    table.insert(self.children, widget) -- keep track of children objects
  end

  f.addText = function(self, text, font)
    font = font or "GameFontHighlightSmall" -- different default?
    local fontObj = nil
    if type(font) ~= "string" then
      fontObj = font
      font = nil
    end
    local t = self:CreateFontString(nil, "ARTWORK", font)
    if fontObj then
      t:SetFontObject(fontObj)
    end
    t:SetText(text)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    self:addMethods(t)
    return t
  end

  -- creates framed texture so it can be placed
  -- (arguments are optional)
  f.addTexture = function(self, layer)
    local t = self:CreateTexture(nil, layer or "BACKGROUND")
    addon:Debug(8, "textures starts with % points", t:GetNumPoints())
    self:addMethods(t)
    return t
  end

  -- Add an animation of 2 textures (typically glow)
  f.addAnimatedTexture = function(self, baseId, glowId, duration, glowAlpha, looping, layer)
    local base = self:addTexture(layer)
    base:SetTexture(baseId)
    if not base:IsObjectLoaded() then
      addon:Warning("Texture % not loaded yet... use ML:PreloadTextures()...", baseId)
      base:SetSize(64, 64)
    end
    addon:Debug("Setting base texture % - height = %", baseId, base:GetHeight())
    local glow = self:CreateTexture(nil, layer or "BACKGROUND")
    glow:SetTexture(glowId)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0) -- start with no change
    glow:SetIgnoreParentAlpha(true)
    local ag = glow:CreateAnimationGroup()
    base.animationGroup = ag
    local anim = ag:CreateAnimation("Alpha")
    anim:SetFromAlpha(0)
    anim:SetToAlpha(glowAlpha or 0.2)
    ag:SetLooping(looping or "BOUNCE")
    anim:SetDuration(duration or 2)
    base.linked = glow
    ag:Play()
    return base
  end

  f.addCheckBox = function(self, text, tooltip)
    -- local name= "self.cb.".. tostring(self.id) -- not needed
    local c = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    addon:Debug(8, "check box starts with % points", c:GetNumPoints())
    c.Text:SetText(text)
    if tooltip then
      c.tooltipText = tooltip
    end
    self:addMethods(c)
    c.extraWidth = c.Text:GetWidth()
    return c
  end

  -- create a slider with the range [minV...maxV] and optional step, low/high labels and optional
  -- strings to print in parenthesis after the text title
  f.addSlider = function(self, text, tooltip, minV, maxV, step, lowL, highL, valueLabels)
    minV = minV or 0
    maxV = maxV or 10
    step = step or 1
    lowL = lowL or tostring(minV)
    highL = highL or tostring(maxV)
    local s = CreateFrame("Slider", nil, self, "OptionsSliderTemplate")
    s.DoDisable = BlizzardOptionsPanel_Slider_Disable -- what does enable/disable do ? seems we need to call these
    s.DoEnable = BlizzardOptionsPanel_Slider_Enable
    s:SetValueStep(step)
    s:SetStepsPerPage(step)
    s:SetMinMaxValues(minV, maxV)
    s:SetObeyStepOnDrag(true)
    s.Text:SetFontObject(GameFontNormal)
    -- not centered, so changing (value) doesn't wobble the whole thing
    -- (justifyH left alone didn't work because the point is also centered)
    s.Text:SetPoint("LEFT", s, "TOPLEFT", 6, 0)
    s.Text:SetJustifyH("LEFT")
    s.Text:SetText(text)
    if tooltip then
      s.tooltipText = tooltip
    end
    s.Low:SetText(lowL)
    s.High:SetText(highL)
    s:SetScript("OnValueChanged", function(w, value)
      local sVal
      if valueLabels and valueLabels[value] then
        sVal = valueLabels[value]
      else
        sVal = tostring(ML:round(value, 0.001))
        if value == minV then
          sVal = lowL
        elseif value == maxV then
          sVal = highL
        end
      end
      w.Text:SetText(text .. ": " .. sVal)
      if w.callBack then
        w:callBack(value)
      end
    end)
    self:addMethods(s)
    return s
  end

  -- the call back is either a function or a command to send to addon.Slash
  f.addButton = function(self, text, tooltip, cb)
    -- local name= "addon.cb.".. tostring(self.id) -- not needed
    local c = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    c.Text:SetText(text)
    c:SetWidth(c.Text:GetStringWidth() + 20) -- need some extra spaces for corners
    if tooltip then
      c.tooltipText = tooltip -- TODO: style/font of tooltip for button is wrong
    end
    self:addMethods(c)
    local callback = cb
    if type(cb) == "string" then
      addon:Debug(4, "Setting callback for % to call Slash(%)", text, cb)
      callback = function()
        addon.Slash(cb)
      end
    else
      addon:Debug(4, "Keeping original function for %", text)
    end
    c:SetScript("OnClick", callback)
    return c
  end

  local function dropdownInit(d)
    addon:Debug("drop down init called initDone=%", d.initDone)
    if d.initDone then
      return
    end
    addon:Debug("drop down first time init called")
    d.initDone = true
    UIDropDownMenu_JustifyText(d, "CENTER")
    UIDropDownMenu_Initialize(d, function(_w, _level, _menuList)
      for _, v in ipairs(d.options) do
        addon:Debug(5, "Creating dropdown entry %", v)
        local info = UIDropDownMenu_CreateInfo() -- don't put it outside the loop!
        info.tooltipOnButton = true
        info.text = v.text
        info.tooltipTitle = v.text
        info.tooltipText = v.tooltip
        info.value = v.value
        info.func = function(entry)
          if d.cb then
            d.cb(entry.value)
          end
          UIDropDownMenu_SetSelectedID(d, entry:GetID())
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetText(d, d.text)
    -- Uh? one global for all dropdowns?? also possible taint issues
    local width = _G["DropDownList1"] and _G["DropDownList1"].maxWidth or 0
    addon:Debug("Found dropdown width to be %", width)
    if width > 0 then
      UIDropDownMenu_SetWidth(d, width)
    end
  end

  -- Note that trying to reuse the blizzard dropdown code instead of duplicating it cause some tainting
  -- because said code uses a bunch of globals notably UIDROPDOWNMENU_MENU_LEVEL
  -- create/show those widgets as late as possible
  f.addDrop = function(self, text, tooltip, cb, options)
    -- local name = self.name .. "drop" .. self.numObjects
    local d = CreateFrame("Frame", nil, self, "UIDropDownMenuTemplate")
    d.tooltipTitle = "Testing dropdown tooltip 1" -- not working/showing (so far)
    d.tooltipText = tooltip
    d.options = options
    d.cb = cb
    d.text = text
    d.tooltipOnButton = true
    d.Init = dropdownInit
    self:addMethods(d)
    self.lastDropDown = d
    return d
  end

  if ML.widgetDemo then
    f:addText("Testing 1 2 3... demo widgets:"):Place(50, 20)
    local _cb1 = f:addCheckBox("A test checkbox", "A sample tooltip"):Place(0, 20) -- A: not here
    local cb2 = f:addCheckBox("Another checkbox", "Another tooltip"):Place()
    cb2:SetChecked(true)
    local s2 = f:addSlider("Test slider", "Test slide tooltip", 1, 4, 1, "Test low", "Test high",
                           {"Value 1", "Value 2", "Third one", "4th value"}):Place(16, 30)
    s2:SetValue(4)
    f:addText("Real UI:"):Place(50, 40)
  end

  return f
end

---
-- Changes the scale without changing the anchor
function ML:ChangeScale(f, newScale)
  local pt1, parent, pt2, x, y = f:GetPoint()
  local oldScale = f:GetScale()
  local ptMult = oldScale / newScale -- correction for point
  self:Debug(7, "Changing scale from % to % for pt % / % x % y % - point multiplier %", oldScale, newScale, pt1, pt2, x,
             y, ptMult)
  f:SetScale(newScale)
  f:SetPoint(pt1, parent, pt2, x * ptMult, y * ptMult)
end

-- Frame to attach all textures for (async) preloading: TODO actually wait for them to be loaded
ML.MoLibTexturesPreLoadFrame = CreateFrame("Frame")

-- ML.debug = 1
function ML:PreloadTextures(texture, ...)
  local t = ML.MoLibTexturesPreLoadFrame:CreateTexture(texture)
  local ret = t:SetTexture(texture)
  ML:Debug(1, "Preloading % : %", texture, ret)
  if not ret then
    error("Can't create texture %", texture)
  end
  if select("#", ...) == 0 then
    return
  end
  ML:PreloadTextures(...)
end

---

ML:Debug("MoLib UI file loaded")
