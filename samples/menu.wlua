--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates a window with a menu

--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")

local bit = require("bit")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor

-- command IDs
ID_EXIT    = 1000
ID_MENU1   = 1001
ID_MENU2   = 1002

--==============================================================
-- create main window

local mainWindow = venster.Window{

  label = _T("Main window"),
  style = bor(WS_VISIBLE, WS_SYSMENU),

  menu   = venster.Menu{
    {
      name = "File",
      { name = "E&xit",                   id=ID_EXIT },
    },
    {
      name = "Edit",
      { name = "Menu 1",                  id=ID_MENU1 },
      { name = "Menu 2",                  id=ID_MENU2  }
    }
  },

  OnClose = function(self)
        winapi.PostQuitMessage(0)
    return true
  end,

  children = {
    venster.TreeView{
      id = "treeView",
      label  = _T"Tree",
      style  = bor(WS_CHILD + WS_VISIBLE + TVS_HASLINES + TVS_LINESATROOT + TVS_HASBUTTONS),
      pos    = { x=0, y=0, w=100, h=100 }
    }
  },

  layout = venster.FillLayout{
    dir = "horizontal",
    "treeView"
  },

  OnCreate = function(self)
    local root = self.children.treeView:AddItem(0, 0, { text = _T("root") } )

    local subitem = self.children.treeView:AddItem(root, 0, { text = _T("subitem") } )

    self.children.treeView:AddItems(subitem, TVI_LAST,
      {
        { _T("child1") },
        { _T("child2") },
        { _T("child3") },
        { _T("child4") }
      }
    )

    self.children.treeView:ExpandAll(root)
  end,

  -- handle commands
  OnCommand = function(self, command, isAccel)
    -- print("OnCommand", command)
    if (ID_EXIT == command) then
      self:OnClose(0)
    end
    return 0
  end,
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

