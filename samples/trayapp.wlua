--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  demonstrates use of listview control

--]]--------------------------------------------------------------------------

local venster = require("venster")
local winapi = require("luawinapi")

local http = require("socket.http")
local ltn12 = require("ltn12")

local json = require("json")


local bit = require("bit32")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor


ID_ICONNOTIFY = 1000

WM_ICONNOTIFY = (WM_USER + 1000)

ID_ADD_BANANAS      = (WM_USER + 2000)
ID_ADD_RASPBERRIES  = (WM_USER + 2001)

--==============================================================
-- create main window


local moduleHandle = winapi.GetModuleHandleW(nil)


local function getDevices()

	local body, code, reshdrs, resstat = http.request("http://127.0.0.1:8080/devices")

	-- print(body, code)

	return json.decode(body);
end


local mainWindow = venster.Window{

  label = "Main window",
  style = bor(WS_OVERLAPPEDWINDOW, WS_VISIBLE, WS_SYSMENU),

  hIcon = winapi.LoadIconW(nil, IDI_INFORMATION),
  hTrayIcon = nil,


  NotifyIcon = function(self, uMessage)
	local nid = winapi.NOTIFYICONDATAW:new();

	print("Shell_NotifyIcon", self.hTrayIcon)

	if (self.hTrayIcon == nil) then
		return
	end

	if (NIM_ADD == uMessage) then
		nid.uFlags = bor(NIF_ICON, NIF_MESSAGE, NIF_TIP)
	elseif (NIM_MODIFY == uMessage) then
		nid.uFlags = NIF_ICON
	elseif (NIM_DELETE == uMessage) then
		nid.uFlags = 0
	else
	end

	nid.cbSize = #nid
	nid.uID = ID_ICONNOTIFY
	nid.hWnd = self.hwnd
	nid.uCallbackMessage = WM_ICONNOTIFY
	nid.hIcon = self.hTrayIcon;
	nid.szTip = "Tooltip text"

	-- print(nid)

	local result = winapi.Shell_NotifyIconW(uMessage, nid)
	print("Shell_NotifyIcon", result)

  end,

  ChangeIcon = function(self, nID)
	-- hTrayIcon = AfxGetApp()->LoadIcon(nID);
	self.hTrayIcon = venster.Icon("logo.ico")
	self:NotifyIcon(NIM_MODIFY)
  end,



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
      pos    = { x=0, y=0, w=400, h=200 },
      columns= {
        { text="Name", percent=0.50 },
        { text="Address",  percent=0.30 },
        { text="State",  percent=0.20 },
      },
      layout = venster.ListViewColumnLayout(),
    }
  },

  layout = venster.FillLayout{
    dir = "horizontal",
    "listView"
  },

  OnTrayMenu = function(self, ptMouse)

	local menu = venster.Menu{
		{
		  name = "ContextMenu",
		  { name = "Add &bananas",      id=ID_ADD_BANANAS     },
		  { name = "Add &raspberries",  id=ID_ADD_RASPBERRIES },
		},
	}

	menu:create()
	menu:Track(self.hwnd, TPM_LEFTALIGN)
  end,


  OnCreate = function(self)
    -- local root = self.children.treeView:AddItem(0, 0, { text = "hello" } )
    -- local subitem = self.children.treeView:AddItem(root, 0, { text = "subitem" } )


	self:setIcon(ICON_SMALL, self.hIcon)
	self:setIcon(ICON_LARGE, self.hIcon)

	self.hTrayIcon = venster.Icon("logo.ico")
	-- self:NotifyIcon(NIM_ADD)

	self:setIcon(ICON_SMALL, self.hTrayIcon)
	self:setIcon(ICON_LARGE, self.hTrayIcon)

    self.children.listView:EnableGroups(true)

    print(">>", self.children.listView:InsertGroup({ name="Available", id=1 }))

--[[
	local devs = getDevices()
	for _, dev in ipairs(devs) do
		print(dev[1], dev[2])

		self.children.listView:AddRow( nil, { dev[2], dev[1] }, 1 )
	end
--]]


    self.children.listView:InsertGroup({ name="Running", id=2 })

    self.children.listView:AddRows(
      {
        { "5", "child1" },
        { "6", "child2" },
        { "7", "child3" },
        { "8", "child4" }
      }
      , 2
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

local trayIconHost = venster.TrayIconHost(mainWindow, venster.Icon("logo.ico"))
trayIconHost:create()

local app = venster.Application(mainWindow)
app:run()

