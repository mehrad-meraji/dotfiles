function chezmoi_update
    # Claude sessions (and you) keep editing these on this machine, so the
    # local copy wins: re-add first, and commit so `update` can still pull
    # with rebase. Without this, every update asks to overwrite them.
    chezmoi re-add ~/.claude/CLAUDE.md ~/.claude/projects ~/.claude/skills
    if not chezmoi git -- diff --quiet -- home/dot_claude
        chezmoi git -- add home/dot_claude
        and chezmoi git -- commit -q -m "chore: re-add Claude memory, CLAUDE.md and skills"
    end
    chezmoi update -R
    source $XDG_CONFIG_HOME/fish/config.fish
end
