VOLT GITHUB MODEL LOADER — original geometry + original UV texture atlases

Upload ALL contents of this folder to the ROOT of your public repo:
https://github.com/commits0985891/rep

You may upload in batches. Files needed: manifest.json, every model_N_chunk_K.json, every texture_N.rgba, and VOLT_LOAD_ALL.lua.
PNG source images are not necessary.

Run in Volt:
loadstring(game:HttpGet("https://raw.githubusercontent.com/commits0985891/rep/main/VOLT_LOAD_ALL.lua"))()

The loader requests chunks sequentially and prints each success/error.
Set LOAD_ONLY = 0 for magazine only, or 1..15 for other components, or nil for all.
Original parts share coordinates; this does NOT guarantee a finished usable weapon / rig.
EditableMesh limits and memory budget can prevent all 16 from loading at once.
Model 15 has no supplied texture and is untextured.
No Studio required; this relies on available executor functions and Roblox EditableMesh / EditableImage APIs.
If parts look displaced, check object origins / scaling in the imported mesh; textures and geometry are preserved in the downloaded files.
