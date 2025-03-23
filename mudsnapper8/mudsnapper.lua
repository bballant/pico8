-- title:  Mudsnapper 2
-- author: Cool Guy
-- desc:   A simple game with physics

-- Constants
WALLTILES = {64, 65, 66, 67}
PI = 3.14159265359

game = {
  tic = 0,
}

hero = {
  x = 64,
  y = 32,
  vx = 0,
  vy = 0,
  base = 128,
  acc = 0.3,
  fric = 0.8,
  maxS = 3.8,
  flpx = false,
  flpy = false,
  rot = 0,
  mud_queue = {},
}

function getMudPattern(x, y, rot)
  local rad = rot / 360

  -- direction vector
  local dx = cos(rad)
  local dy = sin(rad)

  -- center of sprite
  local cx = x + 4
  local cy = y + 4

  -- Start point: 4 pixels behind center
  local xs = cx - dx * 4
  local ys = cy - dy * 4

  -- End point: 8 pixels further from the start
  local xe = xs - dx * 8
  local ye = ys - dy * 8

  -- Find perpendicular direction for splatter width
  local perp_dx = -dy * 2 -- bigger number = wider splatter
  local perp_dy = dx * 2

  -- Splatter triangle
  local x1, y1 = xs + perp_dx, ys + perp_dy
  local x2, y2 = xs - perp_dx, ys - perp_dy
  local x3, y3 = xe, ye  -- Tip of splatter

  -- Randomly sample points within the triangle
  local pat = {}

  for _ = 1, 100 do
    local u = rnd()
    local v = rnd()

    if u + v < 1 then
      local px = x1 + u * (x2 - x1) + v * (x3 - x1)
      local py = y1 + u * (y2 - y1) + v * (y3 - y1)

      if rnd() < 0.1 then
        add(pat, {px, py})
      end
    end
  end

  return pat
end

function updateMudTrail(x, y, rot, t, keep)
  local pat = getMudPattern(x, y, rot)
  add(hero.mud_queue, pat)

  -- If the queue is too large, remove a pattern
  if #hero.mud_queue > keep then
    if rnd() < 1/3 then
      -- Randomly delete an older pattern (not the newest one)
      local index = rnd(keep - 1) + 1 -- (1 to keep-1)
      deli(hero.mud_queue, flr(index))
    else
      -- remove the oldest pattern
      deli(hero.mud_queue, 1)
    end
  end
end

function drawMudTrail()
  for _, pat in ipairs(hero.mud_queue) do
    for _, pixel in ipairs(pat) do
      pset(pixel[1], pixel[2], 8)  -- Draw stored pixel
    end
  end
end

function checkCollision(x, y, vx, vy)
  local tsz = 8
  local hbsz = 4
  local hboff = (tsz - hbsz) / 2

  -- Predict next position
  local nX = x + vx
  local nY = y + vy

  -- Convert hitbox corners to tile coordinates
  local ltx = flr((nX + hboff) / tsz)
  local rtx = flr((nX + hbsz - 1 + hbsz) / tsz)
  local tty = flr((nY + hboff) / tsz)
  local bty = flr((nY + hbsz - 1 + hboff) / tsz)

   local topLeft = mget(ltx, tty)
   local topRight = mget(rtx, tty)
   local bottomLeft = mget(ltx, bty)
   local bottomRight = mget(rtx, bty)

  return topLeft, topRight, bottomLeft, bottomRight
end

function wallBounce(tlTile, trTile, blTile, brTile, vxIn, vyIn)
  local vx, vy = vxIn, vyIn
  local tr = contains(WALLTILES, trTile)
  local br = contains(WALLTILES, brTile)
  local tl = contains(WALLTILES, tlTile)
  local bl = contains(WALLTILES, blTile)

  hitWallXBoth = (tr and br) or (tl and bl)
  hitWallYBoth = (tr and tl) or (br and bl)
  hitOneWall = tr or br or tl or bl

  -- Reverse velocity in the direction of collision (bounce effect)
  if hitWallXBoth or (hitOneWall and not hitWallYBoth) then vx = -vx * 0.5 end
  if hitWallYBoth or (hitOneWall and not hitWallXBoth) then vy = -vy * 0.5 end

  return vx, vy
end

-- Helper function to check if a table contains a value
function contains(tbl, val)
  for _, v in pairs(tbl) do
    if v == val then
      return true
    end
  end
  return false
end

function getTruckBase(r_)
  if r_ == 0 or r_ == 180 then
    return 128
  elseif r_ == 45 or r_ == 135 or r_ == 225 or r_ == 315 then
    return 134
  elseif r_ == 90 or r_ == 270 then
    return 131
  end
end

function getFlipStatus(r_)
  local flipx, flipy = false, false
  // if then statments for every 45 degress
  if r_ == 0 then
    -- do nothing
  end
  if r_ == 45 then
    flipy = true
  end
  if r_ == 90 then
    -- do nothing
  end
  if r_ == 135 then
    flipx = true
    flipy = true
  end
  if r_ == 180 then
    flipx = true
  end
  if r_ == 225 then
    flipy = true
  end
  if r_ == 270 then
    flipy = true
  end
  if r_ == 315 then
    -- do nothing
  end
  return flipx, flipy
end

function dpadRotation()
  if not btn(0) and not btn(1) and not btn(2) and not btn(3) then return -1 end
  local dx = 0
  local dy = 0

  if btn(0) then dx -= 1 end -- Left
  if btn(1) then dx += 1 end -- Right
  if btn(2) then dy -= 1 end -- Up
  if btn(3) then dy += 1 end -- Down

  if dx == 0 and dy == 0 then return 0 end

  return atan2(dx, dy) * 360
end

function _update()
  local x, x0 = hero.x, hero.x
  local y, y0 = hero.y, hero.y
  local vx = hero.vx
  local vy = hero.vy
  local rot = hero.rot
  -- Get rotation from D-pad
  local r_ = dpadRotation()
  if r_ ~= -1 then rot = r_ end

  -- Apply acceleration in the direction of rotation
  if btn(4) then
    local angle = rot / 360 -- Convert degrees to PICO-8 angle range
    local ax, ay = cos(angle), sin(angle) -- FIXED: Corrected x and y components
    vx = vx + ax * hero.acc * (1 - abs(vx) * 0.8)
    vy = vy + ay * hero.acc * (1 - abs(vy) * 0.8)
  end

  -- Apply "stuck in the mud" deceleration when no acceleration
  if not btn(4) then
    vx = vx * hero.fric
    vy = vy * hero.fric
    if abs(vx) < 0.05 then vx = 0 end
    if abs(vy) < 0.05 then vy = 0 end
  end

  -- Update truck visuals based on rotation
  local tb = getTruckBase(rot)
  if tb then hero.base = tb end

  hero.flpx, hero.flpy = getFlipStatus(rot)

  -- Clamp speed
  vx = mid(-hero.maxS, vx, hero.maxS)
  vy = mid(-hero.maxS, vy, hero.maxS)

  -- Bounce off walls
  local tL, tR, bL, bR = checkCollision(x, y, vx, vy)
  vx, vy = wallBounce(tL, tR, bL, bR, vx, vy)

  -- Update position
  x = x + vx
  y = y + vy

  -- Keep within screen bounds
  x = mid(0, x, 120)
  y = mid(0, y, 120)

  -- if we moved, draw mud trail
  if y-y0 ~= 0 or x-x0 ~= 0 then
    updateMudTrail(x, y, rot, game.tic, 30)
  end

  hero.x = x
  hero.y = y
  hero.vx = vx
  hero.vy = vy
  hero.rot = rot
end


function signal(t, n, tics)
    return flr((t / tics) % (n + 1))
end

function _draw()
  cls()
  map()
  local sidx = signal(game.tic, 3, 20)
  -- flips back to origin, then the other way
  if sidx == 2 then sidx = 0 end
  if sidx == 3 then sidx = 2 end
  spr(hero.base + sidx, hero.x, hero.y, 1, 1, hero.flpx, hero.flpy)
  drawMudTrail(hero.x, hero.y, hero.rot)
  game.tic+=1
end
