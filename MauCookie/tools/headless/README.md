# Headless run

Runs the addon under fengari (a Lua VM in JavaScript) with stubbed WoW APIs
and drives it through a whole session (scenario.lua): login, clicks, buying,
upgrades, golden cookies, wrinklers, seasons, Santa, the dragon, lumps, the
four minigames, ascension, wipe and a 0.4.0 migration. Any Lua error prints
with a traceback; the last line counts failures.

    cd tools/headless
    npm i fengari
    node run.js

Frames are stubs (every WoW method name used in the sources is a no-op that
returns the frame; GetWidth and friends return numbers), so this checks the
logic and the code paths, not what the window looks like.
