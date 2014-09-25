--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates tab control
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("winapi")


local bit = require("bit")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

--==============================================================
-- create main window

local mainWindow = venster.Window{

  title = _T("Main window"),
  style = bor(WS_VISIBLE, WS_OVERLAPPEDWINDOW),

  OnClose = function(self)
        winapi.PostQuitMessage(0)
    return true
  end,

  children = {
    venster.Label{
      id = "label",
      title  = _T("label"),
      style=bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
    },
    venster.TabControl{
      id = "tabcontrol",
      title  = _T("tabcontrol"),
      style  = bor(WS_CHILD, WS_VISIBLE),
      pos    = { x=0, y=0, w=100, h=100 },
      children = {
        venster.Label{
          id = "tab1",
          title  = _T("Tab1"),
          style=bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
        },
        venster.Label{
          id = "tab2",
          title  = _T("Tab2"),
          style=bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
        },
      },
      layout = venster.TabLayout()
    }
  },

  layout = venster.FillLayout{
    dir = "vertical",
    -- spacing = 5,
    "label",
    "tabcontrol"
  },


  OnCreate = function(self)
--    self.children.tabcontrol:InsertItem(_T("Tab 1"))
--    self.children.tabcontrol:InsertItem(_T("Tab 2"))
--    self.children.tabcontrol:InsertItem(_T("Tab 3"))
  end,
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

