--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates multiple layout and use of panels
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")

local bit = require("bit32")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

--==============================================================

local mainWindow = venster.Window{
  label = _T("Main window"),
  style = bor(WS_VISIBLE, WS_SYSMENU),

  children = {
    venster.Button{
      id = "btnTop",
      label  = _T"top",
      pos    = { x=100, y=0, w=100, h=100 }
    },

    venster.Panel{
      id = "panel",
      label  = _T"panel",
      pos    = { x=100, y=0, w=100, h=100 },

      children = {
        venster.Button{
          id = "btnBottomLeft",
          label  = _T"bottom left",
          pos    = { x=0, y=0, w=100, h=100 }
        },

        venster.Button{
          id = "btnBottomRight",
          label  = _T"bottom right",
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

