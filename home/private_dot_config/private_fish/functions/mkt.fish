# Create directory structure and touch file in one command
# Usage: mkt path/to/file.txt
function mkt
    if test (count $argv) -eq 0
        echo "Usage: mkt <filepath>"
        return 1
    end
    
    set -l filepath $argv[1]
    mkdir -p (dirname $filepath)
    touch $filepath
end
