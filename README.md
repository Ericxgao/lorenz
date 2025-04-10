# Lorenz Attractor

A crow study implementing chaotic attractor CV outputs and visualization.

## Controls

### Encoders
- **E1**: Adjust sigma/a
- **E2**: Adjust rho/b
- **E3**: Adjust beta/c

### Keys
- **K1+E1**: Adjust simulation speed (dt)
- **K2+K3**: Cycle between attractors:
  - Lorenz
  - Rössler
  - Sprott-Linz F
  - Halvorsen
- **K2+E3**: Adjust selected output attenuation (0-100%)
- **K2**: Switch selected output
- **K3**: Randomize parameters

### Parameters
- **slew**: Crow slew time

## Outputs
- **OUT1**: x coordinate (-5V to 5V)
- **OUT2**: y coordinate (-5V to 5V)
- **OUT3**: z coordinate (-5V to 5V)
- **OUT4**: distance from origin (0V to 5V)
