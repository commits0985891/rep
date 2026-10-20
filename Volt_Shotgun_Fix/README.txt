SHOTGUN REPLACEMENT — Volt / Roblox

1. Extract this ZIP. You will get a folder named Shotgun_Fix with 8 files inside.
2. Go to https://github.com/commits0985891/rep/tree/guns
3. Upload the extracted folder named Shotgun_Fix (not the ZIP) to the guns branch.
4. Ensure the resulting path is guns/Shotgun_Fix/shotgun_manifest.json
5. Run this in Volt:
   loadstring(game:HttpGet("https://raw.githubusercontent.com/commits0985891/rep/guns/Shotgun_Fix/VOLT_LOAD_SHOTGUN_FIXED.lua"))()

The loader uses new shotgun meshes (model_0(2), model_1(2), model_2(2))
and their matching sight_0, sightrail_1, shotgun_2 textures.
On success it removes the previous model_13, model_14, and model_15
from the existing VoltOriginalModels scene.

Note: shotgun dimensions and positioning differ from the original 16-mesh group.
The replacement is scaled and centered automatically; inspect orientation in-game.
