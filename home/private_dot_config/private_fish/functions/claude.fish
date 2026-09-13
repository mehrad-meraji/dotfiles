# ponytail: zellij saves the args, so a restored pane reopens the last chat in that folder.
# Plain `claude` always continues; use /clear (or `command claude`) for a fresh chat.
function claude --wraps claude --description 'claude, continuing the last chat when run with no args'
    if test (count $argv) -eq 0
        command claude --continue
    else
        command claude $argv
    end
end
