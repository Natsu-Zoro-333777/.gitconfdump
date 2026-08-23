if status is-interactive
    # Commands to run in interactive sessions can go here

      # -----------------------------------------------------
# File listing / viewing
# -----------------------------------------------------
    function ls
        command ls -lAFh $argv
    end

    function less
        command less -FSRXc $argv
    end

    function wget
        command wget -c $argv
    end

    function c
        clear
    end

# -----------------------------------------------------
# Path / system info
# -----------------------------------------------------
    function show_path          # ← renamed so it doesn't collide with the builtin
        echo $PATH | tr ':' '\n'
    end

    function numFiles
        ls -1 | count
    end

    function keybinds
        cat ~/.config/ghostty/config.ghostty
    end

    function neofetch
        fastfetch $argv
    end

# -----------------------------------------------------
# File creation helpers
# -----------------------------------------------------
    function make1mb
        truncate -s 1m ./1MB.dat
    end

    function make5mb
        truncate -s 5m ./5MB.dat
    end

    function make10mb
        truncate -s 10m ./10MB.dat
    end

# -----------------------------------------------------
# Search
# -----------------------------------------------------
    function qfind
        find . -name $argv
    end

# -----------------------------------------------------
# Process / memory / CPU
# -----------------------------------------------------
    function memHogsPs
        ps -eo pid,stat,vsz,rss,time,cmd --sort=-rss | head -n 11
    end

    function cpu_hogs
        ps -eo pid,stat,%cpu,time,cmd --sort=-%cpu | head -n 11
    end

# -----------------------------------------------------
# Networking
# -----------------------------------------------------
    function netCons
        lsof -i $argv
    end

    function lsock
        sudo lsof -i -P $argv
    end

    function lsockU
        sudo lsof -nP | grep UDP
    end

    function lsockT
        sudo lsof -nP | grep TCP
    end

    function openPorts
        sudo lsof -i -P -n | grep LISTEN
    end

# -----------------------------------------------------
# Date & Time
# -----------------------------------------------------
    function bdate
        date '+%a, %b %d %Y %T %Z'
    end

    function cal3
        cal -3
    end

    function da
        date "+%Y-%m-%d %A %T %Z"
    end

    function daysleft
        set -l year_end (date -d "Dec 31" +%j)
        set -l today (date +%j)
        echo "There are "(math $year_end - $today)" days left in year "(date +%Y)"."
    end

    function epochtime
        date +%s
    end

    function mytime
        date +%H:%M:%S
    end

    function stamp
        date "+%Y%m%d%a%H%M"
    end

    function timestamp
        date "+%Y%m%dT%H%M%S"
    end

    function today
        date +"%A, %B %-d, %Y"
    end

    function weeknum
        date +%V
    end

# -----------------------------------------------------
# Misc
# -----------------------------------------------------
    function fix_stty
        stty sane
    end

    function fix_term
        echo -e "\033c"
    end

    function editHosts
        sudo $EDITOR /etc/hosts
    end

    function llm
        find /lib/modules/(uname -r) -type f -name '*.ko*'
    end

    set -x GROFF_NO_SGR 1

    fastfetch
    today
    daysleft

end


