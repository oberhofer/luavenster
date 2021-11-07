--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates use of listview control
  
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
  style = bor(WS_VISIBLE, WS_SYSMENU),

  OnClose = function(self)
    winapi.PostQuitMessage(0)
    return true
  end,

  children = {
    venster.ListView{
      id = "listView",
      label  = "ListView",
      style  = bor(LVS_REPORT,LVS_SHOWSELALWAYS,LVS_SINGLESEL,LVS_ALIGNTOP),
      exstyle= bor(LVS_EX_FULLROWSELECT),
      pos    = { x=0, y=0, w=200, h=200 },
      columns= {
        { text="Number", percent=0.15 },
        { text="article",  percent=0.65 },
        { text="price",  percent=0.20 }
      },
      layout = venster.ListViewColumnLayout(),
    }
  },

  layout = venster.FillLayout{
    dir = "horizontal",
    "listView"
  },

  OnCreate = function(self)

    self.children.listView:AddRows(
      {
        { "1", "child1" },
        { "2", "child2" },
        { "3", "child3" },
        { "4", "child4" }
      }
    )

    self.children.listView:AddRows(
      {
        { "5", "child1" },
        { "6", "child2" },
        { "7", "child3" },
        { "8", "child4" }
      }
    )

    text = self.children.listView:GetItemText(1,1)

    print(#text, text)


    row = self.children.listView:GetRow(2, {1, 2})
    print(#row)

    for idx, item in ipairs(row) do
      print(idx, item)
    end

  end,
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

