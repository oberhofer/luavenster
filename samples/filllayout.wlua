--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates fill layout
  
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

  children = {
    venster.Label{
      id = "btnSouth",
      title = _T"South",
      style = bor(WS_VISIBLE, WS_BORDER)
    },

    venster.Button{
      id = "btnWest",
      title = _T"West",
    },

    venster.Button{
      id = "btnNorth",
      title = _T"North",
    },

    venster.Button{
      id = "btnEast",
      title = _T"East",
    },

    venster.Label{
      id = "btnCenter",
      title = _T"Center",
      style = bor(WS_VISIBLE, WS_BORDER)
    },
  },

  layout = venster.FillLayout{
    -- dir = "vertical",
    dir = "horizontal",
    spacing = 20,
    "btnSouth",
    "btnWest",
    "btnNorth",
    "btnEast",
    "btnCenter"
  },

  OnCreate = function(self, createStruct)
    local childs = self.children

    -- add button handlers
    for _, ch in ipairs({ childs.btnSouth, childs.btnWest, childs.btnNorth, childs.btnEast, childs.btnCenter }) do
      ch.OnClicked = function (self)
        self:msgbox("Clicked Item " .. self.title, "Info", MB_OK)
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

