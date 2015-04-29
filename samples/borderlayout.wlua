--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates border layout
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")

local bit = require("bit")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

--==============================================================

local mainWindow = venster.Window{
  label = _T("Main window"),
  style = bor(WS_VISIBLE, WS_SYSMENU),

  children = {
    venster.Button{
      id = "btnSouth",
      label = _T"South",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnWest",
      label = _T"West",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnNorth",
      label = _T"North",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnEast",
      label = _T"East",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnCenter",
      label = _T"Center",
      pos = { x=0, y=0, w=100, h=100 }
    },
  },

  layout = venster.BorderLayout{
    fillCorners = true,
    south       = "btnSouth",
    west        = "btnWest",
    north       = "btnNorth",
    east        = "btnEast",
    center      = "btnCenter"
  },

  OnCreate = function(self, createStruct)
    local childs = self.children

    -- add button handlers
    for _, ch in ipairs({ childs.btnSouth, childs.btnWest, childs.btnNorth, childs.btnEast, childs.btnCenter }) do
      ch.OnClicked = function (self)
        self:msgbox("Clicked Item " .. toASCII(self.label), "Info", MB_OK)
      end
    end
    return nil
  end,

  OnClose = function (self)
    winapi.PostQuitMessage(0)
    return 0
  end
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

