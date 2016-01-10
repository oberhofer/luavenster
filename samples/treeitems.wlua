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


-- command IDs
ID_EXIT    			= 1000
ID_ADD_BANANAS   	= 1001
ID_ADD_RASPBERRIES  = 1002


--==============================================================


local mainWindow = venster.Window{
  label = _T("Main window"),
  style = bor(WS_VISIBLE, WS_OVERLAPPEDWINDOW),

  children = {
    venster.TreeView{
      id = "treeView",
      label  = _T"Tree",
      style  = bor(WS_CHILD, WS_VISIBLE, TVS_HASLINES, TVS_LINESATROOT, TVS_HASBUTTONS),
      pos    = { x=0, y=0, w=100, h=100 }
    },

    venster.Panel{
      id = "panel",
      label  = _T"panel",
      pos    = { x=100, y=0, w=100, h=100 },

      children = {
        venster.Edit{
          id = "lblTop",
          label  = _T"",
          pos    = { x=0, y=0, w=100, h=100 }
        },

        venster.Edit{
          id = "lblBottom",
          label  = _T"",
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

    local tv = self.children.treeView

    tv:setRedraw(FALSE)
    local root = tv:AddItem(0, 0, { text = _T("fruits") } )

    local function insertnodes(collection)
      local subitem = tv:AddItem(root, 0, { text = _T(collection), param = _T(collection) } )
    end

    local collections = { "apples", "pears", "oranges", "lemons", "strawberries", "raspberries", "pineapples" }
    for _, col in ipairs(collections) do
      insertnodes(col)
    end

    tv:setRedraw(TRUE)
    tv:ExpandAll()

    return nil
  end,


  [WM_NOTIFY] = {

	[TVN_SELCHANGEDW] = function(self, nmh)
		local nmtv = winapi.NMTREEVIEWW:attach(nmh)

		-- set text of selected item in lblTop
		self.children.panel.children.lblTop:setText(nmtv.itemNew.lParam.value or _T(""))
		return nil
	end,
    [TVN_DELETEITEMW] = function(self, nmh)
		local nmtv = winapi.NMTREEVIEWW:attach(nmh)
		print("release", nmtv.itemOld.lParam)
		print("release ref", nmtv.itemOld.lParam.ref)
		print("release value", nmtv.itemOld.lParam.value)
		nmtv.itemOld.lParam:release()
		return nil
    end,
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
  },

  [WM_CONTEXTMENU] = function(self, wParam, lParam)
    -- print("handle WM_CONTEXTMENU")

    local ptMouse = GET_POINT_LPARAM(lParam)

	-- print(lParam)
	-- print(ptMouse)

    -- if menu key or Shift-F10
    if (ptMouse.x == -1 and ptMouse.y == -1) then
      ptMouse = winapi.GetMessagePos()
    end

	local menu = venster.Menu{
		{
		  name = "ContextMenu",
		  { name = "Add &bananas",      id=ID_ADD_BANANAS     },
		  { name = "Add &raspberries",  id=ID_ADD_RASPBERRIES },
		},
	  }

	menu:create()
	local popup = winapi.GetSubMenu(menu.hmenu, 0);
	winapi.TrackPopupMenu(popup, TPM_LEFTALIGN, ptMouse.x, ptMouse.y, 0, self.hwnd, nil)

    return 0
  end,


	OnCommand = function(self, command, isAccel)
		-- print("OnCommand", command)
		if (ID_ADD_BANANAS == command) then
			self:AddNode(_T"bananas")
		elseif (ID_ADD_RASPBERRIES == command) then
			self:AddNode(_T"raspberries")
		end
		return 0
	end,

	AddNode = function(self, text)

		-- get selected item
		local htree = self.children.treeView
		local hitem = htree:GetSelectedItem()

		if (hitem) then
			local tvipar = htree:GetItem(hitem)

			-- add node to treeview
			htree:AddItem(hitem, 0, { text = text, param = text } )
			htree:Expand(hitem)
		end
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

