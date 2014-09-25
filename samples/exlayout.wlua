--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates custom layout and use of listview control
  
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
  style = bor(WS_VISIBLE, WS_SYSMENU, WS_BORDER, WS_THICKFRAME),

  OnClose = function(self)
        winapi.PostQuitMessage(0)
    return true
  end,

  children = {
    venster.ListView{
      id = "listView",
      title  = _T"ListView",
      style  = bor(LVS_REPORT,LVS_SHOWSELALWAYS,LVS_SINGLESEL,LVS_ALIGNTOP),
      exstyle= bor(LVS_EX_FULLROWSELECT),
      pos    = { x=0, y=0, w=200, h=200 },
      columns= {
        { text=_T"Number", percent=0.15 },
        { text=_T"article",  percent=0.65 },
        { text=_T"price",  percent=0.20 }
      },
      -- layout = venster.ListViewColumnLayout(),
        -- pos = { x=0, y=0, w=-1, h=-1 }
    },

    venster.Window{
      id = "delimiter",
      style = bor(WS_VISIBLE, WS_CHILD),
      title = _T"delimiter",
      hbrBackground = winapi.GetStockObject(BLACK_BRUSH),

      -- used to return preferred size
      -- w < 0 means parent width
--      pos = { x=0, y=0, w=-1, h=3 }
    },

    venster.Label{
      id = "editDetails",
      -- style = bor(WS_VISIBLE, ES_READONLY, ES_MULTILINE),
      title = _T"label",

--      pos = { x=0, y=0, w=-1, h=30 }
    },
  },

-- [[
  layout = venster.GridLayout{
      verticalSpacing = 0,
    horizontalSpacing = 0,
    colSizes = { -200 },
      rowSizes = { -200, 3, 60 },
    { "listView" },
      { "delimiter" },
      { "editDetails"  },
  },
--]]

--[[
  layout = venster.FillLayout{
    dir = "vertical",
    "listView",
    "delimiter",
    "editDetails"
  },
--]]

  OnCreate = function(self)
    -- local root = self.children.treeView:AddItem(0, 0, { text = "hello" } )
    -- local subitem = self.children.treeView:AddItem(root, 0, { text = "subitem" } )

--    self.children.listView:EnableGroups(true)

--    print(">>", self.children.listView:InsertGroup({ name=_T"group1", id=1 }))

    self.children.listView:AddRows(
      {
        { _T"1", _T"child1" },
        { _T"2", _T"child2" },
        { _T"3", _T"child3" },
        { _T"4", _T"child4" }
      }
--      , 1
    )

--    self.children.listView:InsertGroup({ name=_T"group2", id=2 })

    self.children.listView:AddRows(
      {
        { _T"5", _T"child1" },
        { _T"6", _T"child2" },
        { _T"7", _T"child3" },
        { _T"8", _T"child4" }
      }
--      , 2
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

