--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates tab control

--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")


local bit = require("bit32")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

--==============================================================
-- create main window

local mainWindow = venster.Window{

  label = "Main window",
  style = bor(WS_VISIBLE, WS_OVERLAPPEDWINDOW),

  OnClose = function(self)
        winapi.PostQuitMessage(0)
    return true
  end,

  children = {
    venster.Label{
      id = "label",
      label = "label",
      style = bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
    },
    venster.TabControl{
      id = "tabcontrol",
      label = "tabcontrol",
      style = bor(WS_CHILD, WS_VISIBLE),
      pos   = { x=0, y=0, w=100, h=100 },
      children = {
        venster.Label{
          id = "tab1",
          label = "Tab1",
          style = bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
        },
        venster.Label{
          id = "tab2",
          label = "Tab2",
          style = bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
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
--    self.children.tabcontrol:InsertItem("Tab 1")
--    self.children.tabcontrol:InsertItem("Tab 2")
--    self.children.tabcontrol:InsertItem("Tab 3")
  end,
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

