HITBOX DIAGNOSTICS
==================

This standalone research mod captures and draws monster sphere and capsule
descriptors. It includes its own hit, matrix and hitbox-builder capture code;
no other mod is required.

Hit a monster once to select it. Hitting a different monster changes the target.
Only shapes whose owner matches the selected monster are captured.

Settings
--------

  BONES TO DRAW   Bone limit used before hitbox capture becomes available.
  HITBOX DETAIL   Vertices per ring, from 4 to 24.
  HITBOX STYLE    0 for points, 1 for connected polygon edges.

The compact label uses this format:

  ADDRESS AX,AY,AZ|RADIUS
  ADDRESS AX,AY,AZ|RADIUS/BX,BY,BZ|RADIUS
