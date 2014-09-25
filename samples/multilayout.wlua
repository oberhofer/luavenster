--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates multiple layout and use of panels
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("winapi")

--==============================================================


local mainWindow = venster.Window{
  title = _T("Main window"),

  children = {
    venster.Button{
      id = "btnTop",
      title  = _T"top",
      pos    = { x=100, y=0, w=100, h=100 }
    },

    venster.Panel{
      id = "panel",
      title  = _T"panel",
      pos    = { x=100, y=0, w=100, h=100 },

      children = {
        venster.Button{
          id = "btnBottomLeft",
          title  = _T"bottom left",
          pos    = { x=0, y=0, w=100, h=100 }
        },

        venster.Button{
          id = "btnBottomRight",
          title  = _T"bottom right",
          pos    = { x=100, y=0, w=100, h=100 }
        },
      },
      layout = venster.SashLayout{
        dir       = "horizontal",
        positions = { 0.2 },
        "btnBottomLeft",
        "btnBottomRight",
      }
    },
  },

  layout = venster.SashLayout{
    dir       = "vertical",
    positions = { 0.2 },
    "btnTop",
    "panel"
  },

  OnCreate = function(self, createStruct)
    local childs = self.children

    -- add button handlers
    for _, ch in ipairs({ childs.btnTop, childs.panel.children.btnBottomLeft, childs.panel.children.btnBottomRight }) do
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

