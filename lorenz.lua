-- lorenz: crow study with 
-- chaotic attractor visualization
-- 
-- E1 adjust sigma/a
-- E2 adjust rho/b
-- E3 adjust beta/c
--
-- K1+E1 adjust simulation speed (dt)
-- K2+K3 cycle between 
-- Lorenz, Rössler, 
-- Sprott-Linz F, and 
-- Halvorsen attractors
--
-- K2+E3 adjust selected output attenuation (0-100%)
-- K2 switch selected output
-- K3 randomize parameters
--
-- OUT1: x coordinate (-5V to 5V)
-- OUT2: y coordinate (-5V to 5V)
-- OUT3: z coordinate (-5V to 5V)
-- OUT4: distance from origin
-- (0V to 5V)

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

-- Sprott-Linz F parameters
local sprott_a = 0.5

-- Halvorsen parameters
local halvorsen_a = 1.89

local scale = 1  -- Scale factor for visualization
local display_scale = 1  -- Display scale that changes per attractor
local points = {}
local max_points = 300  -- Increased for longer trails
local offset_x, offset_y = 64, 32  -- Center of the screen
local lorentz_metro
local key1_down = false
local key2_down = false
local current_attractor = "lorenz"  -- Can be "lorenz", "rossler", "sprott", or "halvorsen"
local out1_volts, out2_volts, out3_volts, out4_volts = 0, 0, 0, 0
local selected_output = 1  -- Track which output is currently selected
local output_attenuation = {1.0, 1.0, 1.0, 1.0}  -- Attenuation for each output (0.0-1.0)
local encoder_adjusted_during_k2 = false  -- Track if encoder was adjusted while K2 was held
local att_display_fade = 0  -- Fade timer for attenuation display (0-1)
local att_fade_metro  -- Metro for fading out attenuation display

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
  
  -- Initialize attenuation fade metro
  att_fade_metro = metro.init()
  att_fade_metro.time = 1/60  -- 20 fps for smooth fade
  att_fade_metro.event = function()
    if att_display_fade > 0 then
      att_display_fade = math.max(0, att_display_fade - 1/60)  -- Fade over ~3 seconds (0.016 * 20fps * 3s = ~1)
      if att_display_fade == 0 then
        att_fade_metro:stop()
      end
    end
  end
  
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
    display_scale = 1  -- Set display scale for Lorenz
  elseif current_attractor == "rossler" then -- rossler
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
    display_scale = 1  -- Set display scale for Rössler
  elseif current_attractor == "sprott" then -- sprott
    if randomize then
      sprott_a = math.random(40, 50) / 100  -- 0.4 to 0.5
      
      -- Also randomize initial conditions
      x = math.random(50) * 0.01         -- 0 to 0.5
      y = math.random(-25, 25) * 0.01         -- -0.25 to 0.25
      z = math.random(-25, 25) * 0.01         -- -0.25 to 0.25
    else
      sprott_a = 0.5
      x, y, z = 1, 0, 0
    end
    dt = 0.05
    display_scale = 5.5  -- Set display scale for Sprott
  else -- halvorsen
    if randomize then
      halvorsen_a = math.random(165, 300) / 100  -- 1.65 to 3.0
      
      -- Also randomize initial conditions
      x = math.random(-1000, 1000) * 0.01     -- -10 to 10
      y = math.random(-1000, 1000) * 0.01     -- -10 to 10
      z = math.random(-1000, 1000) * 0.01     -- -10 to 10
    else
      halvorsen_a = 1.89
      x, y, z = 0.1, 0, 0
    end
    dt = 0.01
    display_scale = 3.0  -- Set display scale for Halvorsen
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
  elseif current_attractor == "rossler" then -- rossler
    -- Calculate next point in the Rössler system
    local dx = -y - z
    local dy = x + a * y
    local dz = b + z * (x - c)
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  elseif current_attractor == "sprott" then -- sprott
    -- Calculate next point in the Sprott-Linz F system
    local dx = y + z
    local dy = -x + sprott_a * y
    local dz = x * x - z
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  else -- halvorsen
    -- Calculate next point in the Halvorsen system
    local dx = -halvorsen_a * x - 4 * y - 4 * z - y * y
    local dy = -halvorsen_a * y - 4 * z - 4 * x - z * z
    local dz = -halvorsen_a * z - 4 * x - 4 * y - x * x
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  end
  
  -- Prevent numerical overflow with extreme values
  local max_value = 1000
  x = math.max(math.min(x, max_value), -max_value)
  y = math.max(math.min(y, max_value), -max_value)
  z = math.max(math.min(z, max_value), -max_value)

  if (math.abs(x) == 1000 or math.abs(y) == 1000 or math.abs(z) == 1000) then
    reset_parameters(true)
  end

  -- Add new point to the list
  table.insert(points, {x = x, y = y, z = z})
  
  -- Limit the number of points
  if #points > max_points then
    table.remove(points, 1)
  end
  
  -- Update crow outputs with scaled values
  if current_attractor == "lorenz" then
    -- Lorenz typically has larger values
    out1_volts = util.clamp(x * 0.1, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 0.1, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 0.1, -5, 5) * output_attenuation[3]  -- Z is much larger in Lorenz
    -- Calculate distance from origin (normalized chaos intensity)
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.05, 0, 5) * output_attenuation[4]
  elseif current_attractor == "rossler" then
    -- Rössler has different ranges for each dimension
    out1_volts = util.clamp(x * 0.25, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 0.25, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 0.25, -5, 5) * output_attenuation[3]  -- Z is still larger but not as extreme
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.1, 0, 5) * output_attenuation[4]
  elseif current_attractor == "sprott" then -- sprott
    -- Sprott-Linz F has smaller ranges
    out1_volts = util.clamp(x * 1.0, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 1.0, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 1.0, -5, 5) * output_attenuation[3]
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.5, 0, 5) * output_attenuation[4]
  else -- halvorsen
    -- Halvorsen has moderate ranges
    out1_volts = util.clamp(x * 0.5, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 0.5, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 0.5, -5, 5) * output_attenuation[3]
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.25, 0, 5) * output_attenuation[4]
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
    local prev_x = prev.x * scale * display_scale + offset_x
    local prev_y = prev.y * scale * display_scale + offset_y
    local curr_x = curr.x * scale * display_scale + offset_x
    local curr_y = curr.y * scale * display_scale + offset_y
    
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
  screen.rect(0, 0, 128, 7)
  screen.fill()
  screen.level(0)
  screen.move(2, 6)
  
  if current_attractor == "lorenz" then
    screen.text("Lorenz  a:" .. string.format("%.1f", sigma) .. 
                " b:" .. string.format("%.1f", rho) .. 
                " c:" .. string.format("%.1f", beta))
  elseif current_attractor == "rossler" then -- rossler
    screen.text("Rossler  a:" .. string.format("%.2f", a) .. 
                " b:" .. string.format("%.2f", b) .. 
                " c:" .. string.format("%.1f", c))
  elseif current_attractor == "sprott" then -- sprott
    screen.text("Sprott-F  a:" .. string.format("%.2f", sprott_a))
  else -- halvorsen
    screen.text("Halvorsen  a:" .. string.format("%.2f", halvorsen_a))
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
    {value = out1_volts, name = "1", att = output_attenuation[1]},
    {value = out2_volts, name = "2", att = output_attenuation[2]},
    {value = out3_volts, name = "3", att = output_attenuation[3]},
    {value = out4_volts, name = "4", att = output_attenuation[4]}
  }
  
  for i, output in ipairs(outputs) do
    local y_pos = viz_y_start + (i-1) * viz_spacing
    
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
    
    -- Draw selection border if this output is selected
    screen.level(i == selected_output and 15 or 0)
    screen.rect(viz_x, y_pos, viz_width + 1, viz_height + 1)
    screen.stroke()
    
    -- Draw attenuation indicator
    local att_percent = math.floor(output.att * 100)
    
    -- Only show percentage when K2 is held or during fade-out
    if key2_down or att_display_fade > 0 then
      -- Calculate brightness based on fade timer
      local brightness = key2_down and 15 or math.floor(15 * att_display_fade)
      screen.level(i == selected_output and brightness or math.floor(brightness * 0.5))
      screen.move(viz_x - 20, y_pos + 5)
      screen.text(att_percent .. "%")
    else
      -- Show dots for non-selected outputs when not displaying percentages
      if i ~= selected_output then
        screen.level(3)
        screen.move(viz_x - 20, y_pos + 5)
        screen.text(string.rep("·", math.ceil(output.att * 5)))
      end
    end
  end
end

function enc(n,d)
  if n==1 then
    if key1_down then
      -- Adjust dt when K1 is held
      dt = util.clamp(dt + d*0.001, dt_min, dt_max)
    else
      if current_attractor == "lorenz" then
        -- Adjust sigma parameter
        sigma = util.clamp(sigma + d*0.1, 0, 20)
      elseif current_attractor == "rossler" then -- rossler
        -- Adjust a parameter
        a = util.clamp(a + d*0.01, 0, 0.5)
      elseif current_attractor == "sprott" then -- sprott
        -- Adjust sprott_a parameter
        sprott_a = util.clamp(sprott_a + d*0.01, 0.4, 0.5)
      else -- halvorsen
        -- Adjust halvorsen_a parameter
        halvorsen_a = util.clamp(halvorsen_a + d*0.01, 1.65, 3.0)
      end
    end
  elseif n==2 then
    if key2_down then
      -- No longer adjusting dt with K2+E2
      encoder_adjusted_during_k2 = true
    else
      -- Adjust rho/b parameter
      if current_attractor == "lorenz" then
        rho = util.clamp(rho + d*0.1, 0, 60)
      elseif current_attractor == "rossler" then -- rossler
        b = util.clamp(b + d*0.01, 0, 0.5)
      end
      -- No second parameter for Sprott-Linz F or Halvorsen
    end
  elseif n==3 then
    if key2_down then
      -- Adjust attenuation for selected output when K2 is held
      output_attenuation[selected_output] = util.clamp(output_attenuation[selected_output] + d*0.01, 0.0, 1.0)
      encoder_adjusted_during_k2 = true
    else
      if current_attractor == "lorenz" then
        -- Adjust beta parameter
        beta = util.clamp(beta + d*0.05, 0, 10)
      elseif current_attractor == "rossler" then -- rossler
        -- Adjust c parameter
        c = util.clamp(c + d*0.1, 3, 24)
      end
      -- No third parameter for Sprott-Linz F or Halvorsen
    end
  end
end 

function key(n,z)
  if n==1 then
    key1_down = (z==1)
  elseif n==2 then
    if z==1 then
      -- K2 pressed down
      key2_down = true
      encoder_adjusted_during_k2 = false
      att_display_fade = 1  -- Show attenuation display
      att_fade_metro:stop()  -- Stop any ongoing fade
    else
      -- K2 released
      if key2_down and not encoder_adjusted_during_k2 then
        -- Switch selected output only on K2 release and if no encoder was adjusted
        selected_output = (selected_output % 4) + 1
      end
      key2_down = false
      att_display_fade = 1  -- Start fade from full brightness
      att_fade_metro:start()  -- Start fade-out timer
    end
  elseif n==3 and z==1 then
    if key2_down then
      -- Cycle between attractors when K2+K3 is pressed
      if current_attractor == "lorenz" then
        current_attractor = "rossler"
      elseif current_attractor == "rossler" then
        current_attractor = "sprott"
      elseif current_attractor == "sprott" then
        current_attractor = "halvorsen"
      else
        current_attractor = "lorenz"
      end
      print("Switched to " .. current_attractor)
      reset_parameters(true)
      encoder_adjusted_during_k2 = true  -- Prevent output selection change
    else
      -- Randomize parameters when K3 is pressed alone
      reset_parameters(true)
      print("Randomized parameters")
    end
  end
end

function cleanup()
  -- Stop the metros when the script is cleaned up
  lorentz_metro:stop()
  att_fade_metro:stop()
end