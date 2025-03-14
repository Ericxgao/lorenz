-- lorentz: crow study with chaotic attractor visualization
-- 
-- E1 adjust first parameter (sigma/a)
-- E2 adjust second parameter (rho/b)
-- E3 adjust third parameter (beta/c)
--
-- K1 toggle between Lorenz and Rössler attractors
-- K2+E2 adjust simulation speed (dt)
-- K2 reset to default parameters
-- K3 randomize parameters
--
-- OUT1: x coordinate (scaled -5V to 5V)
-- OUT2: y coordinate (scaled -5V to 5V)
-- OUT3: z coordinate (scaled -5V to 5V)
-- OUT4: derived parameter (scaled 0V to 5V)

local x, y, z = 0.1, 0, 0
local dt = 0.005  -- Smaller time step for smoother simulation
local dt_min = 0.001
local dt_max = 0.2

-- Lorenz parameters
local sigma = 10
local rho = 28
local beta = 8/3

-- Rössler parameters
local a = 0.2
local b = 0.2
local c = 5.7

local scale = 1  -- Scale factor for visualization
local points = {}
local max_points = 300  -- Increased for longer trails
local offset_x, offset_y = 64, 32  -- Center of the screen
local lorentz_metro
local key2_down = false
local current_attractor = "lorenz"  -- Can be "lorenz" or "rossler"
local out1_volts, out2_volts, out3_volts, out4_volts = 0, 0, 0, 0

function init()
  -- Initialize crow outputs for direct voltage control
  crow.output[1].slew = 0.001  -- Small slew for smooth transitions
  crow.output[2].slew = 0.001
  crow.output[3].slew = 0.001  -- Add slew for z coordinate
  crow.output[4].slew = 0.001  -- Add slew for out4
  
  -- Initialize screen
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
  
  -- Start the attractor calculation using metro
  lorentz_metro = metro.init()
  lorentz_metro.time = 1/60 -- 60 fps (faster update rate)
  lorentz_metro.event = function()
    update_attractor()
    redraw()
  end
  lorentz_metro:start()
  
  -- Initialize with default values
  reset_parameters()
end

function reset_parameters(randomize)
  if current_attractor == "lorenz" then
    if randomize then
      sigma = math.random() * 49.9 + 0.1  -- 0.1 to 50
      rho = math.random() * 59.5 + 0.5    -- 0.5 to 60
      beta = math.random() * 9.9 + 0.1    -- 0.1 to 10
      
      -- Also randomize initial conditions
      x = math.random() * 20 - 10         -- -10 to 10
      y = math.random() * 20 - 10         -- -10 to 10
      z = math.random() * 10              -- 0 to 10
    else
      sigma = 10
      rho = 28
      beta = 8/3
      x, y, z = 0.1, 0, 0
    end
	dt = 0.005
  else -- rossler
    if randomize then
      a = math.random(10, 40) / 100
      b = math.random(10, 40) / 100
      c = math.random(40, 80) / 10

	  -- Also randomize initial conditions
      x = math.random() * 20 - 10         -- -10 to 10
      y = math.random() * 20 - 10         -- -10 to 10
      z = math.random() * 10              -- 0 to 10
    else
      a = 0.1
      b = 0.1
      c = 14

	  x, y, z = 0.1, 0.1, 0.1
    end
	dt = 0.05
  end
  
  points = {}
end

function update_attractor()
  if current_attractor == "lorenz" then
    -- Calculate next point in the Lorenz system
    local dx = sigma * (y - x)
    local dy = x * (rho - z) - y
    local dz = x * y - beta * z
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  else -- rossler
    -- Calculate next point in the Rössler system
    local dx = -y - z
    local dy = x + a * y
    local dz = b + z * (x - c)
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  end
  
  -- Prevent numerical overflow with extreme values
  local max_value = 1000
  x = math.max(math.min(x, max_value), -max_value)
  y = math.max(math.min(y, max_value), -max_value)
  z = math.max(math.min(z, max_value), -max_value)
  
  -- Add new point to the list
  table.insert(points, {x = x, y = y, z = z})
  
  -- Limit the number of points
  if #points > max_points then
    table.remove(points, 1)
  end
  
  -- Update crow outputs with scaled values
  if current_attractor == "lorenz" then
    -- Lorenz typically has larger values
    out1_volts = util.clamp(x * 0.1, -5, 5)
    out2_volts = util.clamp(y * 0.1, -5, 5)
    out3_volts = util.clamp(z * 0.1, -5, 5)  -- Z is much larger in Lorenz
    -- Calculate distance from origin (normalized chaos intensity)
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.05, 0, 5)
  else
    -- Rössler has different ranges for each dimension
    out1_volts = util.clamp(x * 0.25, -5, 5)
    out2_volts = util.clamp(y * 0.25, -5, 5)
    out3_volts = util.clamp(z * 0.25, -5, 5)  -- Z is still larger but not as extreme
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.1, 0, 5)
  end
  
  crow.output[1].volts = out1_volts
  crow.output[2].volts = out2_volts
  crow.output[3].volts = out3_volts
  crow.output[4].volts = out4_volts
end

function redraw()
  screen.clear()
  
  -- Draw the attractor
  for i = 2, #points do
    local prev = points[i-1]
    local curr = points[i]
    
    -- Project 3D to 2D (simple orthographic projection)
    local prev_x = prev.x * scale + offset_x
    local prev_y = prev.y * scale + offset_y
    local curr_x = curr.x * scale + offset_x
    local curr_y = curr.y * scale + offset_y
    
    -- Fade based on age of the point (newer points are brighter)
    local age_factor = (i - 1) / #points
    local brightness = util.linlin(0, 1, 1, 15, age_factor)
    
    -- Also factor in z-coordinate for depth effect
    local z_brightness = util.linlin(-30, 30, 1, 15, curr.z)
    
    -- Combine age and z factors for final brightness
    local final_brightness = math.min(brightness, z_brightness)
    screen.level(math.floor(final_brightness))
    
    screen.move(prev_x, prev_y)
    screen.line(curr_x, curr_y)
    screen.stroke()
  end
  
  -- Draw output visualizers in bottom right
  draw_output_visualizers()
  
  -- Draw attractor name and parameters in title bar
  screen.level(15)
  screen.rect(0, 0, 128, 12)
  screen.fill()
  screen.level(0)
  screen.move(2, 8)
  
  if current_attractor == "lorenz" then
    screen.text("Lorenz  a:" .. string.format("%.1f", sigma) .. 
                " b:" .. string.format("%.1f", rho) .. 
                " c:" .. string.format("%.1f", beta))
  else -- rossler
    screen.text("Rossler  a:" .. string.format("%.2f", a) .. 
                " b:" .. string.format("%.2f", b) .. 
                " c:" .. string.format("%.1f", c))
  end
  
  -- Display coordinate values
  screen.level(15)
  
  -- Show dt value at the bottom
  screen.level(15)
  screen.move(2, 60)
  screen.text("dt:" .. string.format("%.5f", dt))
  
  screen.update()
end

function draw_output_visualizers()
  local viz_width = 30
  local viz_height = 4
  local viz_x = 128 - viz_width - 2
  local viz_y_start = 40
  local viz_spacing = 6
  
  -- Draw output visualizers
  local outputs = {
    {value = out1_volts, name = "1"},
    {value = out2_volts, name = "2"},
    {value = out3_volts, name = "3"},
    {value = out4_volts, name = "4"}
  }
  
  for i, output in ipairs(outputs) do
    local y_pos = viz_y_start + (i-1) * viz_spacing
    
    -- Draw label
    screen.level(5)
    screen.move(viz_x - 5, y_pos + 3)
    screen.text(output.name)
    
    -- Draw bipolar meter background
    screen.level(1)
    screen.rect(viz_x, y_pos, viz_width, viz_height)
    screen.fill()
    
    -- Draw center line (zero point)
    screen.level(3)
    screen.move(viz_x + viz_width/2, y_pos)
    screen.line(viz_x + viz_width/2, y_pos + viz_height)
    screen.stroke()
    
    -- Draw output level
    screen.level(15)
    local normalized_value = output.value / 5  -- Normalize to -1 to 1 range
    local bar_width = math.abs(normalized_value) * (viz_width/2)
    
    if normalized_value >= 0 then
      -- Positive value (right side)
      screen.rect(viz_x + viz_width/2, y_pos, bar_width, viz_height)
    else
      -- Negative value (left side)
      screen.rect(viz_x + viz_width/2 - bar_width, y_pos, bar_width, viz_height)
    end
    screen.fill()
  end
end

function enc(n,d)
  if n==1 then
    if current_attractor == "lorenz" then
      -- Adjust sigma parameter
      sigma = util.clamp(sigma + d*0.1, 0, 20)
    else -- rossler
      -- Adjust a parameter
      a = util.clamp(a + d*0.01, 0, 0.5)
    end
  elseif n==2 then
    if key2_down then
      -- Adjust dt when K2 is held
      dt = util.clamp(dt + d*0.001, dt_min, dt_max)
    else
      -- Adjust rho/b parameter
      if current_attractor == "lorenz" then
        rho = util.clamp(rho + d*0.1, 0, 60)
      else -- rossler
        b = util.clamp(b + d*0.01, 0, 0.5)
      end
    end
  elseif n==3 then
    if current_attractor == "lorenz" then
      -- Adjust beta parameter
      beta = util.clamp(beta + d*0.05, 0, 10)
    else -- rossler
      -- Adjust c parameter
      c = util.clamp(c + d*0.1, 3, 24)
    end
  end
end 

function key(n,z)
  if n==1 and z==1 then
    -- Toggle between Lorenz and Rössler
    if current_attractor == "lorenz" then
      current_attractor = "rossler"
    else
      current_attractor = "lorenz"
    end
    print("Switched to " .. current_attractor)
    reset_parameters()
  elseif n==2 then
    key2_down = (z==1)
  elseif n==3 and z==1 then
    -- Randomize parameters
    reset_parameters(true)
    print("Randomized parameters")
  end
end

function cleanup()
  -- Stop the metro when the script is cleaned up
  lorentz_metro:stop()
end