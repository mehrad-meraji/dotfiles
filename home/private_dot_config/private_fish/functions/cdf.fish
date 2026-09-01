# Change working directory to top-most Finder window location
# macOS specific function
function cdf
    cd (osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')
end
