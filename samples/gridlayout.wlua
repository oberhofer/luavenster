--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates grid layout
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("winapi")

--==============================================================
-- create main window


local mainWindow = venster.Window{
  title = _T("Main window"),

  children = {
    venster.Button{
      id = "btnSouth",
      title = _T"South",
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

    venster.Button{
      id = "btnCenter",
      title = _T"Center",
    },
  },

  layout = venster.GridLayout{
    columnSizes = { 0, 0, 0, -200 },
    rowSizes    = { -200, -200 },
    { "btnSouth", "btnWest", ">"        , "btnNorth" },
    { "btnEast" , ""       , "btnCenter", ">"        }
  },

  OnCreate = function(self, createStruct)
    local childs = self.children

    -- add button handlers
    for _, ch in ipairs({ childs.btnSouth, childs.btnWest, childs.btnNorth, childs.btnEast, childs.btnCenter }) do
      ch.OnClicked = function (self)
        msgbox("Clicked Item " .. self.title, "Info", MB_OK)
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

