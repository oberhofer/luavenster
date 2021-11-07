--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates row layout

--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")


--==============================================================

local mainWindow = venster.Window{
  label = "Main window",

  children = {
    venster.Button{
      id = "btnSouth",
      label = "South",
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

    venster.Button{
      id = "btnCenter",
      label = "Center",
    },
  },

  layout = venster.RowLayout{
    dir="horizontal",
    wrap=true,
    -- pack=false,
    -- fill=true,
    justify=true,
    center=true,

    "btnSouth",
    "btnWest",
    "btnNorth",
    "break",
    "btnEast",
    "btnCenter"
  },

  OnCreate = function(self, createStruct)
    local childs = self.children

    -- add button handlers
    for _, ch in ipairs({ childs.btnSouth, childs.btnWest, childs.btnNorth, childs.btnEast, childs.btnCenter }) do
      ch.OnClicked = function (self)
        self:msgbox("Clicked Item " .. self.id, "Info", MB_OK)
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
