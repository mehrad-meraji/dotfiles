# Bat-enhanced commands
# ======================

# Colorize help output with bat
function help
    $argv --help 2>&1 | bat --plain --language=help
end

# Use batman for man pages (requires bat-extras)
function man
    set -lx BAT_THEME "Monokai Extended"
    command batman $argv
end
