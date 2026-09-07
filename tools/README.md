# CWCheat converter

Convert one CWCheat entry into a PSP Lua Mod Manager directory:

```sh
python3 tools/cwcheat_to_mod.py CHEAT.TXT output/my_mod --game-id ULJM05500
```

When the file contains multiple `_C0`/`_C1` entries, select one by its exact name:

```sh
python3 tools/cwcheat_to_mod.py CHEAT.TXT output/my_mod \
  --game-id ULJM05500 --cheat "Infinite Stamina"
```

Copy the generated directory to `ms0:/mods/`. Use `--id` and `--name` to override its internal ID and displayed name. Existing output is preserved unless `--force` is supplied.

The converter currently supports constant writes:

- `0x0`: 8-bit
- `0x1`: 16-bit
- `0x2`: 32-bit

Pointer codes, conditionals, multi-write commands, copy commands, and Joker/button codes are rejected. Those commands span multiple lines and require an interpreter; rejecting them prevents creation of a mod with subtly different behavior.
