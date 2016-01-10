--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates use of sashes

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
      label = _T("Top"),
    },

    venster.Button{
      id = "btnCenter",
      label = _T("Center"),
    },

    venster.Button{
      id = "btnBottom",
      label = _T("Bottom"),
  },

  },
  layout = venster.SashLayout{
    -- dir       = "horizontal",
    dir       = "vertical",
    positions = { 0.2, 0.4 },
    "btnTop",
    "btnCenter",
    "btnBottom"
  },

  OnCreate = function(self, createStruct)
    local childs = self.children

    -- add button handlers
    for _, ch in ipairs({ childs.btnLeft, childs.btnMiddle, childs.btnRight }) do
      ch.OnClicked = function (self)
        print("Pressed", self.label)
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

