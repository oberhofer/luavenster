--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  Layout classes

--]]--------------------------------------------------------------------------

module("venster", package.seeall)

require("venster")
local winapi = require("luawinapi")

require("venster.utils")

local bit = require("bit32")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor


-- determine max size over all childs
function determineMaxSize(self)
  local result = { width=0, height=0 }
  for _, ch in ipairs(self) do
    if (type(ch) ~= "string") then
      local size = ch:getPreferredSize()
      result.width  = math.max(result.width , size.width)
      result.height = math.max(result.height, size.height)
    end
  end
  return result
end


---------------------------------------------------------------------
--[[

    PositionLayout


    place children relative to parent

  Usage:

    PositionLayout

  Example:

    self.layout = venster.PositionLayout

  Remark

    PositionLayout is a singleton and does not contain/use a internal state

--]]


mtPositionLayout = {
  margin  = venster.Rect(0, 0, 0, 0),
}

function mtPositionLayout:createLayout(parent)

  -- do not change internal state

  return self
end


function mtPositionLayout:layoutContainer(parent)
  local bounds = parent:getBounds()

  -- reference point
  local x, y = bounds.left + self.margin.left, bounds.top + self.margin.top

  -- layout uses parent.children collection
  for _, ch in ipairs(parent.children or {}) do
    -- layout child
    ch:setBounds(x + ch.pos.x, y + ch.pos.y, ch.pos.w, ch.pos.h)
  end
end

function mtPositionLayout:preferredLayoutSize(parent)
  -- use parent size
end

PositionLayout = setmetatable({}, { __index = mtPositionLayout } )


---------------------------------------------------------------------
--[[

    Fill layout


    Layout is as follows:

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

  Remarks:
    Available space is divided into equal sized parts.

  Usage:

    FillLayout{
      dir  = "horizontal" | "vertical",
      spacing  = horizontal/vertical spacing [pixels]
      <list of childs>
    }

  Example:

    self.layout = venster.FillLayout{
      dir = "horizontal",
      self.btnSouth,
      self.btnWest,
      self.btnNorth,
      self.btnEast,
      self.btnCenter
    }

--]]


mtFillLayoutBase = {}

function mtFillLayoutBase:createLayout(parent)
  self.parent = parent

  -- print("mtFillLayoutBase:createLayout")

  -- resolve control references
  for idx, name in ipairs(self) do
    local ch = parent.children[name]
    assert(ch, "unknown name: " .. name)
    self[idx] = ch or name
  end

  return self
end



mtFillLayoutVertical = {
  margin  = venster.Rect(0, 0, 0, 0),
  spacing = 0
}
setmetatable(mtFillLayoutVertical, { __index = mtFillLayoutBase })



function mtFillLayoutVertical:layoutContainer(parent)
  local bounds = parent:getBounds()

  -- print("mtFillLayoutVertical:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

    -- add spacing to move last divisor to end of available space
  local height = bounds:height() + self.spacing
  local width  = bounds:width()
    local incr   = height / #self

  local x, y = bounds.left, bounds.top

  for idx, ch in ipairs(self) do
    local nexty = math.floor(incr * idx - self.spacing)
    -- layout child
    -- print("child:", y, nexty, nexty-y)
    ch:setBounds(x, y, width, nexty-y)
    y = nexty + self.spacing
  end
end

function mtFillLayoutVertical:preferredLayoutSize(parent)
  local dim = { width=0, height=0 }

    for idx, ch in ipairs(self) do
      if (ch:isVisible()) then
      local size = ch.getPreferredSize()
      dim.width  = math.max(dim.width, size.width)
      dim.height = dim.height + size.height
      if (idx ~= 1) then
        dim.height = dim.height + self.spacing
      end
    end
  end

  local margin = self.margin
  dim.width  = dim.width  + margin.left + margin.right;
  dim.height = dim.height + margin.top  + margin.bottom;

  return dim
end

---------------------------------------------------------------------

mtFillLayoutHorizontal = {
  margin  = venster.Rect(0, 0, 0, 0),
  spacing = 0
}
setmetatable(mtFillLayoutHorizontal, { __index = mtFillLayoutBase })


function mtFillLayoutHorizontal:layoutContainer(parent)
  local bounds = parent:getBounds()

  -- print("mtFillLayoutHorizontal:", parent.label,  bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

    -- add spacing to move last divisor to end of available space
  local width  = bounds:width() + self.spacing
  local heigth = bounds:height()
    local incr   = width / #self

  local x, y = bounds.left, bounds.top

  for idx, ch in ipairs(self) do
    local nextx = math.floor(incr * idx - self.spacing)
    -- layout child
    -- print("child:", x, nextx, nextx-x)
    ch:setBounds(x, y, nextx-x, heigth)
    x = nextx + self.spacing
  end
end

function mtFillLayoutHorizontal:preferredLayoutSize(parent)
  local dim = { width=0, height=0 }

  for idx, ch in ipairs(self) do
    if (ch:isVisible()) then
    local size = ch:getPreferredSize()
    dim.width  = dim.width + size.width
    dim.height = math.max(dim.height, size.height)
    if (idx ~= 1) then
      dim.width = dim.width + self.spacing
    end
    end
  end

  local margin = self.margin
  dim.width  = dim.width  + margin.left + margin.right;
  dim.height = dim.height + margin.top  + margin.bottom;

  return dim
end

function FillLayout(arg)
  local self = arg or {}

  local mt = mtFillLayoutHorizontal
  if ("vertical" == self.dir) then
    mt = mtFillLayoutVertical
  end

  return setmetatable(self, { __index = mt } )
end

---------------------------------------------------------------------
--[[

  Row layout

    Lays out components like text. If Components do not fit into
    one line (row), the next Components are moved to the next line (row).

    Intended 'line breaks' could be inserted by adding "break" string to the
    list of childs.

    If wrap=true automatic line breaks will be inserted if "line" exceeds
    the available space.

    If pack=false then all childs get the size of the biggest child.

    If justify is set, the childs are spread across the available space.

  If fill is set all childs get the same heigth/width depending on
  horizontal/vertical layout.

  If center is set, controls in a row are centered vertically in
  each cell for horizontal layouts, or centered horizontally in each cell
  for vertical layouts.

  Remarks:

  Usage:

      RowLayout{
         dir     = "horizontal" | "vertical",
         spacing = horizontal/vertical spacing [pixels],
         margin  = { <left>, <top>, <right>, <bottom> },
        <list of childs>
      }

    Example:

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

--]]
---------------------------------------------------------------------

mtRowLayoutBase =
{
  spacing = 3,
  margin  = venster.Rect(0, 0, 0, 0),
  wrap    = true,
  pack    = true,
  fill    = false,
  justify = false,
  center  = false
}

function mtRowLayoutBase:createLayout(parent)
  self.parent = parent

  -- resolve control references
  for idx, name in ipairs(self) do
    local ch = parent.children[name]
    self[idx] = ch or name
  end
end

---------------------------------------------------------------------

mtRowLayoutVertical = setmetatable({}, { __index = mtRowLayoutBase })

function mtRowLayoutVertical:layoutContainer(parent)

  local bounds = parent:getBounds()

  -- print("mtRowLayoutVertical:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  -- determine max size over all childs
  local maxsize = determineMaxSize(self)

  local col = { height = 0, width = 0 }

  local function layoutCol()
    local y = bounds.top
    if (#col > 0) then
      local space = self.spacing
      if (self.justify) then
        space = (bounds:height() - col.height) / (#col + 1)
        y = y + space
      end

      for _, item in ipairs(col) do
        local x = bounds.left + item.x
        if (self.center) then
          x = x + ((col.width - item.w) / 2)
        end

        item.ch:setBounds(x, y, item.w, item.h)
--        if (item.ch.layout) then
--          item.ch.layout:layoutContainer(item.ch)
--        end
        y = y + item.h + space
      end
    end
    col = { height = 0, width = 0 }
  end

  local x, y = self.margin.left, self.margin.top
  for _, ch in ipairs(self) do
    -- check for "break"
    if ((type(ch) == "string") and (ch == "break")) then
      x = x + col.width + self.spacing
      y = self.margin.top
      layoutCol()
    else
      local size = ch:getPreferredSize()

      -- check for col break
      if (self.wrap and (y + size.height > bounds.bottom)) then
        x = x + col.width + self.spacing
        y = self.margin.top
        layoutCol()
      end

      if (self.fill) then
        size.width = maxsize.width
      end
      if (not self.pack) then
        size.height = maxsize.height
      end

      -- remember current column width and height (without spacing)
      col.width  = math.max(size.width, col.width)
      col.height = col.height + size.height

      col[#col+1] = { x=x, h=size.height, w=size.width, ch=ch }

      y = y + size.height + self.spacing
    end
  end
  layoutCol()
end

function mtRowLayoutVertical:preferredLayoutSize(parent)
  local dim = { width=0, height=0 }

  local row = { height = 0, width = 0 }

  local x, y = self.margin.left, self.margin.top

  -- right/bottom of last child in a row
  local last = { x=x, y=y }

  for _, ch in ipairs(self) do
    -- check for "break"
    if ((type(ch) == "string") and (ch == "break")) then
      x = x + col.width + self.spacing
      y = self.margin.top
    else
      local size = ch:getPreferredSize()

      -- check for col break
      if (self.wrap and (y + size.height > bounds.bottom)) then
        x = x + col.width + self.spacing
        y = self.margin.top
      end

      if (self.fill) then
        size.width = maxsize.width
      end
      if (not self.pack) then
        size.height = maxsize.height
      end

      -- remember current column width and height (without spacing)
      col.width  = math.max(size.width, col.width)
      col.height = col.height + size.height

      -- remember right/bottom of last child within current row
      last = { x= x + size.width, y= y + row.height }

      y = y + size.height + self.spacing
    end
  end

  -- add right/bottom margin
  dim.width  = last.x + self.margin.right
  dim.height = last.y + self.margin.bottom

  return dim
end

---------------------------------------------------------------------

mtRowLayoutHorizontal = setmetatable({}, { __index = mtRowLayoutBase })

function mtRowLayoutHorizontal:layoutContainer(parent)

  local bounds = parent:getBounds()

  -- print("mtRowLayoutHorizontal:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  -- determine max size over all childs
  local maxsize = determineMaxSize(self)

  local row = { height = 0, width = 0 }

  local function layoutRow()
    local x = bounds.left
    if (#row > 0) then
      local space = self.spacing
      if (self.justify) then
        space = (bounds:width() - row.width) / (#row + 1)
        x = x + space
      end

      for _, item in ipairs(row) do
        local y = bounds.top + item.y
        if (self.center) then
          y = y + ((row.height - item.h) / 2)
        end

        item.ch:setBounds(x, y, item.w, item.h)
--        if (item.ch.layout) then
--          item.ch.layout:layoutContainer(item.ch)
--        end
        x = x + item.w + space
      end
    end
    row = { height = 0, width = 0 }
  end


  local x, y = self.margin.left, self.margin.top
  for _, ch in ipairs(self) do
    -- check for "break"
    if ((type(ch) == "string") and (ch == "break")) then
      y = y + row.height + self.spacing
      x = self.margin.left
      layoutRow()
    else
      local size = ch:getPreferredSize()

      -- check for row break
      if (self.wrap and (x + size.width > bounds.right)) then
        y = y + row.height + self.spacing
        x = self.margin.left
        layoutRow()
      end

      if (self.fill) then
        size.height = maxsize.height
      end
      if (not self.pack) then
        size.width = maxsize.width
      end

      -- remember current row height
      row.height = math.max(size.height, row.height)
      row.width  = row.width + size.width

      row[#row+1] = { y=y, h=size.height, w=size.width, ch=ch }

      x = x + size.width + self.spacing
    end
  end
  layoutRow()
end

function mtRowLayoutHorizontal:preferredLayoutSize(parent)

  local bounds = parent:getBounds()

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  -- determine max size over all childs
  local maxsize = determineMaxSize(self)

  local dim = { width=0, height=0 }

  local row = { height = 0, width = 0 }

  local x, y = self.margin.left, self.margin.top

  -- right/bottom of last child in a row
  local last = { x=x, y=y }

  for _, ch in ipairs(self) do
    -- check for "break"
    if ((type(ch) == "string") and (ch == "break")) then
      y = y + row.height + self.spacing
      x = self.margin.left
    else
      local size = ch:getPreferredSize()

      -- check for row break
      if (self.wrap and (x + size.width > bounds.right)) then
        y = y + row.height + self.spacing
        x = self.margin.left
      end

      if (self.fill) then
        size.height = maxsize.height
      end
      if (not self.pack) then
        size.width = maxsize.width
      end

      -- remember current row height and width (without spacing)
      row.height = math.max(size.height, row.height)
      row.width  = row.width + size.width

      -- remember right/bottom of last child within current row
      last = { x= x + size.width, y= y + row.height }

      x = x + size.width + self.spacing
    end
  end

  -- add right/bottom margin
  dim.width  = last.x + self.margin.right
  dim.height = last.y + self.margin.bottom

  return dim
end

---------------------------------------------------------------------

function RowLayout(arg)
  local self = arg or {}

  local mt = mtRowLayoutHorizontal
  if ("vertical" == self.dir) then
    mt = mtRowLayoutVertical
  end

  return setmetatable(self, { __index = mt } )
end



---------------------------------------------------------------------
--[[

   border layout

   Has up to 5 childs called
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

  Remarks:
    Heigth of south/north and width of west/east is determined from
    preferredLayoutSize() of the contained controls.

  Usage:

    BorderLayout{
      fillCorners = true | false,
      south       = <child view>,
      west        = <child view>,
      north       = <child view>,
      east        = <child view>,
      center      = <child view>
    }

  Example:

  self.layout = venster.BorderLayout{
    fillCorners = true,
    south       = self.btnSouth,
    west        = self.btnWest,
    north       = self.btnNorth,
    east        = self.btnEast,
    center      = self.btnCenter
  }


--]]

mtBorderLayout = {
  margin  = venster.Rect(0, 0, 0, 0),
  horizontalSpacing = 2,
  verticalSpacing   = 2
}

function mtBorderLayout:createLayout(parent)
  self.parent = parent

  -- resolve control references
  for _, dir in ipairs{"south", "west", "north", "east", "center"} do
    local name = self[dir]
    local ch = parent.children[name]
    self[dir] = ch
  end
end


function mtBorderLayout:layoutContainer(parent)

  local bounds = parent:getBounds()

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  local top    = bounds.top;
  local bottom = bounds.bottom;
  local right  = bounds.right;
  local left   = bounds.left;

  local south, west, north, east, center = self.south, self.west, self.north, self.east, self.center

  local northcoords, southcoords;

  if (north and north:isVisible()) then
    local northheight = north:getPreferredSize().height
    northcoords = {top=top, height=northheight}
    top = top + northheight + self.verticalSpacing
  end

  if (south and south:isVisible()) then
    local southheight = south:getPreferredSize().height
    southcoords = {top=bottom - southheight, height=southheight}
    bottom = bottom - southheight - self.verticalSpacing
  end

  -- remember left/right for south/north
  local snxlimits = { left=left, right=right }

  if (east and east:isVisible()) then
    local eastwidth = east:getPreferredSize().width
    east:setBounds(right-eastwidth, top, eastwidth, bottom - top);
    right = right - eastwidth - self.horizontalSpacing
  end

  if (west and west:isVisible()) then
    local westwidth = west:getPreferredSize().width
    west:setBounds(left, top, westwidth, bottom - top);
    left = left + westwidth + self.horizontalSpacing
  end

  if (center and center:isVisible()) then
    center:setBounds(left, top, right - left, bottom - top);
  end

  -- resize north and south if corners are not filled
  if (not self.fillCorners) then
    if (west and west:isVisible()) then
      local westwidth   = west:getBounds():width() + self.horizontalSpacing
      snxlimits.left  = snxlimits.left  + westwidth
    end
    if (east and east:isVisible()) then
      local eastwidth   = east:getBounds():width() + self.horizontalSpacing
      snxlimits.right = snxlimits.right - eastwidth
    end
 end

  -- limit width to 0
  local snwidth = math.max(0, snxlimits.right - snxlimits.left)

  if (north and north:isVisible()) then
    north:setBounds(snxlimits.left, northcoords.top, snwidth, northcoords.height)
  end

  if (south and south:isVisible()) then
    south:setBounds(snxlimits.left, southcoords.top, snwidth, southcoords.height)
  end
end


function mtBorderLayout:preferredLayoutSize(parent)
  local dim = { width=0, heigth = 0 }

  local function calcHorz(child)
    if (child and child:isVisible()) then
      local childPS = child:getPreferredSize()

      dim.width  = dim.width + childPS.width + self.horizontalSpacing
      dim.height = max(childPS.height, dim.height);

      if(not fillCorners) then
        dim.width = dim.width + childPS.width;
      end
    end
  end
  calcHorz(east)
  calcHorz(west)

  if(center and center:isVisible()) then
    local childPS = center:getPreferredSize()
    dim.width  = dim.width + childPS.width;
    dim.height = max(childPS.height, dim.height);
  end

  local function calcVert(child)
    if(child and child:isVisible()) then
      local childPS = child:getPreferredSize()
      dim.width = max(childPS.width,dim.width)
      dim.height = dim.height + childPS.height + self.verticalSpacing
    end
  end
  calcVert(self.north)
  calcVert(self.south)

  dim.width  = dim.width  + self.margin.left + self.margin.right;
  dim.height = dim.height + self.margin.top  + self.margin.bottom;

  return dim
end

function BorderLayout(arg)
  local self = arg or { fillCorners=true }

  return setmetatable(self, { __index = mtBorderLayout } )
end


---------------------------------------------------------------------
--[[

  Grid layout

  Has n columns or rows and up to m childs.

  Possible Layout:

    Layout is as follows (example):

     +---------+---------------------+----------+
     |    1    |          2          |     3    |
     +---------+----------+----------+----------+
     |    4    |  empty   |    5     |  empty   |
     +---------+----------+----------+----------+
     |                                          |
     |                                          |
     +------------------------------------------+

  Remarks:

     Column height and row width is determined by the
     tallest/widest child in column/row.

     The layout gets an table of row tables, where ">" and "<" could
     be used to expand the left or right child to span further cells.

     Row/Column sizes could be specified, where
       positive number is fixed width/height in pixel
       0 means shrink to fit
       -1 to -100 is percent of parent width
       < -100 means use rest (expand)

  Usage:

    GridLayout{
      [colSizes = { list of sizes },]
      { row_1 },
      ...
      { row_n }
    }

  Example:

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

     +---------+---------------------+----------+
     |    1    |          2          |     3    |
     +---------+----------+----------+----------+
     |    4    |  empty   |    5     |  empty   |
     +---------+----------+----------+----------+



--]]

mtGridLayout = {
  margin  = venster.Rect(0, 0, 0, 0),
  horizontalSpacing = 2,
  verticalSpacing   = 2,
  columnSizes = { },
  rowSizes    = { }
}

function mtGridLayout:createLayout(parent)
  self.parent = parent

  -- resolve control references
  for rowidx, row in ipairs(self) do
    for colidx, ch in ipairs(row) do
      if (parent.children[ch]) then
        row[colidx] = parent.children[ch]
      end
    end
  end
end

function mtGridLayout:determineRowColSizes(bounds)

  -- determine row and col sizes
  local rowSizes = {}
  local colSizes = {}

  local numcols = 0

  -- determine preferred sizes
  for rowidx, row in ipairs(self) do
    for colidx, ch in ipairs(row) do
      if (ch and "string" ~= type(ch)) then
        local childPS = ch:getPreferredSize()
        rowSizes[rowidx] = math.max(childPS.height, rowSizes[rowidx] or -1)
        colSizes[colidx] = math.max(childPS.width , colSizes[colidx] or -1)
      end
      numcols = math.max(numcols, colidx)
    end
  end

  local function adjustsizes(sizes, curSizes, wholesize)
    local numadj = 0
    for idx, sz in ipairs(sizes) do
      if (sz >= -100) then
        if (sz < 0) then
          -- set width in percent of parent width
          sz = math.floor((wholesize * (-sz)) / 100)
        end
        if (sz > 0) then
          -- set fixed width
          curSizes[idx] = sz
        end
        -- if (sz == 0) use preferred size
      else
        -- eat rest of space
        curSizes[idx] = -1
        numadj = numadj + 1
      end
    end

    -- take all columns with size == -1 and distribute them equally over the rest
    -- of the available space
    if (numadj > 0) then
      local rest   = wholesize
      for idx, sz in ipairs(curSizes) do
        if (sz > 0) then
          rest = rest - sz
        end
      end

      local npos  = numadj-1
      local incr = rest / numadj
      for idx, sz in ipairs(curSizes) do
        if (sz < 0) then
          local w = rest - math.floor(npos * incr)
          curSizes[idx] = w
          rest = rest - w
          npos = npos - 1
        end
      end
    end
  end

  local allcolumnwidth = bounds:width() - (self.horizontalSpacing * (numcols - 1))
  adjustsizes(self.columnSizes, colSizes, allcolumnwidth)

  local numrows = #self
  local allrowheight = bounds:height() - (self.verticalSpacing * (numrows - 1))
  adjustsizes(self.rowSizes, rowSizes, allrowheight)

  return rowSizes, colSizes
end


function mtGridLayout:layoutContainer(parent)

  -- determine number of rows/cols
  local numRows = #self
  local numCols = 0
  for _, row in ipairs(self) do
    numCols = math.max(numCols, #row)
  end

  local bounds = parent:getBounds()

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  -- print("GridLayout:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- determine minimal row/col sizes
  local rowSizes ,colSizes = self:determineRowColSizes(bounds)

  local y = bounds.top
  local col = 1

  for rowidx, row in ipairs(self) do

    local height = rowSizes[rowidx] or 0

    local x       = bounds.left
    local chwidth = 0

    local lastchild
    local lastx   = x

    -- for each columns in rows
    for colidx, ch in ipairs(row) do

      local width  = colSizes[colidx]

      if ("string" == type(ch)) then

        -- if entry is ">" then extend width
        if (">" == ch) then
          -- add cell width
          chwidth = chwidth + width + self.horizontalSpacing
        elseif ("" == ch) then
          -- if entry is "" then leave a hole
          if (lastchild) then
            lastchild:setBounds(lastx,y,chwidth,height)
          end

          -- skip cell
          lastchild = nil
          chwidth   = 0
        end
      elseif (ch) then
        if (lastchild) then
          lastchild:setBounds(lastx,y,chwidth,height)
        end
        lastchild = ch
        lastx     = x
        chwidth   = width
      end

      -- add spacing
      x = x + width + self.horizontalSpacing
    end
    if (lastchild) then
      lastchild:setBounds(lastx,y,chwidth,height)
      lastchild = nil
    end
    y = y + height + self.verticalSpacing
  end
end


function mtGridLayout:preferredLayoutSize(parent)
  local numComponents = #self

  local numRows = #self.columnSizes
  local numCols = #self.rowSizes

  if (numRows) then
    numCols = (numComponents + numRows - 1) / numRows
  else
    numRows = (numComponents + numCols - 1) / numCols
  end

  local w,h = 0,0
  for _, ch in ipairs(parent) do
    local childPS = ch:getPreferredSize()
    w = max(childPS.width , w)
    h = max(childPS.height, h)
  end

  local margin = self.margin
  return { width  = margin.left + margin.right  + numCols * w + ((numCols-1) * self.horizontalSpacing),
           height = margin.top  + margin.bottom + numRows * h + ((numRows-1) * self.verticalSpacing)  }
end


function GridLayout(arg)
  local self = arg or {  }

  return setmetatable(self, { __index = mtGridLayout } )
end


---------------------------------------------------------------------
--[[

  Sash control

  Used within SashLayout to implement mouse interaction.

--]]
---------------------------------------------------------------------

local mtSash = setmetatable({ class="Sash" }, { __index =  mtWindow })


mtSash.classname = _T( "guiwin_Sash" )

-- load corsor
mtSash.horzCursor = winapi.LoadCursorW(nil, IDC_SIZENS)
assert(mtSash.horzCursor ~= 0)
mtSash.vertCursor = winapi.LoadCursorW(nil, IDC_SIZEWE)
assert(mtSash.vertCursor ~= 0)


mtSash[WM_SETCURSOR] = function(self, wParam, lParam)
  if ("vertical" == self.outerlayout.dir) then
    winapi.SetCursor(self.horzCursor)
  else
    winapi.SetCursor(self.vertCursor)
  end
  return 0
end

function mtSash:DrawBar(hdc)
  if ("vertical" == self.outerlayout.dir) then
    winapi.DrawXorBar(hdc, self.size.left, self.size.top + self.dragpos,self.size.width,self.size.height)
  else
    winapi.DrawXorBar(hdc, self.size.left + self.dragpos, self.size.top,self.size.width,self.size.height)
  end
end

mtSash[WM_LBUTTONDOWN] = function(self, wParam, lParam)

  self.dragMode = true

  self.dragstart = self.outerlayout:GetSashPos(self.index)
  self.dragpos   = self.dragstart

  local l,r = self.outerlayout:GetSashLimits(self.index)
  self.draglimits = { lo=l, hi=r }

  --
  local bounds = self.parent:getBounds()

  local rc = winapi.RECT:new()
  winapi.GetWindowRect(self.hwnd, rc);

  self.size = { left = bounds.left, top = bounds.top, width=rc:width(), height=rc:height() }

  local hdc = winapi.GetDC(self.parent.hwnd)
  self:DrawBar(hdc)

  winapi.SetCapture(self.hwnd)

  return 0
end

mtSash[WM_MOUSEMOVE] = function(self, wParam, lParam)
  if (self.dragMode) then
    local x, y     = GET_XY_LPARAM(lParam)

    local hdc = winapi.GetDC(self.parent.hwnd)
    self:DrawBar(hdc)

    if ("vertical" == self.outerlayout.dir) then
      self.dragpos = self.dragstart + y
    else
      self.dragpos = self.dragstart + x
    end
    self.dragpos = venster.utils.limit(self.dragpos, self.draglimits.lo, self.draglimits.hi)

    self:DrawBar(hdc)
  end

  return 0
end


mtSash[WM_LBUTTONUP] = function(self, wParam, lParam)
  if (self.dragMode) then
    winapi.ReleaseCapture()
    self.dragMode = false

    local hdc = winapi.GetDC(self.parent.hwnd)
    self:DrawBar(hdc)

    self.outerlayout:MoveSash(self.index, self.dragpos)
  end

  return 0
end

registerclass(mtSash.classname, {  hbrBackground = COLOR_3DFACE+1 } )


function mtSash:create(parent)

  self.parent = parent

  local x, y, w, h = venster.getPosSize(self)
  local style      = bor(WS_CHILD + WS_VISIBLE, self.style or 0)

  local hParent = self.parent.hwnd

  local hwnd = winapi.CreateWindowExW(
      0,
      mtSash.classname,         -- window class name
      self.label .. "\0\0",     -- window caption
      style,                    -- window style
      x, y, w, h,
      hParent,                  -- parent window handle
      0,                        -- window menu handle/child id
      hInstance,                -- program instance handle
      registerCreate(self))     -- creation parameters
  winapi.Assert(hwnd)
  -- setWindowPeer(hwnd, self)

  return self
end


function Sash(args)
  local self = args or { }

  self.label = self.label or _T""
  self.id    = self.id    or "sash"

  setmetatable(self, { __index = mtSash } )

  return self
end


---------------------------------------------------------------------
--[[

    Sash layout


    Layout is as follows:

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

  Remarks:
    Creates sashes between childs to support resizeable child width/height.

    Layout fills whole available space.
    Initial size of childs is determined by the (relative) start positions
    specified in self.layout.positions table.


  Usage:

    SashLayout{
        dir  = "horizontal" | "vertical",
      positions = { list of positions in percent (1.0 = 100%) },
      <list of childs>
    }

  Example:

    self.layout = venster.SashLayout{
      parent    = self,
      -- dir       = "horizontal",
      dir       = "vertical",
      positions = { 0.2, 0.4 },
      self.btnLeft,
      self.btnMiddle,
      self.btnRight
    }


--]]


--------------------------------------------------------------------

mtSashLayoutBase = {}

function mtSashLayoutBase:createLayout(parent)
  self.parent = parent

  -- resolve control references
  for idx, ident in ipairs(self) do
    local ch = self.parent.children[ident]
    assert(ch, string.format("unknown referenced child: '%s'", ident))
    self[idx] = ch
  end

  self.sashes = {}

  -- check parameters
  assert(#self.positions == (#self-1))

  -- create sash windows
  for idx=1, #self-1 do
    self.sashes[#self.sashes+1] = venster.Sash{
      outerlayout = self,
      index  = idx,
      -- parent = arg.parent,
      pos = { x=200, y=0, w=100, h=100 }
    }:create(parent)
  end
end


mtSashLayoutVertical = {
  margin  = venster.Rect(0, 0, 0, 0),
  spacing = 4
}
setmetatable(mtSashLayoutVertical, { __index = mtSashLayoutBase })

function mtSashLayoutVertical:layoutContainer(parent)
  local bounds = parent:getBounds()

  -- print("SashLayoutVertical:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  local numgaps= (#self - 1)

  self.height = bounds:height()
  self.width  = bounds:width()

  local x, y = bounds.left, bounds.top

  for idx, ch in ipairs(self) do
  local y2 = bounds.top + math.floor(self.height * (self.positions[idx] or 1.0))

  -- layout child
  ch:setBounds(x, y, self.width, y2 - y)

  -- place sash
  if (idx < #self) then
    self.sashes[idx]:setBounds(x, y2, self.width, self.spacing)
  end

  y = y2 + self.spacing
  end
end

function mtSashLayoutVertical:preferredLayoutSize(parent)
  -- use parent size
end

function mtSashLayoutVertical:GetSashPos(index)
  local pos  = math.floor(self.height * (self.positions[index] or 0.0))
  return pos
end

function mtSashLayoutVertical:GetSashLimits(index)
  local  lo = math.floor(self.height * (self.positions[index-1] or 0.0))
  local  hi = math.floor(self.height * (self.positions[index+1] or 1.0))
  hi = math.min(hi, self.height - self.spacing)
  return lo, hi
end

function mtSashLayoutVertical:MoveSash(index, pos)
  pos = 1.0 * pos / self.height
  if (self.positions[index] ~= pos) then
    self.positions[index] = pos
    self:layoutContainer(self.parent)
  end
end


--------------------------------------------------------------------

mtSashLayoutHorizontal = {
  margin  = venster.Rect(0, 0, 0, 0),
  spacing = 4
}
setmetatable(mtSashLayoutHorizontal, { __index = mtSashLayoutBase })

function mtSashLayoutHorizontal:layoutContainer(parent)
  local bounds = parent:getBounds()

  -- print("SashLayoutHorizontal:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  local numgaps= (#self - 1)

  self.height = bounds:height()
  self.width  = bounds:width()

  local x, y = bounds.left, bounds.top

  for idx, ch in ipairs(self) do
    local x2 = bounds.left + math.floor(self.width * (self.positions[idx] or 1.0))

    -- layout child
    ch:setBounds(x, y, x2 - x, self.height)

    -- place sash
    if (idx < #self) then
      self.sashes[idx]:setBounds(x2, y, self.spacing, self.height)
    end

    x = x2 + self.spacing
  end
end

function mtSashLayoutHorizontal:preferredLayoutSize(parent)
  -- use parent size
end

function mtSashLayoutHorizontal:GetSashPos(index)
  local pos  = math.floor(self.width * (self.positions[index] or 0.0))
  return pos
end

function mtSashLayoutHorizontal:GetSashLimits(index)
  local  lo = math.floor(self.width * (self.positions[index-1] or 0.0))
  local  hi = math.floor(self.width * (self.positions[index+1] or 1.0))
  hi = math.min(hi, self.width - self.spacing)
  return lo, hi
end

function mtSashLayoutHorizontal:MoveSash(index, pos)
  pos = 1.0 * pos / self.width
  if (self.positions[index] ~= pos) then
  self.positions[index] = pos
  self:layoutContainer(self.parent)
  end
end


--------------------------------------------------------------------

function SashLayout(args)
  local self = args or {  }

  local mt = mtSashLayoutHorizontal
  if ("vertical" == self.dir) then
    mt = mtSashLayoutVertical
  end

  return setmetatable(self, { __index = mt } )
end


---------------------------------------------------------------------
--[[

 Special layout for ListViews to adjust Listview columns


--]]
---------------------------------------------------------------------

mtListViewColumnLayout = {}

function mtListViewColumnLayout:createLayout(parent)
  self.parent = parent
end

function mtListViewColumnLayout:layoutContainer(parent)
  local bounds = parent:getBounds()
  -- print("ListViewColumnLayout:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  local width  = (bounds.right - bounds.left)
  local rest   = width

  -- print("ListViewColumnLayout:", width);

  for idx, col in ipairs(parent.columns) do
    local cw = math.floor(col.percent * width + 0.5)

    -- if less than rest -> use rest
    if (rest < cw) then
      cw   = rest
      rest = 0
    else
      rest = rest - cw
    end
    --  print("COL:", cw);
    parent:SetColumnWidth(idx, cw)
  end

  -- use standard layout
  return nil
end

function mtListViewColumnLayout:preferredLayoutSize(parent)
  -- use parent size
end

function ListViewColumnLayout()
  return setmetatable({}, { __index = mtListViewColumnLayout } )
end


---------------------------------------------------------------------
--[[

    Popup layout


    Layout is as follows:


     +------------------+
     |      child       |
     |                  |
     |                  |
     |                  |
     |                  |
     |                  |
     |                  |
     |                  |
     |                  |
     +------------------+


  Remarks:
    Childs share the same place.

    They are aligned within the bounds of their common parent.

  Usage:

    PopupLayout{
      halign    =  "left" | "center" | "right",
      valign    =  "top"  | "center" | "bottom",
      <list of childs>
    }

  Example:

    self.layout = venster.PopupLayout{
      "btnLeft",
      "btnMiddle",
      "btnRight"
    }


    self.layout.enable(1);

--]]
--------------------------------------------------------------------

mtPopupLayout = {
  margin  = venster.Rect(0, 0, 0, 0),
}


function mtPopupLayout:createLayout(parent)
  self.parent = parent

  -- resolve control references
  for idx, name in ipairs(self) do
	assert(parent.children, parent.id)

    local ch = parent.children[name]
    assert(ch, "unknown name: " .. name)
    self[idx] = ch or name
  end

  return self
end


function mtPopupLayout:layoutContainer(parent)
  local bounds = parent:getBounds()

  -- print("mtPopupLayout:", bounds.left, bounds.top, bounds.right, bounds.bottom)

  -- shrink parent dimension by margin
  bounds:shrink(self.margin)

  self.height = bounds:height()
  self.width  = bounds:width()

  local x, y = bounds.left, bounds.top

  for idx, ch in ipairs(self) do
    ch:setBounds(x, y, self.width, self.height)
    ch:show(idx == self.active)
    if (ch.layout) then
      ch.layout:layoutContainer(ch)
    end
  end
end

function mtPopupLayout:setActive(index)
  if ("string" == type(index)) then
    for idx, ch in ipairs(self) do
      if (index == ch.id) then
        index = idx
        break
      end
    end
  end

  if (self.active ~= index) then
    self[self.active]:show(false)
    self.active = index
    self[self.active]:show(true)
  end
end

function mtPopupLayout:preferredLayoutSize(parent)
  -- use parent size
end

function PopupLayout(args)
  local self = args or {}

  if (nil == self.active) then
      self.active = 1
  end

  return setmetatable(self, { __index = mtPopupLayout } )
end


---------------------------------------------------------------------
--[[

  Special layout for TabControls to layout children within tabs

--]]
---------------------------------------------------------------------

mtTabLayout = setmetatable( {}, { __index =  mtPopupLayout })


function mtTabLayout:preferredLayoutSize(parent)
  -- use parent size
end

function mtTabLayout:createLayout(parent)
  self.parent = parent

  -- resolve control references
  for idx, ch in ipairs(parent.children) do
    self[idx] = ch
  end

  return self
end


function TabLayout(args)
  local self = args or {}

  if (nil == self.active) then
      self.active = 1
  end

  return setmetatable(self, { __index = mtTabLayout } )
end

