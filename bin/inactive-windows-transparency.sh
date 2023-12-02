#!/bin/bash


if ! ps aux | grep -v grep | grep inactive-windows-transparency.py >/dev/null; then
    python ${HOME}/.config/sway/bin/inactive-windows-transparency.py
fi
