--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates tree view control
  
--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("winapi")

local bit = require("bit")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor


--==============================================================


local mainWindow = venster.Window{
  title = _T("Main window"),
  style = bor(WS_VISIBLE, WS_OVERLAPPEDWINDOW),

  children = {
    venster.TreeView{
      id = "treeView",
      title  = _T"Tree",
      style  = bor(WS_CHILD, WS_VISIBLE, TVS_HASLINES, TVS_LINESATROOT, TVS_HASBUTTONS),
      pos    = { x=0, y=0, w=100, h=100 }
    },

    venster.Panel{
      id = "panel",
      title  = _T"panel",
      pos    = { x=100, y=0, w=100, h=100 },

      children = {
        venster.Edit{
          id = "lblTop",
          title  = _T"",
          pos    = { x=0, y=0, w=100, h=100 }
        },

        venster.Edit{
          id = "lblBottom",
          title  = _T"",
          pos    = { x=100, y=0, w=100, h=100 }
        },
      },
      layout = venster.SashLayout{
        dir       = "vertical",
        positions = { 0.8 },
        "lblTop",
        "lblBottom",
      }
    },
  },

  layout = venster.SashLayout{
    dir       = "horizontal",
    positions = { 0.3 },
    "treeView",
    "panel"
  },

  OnCreate = function(self, createStruct)

    self.children.treeView:setRedraw(FALSE)

    local root = self.children.treeView:AddItem(0, 0, { text = _T("fruits") } )

    local function insertnodes(collection)
      local subitem = self.children.treeView:AddItem(root, 0, { text = _T(collection), param = _T(collection) } )
    end

    local collections = { "apples", "pears", "oranges", "lemons", "strawberries", "raspberries", "pineapples" }

    for _, col in ipairs(collections) do
      insertnodes(col)
    end

    self.children.treeView:setRedraw(TRUE)

    self.children.treeView:ExpandAll()


    return nil
  end,

  OnNotify = function(self, code, lParam)
    -- print("OnNotify", code - TVN_FIRST)
    if (TVN_SELCHANGEDW == code) then
      local nmtv = winapi.NMTREEVIEWW:attach(lParam)

      print("Select item:", self, lParam)

      self.children.panel.children.lblTop:setText(nmtv.itemNew.lParam.value or "")
    elseif (TVN_DELETEITEMW == code) then
      local nmtv = winapi.NMTREEVIEWW:attach(lParam)
      print("release", nmtv.itemOld.lParam)
      print("release ref", nmtv.itemOld.lParam.ref)
      print("release value", nmtv.itemOld.lParam.value)
      nmtv.itemOld.lParam:release()
    end
    return nil
  end,

  OnClose = function (self)
    self.children.treeView:DeleteItem(TVI_ROOT)

    winapi.PostQuitMessage(0)
    return 0
  end
}


--==============================================================





local app = venster.Application(mainWindow)
app:run()

