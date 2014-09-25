--[[--------------------------------------------------------------------------

  luavenster - object oriented GUI on winapi for Lua
  Copyright (C) 2011 Klaus Oberhofer. See copyright notice in
  LICENSE file

  utility functions
  
--]]--------------------------------------------------------------------------

module(..., package.seeall)

--==============================================================
-- utility functions

function round(val)
    return math.floor(val+0.5)
end

-- limit new value against upper border
function limit_up(new, old)
  if (new > old) then
    return old
  end
  return new
end

-- limit new value against lower border
function limit_low(new, old)
  if (new < old) then
    return old
  end
  return new
end

function limit(new, lo, hi)
  if (new < lo) then
    return lo
  end
  if (new > hi) then
    return hi
  end
  return new
end

