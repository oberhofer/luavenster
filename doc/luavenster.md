![LuaVenster logo](logo.png "LuaVenster logo")

# Introduction

LuaVenster is an object oriented wrapper for GUI applications on top of the Windows API. 

Although the name LuaVenster is a reminescent to the Win32 Python GUI libraries 
Venster and VensterCE they have no common roots other than the same spirit in being a 
minimal lightweight wrapper that integrates smoothly into the target language Lua.

Please note that the development of LuaVenster is demand driven, 
so not all functionality of WinAPI controls is wrapped, yet. 

## Features

* object oriented abstraction for GUI application
* wrapper classes for windows controls
* support for different standard layouts (fill, row, border, grid, sash)
* layout for listview columns
* popup layout to support tab control usage

# Dependencies

LuaVenster depends on the

* [LuaCwrap project](http://github.com/oberhofer/luacwrap)
* [LuaWinAPI project](http://github.com/oberhofer/luawinapi)

# Installation via Luarocks

## Prerequisites

For a beginner I would recommend to install the latest "Lua for Windows" 
setup from from the [Lua for windows project](http://luaforwindows.googlecode.com) and install 
LuaVenster via LuaRocks.

Install on console via 

    luarocks install luavenster

# Reference

## Application

The starting point of a LuaVenster project is the application object, so every 
LuaVenster application contains these two lines:

    local app = venster.Application(mainWindow)
    app:run() 

It displays the mainWindow and starts the main message loop.

## GuiComponent

This is the base class for all visible and hidden GUI components. Descendants are

* Panel  (hidden place holder)
* Window (base class of all visible GUI components)

Every GuiComponent supports a preferred size (via getPreferredSize()) and most of 
the derived classes have constructor functions which have the same name as the 
class, e.g. Window() or Panel(). Most of these constructor functions take a
Lua table which is copied into the created object.
This enables to describe GUIs in a declarative way by specifiying

* zero or more child components
* an optional associated layout object or function

within this table.

## Panel

A panel is a place holder and necessary to support boxed layouts.

## Window

Window is the base class of all visible GUI components. All Controls are derived from this class.

Every window object is treated by the message loop as an array of message handlers indexed by 
the message id. In most cases LuaVenster hides this fact by defining the core message handler 
in the metatable and route then to specific OnXXX functions the user can override.
In most cases only a few of this overrides are necessary.

### Window() constructor

In the argument table of the Window you can specify an optional menu object which describes 
the window main menu.

#### Usage

This example code specifies a main window with five child controls
and a associated fill layout along with Handlers for the OnCreate and OnClose event:


    local mainWindow = venster.Window{
      title = _T("Main window"),

      children = {
        venster.Label{
          id = "btnSouth",
          title = _T"South",
          style = bor(WS_VISIBLE, WS_BORDER)
        },

        venster.Button{
          id = "btnWest",
          title = _T"West",
        },

        venster.Button{
          id = "btnNorth",
          title = _T"North",
        },

        venster.Button{
          id = "btnEast",
          title = _T"East",
        },

        venster.Label{
          id = "btnCenter",
          title = _T"Center",
          style = bor(WS_VISIBLE, WS_BORDER)
        },
      },

      layout = venster.FillLayout{
        -- dir = "vertical",
        dir = "horizontal",
        spacing = 20,
        "btnSouth",
        "btnWest",
        "btnNorth",
        "btnEast",
        "btnCenter"
      },

      OnCreate = function(self, createStruct)
        local childs = self.children

        -- add button handlers to the child controls
        for _, ch in ipairs({ childs.btnSouth, childs.btnWest, childs.btnNorth, childs.btnEast, childs.btnCenter }) do
          ch.OnClicked = function (self)
            self:msgbox("Clicked Item " .. self.title, "Info", MB_OK)
          end
        end
        return nil
      end,

      OnClose = function (self)
        winapi.PostQuitMessage(0)
        return 0
      end
    }

### Event methods

...

### Wrapper methods

...

## Controls

Currently there are wrappers for the following Controls:

* Button
* Label
* Edit
* ListView
* TreeView
* TabControl
* Menu

## Layouts

### Arrange child windows

The layouts used for arranging child windows are fill, row, border, grid and sash layout.

#### Fill layout

The fill layout is as follows:

     +------------------+
     |      child       |       dir(ection) = "vertical"
     +------------------+
     |      child       |
     +------------------+
     |      child       |
     +------------------+

or:

     +-----------------+
     |     |     |     |       dir(ection) = "horizontal"
     |     |     |     |
     |child|child|child|
     |     |     |     |
     |     |     |     |
     +-----------------+

The available space is divided into equal sized parts.

##### Usage:

    FillLayout{
      dir  = "horizontal" | "vertical",
      spacing  = horizontal/vertical spacing [pixels],
      <list of childs>
    }

##### Example:

    self.layout = venster.FillLayout{
      dir = "horizontal",
      self.btnSouth,
      self.btnWest,
      self.btnNorth,
      self.btnEast,
      self.btnCenter
    }


#### Row layout

This layout lays out components like text. If Components do not fit into
one line (row), the next Components are moved to the next line (row).

Intended 'line breaks' could be inserted by adding "break" string to the
list of childs.

If wrap=true automatic line breaks will be inserted if "line" exceeds
the available space.

If pack=false then all childs get the size of the biggest child.

If justify is set, the childs are spread across the available space.

If fill is set all childs get the same height/width depending on
horizontal/vertical layout.

If center is set, controls in a row are centered vertically in
each cell for horizontal layouts, or centered horizontally in each cell
for vertical layouts.

##### Usage:

      RowLayout{
         dir     = "horizontal" | "vertical",
         spacing = horizontal/vertical spacing [pixels],
         margin  = { <left>, <top>, <right>, <bottom> },
        <list of childs>
      }

##### Example:

    self.layout = venster.RowLayout{
      dir = "horizontal",
      spacing = 2,
      margin  = venster.Rect(2, 2, 2, 2),
      self.btnSouth,
      self.btnWest,
      self.btnNorth,
      self.btnEast,
      self.btnCenter
    }

#### Border layout

This layout has up to 5 childs called
     south
     east
     north
     west
     center

Layout is as follows:

     +------------------+
     |      south       |
     +---+----------+---+
     | w |          | e |
     | e |          | a |
     | s |  center  | s |
     | t |          | t |
     |   |          |   |
     +---+----------+---+
     |      north       |
     +------------------+

Optional the corners could be unfilled:

         +----------+
         |  south   |
     +---+----------+---+
     | w |          | e |
     | e |          | a |
     | s |  center  | s |
     | t |          | t |
     |   |          |   |
     +---+----------+---+
         |  north   |
         +----------+

Height of south/north and width of west/east is determined from
preferredLayoutSize() of the contained controls.

##### Usage:

    BorderLayout{
      fillCorners = true | false,
      south       = <child view>,
      west        = <child view>,
      north       = <child view>,
      east        = <child view>,
      center      = <child view>
    }

##### Example:

    self.layout = venster.BorderLayout{
      fillCorners = true,
      south       = self.btnSouth,
      west        = self.btnWest,
      north       = self.btnNorth,
      east        = self.btnEast,
      center      = self.btnCenter
    }

#### Grid layout

The grid layout has n columns or rows and up to m childs.

Layout is as follows (example):

     +---------+---------------------+----------+
     |    1    |          2          |     3    |
     +---------+----------+----------+----------+
     |    4    |  empty   |    5     |  empty   |
     +---------+----------+----------+----------+
     |                                          |
     |                                          |
     +------------------------------------------+

##### Remarks:

Column height and row width is determined by the
tallest/widest child in column/row.

The layout gets an table of row tables, where ">" and "<" could
be used to expand the left or right child to span further cells.

Row/Column sizes could be specified, where
positive number is fixed width/height in pixel
* 0 means shrink to fit
* -1 to -100 is percent of parent width
* < -100 means use rest (expand)

##### Usage:

    GridLayout{
      [colSizes = { list of sizes },]
      { row_1 },
      ...
      { row_n }
    }

##### Example:

    self.layout = venster.GridLayout{
      colSizes = { 0, -200, -50),
      { self.btn_1, self.btn_2, ">"         , self.btn_3  },
      { self.btn_4, ""        , self.btn_5                }
    }

    -- set row/column layout data
    self.layout.setRowData(1, { size = "30%", halign="center" } )   -- 30 %
    self.layout.setColData(1, { size = 30,    halign="center" } )   -- 30 pixel
    self.layout.setColData(2, { size = -30,   halign="left"   } )   -- 30 %
    self.layout.setColData(3, { valign="fill", halign="fill"  } )   -- expand column 2

    -- set cell layout data
    self.layout.setCellData(3, 1, { fill=true

This results in:    
    
     +---------+---------------------+----------+
     |    1    |          2          |     3    |
     +---------+----------+----------+----------+
     |    4    |  empty   |    5     |  empty   |
     +---------+----------+----------+----------+

#### Sash layout

The sash layout provides movable sashes between childs to support resizeable child width/height.
The layout is as follows:

     +------------------+
     |      child       |       dir(ection) = "vertical"
     +------------------+
     |      child       |
     +------------------+
     |      child       |
     +------------------+

or:

     +-----------------+
     |     |     |     |       dir(ection) = "vertical"
     |     |     |     |
     |child|child|child|
     |     |     |     |
     |     |     |     |
     +-----------------+

The Layout fills whole available space.
Initial size of childs is determined by the (relative) start positions
specified in self.layout.positions table.

##### Usage:

    SashLayout{
        dir  = "horizontal" | "vertical",
      positions = { list of positions in percent (1.0 = 100%) },
      <list of childs>
    }

##### Example:

    self.layout = venster.SashLayout{
      parent    = self,
      -- dir       = "horizontal",
      dir       = "vertical",
      positions = { 0.2, 0.4 },
      self.btnLeft,
      self.btnMiddle,
      self.btnRight
    }

### Size listview columns

ListViewColumnLayout is a special layout that is used to adjust the widths of listview columns.
The sizes are specified in percent of the listview size.

#### Usage

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
        layout = venster.ListViewColumnLayout(),
      } 
    }

### Switch views with TabControl

The popup layout is used to support tab control usage. It supports multiple child windows
which share the same area but only one is visible while the others are hidden.

#### Usage

    venster.TabControl{
      id = "tabcontrol",
      title  = _T("tabcontrol"),
      style  = bor(WS_CHILD, WS_VISIBLE),
      pos    = { x=0, y=0, w=100, h=100 },
      children = {
        venster.Label{
          id = "tab1",
          title  = _T("Tab1"),
          style=bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
        },
        venster.Label{
          id = "tab2",
          title  = _T("Tab2"),
          style=bor(WS_VISIBLE, WS_CHILD, WS_BORDER)
        },
      },
      layout = venster.TabLayout()
    } 

## PocketPC/WindowsCE

There is a special PocketPCFrame class which contains some PocketPC/WindowsCE
specific code, e.g. to handle the appliction menu.

# Samples

The samples folder contains example programs which demonstrates different aspects of
LuaVenster. The samples have the .wlua extension and are therefore associated with the 
wlua.exe interpreter from "Lua for Windows". 

# License

LuaVenster is licensed under the terms of the MIT license reproduced below.
This means that LuaVenster is free software and can be used for both academic
and commercial purposes at absolutely no cost.

Copyright (C) 2011 Klaus Oberhofer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
