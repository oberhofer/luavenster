--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates border layout
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("winapi")

--==============================================================

local mainWindow = venster.Window{
  title = _T("Main window"),

  children = {
    venster.Button{
      id = "btnSouth",
      title = _T"South",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnWest",
      title = _T"West",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnNorth",
      title = _T"North",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnEast",
      title = _T"East",
      pos = { x=0, y=0, w=100, h=100 }
    },

    venster.Button{
      id = "btnCenter",
      title = _T"Center",
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
        self:msgbox("Clicked Item " .. toASCII(self.title), "Info", MB_OK)
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

