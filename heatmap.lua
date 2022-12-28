-- heatmap
-- @eigen
--
--


-- ------------------------------------------------------------------------
-- CONST

local RESOLUTION = 500
local HEAT_INC = 50
local HEAT_DEC = 10

local GRID_FPS = 10
local HEATMAP_FPS = 10


-- ------------------------------------------------------------------------
-- STATE

local g

-- local heatmap = {}
vgrid = {}
heatmap = {}


-- ------------------------------------------------------------------------
-- CLOCKS

local heatmap_clock = nil
local grid_redraw_clock = nil


-- ------------------------------------------------------------------------
-- CORE

function tab_copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  -- return setmetatable(u, getmetatable(t))
  return u
end


-- ------------------------------------------------------------------------
-- COORD LISTS

local function are_equal_coords(l, r)
  if l[1] == r[1] and l[2] == r[2] then
    return true
  end
  return false
end

local function has_coord(coords, search)
  for _, coord in ipairs(coords) do
    if are_equal_coords(coord, search) then
      return true
    end
  end
  return false
end

function sum_coord_lists(left_coords, right_coords)
  local ret = tab_copy(left_coords)
  for _, coord in ipairs(right_coords) do
    if not has_coord(ret, coord) then
      table.insert(ret, coord)
    end
  end
  return ret
end

function diff_coord_lists(left_coords, right_coords)
  local ret = {}
  for _, coord in ipairs(left_coords) do
    if not has_coord(right_coords, coord) then table.insert(ret, coord) end
  end
  return ret
end


-- ------------------------------------------------------------------------
-- GRID UTILS

local function is_valid_coord(g, x, y)
  if x < 1 or x > g.cols then
    return false
  end
  if y < 1 or y > g.rows then
    return false
  end
  return true
end

local function surrounding_btns(g, x, y)
  local btns = {}
  -- cross
  for _, d in pairs({{-1, 0}, {0, -1}, {1, 0}, {0, 1}}) do
    local dx = d[1]
    local dy = d[2]
    local x2 = x + dx
    local y2 = y + dy
    if is_valid_coord(g, x2, y2) then
      table.insert(btns, {x2, y2})
    end
  end
  -- TODO: add diagonal + lower factor
  return btns
end

-- ------------------------------------------------------------------------
-- GRID UI

local function init_vgrid(g)
  local p = {}
  for x=1, g.cols do
    table.insert(p, {})
    for y=1, g.rows do
      p[x][y] = 0
    end
  end
  vgrid = p
end

local function init_heatmap(g)
  local hm = {}
  for x=1, g.cols do
    table.insert(hm, {})
    for y=1, g.rows do
      hm[x][y] = 0
    end
  end
  heatmap = hm
end

local function grid_key(x, y, z)
  vgrid[x][y] = z
end

local function cool_button(x, y, v)
  heatmap[x][y] = util.clamp(heatmap[x][y] - v, 0, RESOLUTION)
end

local function heat_button(x, y, v, parents, gen)
  gen = gen or 0

  heatmap[x][y] = util.clamp(heatmap[x][y] + v, 0, RESOLUTION*2)

  if gen > 3 then
    return
  end

  if heatmap[x][y] > RESOLUTION * 1/3 then
    local curr_heat = math.min(heatmap[x][y], RESOLUTION)
    -- local next_v = math.floor(curr_heat/(RESOLUTION/2))
    local next_v = math.floor(v/2)
    if next_v == 0 then
      return
    end
    local btns = surrounding_btns(g, x, y)
    btns = diff_coord_lists(btns, parents)
    for _, btn in ipairs(btns) do
      local x2 = btn[1]
      local y2 = btn[2]
      heat_button(x2, y2, next_v, sum_coord_lists(btns, parents), gen+1)
      -- heatmap[x2][y2] = util.clamp(heatmap[x2][y2] + v, 0, RESOLUTION)
      -- tab.print(btn)
      -- print("  = "..heatmap[x2][y2])
    end
  end
end

local function heatmap_loop()
  -- print("---------------")
  for x=1, g.cols do
    for y=1, g.rows do
      if vgrid[x][y] == 0 then
        cool_button(x, y, HEAT_DEC)
      else
        heat_button(x, y, HEAT_INC, {{x, y}})
      end
    end
  end
end

local function grid_redraw()
  g:all(0)
  for x=1, g.cols do
    for y=1, g.rows do
      local led_v = math.floor(util.linlin(0, RESOLUTION, 0, 15, heatmap[x][y]))
      g:led(x, y, led_v)
    end
  end
  g:refresh()
end


-- ------------------------------------------------------------------------
-- SCRIPT LIFECYCLE

function init()
  g = grid.connect()
  g.key = grid_key
  init_vgrid(g)
  init_heatmap(g)
  -- TODO: support add/remove, grid selection...

  heatmap_clock = clock.run(
    function()
      local step_s = 1 / HEATMAP_FPS
      while true do
        clock.sleep(step_s)
        heatmap_loop()
      end
  end)
  grid_redraw_clock = clock.run(
    function()
      local step_s = 1 / GRID_FPS
      while true do
        clock.sleep(step_s)
        grid_redraw()
      end
  end)
end

function cleanup()
  heatmap_clock.cancel()
  grid_redraw_clock.cancel()
end
