--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file
  
--]]--------------------------------------------------------------------------

function winapi.ImageList_LoadBitmap(hi,lpbmp,cx,cGrow,crMask)
  return winapi.ImageList_LoadImageW(hi,lpbmp,cx,cGrow,crMask,IMAGE_BITMAP,0)
end
