HITBOX INJECTOR
===============

This mod replaces multiple sphere and capsule descriptors without installing
additional hooks. It can run together with HITBOX DIAGNOSTICS.

Edit the file matching the game ID under definitions/. Each entry accepts:

  address  Descriptor address shown as DESC by HITBOX DIAGNOSTICS.
  kind     "sphere" or "capsule".
  radius   Radius in game units. Decimal values are supported.
  a        Local X, Y and Z offsets for the first point.
  b        Local X, Y and Z offsets for the second point (capsules only).

Example:

  return {
      {
          address = 0x09D2E240,
          kind = "capsule",
          radius = 400.0,
          a = { 0.0, 0.0, 0.0 },
          b = { 0.0, 0.0, -100.0 }
      }
  }

The injector waits for each descriptor, preserves its original words, applies
the configured values while active, and restores the original data on disable.
If another overlay replaces the data at an address, the injector stops writing
there until a matching descriptor is available again.
