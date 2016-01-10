--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates tree view control

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

	local tv = self.children.treeView

    local root = tv:AddItem(0, 0, { text = _T("root") } )

    local subitem = tv:AddItem(root, 0, { text = _T("subitem") } )

    tv:AddItems(subitem, TVI_LAST,
      {
        { _T("child1") },
        { _T("child2") },
        { _T("child3") },
        { _T("child4") }
      }
    )

    tv:ExpandAll(root)

  end,

  [WM_NOTIFY] = {
    [NM_RCLICK] = function(self, nmh)
		-- select item on right click
		local htree = self.children.treeView

		local tvh = htree:Hittest()
		if (tvh) then
		  htree:SelectItem(tvh.hItem)
		end

		-- don't suppress default handling
		return nil
	end
  }
}


--==============================================================

local app = venster.Application(mainWindow)
app:run()

