#!/bin/bash


BINDIR="$HOME/.config/sway/bin"
RUNCMD="$HOME/.local/bin/pipenv run python"
BGDIR="$HOME/Pictures/wallpapers"
STDOUT='/tmp/swayora/random_bg.log'
LINE='----------------------------------------------------------------------'
NOTIFYICON='/usr/share/icons/Adwaita/scalable/devices/video-display.svg'
DAEMON_FLAGS='-Frdnt 5'

[ ! -d "$(dirname ${STDOUT})" ] && mkdir -p "$(dirname ${STDOUT})"
[ ! -f "${STDOUT}" ] && touch "${STDOUT}"

function is_daemon_running() {
    ps aux | grep -v grep | grep "python random_bg.py ${DAEMON_FLAGS}" >/dev/null 2>&1
    return $?
}

case "$1" in
    once)
        cd $BINDIR
        output=$(${RUNCMD} random_bg.py -rFn ~/Pictures/wallpapers)
        echo "$(date +'%Y/%m/%d %H:%M:%S') - ($output)" &>> "$STDOUT"
        echo "$LINE" &>> "$STDOUT"
        ;;
    daemon-start|start)
        if ! is_daemon_running; then
            echo 'Starting random_bg.py daemon mode.'
            cd "$BINDIR"
            echo "$(date +'%Y/%m/%d %H:%M:%S') - Starting random_bg.py daemon mode" &>> $STDOUT
            ${RUNCMD} random_bg.py ${DAEMON_FLAGS} "${BGDIR}"
            notify-send -i $NOTIFYICON -t 5000 'Random Wallpaper Daemon' "Has been started"
            echo "$LINE" &>> "$STDOUT"
        else
            echo 'random_bg.py daemon is already running.'
        fi
        ;;
    daemon-stop|stop|kill)
        if is_daemon_running; then
            echo 'Stopping random_bg.py daemon mode.'
            echo "$(date +'%Y/%m/%d %H:%M:%S') - Stopping random_bg.py daemon mode" &>> $STDOUT
            kill $(ps aux | grep -v grep | grep "python random_bg.py ${DAEMON_FLAGS}" | head -1 | awk '{print $2}')
            notify-send -i $NOTIFYICON -t 5000 'Random Wallpaper Daemon' "Has been stopped"
            echo "$LINE" &>> "$STDOUT"
        else
            echo 'random_bg.py daemon is not running.'
        fi
        ;;
    daemon-status|status)
        if is_daemon_running; then
            echo 'random_bg.py daemon is running.'
        else
            echo 'random_bg.py daemon is not running.'
        fi
        ;;
    *)
        echo 'Available arguments:  once|daemon-start|daemon-stop|daemon-status'
        ;;
esac

