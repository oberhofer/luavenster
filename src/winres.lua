--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

--]]--------------------------------------------------------------------------

module("venster", package.seeall)


-- require("venster")
local winapi = require("luawinapi")

local bit = require("bit32")
local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor


local lpeg = require 'lpeg'

---------------------------------------------------------------------------
-- shortcuts
--
local locale                         = lpeg.locale();
local P, R, S, C, V                  = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.V
local C, Cb, Cc, Cg, Cs, Ct, Cf, Cmt = lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Ct, lpeg.Cf, lpeg.Cmt

---------------------------------------------------------------------------
-- lexical elements
--

local whitespace = S' \t\v\n\f'
local WS = whitespace^0

local digit = R'09'
local letter = R('az', 'AZ') + P'_'
local alphanum = letter + digit
local hex = R('af', 'AF', '09')
local exp = S'eE' * S'+-'^-1 * digit^1
local fs = S'fFlL'
local is = S'uUlL'^0

local hexnum = P'0' * S'xX' * hex^1 * is^-1
local octnum = P'0' * digit^1 * is^-1
local decnum = digit^1 * is^-1
local numlit = (hexnum + octnum + decnum) * WS / tonumber

local stringlit = (P'"' * C( (P'\\' * P(1) + (1 - S'\\"'))^0) * P'"') * WS

local literal = numlit + stringlit
        -- / function(...) print('LITERAL', ...) end

local keyword = P"typedef"

local identifier = (letter * alphanum^0 - keyword * (-alphanum))
        -- / function(...) print('ID',...) end

local endline = (S'\n' + -P(1))
local comment = (P'//' * (1 - endline)^0 * endline)


function convertGlobVar(v)
	assert(_G[v], v)
	return _G[v] or 0
end

function combineStyle(...)
    local result = 0
	for _,v in ipairs{...} do
		result = bor(result, v)
	end
	return result
end

---------------------------------------------------------------------------
-- syntax for list of window controls
--
local wndcontrols = P{"controls";

  -- determine IDs and styles from globals
  globvarref    = C(identifier) / convertGlobVar;

  resclass = Cg(C(identifier), "tag");

  stringlit_tounicode = stringlit;

  label = Cg(V"stringlit_tounicode" * WS * P",", "label");

  label_opt = Cg((V"stringlit_tounicode" * WS * P",")^-1, "label");

  ctrlid = Cg(V"globvarref" * WS * P",", "id");

  position =  Cg(Ct(Cg(numlit, "x") * WS * P"," * WS * Cg(numlit, "y") * WS * P"," * WS * Cg(numlit, "w") * WS * P"," * WS * Cg(numlit, "h") * WS), "pos");

  -- style flags
  stylebase     = V"globvarref" * WS * ('|' * WS * V"globvarref" * WS)^0 / combineStyle;
  style 		= P"," * WS * V"stylebase";

  -- style = 0
  style_opt 	= V"style" + Cc(0);

  style_n 		= Cg(V"style", "style");

  style_opt_n   = Cg(V"style_opt", "style");
  exstyle_opt_n = Cg(V"style_opt", "exstyle");

  otherresource		= Ct(WS * V"resclass" * WS * V"label_opt" * WS * V"ctrlid" * WS * V"position" * WS * V"style_opt_n");

  controlclass  	= Cg(stringlit, "class");

  controlresource 	= Ct(WS * Cg(P"CONTROL", "tag")      * WS * V"label"     * WS * V"ctrlid"   * WS * V"controlclass" * WS * V"style_n" * P"," * WS * V"position" * WS * V"exstyle_opt_n");

  controls = Ct( ( (comment + V"controlresource" + V"otherresource" ) * WS)^0 );
}


function convertDLU(pos)
  return { x = pos.x * 2, y = pos.y * 2, w = pos.w * 2, h = pos.h * 2 }
end



local controlFactory = {

	["GROUPBOX"] = function(args)
		return nil
	end,
	["LTEXT"] = function(args)
    args.pos = convertDLU(args.pos)
		return venster.Label(args)
	end,
	["EDITTEXT"] = function(args)
    args.pos = convertDLU(args.pos)
		return venster.Edit(args)
	end,
	["COMBOBOX"] = function(args)
		return nil
	end,
	["CONTROL"] = function(args)
		return nil
	end,

}

function FromWinResource(dlgres)

	local res =  lpeg.match(wndcontrols, dlgres)
	assert(res)

	local controls = {}

	for _, control in ipairs(res) do

		local factory = controlFactory[control.tag]
		assert(factory, control.tag)

		controls[#controls+1] = factory(control)
	end

	local result = venster.Dialog{
    id = "Dialog_",  -- .. tostring(idGenerator:createid()),
    label = "Dialog",
		pos    = { x=0, y=0, w=100, h=100 },

    -- children = controls
  }

	return result
end


---------------------------------------------------------------------------
-- test
--

--[==[

require("datadumper")
function dump(...)
  print(DataDumper(...), "\n---")
end

dlg = [[
  GROUPBOX        "&GroupBoxLabel",IDC_STATIC,7,7,306,226
  LTEXT           "&TextLabel",IDC_STATIC,19,33,42,11
  EDITTEXT        IDC_EDIT_ITEM,66,31,236,12,ES_AUTOHSCROLL | WS_TABSTOP
  // CONTROL         "&DateTimePickerLabel",IDC_DATE_ITEM,"SysDateTimePick32",DTS_RIGHTALIGN | WS_TABSTOP,66,106,236,14
  // COMBOBOX        IDC_COMBOBOX_ITEM,66,186,123,58,CBS_DROPDOWNLIST | WS_VSCROLL | WS_TABSTOP
]]

local res =  lpeg.match(wndcontrols, dlg)

print(dump(res))

--]==]
