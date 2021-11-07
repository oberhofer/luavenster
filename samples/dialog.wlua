--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates fill layout

--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")

local bit = require("bit")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

--==============================================================
-- create main window

local mainWindow = venster.Dialog{
  label = "Main window",
  style = bor(WS_VISIBLE, WS_SYSMENU),

  children = {
    venster.Label{
      id = "btnSouth",
      label = "South",
      style = bor(WS_VISIBLE, WS_BORDER)
    },

    venster.Button{
      id = "btnWest",
      label = "West",
    },

    venster.Button{
      id = "btnNorth",
      label = "North",
    },

    venster.Button{
      id = "btnEast",
      label = "East",
    },

    venster.Label{
      id = "btnCenter",
      label = "Center",
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
        self:msgbox("Clicked Item " .. self.label, "Info", MB_OK)
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

