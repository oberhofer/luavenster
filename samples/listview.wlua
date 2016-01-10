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

  label = _T("Main window"),
  style = bor(WS_VISIBLE, WS_SYSMENU),

  OnClose = function(self)
    winapi.PostQuitMessage(0)
    return true
  end,

  children = {
    venster.ListView{
      id = "listView",
      label  = _T"ListView",
      style  = bor(LVS_REPORT,LVS_SHOWSELALWAYS,LVS_SINGLESEL,LVS_ALIGNTOP),
      exstyle= bor(LVS_EX_FULLROWSELECT),
      pos    = { x=0, y=0, w=200, h=200 },
      columns= {
        { text=_T"Number", percent=0.15 },
        { text=_T"article",  percent=0.65 },
        { text=_T"price",  percent=0.20 }
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
        { _T"1", _T"child1" },
        { _T"2", _T"child2" },
        { _T"3", _T"child3" },
        { _T"4", _T"child4" }
      }
    )

    self.children.listView:AddRows(
      {
        { _T"5", _T"child1" },
        { _T"6", _T"child2" },
        { _T"7", _T"child3" },
        { _T"8", _T"child4" }
      }
    )

    text = self.children.listView:GetItemText(1,1)

    print(#text, toASCII(text))


    row = self.children.listView:GetRow(2, {1, 2})
    print(#row)

    for idx, item in ipairs(row) do
      print(idx, toASCII(item))
    end

  end,
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

