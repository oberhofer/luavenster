--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

--]]--------------------------------------------------------------------------

module("venster", package.seeall)

require("venster.utils")

local winapi = require("luawinapi")

local bit = require("bit")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

-- instance handle
local moduleHandle = winapi.GetModuleHandleW(nil)

-- the current active frame window
local activeFrame = nil

-- list of window classes
local windowClasses = {}

-- The dict which maps indices to venster.Window instances
-- (used during creation CreateWindowEx/WM_CREATE)
local instanceInitMap = {}

-- The dict which maps HWND to venster.Window instances
local windowPeerMap = {}

-- init common controls
winapi.InitCommonControls();

function registerCreate(instance)
  -- print("registerCreate", instance)
  instanceInitMap[#instanceInitMap+1] = instance
  return #instanceInitMap
end

local function peerToWindow(peer)
  -- print("peerToWindow", peer, windowPeerMap[peer])
  return windowPeerMap[peer]
end

local function setWindowPeer(peer, object)
  -- print("setWindowPeer", peer, object)
  assert(nil ~= peer)
  if (object) then
    object.hwnd = peer
  end
  windowPeerMap[peer] = object;
end

---------------------------------------------------------------------
-- Rect datatype
--
-- ctor function
function Rect(l,t,r,b)
  local self =  { ["left"]   = l or 0,
                  ["top"]    = t or 0,
                  ["right"]  = r or 0,
                  ["bottom"] = b or 0 }
  return self
end

---------------------------------------------------------------------
-- extract pos/size from arg
--
function getPosSize(arg)
  local x, y, w, h = CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT
  if (arg.pos) then
    x = arg.pos.x or x
    y = arg.pos.y or y
    w = arg.pos.w or w
    h = arg.pos.h or h
  end
  return x, y, w, h
end

---------------------------------------------------------------------
-- id generator singleton
--
local mtIdGenerator = {}

function mtIdGenerator:createid()
  if (#self.recycle ~= 0) then
    return table.remove(self.recycle, 1)
  else
    self.current_id = self.current_id + 1
    return self.current_id
  end
end

function mtIdGenerator:reuseid(id)
  table.insert(self.recycle, id)
end

-- id generator instance
local idGenerator = setmetatable({ current_id = 999, recycle = { } }, { __index = mtIdGenerator })


--------------------------------------------------------------------

local function xpcallwithparams(func, err, ...)
  local params = {...}
  return xpcall(function() return func(unpack(params)) end, err)
end

---------------------------------------------------------------------
-- the central window procedure
--
local function internalWndProc(hwnd, msg, wParam, lParam, object, prevproc)
  -- print("WndProc", hwnd, MSG_CONSTANTS[msg] or msg, wParam, lParam)

  -- register peers on creation and
  -- map command messages and notification messages
  -- to the specific child window
  if (WM_CREATE == msg) then
    local createStruct = winapi.CREATESTRUCTW:attach(lParam)

    local widget = instanceInitMap[createStruct.lpCreateParams.value]
    setWindowPeer(hwnd, widget)
  elseif (WM_COMMAND == msg) then
    if (lParam > 0) then
      hwnd = winapi.WrapWindow(lParam)
    end
  end

  -- map to object
  local widget = peerToWindow(hwnd)

  -- map WM_COMMAND messages of "unpeered" windows
  -- to the current frame window
  widget = widget or activeFrame

  if (widget) then
    local handler = widget[msg]

    -- print("msg", toASCII(widget.label), MSG_CONSTANTS[msg] or msg, wParam, lParam, hwnd, widget)

    if (handler) then
      if ("function" == type(handler)) then
        local result = handler(widget, wParam, lParam)

        -- print("msg", toASCII(widget.label), MSG_CONSTANTS[msg] or msg, wParam, lParam, msgprocessed, result, (result or 0))

        -- returning nil means msg has not been processed
        if (nil ~= result) then
          -- print("msg(rets table) ", result, (result or 0))
          return result
        end
      elseif ("table" == type(handler)) then
        if (WM_NOTIFY == msg) then
          local nmh = winapi.NMHDR:attach(lParam)
          local nhdlr = handler[nmh.code]
          if (nhdlr) then
            msgprocessed, result = nhdlr(widget, nmh)
            if (msgprocessed) then
              print("notify result ", result, (result or 0))
              return result
            end
          end
        end
      end
    end

--[[
    -- route not processed notification messages to the associated window
    if (WM_NOTIFY == msg) then
      local nmh = winapi.NMHDR:attach(lParam)

      -- print("WM_NOTIFY", widget and toASCII(widget.label), (0xFFFFFFFF - nmh.code + 1) )

      if (widget and widget.OnNotify) then

        -- print("call OnNotify")
        msgprocessed, result = widget:OnNotify(nmh)
        if (msgprocessed) then
          print("notify result ", result, (result or 0))
          return result
        end
      end

      -- do default processing
      return 0
    end
--]]

  end

  -- nil means call previous window proc
  return nil
end


local function internalErrorFunc(errmsg, hwnd, msg, wParam, lParam)
  print("------- internalErrorFunc", hwnd, MSG_CONSTANTS[msg] or msg, wParam, lParam)
  print(errmsg)

  winapi.PostQuitMessage(0)
end

---------------------------------------------------------------------
-- register window classes
--
function registerclass(classname, args)
  if (not windowClasses[classname]) then

    print("registerclass ", toASCII(classname))

    -- takes object, msgproc, errorfunc
    local WndProc_callback = winapi.WndProc.new(nil, internalWndProc, internalErrorFunc)

    -- check params
    args = args or { }
    args.hbrBackground = args.hbrBackground or winapi.GetStockObject(WHITE_BRUSH)

    local wndClass = winapi.WNDCLASSW:new()
    wndClass.style          = CS_HREDRAW + CS_VREDRAW;
    wndClass.lpfnWndProc    = WndProc_callback.entrypoint
    wndClass.cbClsExtra     = 0
    wndClass.cbWndExtra     = 0
    wndClass.hInstance      = moduleHandle
    wndClass.hIcon          = 0  -- LoadIcon(NULL, IDI_APPLICATION);
    wndClass.hCursor        = winapi.LoadCursorW(NULL, IDC_ARROW);
    wndClass.hbrBackground  = args.hbrBackground;
    wndClass.lpszMenuName   = 0
    wndClass.lpszClassName  = classname

    local atom = winapi.RegisterClassW(wndClass);
    if (not atom) then
      error(WinError())
    end

    -- store atom and callback
    windowClasses[classname] = { atom, WndProc_callback }
  end
end

---------------------------------------------------------------------
-- Menu
--
mtMenu = { class="Menu" }

function mtMenu:setMenuItemText(id, text)
  local mii = winapi.MENUITEMINFOW:new()

  mii.cbSize = #mii
  mii.fMask = MIIM_TYPE
  mii.fType = MFT_STRING
  mii.fState = 0
  mii.wID = 0
  mii.hSubMenu = 0
  mii.hbmpChecked = 0
  mii.hbmpUnchecked = 0
  mii.dwItemData = 0
  mii.dwTypeData = _T(text)
  mii.cch = 0

  return winapi.SetMenuItemInfoW(self.hmenu, id, 0, mii)
end


local function CreateSubMenu(items)
  if (items and  (#items > 0)) then
    local hmenu = winapi.CreatePopupMenu()

    for idx, item in ipairs(items) do
      local submenu = CreateSubMenu(item)

      if (submenu) then
        winapi.AppendMenuW(hmenu, MF_POPUP, submenu, _T(item.name) )
      else
        local flags = item.flags or bor(MF_ENABLED, MF_STRING)
        winapi.AppendMenuW(hmenu, flags, item.id or 0, _T(item.name))
      end
    end

    return hmenu
  end
  return nil
end


local function CreateMenu(items)
  local hmenu = winapi.CreateMenu()

  for idx, item in ipairs(items) do
    local submenu = CreateSubMenu(item)

    if (submenu) then
      winapi.AppendMenuW(hmenu, MF_POPUP, submenu, _T(item.name) )
    else
      local flags = item.flags or bor(MF_ENABLED, MF_STRING)
      winapi.AppendMenuW(hmenu, flags, item.id or 0, _T(item.name))
    end
  end

  return hmenu
end

function mtMenu:create()
  if (not self.hmenu) then
    self.hmenu = CreateMenu(self.items)
  end
  return self.hmenu
end

function mtMenu:contextMenu(parent, offset)
  local rc = parent:getBounds()
  self:create()
  offset = offset or { x=0, y=0 }
  winapi.TrackPopupMenuEx(winapi.GetSubMenu(self.hmenu, 0), 0, rc.left + offset.x, rc.top + offset.y, parent.hwnd.handle, 0)
end


function Menu(items)
  local self = setmetatable( { items = items }, { __index = mtMenu } )
  return self
end

---------------------------------------------------------------------
-- Component
--
mtComponent = { class="GuiComponent" }

function mtComponent:getPreferredSize()
  -- print("mtComponent:getPreferredSize", self.id)

  -- if we have a layout manager, use it to calculate
  -- the preferredSize.
  local preferredSize = nil
  if (self.layout) then

      -- print("layout", self.layout)
    preferredSize = self.layout:preferredLayoutSize(self);
  end
  if (nil == preferredSize) then
      -- by default use parent size
      -- preferredSize =  { width=-1, height=-1 }
      preferredSize =  self.parent:getSize()

    if (self.pos) then
      -- or, just stick to the Components default size.
      if (self.pos and (self.pos.w == nil or self.pos.w >= 0)) then
      preferredSize.width = self.pos.w
      end
      if (self.pos.h == nil or self.pos.h >= 0) then
      preferredSize.height = self.pos.h
      end
    end
  end
  return preferredSize
end

function mtComponent:show(showwnd)
  -- show/hide children
  for _, ch in ipairs(self.children) do
    ch:show(showwnd)
  end
end

function mtComponent:initChildren()

  print("mtComponent:initChildren", self.id, self.layout)
  -- print(self.hwnd.handle)

  -- init children
  if (self.children) then
    for _, ch in ipairs(self.children) do
      -- print("create", ch.id)
      self.children[ch.id] = ch:create(self)
    end
  end

  -- init layout
  if (self.layout) then
    local typ = type(self.layout)
    if ("table" == typ) then
      self.layout:createLayout(self)
    elseif ("function" == typ) then
      -- wrap function as a layout object
    end
  end
end

---------------------------------------------------------------------
-- Panel
--
mtPanel = setmetatable({ class="Panel" }, { __index = mtComponent })

function mtPanel:setBounds(x,y,w,h,repaint)
  -- print("mtPanel:setBounds", self.id, x,y,w,h)
  self.pos = { x=x, y=y, w=w, h=h }
  -- layout panel content
  if (self.layout) then
    self.layout:layoutContainer(self)
  else
    PositionLayout:layoutContainer(self)
  end
end

function mtPanel:setPos(x,y)
  -- print("mtPanel:setPos", self.id, x,y)
  self.pos.x = x
  self.pos.y = y
  -- layout panel content
  if (self.layout) then
    self.layout:layoutContainer(self)
  else
    PositionLayout:layoutContainer(self)
  end
end

function mtPanel:getBounds()
  local x, y, w, h = self.pos.x, self.pos.y, self.pos.w, self.pos.h
  local rc = winapi.RECT:new()
  rc.left, rc.top, rc.right, rc.bottom = x, y, x + w, y + h
  return rc
end

function mtPanel:isVisible()
  return true
end

function  mtPanel:getSize()
  return { width = self.pos.w, height = self.pos.h }
end


function  mtPanel:create(parent)
  self.parent = parent

  -- panels are components without a peer
  -- so we have to take the handle from the parent to be able to create childs
  self.hwnd = parent.hwnd

  -- init children and layout
  self:initChildren()

  return self
end

function Panel(args)
  local self = args or { }

  return setmetatable(self, { __index = mtPanel } )
end


---------------------------------------------------------------------
-- Window
--
mtWindow = setmetatable({ class="Window" }, { __index = mtComponent })

mtWindow[WM_CREATE] = function(self, wParam, lParam)
  local createStruct = winapi.CREATESTRUCTW:attach(lParam)

  self:initChildren()

  -- call OnCreate
  if (self.OnCreate) then
    return self:OnCreate(createStruct)
  end
  return 0
end

mtWindow[WM_ACTIVATE] = function(self, wParam, lParam)
  local fActive = LOWORD(wParam)
  local fMinimized = HIWORD(wParam)
  local hwndPrevious = lParam
  if (self.OnActivate) then
    self:OnActivate(fActive, fMinimized, hwndPrevious)
  end
  return nil
end

--[[
mtWindow[WM_NOTIFY] = function(self, nmh)
  if (self.OnNotify) then
    local result = self:OnNotify(nmh)
    -- print("OnNotify gives: ", result)
  end
  return nil
end
--]]

mtWindow[WM_DESTROY] = function(self)
  if (self.isrunningmodal) then
    self:endmodal(IDCANCEL)
  end
  if (self.OnDestroy) then
    self:OnDestroy()
  end
  return nil
end

mtWindow[WM_COMMAND] = function(self, wParam)
  if (self.OnCommand) then
    local cmdId   = LOWORD(wParam)
    local isAccel = (HIWORD(wParam) == 1)
    return self:OnCommand(cmdId, isAccel)
  end
  return nil
end

mtWindow[WM_KEYDOWN] = function(self, wParam, lParam)
  if (self.OnKeyDown) then
    return self:OnKeyDown(wParam, lParam)
  end
  return nil
end

mtWindow[WM_PAINT] = function(self, wParam, lParam)
  if (self.OnPaint) then
    local ps = winapi.PAINTSTRUCT:new()
    local hdc = winapi.BeginPaint(self.hwnd, ps);
    local result = self:OnPaint(ps, hdc)
    winapi.EndPaint(self.hwnd, ps)
    return result
  end
  return nil
end

mtWindow[WM_WINDOWPOSCHANGED] = function(self, wParam, lParam)
  -- print("WM_WINDOWPOSCHANGED", self.class, toASCII(self.label))
  if (self.layout) then
    self.layout:layoutContainer(self)
  else
    PositionLayout:layoutContainer(self)
  end
  return nil
end

--
-- wrapper functions
--
function mtWindow:msgbox(text, title, buttons)
  buttons = buttons or MB_OK
  title = title or self.label
  return winapi.MessageBoxW(self.hwnd, _T(text), _T(title), buttons)
end

function mtWindow:show(showwnd)
  if (showwnd or (nil == showwnd)) then
    showwnd = SW_SHOW
  else
    showwnd = SW_HIDE
  end
  winapi.ShowWindow(self.hwnd, showwnd)
end

function mtWindow:hide()
  winapi.ShowWindow(self.hwnd, SW_HIDE)
end

function mtWindow:invalidate(erase)
  erase = toBOOL(erase)
  return winapi.InvalidateRect(self.hwnd,nil,erase)
end

function mtWindow:getBounds()
  local rc = winapi.RECT:new()
  winapi.GetClientRect(self.hwnd, rc)
  return rc
end

function mtWindow:getSize()
  local rc = winapi.RECT:new()
  winapi.GetClientRect(self.hwnd, rc)
  return rc:size()
end

function mtWindow:setBounds(x,y,w,h,repaint)
  -- print("setBounds", self.id, x,y,w,h);
  if (nil == repaint) then
    repaint = TRUE
  end
  winapi.MoveWindow(self.hwnd, x, y, w, h, repaint)
end

function mtWindow:setPos(x, y)
  -- print("setPos", self.id, x, y);
  winapi.SetWindowPos(self.hwnd, 0, x, y, 0, 0, SWP_NOSIZE)
end

function mtWindow:tofront()
  winapi.BringWindowToTop(self.hwnd)
end

function mtWindow:update()
  if (self.layout) then
    self.layout:layoutContainer(self)
  else
    PositionLayout:layoutContainer(self)
  end
  winapi.UpdateWindow(self.hwnd)
end

function mtWindow:isVisible()
  return winapi.IsWindowVisible(self.hwnd)
end

function mtWindow:isEnabled()
  return winapi.IsWindowEnabled(self.hwnd)
end

function mtWindow:disable()
  winapi.EnableWindow(self.hwnd, FALSE)
end

function mtWindow:enable()
  winapi.EnableWindow(self.hwnd, TRUE)
end

function mtWindow:activate()
  winapi.SetActiveWindow(self.hwnd)
end

function mtWindow:setText(text)
  winapi.SendMessageW(self.hwnd, WM_SETTEXT, 0, text)
end

function mtWindow:getText()
  local textLength = winapi.SendMessageW(self.hwnd, WM_GETTEXTLENGTH) + 1
  local buffer   = string.rep("\0\0", textLength)
  winapi.SendMessageW(self.hwnd, WM_GETTEXT, textLength, buffer)
  return buffer
end

function mtWindow:setFocus()
  return winapi.SetFocus(self.hwnd)
end

function mtWindow:setRedraw(state)
  state = toBOOL(state)
  return winapi.SendMessageW(self.hwnd, WM_SETREDRAW, state)
end

function mtWindow:endmodal(result)
  -- end a modal loop
  print("-> mtWindow:endmodal ", self.isrunningmodal, result)
  self.isrunningmodal = false
  self.result = result

  if (self.modal_parent) then
    if (UNDER_CE) then
      winapi.SetForegroundWindow(self.modal_parent.hwnd)
    end
    self.modal_parent:enable()
    -- self.modal_parent:show()
    -- self.modal_parent:tofront()
    -- if (self.prevfocus) then
    --   winapi.SetFocus(self.prevfocus)
    -- end
  end
  self:hide()
end

function mtWindow:runmodal(parent, ...)
  print("-> mtWindow:runmodal", self and toASCII(self.label))

  self.modal_parent = parent

  -- if (parent) then
  --   self.prevfocus = winapi.GetFocus()
  -- end

  -- create if not already done
  if (nil == self.hwnd) then
    -- specify self as third param for window class registering arguments
    self = self:create(nil, self)
  end

  if (self.modal_parent) then
    self.modal_parent:disable()
    -- self.modal_parent:hide()
  end
  self:show()

  -- print("set active frame", toASCII(self.label))
  local prevFrame = activeFrame
  activeFrame = self

    -- notify about runmodal
  if (self.OnRunModal) then
    self:OnRunModal(...)
  end

  local msg  = winapi.MSG:new()

  self.result = 0
  self.isrunningmodal = true
  while (self.isrunningmodal) do
    local res = winapi.GetMessageW(msg, NULL, 0, 0)
    if (res > 0) then
      winapi.TranslateMessage(msg)
      winapi.DispatchMessageW(msg)
    else
      -- use result from WM_QUIT
      -- self.result = msg.wParam or 0
      -- received WM_QUIT -> repost
      winapi.PostQuitMessage(msg.wParam)
      return self.result
    end
  end

  activeFrame = prevFrame

  print("<- mtWindow:runmodal", self and toASCII(self.label), self.result, self.hwnd)

  -- destroy dialog
  -- winapi.DestroyWindow(self.hwnd);
  -- setWindowPeer(self.hwnd, nil)
  -- self.hwnd = nil

  -- menu has been destroyed -> disconnect handle
  -- if (self.menu) then
  --     self.menu.hmenu = nil
  -- end

  -- print("restore active frame", toASCII(prevFrame.label))
  activeFrame = prevFrame

  -- return result
  return self.result
end


function mtWindow:create(parent)
  print("mtWindow:create ", toASCII(self.label), parent)

  self.parent = parent

  self.ctrlid = idGenerator:createid()
  if (not self.classregistered) then
    self.classregistered = true
    self.classname = self.classname or _T( "guiwin_" .. self.ctrlid )
    registerclass(self.classname, self)
  end

  -- print("after registerclass", toASCII(self.label))

  local x, y, w, h = getPosSize(self)
  local style   = self.style or WS_VISIBLE
  local exstyle = self.exstyle or 0

  if (self.layout) then
    self.layout.parent = self
  end

  local parenthwnd = parent
  if ("table" == type(parent)) then
    parenthwnd = parent.hwnd.handle
  end

  local hmenu = nil
  if (self.menu) then
    hmenu = self.menu:create()
  end
  local hwnd = winapi.CreateWindowExW(
      exstyle,
      self.classname,           -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      parenthwnd or 0,          -- parent window handle
      hmenu,                    -- window menu handle
      moduleHandle,             -- program instance handle
      registerCreate(self));    -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  return self
end


function Window(args, mt)

  local self
  if ("string"==type(args)) then
    self = {  }
  else
    self = args or { label=_T"" }
  end

  self.label = self.label or _T""

  setmetatable(self, { __index = mt or mtWindow } )

  return self
end

---------------------------------------------------------------------
-- Button
--
mtButton = setmetatable({ class="Button" }, { __index = mtWindow })

mtButton[WM_COMMAND] = function(self, wParam, lParam)
  if ( BN_CLICKED == HIWORD(wParam) ) then
    -- print("BN_CLICKED:", self, wParam, lParam)
    if (self.OnClicked) then self:OnClicked() end
  end
  return 0
end

function mtButton:recalcSize()
  -- calculate ideal size
  -- (BCM_GETIDEALSIZE works only  under WinXP)

  local hdc   = winapi.GetDC(self.hwnd)
  local label = self:getText()

  local hfont = winapi.SendMessageW(self.hwnd, WM_GETFONT, 0, 0);

  if (0 == hfont) then
    hfont = winapi.GetStockObject(SYSTEM_FONT);
  end
  local oldfont = winapi.SelectObject(hdc, hfont);

  local cx, cy = GetTextExtent(hdc, label)

  winapi.SelectObject(hdc, oldfont);
  winapi.ReleaseDC(self.hwnd, hdc)

  -- add button default border
  cx = cx + 16
  cy = cy +  8

  if (not self.pos) then
    self.pos = { x=0, y=0 }
  end

  self.pos.w = self.pos.w or cx
  self.pos.h = self.pos.h or cy
end

function mtButton:getPreferredSize()
  -- print("mtButton:getPreferredSize", toASCII(self.label))

  -- if we have a layout manager, use it to calculate
  -- the preferredSize.
  local preferredSize
  if (self.layout) then
    preferredSize = self.layout:preferredLayoutSize(self);
  elseif (self.pos) then
    preferredSize = { width  = self.pos.w, height = self.pos.h }
  end
  -- printtable("mtButton:getPreferredSize", preferredSize)
  return preferredSize
end


function mtButton:create(parent)
  self.parent = parent

  local x, y, w, h = getPosSize(self)
  local hParent = self.parent.hwnd     -- parent window handle
  local style   = bor(WS_CHILD, WS_VISIBLE, WS_TABSTOP, self.style or 0)

  local hwnd = winapi.CreateWindowExW(
      0,
      _T("BUTTON"),             -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      0,                        -- window menu handle
      moduleHandle,             -- program instance handle
      0);    -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  self.hwnd:SendMessageW(WM_SETFONT, winapi.GetStockObject(SYSTEM_FONT), 0)
  self:recalcSize()

  return self
end

function Button(args)
  return Window(args, mtButton)
end

function GroupBox(args)
  args.style = bor(args.style or 0, BS_GROUPBOX)
  return Button(args, mtButton)
end


---------------------------------------------------------------------
-- Label
--
mtLabel = setmetatable({ class="Label" }, { __index = mtWindow })

function mtLabel:recalcSize()

  -- calculate ideal size
  local hdc   = winapi.GetDC(self.hwnd)
  local label = self:getText()

  local hfont = winapi.SendMessageW(self.hwnd, WM_GETFONT, 0, 0);

  if (0 == hfont) then
    hfont = winapi.GetStockObject(SYSTEM_FONT);
  end
  local oldfont = winapi.SelectObject(hdc, hfont);

  local cx, cy = GetTextExtent(hdc, label)

  winapi.SelectObject(hdc, oldfont);
  winapi.ReleaseDC(self.hwnd, hdc)

  -- add label default border
  cx = cx + 8
  cy = cy + 8

  if (not self.pos) then
    self.pos = { x=0, y=0 }
  end

  self.pos.w = self.pos.w or cx
  self.pos.h = self.pos.h or cy
end

function mtLabel:getPreferredSize()
  local preferredSize
  preferredSize = { width  = self.pos.w, height = self.pos.h }
  return preferredSize
end


function mtLabel:create(parent)
  self.parent = parent

  local x, y, w, h = getPosSize(self)
  local hParent = self.parent.hwnd     -- parent window handle
  local style   = bor(WS_CHILD, WS_VISIBLE, self.style or 0)

  print("create label", hParent)

  local hwnd = winapi.CreateWindowExW(
      0,
      _T("Static"),             -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      0,                        -- window menu handle
      moduleHandle,             -- program instance handle
      0)                        -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  self.hwnd:SendMessageW(WM_SETFONT, winapi.GetStockObject(SYSTEM_FONT), 0)
  self:recalcSize()

  return self
end

function Label(args)
  return Window(args, mtLabel)
end


---------------------------------------------------------------------
-- Edit
--
mtEdit = setmetatable({ class="Edit" }, { __index = mtWindow })

-- use same functions as for label
mtEdit.recalcSize       = mtLabel.recalcSize
mtEdit.getPreferredSize = mtLabel.getPreferredSize

function mtEdit:create(parent)
  self.parent = parent

  local x, y, w, h = getPosSize(self)
  local hParent = self.parent.hwnd     -- parent window handle
  local style   = bor(WS_CHILD, WS_VISIBLE, WS_TABSTOP, self.style or 0)

  local hwnd = winapi.CreateWindowExW(
      0,
      _T("EDIT"),               -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      0,                        -- window menu handle
      moduleHandle,             -- program instance handle
      0)                        -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  self.hwnd:SendMessageW(WM_SETFONT, winapi.GetStockObject(SYSTEM_FONT), 0)
  self:recalcSize()

  return self
end

function Edit(args)
  return Window(args, mtEdit)
end


---------------------------------------------------------------------
-- ListView
--
WC_LISTVIEWW = _T("SysListView32")

mtListView = setmetatable({ class="ListView" }, { __index =  mtWindow })

mtListView.AddColumn = function(self, iCol, text, cx)
  local lvc = winapi.LVCOLUMNW:new()
  lvc.mask = bor(LVCF_FMT, LVCF_WIDTH, LVCF_TEXT)
  lvc.fmt = LVCFMT_LEFT
  lvc.cx = cx
  lvc.pszText = text .. "\0\0"
  winapi.SendMessageW(self.hwnd, LVM_INSERTCOLUMNW, iCol-1, lvc)
end

mtListView.AutoSizeColumn = function(self, iCol)
  winapi.SendMessageW(self.hwnd, LVM_SETCOLUMNWIDTH, iCol-1, LVSCW_AUTOSIZE_USEHEADER)
end

mtListView.SetColumnWidth = function(self, iCol, width)
  winapi.SendMessageW(self.hwnd, LVM_SETCOLUMNWIDTH, iCol-1, MAKELPARAM(width, 0))
end

mtListView.AddItem = function(self, iRow, item)
  local lvi    = winapi.LVITEMW:new()
  lvi.mask     = bor(LVIF_TEXT, LVIF_IMAGE)
  lvi.iItem    = iRow-1
  lvi.iSubItem = 0
  lvi.pszText = item.text .. "\0\0"
  lvi.iImage   = item.imgidx or 0
  winapi.SendMessageW(self.hwnd, LVM_INSERTITEMW, 0, lvi)
  if (item.subitems) then
    for idx,v in ipairs(item.subitems) do
      lvi.iSubItem = idx
      lvi.pszText  = v.text .. "\0\0"
      lvi.iImage   = v.imgidx
      winapi.SendMessageW(self.hwnd, LVM_SETITEMW, 0, lvi)
    end
  end
end

mtListView.SetItemText = function(self, item, subitem, text)
  local lvi    = winapi.LVITEMW:new()
  lvi.mask     = bor(LVIF_TEXT)
  lvi.iItem    = item-1
  lvi.iSubItem = subitem-1
  lvi.pszText  = text .. "\0\0"
  lvi.iImage   =  0
  return winapi.SendMessageW(self.hwnd, LVM_SETITEMW, 0, lvi)
end

mtListView.DeleteItem = function(self, iItem)
  winapi.SendMessageW(self.hwnd, LVM_DELETEITEM, iItem-1, 0)
end

mtListView.AddItems = function(self, items)
  for idx,v in ipairs(items) do
    self:AddItem(idx, v)
  end
end

mtListView.GetItemCount = function(self)
  return winapi.SendMessageW(self.hwnd, LVM_GETITEMCOUNT, 0, 0)
end

mtListView.GetSelectionMark = function(self)
  return winapi.SendMessageW(self.hwnd, LVM_GETSELECTIONMARK, 0, 0)
end

mtListView.SetSelectionMark = function(self, idx)
  return winapi.SendMessageW(self.hwnd, LVM_SETSELECTIONMARK, 0, (idx or 1) - 1)
end

mtListView.AddRow = function(self, iRow, rowitems, groupid)
  if (nil == iRow) then
    iRow = self:GetItemCount() + 1
  end
  local grpflag = 0
  if (groupid) then
    grpflag = LVIF_GROUPID
  end
  local lvi    = winapi.LVITEMW:new()
  lvi.mask     = bit.bor(LVIF_TEXT, grpflag)
  lvi.iItem    = iRow-1
  lvi.iSubItem = 0
  lvi.iImage   = 0
  if (not UNDER_CE) then
    lvi.iGroupId = groupid or 0
  end
  local msg    = LVM_INSERTITEMW
  for idx, v in ipairs(rowitems) do
    lvi.pszText = tostring(v) .. "\0\0"
    winapi.SendMessageW(self.hwnd, msg, 0, lvi)
    lvi.iSubItem = idx
    msg = LVM_SETITEMW
  end
  return iRow
end

mtListView.AddRows = function(self, rows, groupid)
  for _,v in ipairs(rows) do
    self:AddRow(nil, v, groupid)
  end
end

mtListView.GetRow = function(self, iRow, columns)
  iRow = iRow or 1
  assert(iRow > 0)
  if (self:GetItemCount() < iRow) then
    return nil, "eol"
  end
  local row = {}
  for idx, col in ipairs(columns) do
    row[idx] = self:GetItemText(iRow, col)
  end
  return row
end


mtListView.SetExStyle = function(self, exstyle)
  winapi.SendMessageW(self.hwnd, LVM_SETEXTENDEDLISTVIEWSTYLE, 0, exstyle)
end

mtListView.GetItemText = function(self, idx, subitem)
  subitem = subitem or 1
  assert(subitem > 0)
  local lvi = winapi.LVITEMW:new()
  local result = string.rep("\0", 514)
  lvi.pszText    = result
  lvi.iSubItem   = subitem-1
  lvi.cchTextMax = 512/2
  local len = winapi.SendMessageW(self.hwnd, LVM_GETITEMTEXTW, idx-1, lvi)
  return result:sub(1, len*2)
end

mtListView.SetImageList = function(self, iml)
  winapi.SendMessageW(self.hwnd, LVM_SETIMAGELIST, LVSIL_NORMAL, iml)
end

mtListView.GetFirstSelectedItem = function(self)
  local res = winapi.SendMessageW(self.hwnd, LVM_GETNEXTITEM, -1, LVNI_SELECTED)
  if (res ~= -1) then
    return res + 1
  end
  return nil
end

mtListView.GetSelectedItems = function(self)
  local list = { }
  local res = winapi.SendMessageW(self.hwnd, LVM_GETNEXTITEM, -1, LVNI_SELECTED)
  if (res ~= -1) then
    list[#list+1] = res
    repeat
      res = winapi.SendMessageW(self.hwnd, LVM_GETNEXTITEM, res, LVNI_SELECTED)
      if (res ~= -1) then
        list[#list+1] = res
      end
    until (res == -1)
  end
  return list
end

mtListView.SetCallbackMask = function(self, mask)
  return winapi.SendMessageW(self.hwnd, LVM_SETCALLBACKMASK, mask)
end

mtListView.SetItemState = function(self, idx, state, mask)
  local lvi = winapi.LVITEMW:new()
  lvi.iItem      = idx - 1
  lvi.state      = state
  lvi.stateMask  = mask
  return winapi.SendMessageW(self.hwnd, LVM_SETITEMSTATE, idx - 1, lvi)
end

mtListView.UpdateItems = function(self, ...)
  for _, v in ipairs{...} do
    winapi.SendMessageW(self.hwnd, LVM_UPDATE, v)
  end
end

function mtListView:DeleteAllItems()
  return winapi.SendMessageW(self.hwnd, LVM_DELETEALLITEMS)
end

function mtListView:EnableGroups(enable)
  return winapi.SendMessageW(self.hwnd, LVM_ENABLEGROUPVIEW, toBOOL(enable))
end

function mtListView:InsertGroup(item, index)
  index = index or -1
  local group = winapi.LVGROUP:new()
  group.cbSize = #group;
  group.mask = bit.bor(LVGF_HEADER, LVGF_GROUPID)
  group.cchHeader = #item.name
  group.pszHeader = item.name;
  if (not UNDER_CE) then
    group.iGroupId = item.id;
  end
  group.uAlign = LVGA_HEADER_CENTER;
  return winapi.SendMessageW(self.hwnd, LVM_INSERTGROUP, index, group)
end

function mtListView:EnsureVisible(item, partialOk)
  item = item or 1
  return winapi.SendMessageW(self.hwnd, LVM_ENSUREVISIBLE, item - 1, toBOOL(partialOk))
end

function mtListView:create(parent)
  self.parent = parent

  local x, y, w, h = getPosSize(self)
  local hParent = self.parent.hwnd     -- parent window handle
  local style   = bor(WS_CHILD, WS_VISIBLE, WS_TABSTOP, self.style or 0)

  local hwnd = winapi.CreateWindowExW(
      0,
      WC_LISTVIEWW,             -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      100,                      -- window menu handle
      moduleHandle,             -- program instance handle
      0)                        -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  if (self.exstyle) then
    self:SetExStyle(self.exstyle)
  end

  if (self.columns) then
    for idx, col in ipairs(self.columns) do
      self:AddColumn(idx, col.text, col.percent * w)
    end

    for idx, col in ipairs(self.columns) do
      self:AutoSizeColumn(idx, col)
    end
  end

  if (self.imagelist) then
    local iml = winapi.ImageList_LoadImageW(0, self.imagelist, 32, 1, RGB(0xff, 0x00, 0xff), IMAGE_BITMAP, bor(LR_CREATEDIBSECTION, LR_LOADFROMFILE))
    self:SetImageList(iml)
  end

  -- layout listview columns depending on width
  -- self.layout = ListViewLayout()

  if (self.items) then
  self:AddItems(self.items)
  end

  return self
end

function ListView(args)
  return Window(args, mtListView)
end


--------------------------------------------------------------------
-- TreeView
--
WC_TREEVIEWW = _T("SysTreeView32")

mtTreeView = setmetatable({ class="TreeView" }, { __index =  mtWindow })

mtTreeView.AddItem = function(self, parent, after, item)
  local text       = item.text .. "\0\0"
  local tvi        = winapi.TVINSERTSTRUCTW:new()
  local mask       = TVIF_TEXT
  if (nil ~= item.param) then
    mask = bor(mask, TVIF_PARAM)
  end
  if (nil ~= item.image) then
    mask = bor(mask, TVIF_IMAGE)
  end
  if (nil ~= item.selectedimage) then
    mask = bor(mask, TVIF_SELECTEDIMAGE)
  end

  tvi.hParent      = parent
  tvi.hInsertAfter = after
  tvi.item.mask    = mask
  tvi.item.pszText = text
  tvi.item.cchTextMax = #text / 2;
  tvi.item.lParam        = item.param or 0
  tvi.item.iImage        = item.image or 0
  tvi.item.iSelectedImage = item.selectedimage or 0

  return winapi.SendMessageW(self.hwnd, TVM_INSERTITEMW, 0, tvi)
end

mtTreeView.NumChildren = function(self, item)
  local tvi  = winapi.TVITEMW:new()
  tvi.hItem = item;
  tvi.mask  = TVIF_CHILDREN;
  winapi.SendMessageW(self.hwnd, TVM_GETITEMW, 0, tvi)
  return tvi.cChildren;
end

mtTreeView.GetItem = function(self, hitem, mask)
  mask = mask or bor(TVIF_PARAM, TVIF_TEXT)

  local tvi  = winapi.TVITEMW:new()
  tvi.hItem = hitem;
  tvi.mask  = mask;
  winapi.SendMessageW(self.hwnd, TVM_GETITEMW, 0, tvi)

  return tvi
end

mtTreeView.GetNextItem  = function(self, item, code)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, code, item)
end
mtTreeView.GetChildItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_CHILD, item)
end
mtTreeView.GetNextSiblingItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_NEXT, item)
end
mtTreeView.GetPrevSiblingItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_PREVIOUS, item)
end
mtTreeView.GetParentItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_PARENT, item)
end
mtTreeView.GetFirstVisibleItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_FIRSTVISIBLE, item)
end
mtTreeView.GetNextVisibleItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_NEXTVISIBLE, item)
end
mtTreeView.GetPrevVisibleItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_PREVIOUSVISIBLE, item)
end
mtTreeView.GetLastVisibleItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_LASTVISIBLE, item)
end
mtTreeView.GetSelectedItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_CARET, item)
end
mtTreeView.GetDropHilightItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_DROPHILITE, item)
end
mtTreeView.GetRootItem = function(self)
  return winapi.SendMessageW(self.hwnd, TVM_GETNEXTITEM, TVGN_ROOT, 0)
end
mtTreeView.SelectItem = function(self, item, flags)
  flags = flags or TVGN_CARET
  return winapi.SendMessageW(self.hwnd, TVM_SELECTITEM, flags, item)
end
mtTreeView.DeleteItem = function(self, item)
  return winapi.SendMessageW(self.hwnd, TVM_DELETEITEM, item)
end

mtTreeView.Hittest = function(self)
  local tvh = winapi.TVHITTESTINFO:new()
  if (winapi.GetCursorPos(tvh.pt) and
      winapi.ScreenToClient(self.hwnd.handle, tvh.pt)) then
    if (winapi.SendMessageW(self.hwnd.handle, TVM_HITTEST, 0, tvh)) then
      return tvh
    end
  end
  return nil -- , GetLastError
end


mtTreeView.AddItems = function(self, parent, after, items)
  -- print(self, parent, after)
  for _, it in ipairs(items) do
    self:AddItem(parent, after, { text = it[1] })
  end

end

mtTreeView.Expand = function(self, parent)
  return winapi.SendMessageW(self.hwnd, TVM_EXPAND, TVE_EXPAND, parent)
end

local RECURSE = {
  CONTINUE = 0,
  BREAK    = 1,
  DIVEIN   = 2
}

-- recurse over items
mtTreeView.foreachItem = function(self, hitem, func)
  local function recurse(cur)
    while (cur > 0) do
      local result = func(self, cur)
      if (RECURSE.BREAK == result) then
        return result
      end
      if (RECURSE.DIVEIN == result) then
        -- Check whether we have child items.
        if (self:NumChildren(cur) > 0) then
          local hItemChild = self:GetChildItem(cur)
          result = recurse(hItemChild)
          if (RECURSE.BREAK == result) then
            return result
          end
        end
      end
      -- Go to next sibling item.
      cur = self:GetNextSiblingItem(cur);
    end
  end

  -- If hItem is NULL, start search from root item.
  hitem = hitem or self:GetRootItem()
  recurse(hitem)
end

-- expand all items
mtTreeView.ExpandAll = function(self, root)
  self:foreachItem( root,
    function(tree, item)
      if (tree:NumChildren(item) > 0) then
        tree:Expand(item)
      return RECURSE.DIVEIN
      end
    return RECURSE.CONTINUE
    end
  )
end

function mtTreeView:create(parent)
  self.parent = parent

  local x, y, w, h = getPosSize(self)
  local hParent = self.parent.hwnd     -- parent window handle
  local style   = bor(WS_CHILD, WS_VISIBLE, WS_TABSTOP, self.style or 0)

  local hwnd = winapi.CreateWindowExW(
      self.exstyle or 0,
      WC_TREEVIEWW,             -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      100,                      -- window menu handle
      moduleHandle,             -- program instance handle
      0)                        -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  return self
end

function TreeView(args)
  return Window(args, mtTreeView)
end


--------------------------------------------------------------------
-- TabControl
--
WC_TABCONTROLW = _T("SysTabControl32")

mtTabControl = setmetatable({ class="TabControl" }, { __index =  mtWindow })


function mtTabControl:create(parent)
  self.parent = parent

  local x, y, w, h = getPosSize(self)
  local hParent = self.parent.hwnd     -- parent window handle
  local style   = bor(WS_CHILD, WS_VISIBLE, WS_TABSTOP, self.style or 0)

  local hwnd = winapi.CreateWindowExW(
      self.exstyle or 0,
      WC_TABCONTROLW,           -- window class name
      self.label .. "\0\0",           -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      100,                      -- window menu handle
      moduleHandle,             -- program instance handle
      0)                        -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  --
  assert(self.children, string.format("tabcontrol '%s' should contain childrens", self.id))
  for _, ch in ipairs(self.children) do
    self:InsertItem(ch.label)
  end

  -- init children and layout
  self:initChildren()

  return self
end

function mtTabControl:setBounds(x,y,w,h,repaint)
  -- print("mtTabControl:setBounds", self.id, x,y,w,h)
  mtWindow.setBounds(self,x,y,w,h,repaint)

  -- layout tab content
  if (self.layout) then
    self.layout:layoutContainer(self)
  else
    PositionLayout:layoutContainer(self)
  end
end

function mtTabControl:getBounds()
  local rc = winapi.RECT:new()
  winapi.GetClientRect(self.hwnd, rc)
  self:AdjustRect(rc, false)
  return rc
end

function mtTabControl:AdjustRect(rc, larger)
  larger = toBOOL(larger)
  return winapi.SendMessageW(self.hwnd, TCM_ADJUSTRECT, larger, rc)
end

function mtTabControl:GetCurSel()
  return winapi.SendMessageW(self.hwnd, TCM_GETCURSEL)
end

function mtTabControl:GetItemCount(text)
  return winapi.SendMessageW(self.hwnd, TCM_GETITEMCOUNT)
end


function mtTabControl:InsertItem(text, pos)
    pos = pos or self:GetItemCount()
  local tci = winapi.TCITEMW:new()
  tci.mask    = TCIF_TEXT
  tci.pszText = text .. "\0\0"
  tci.iImage  = -1
  return winapi.SendMessageW(self.hwnd, TCM_INSERTITEMW, pos, tci)
end

function mtTabControl:OnNotify(nmh)
  if (TCN_SELCHANGE == nmh.code) then
    -- by default use TabLayout instance to select correct child
    if (self.layout and self.layout.setActive) then
      self.layout:setActive(self:GetCurSel() + 1)
    end
  end
  return nil
end

function TabControl(args)
  -- by default use TabLayout instance
  args.layout = args.layout or venster.TabLayout()

  return Window(args, mtTabControl)
end

--------------------------------------------------------------------
-- Dialog
--

mtDialog = setmetatable({ class="Dialog" }, { __index =  mtWindow })


function mtDialog:create(parent)
  self.parent = parent

  local hParent = 0
  if (self.parent) then
	hParent = self.parent.hwnd     -- parent window handle
  end

  local x, y, w, h = getPosSize(self)
  local style   = bor(0, self.style or 0)

  -- select font
  --   if (DS_SETFONT) {
  --     use font specified in template
  --   } else if (DS_FIXEDSYS) {
  --     use GetStockFont(SYSTEM_FIXED_FONT);
  --   } else {
  --     use GetStockFont(SYSTEM_FONT);
  --   }

  -- cx = XDLU2Pix(DialogTemplate.cx);
  -- cy = YDLU2Pix(DialogTemplate.cy);

  -- convert to nonclient area
  -- RECT rcAdjust = { 0, 0, cxDlg, cyDlg };
  -- AdjustWindowRectEx(&rcAdjust, dwStyle, hmenu != NULL, dwExStyle);
  -- int cxDlg = rcAdjust.right - rcAdjust.left;
  -- int cyDlg = rcAdjust.bottom - rcAdjust.top;

  -- if ~DS_ABSALIGN
  --    POINT pt = { XDLU2Pix(DialogTemplate.x),
  --                 YDLU2Pix(DialogTemplate.y) };
  --   ClientToScreen(hwndParent, &pt);



  local wasVisible = (bit.band(style, WS_VISIBLE) > 0)
  style   = band(style, bnot(WS_VISIBLE))

  -- remove per class style bits
  style   = band(style, 0xFFFF0000)

  print("WC_DIALOG", WC_DIALOG)

  local hwnd = winapi.CreateWindowExW(
      self.exstyle or 0,
      WC_DIALOG,                -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      hParent,
      0,                        -- window menu handle
      moduleHandle,             -- program instance handle
      0)                        -- creation parameters
  winapi.Assert(hwnd)
  print("hwnd", hwnd)
  setWindowPeer(hwnd, self)

  -- set dialog procedure
  -- winapi.SetWindowLongPtr(hwnd, DWLP_DLGPROC, winapi.GetDefDlgProc());

  -- set window font
  -- SetWindowFont(hdlg, hf, FALSE);

  -- init children and layout
  self:initChildren()

  -- init helpids/fonts of childs
  -- SetWindowContextHelpId(hwndChild, ItemTemplate.dwHelpID);
  -- SetWindowFont(hwndChild, hf, FALSE);

  -- The default focus is the first item that is a valid tab-stop.
  -- local hwndDefaultFocus = GetNextDlgTabItem(hdlg, NULL, FALSE);
  -- if (SendMessage(hdlg, WM_INITDIALOG, hwndDefaultFocus, lParam)) {
  --    SetDialogFocus(hwndDefaultFocus);
  -- }

  -- if (fWasVisible) then
  --  self:show()
  -- end

  return self
end

function Dialog(args)
  return Window(args, mtDialog)
end

--------------------------------------------------------------------
-- Application
--
mtApplication = { }

function mtApplication:run(...)
  return self.mainframe:runmodal(nil, ...)
end


---------------------------------------------------------------------
if (UNDER_CE) then

  local mtPocketPCApplication = setmetatable({ class="PocketPCApplication" }, { __index =  mtApplication })

  function mtPocketPCApplication:run(...)

    -- SHInitExtraControls() should be called once during
    -- startup to initialize any device specific controls.
    if (winapi.SHInitExtraControls) then
      winapi.SHInitExtraControls()
    end

    return mtApplication.run(self, ...)
  end

  function Application(frame)
    local self = { mainframe = frame }
    return setmetatable(self, { __index = mtPocketPCApplication })
  end

else

  function Application(frame)
    local self = { mainframe = frame }
    return setmetatable(self, { __index = mtApplication })
  end

end

---------------------------------------------------------------------
-- PocketPCFrame
--
mtPocketPCFrame = setmetatable({ class="PocketPCFrame" }, { __index = mtWindow })

function mtPocketPCFrame:AttachMenuKeys()
  local hwndMB = winapi.SHFindMenuBar(self.hwnd)
    if (hwndMB) then
      -- ignore the phone key
      winapi.SendMessageW(hwndMB, SHCMBM_OVERRIDEKEY, VK_TTALK,
          MAKELPARAM( bor(SHMBOF_NODEFAULT,SHMBOF_NOTIFY),
                      bor(SHMBOF_NODEFAULT,SHMBOF_NOTIFY)));
  end
end

function mtPocketPCFrame:ReleaseMenuKeys()
  local hwndMB = winapi.SHFindMenuBar(self.hwnd)
    if (hwndMB) then
      -- enable the phone key
      winapi.SendMessageW(hwndMB, SHCMBM_OVERRIDEKEY, VK_TTALK,
          MAKELPARAM( bor(SHMBOF_NODEFAULT,SHMBOF_NOTIFY),
                      0));
  end
end

function mtPocketPCFrame:create(parent)
  print("mtPocketPCFrame:create ", toASCII(self.label))

  self.ctrlid = idGenerator:createid()
  self.classname = self.classname or _T( "guiwin_" .. self.ctrlid )

  registerclass(self.classname, self)

  local x, y, w, h = getPosSize(self)
  local style   = self.style or WS_VISIBLE
  local exstyle = self.exstyle or 0

  if (self.layout) then
    self.layout.parent = self
  end

  local parenthwnd = parent
  if ("table" == type(parent)) then
    parenthwnd = parent.hwnd.handle
  end

  local hwnd = winapi.CreateWindowExW(
      exstyle,
      self.classname,           -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x,y,w,h,
      parenthwnd or 0,          -- parent window handle
      0,                        -- window menu handle
      moduleHandle,             -- program instance handle
      registerCreate(self));    -- creation parameters
  winapi.Assert(hwnd)
  setWindowPeer(hwnd, self)

  return self
end

mtPocketPCFrame[WM_CREATE] = function(self, wParam, lParam)

  -- call
  self:initChildren()

  if (winapi.SHDoneButton) then
    winapi.SHDoneButton(self.hwnd, SHDB_HIDE)
  end

  if (UNDER_CE and winapi.SHCreateMenuBar and winapi.SHInitDialog) then

    local hmenu = nil
    if (self.menu) then
      hmenu = self.menu:create()
    end

    -- create PocketPC specific menu bar
    local mbi = winapi.SHMENUBARINFO:new()
    mbi.cbSize     = #mbi
    mbi.hwndParent = self.hwnd.handle
    mbi.hInstRes   = winapi.GetModuleHandleW(nil)
    mbi.dwFlags = SHCMBF_EMPTYBAR
    if (hmenu) then
      mbi.dwFlags = SHCMBF_HMENU
      mbi.nToolBarId = hmenu
    end
    if (not winapi.SHCreateMenuBar(mbi)) then
      error(WinError())
    end

    -- remember menubar handle
    self.hwndMB = mbi.hwndMB

    -- disable keys
    self:AttachMenuKeys()

    -- Windows Mobile applications should always display their main window
    -- full-screen. We're going to let the OS do this for us by calling
    -- SHInitDialog, even though technically this window isn't a dialog window.

    -- print(">> SHInitDialog")
    local shidi = winapi.SHINITDLGINFO:new()
    shidi.dwMask = SHIDIM_FLAGS
    shidi.hDlg = self.hwnd.handle
    shidi.dwFlags = bor(SHIDIF_SIZEDLGFULLSCREEN, SHIDIF_SIPDOWN)
    winapi.SHInitDialog(shidi)
    -- print("<< SHInitDialog")
  end

  -- call OnCreate
  if (self.OnCreate) then
    return self:OnCreate(createStruct)
  end
  return 1
end


--[[
mtPocketPCFrame[WM_KEYDOWN] = function(self, wParam, lParam)
  -- Allow ESC to quit the application. Most users won't ever see
  -- this, but it's handy for debugging.
  if (wParam == VK_ESCAPE) then
    -- print("-> Escaping")
    winapi.PostQuitMessage(0);
  else
    return mtWindow[WM_KEYDOWN](self, wParam, lParam)
  end
  return 0
end
--]]


mtPocketPCFrame[WM_ACTIVATE] = function(self, wParam, lParam)
--[[
  if (WA_INACTIVE ~= LOWORD(wParam)) then
    print("mtPocketPCFrame_WM_ACTIVATE", toASCII(self.label))
    winapi.SHFullScreen( self.hwnd, bor(SHFS_SHOWTASKBAR, SHFS_SHOWSIPBUTTON))
  end
--]]
--[[
  if (winapi.SHHandleWMActivate) then
    if (nil == self.shai) then
      self.shai = winapi.SHACTIVATEINFO:new()
      self.shai.cbSize = #self.shai
    end
    print("winapi.SHHandleWMActivate")
    winapi.SHHandleWMActivate(self.hwnd, wParam, lParam, self.shai, 1)
  end
--]]
  if (self.OnActivate) then
    self:OnActivate()
  end
  return nil
end

mtPocketPCFrame[WM_SETTINGCHANGE] = function(self, wParam, lParam)
  if (winapi.SHHandleWMSettingChange) then
    winapi.SHHandleWMSettingChange(self.hwnd, wParam, lParam, self.shai)
  end
  return nil
end

function PocketPCFrame(args)
  return Window(args, mtPocketPCFrame)
end


if (UNDER_CE) then
  Frame = PocketPCFrame
else
  Frame = Window
end

require("venster.layout")
require("venster.winres")


-- error handling

--[[
function printMsgProcError(errormsg, hwnd, Msg, wParam, lParam)
	print("Error in WndProc", hwnd, MSG_CONSTANTS[msg] or msg, wParam, lParam)
	print(errormsg)
	print(debug.traceback())
end
--]]
