-- This file runs after all other mods have finished their data-updates phase.
-- It ensures that all technologies have corresponding virtual signals, even if they were
-- added by mods that loaded after our data-updates.lua (fixing data-loading-order issues).
-- It also removes any orphaned signals for technologies that no longer exist.

local signal = require("prototypes.signal")

signal.create_missing_signals()
signal.remove_extra_signals()
signal.fix_signal_icons()