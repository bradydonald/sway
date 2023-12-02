#!/usr/bin/python
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4 foldmethod=marker
# ----------------------------------------------------------------------


""" {{{
sway-bg-changer
    This program is designed to take in a folder of images and rotate the background image to
    a random picture in a provided folder.

    original repo: https://github.com/jdonofrio728/swaywm-bg-changer

2023 - Modified by: DeaDSouL
    Added features:
        - Recursively scan path.
        - Follow links.
        - Make sure the file is an image before setting it as a wallpaper.
        - Show a notification whenever wallpaper is changed by the script.

    Repo: https://gitlab.com/DeaDSouL/swayora/
""" # }}}

# Imports {{{
import argparse
import daemon
import json
import os
import random
import socket
import struct
import sys
import time
import subprocess
from PIL import Image
# }}}

try:
  SWAYSOCK=os.environ['SWAYSOCK']
except KeyError:
  print("SWAYSOCK not set, are you running swaywm?")
  sys.exit(1)

IPC_MAGIC = b"i3-ipc"
IPC_HEADER = "=6s I I"
IPC_HEADER_SIZE = struct.calcsize(IPC_HEADER)

def eprint(*args, **kwargs): # {{{
  print(*args, file=sys.stderr, **kwargs)
# }}}

""" # {{{
run_sway_command sets up the socket and handles io
header is a struct packed object that cannot be null
payload is also a struct packed object, but can be null if it is not needed
""" # }}}
def run_sway_command(header, payload): # {{{
  if header == None or len(header) == 0:
    return
  sway_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
  try:
    sway_socket.connect(SWAYSOCK)
    if sway_socket.send(header, IPC_HEADER_SIZE) < 0:
      eprint("Failed to send IPC header")
    if payload != None:
      sway_socket.sendall(payload)

    header_resp_raw = sway_socket.recv(IPC_HEADER_SIZE)
    header_resp = struct.unpack(IPC_HEADER, header_resp_raw)
    data_size = int(header_resp[1])
    msg_type = int(header_resp[2])
    data = sway_socket.recv(data_size)
  finally:
    sway_socket.close()
  return json.loads(data)
# }}}

def get_outputs(): # {{{
  msg = struct.pack(IPC_HEADER, IPC_MAGIC, 0, 3)
  data = run_sway_command(msg, None)
  monitor_list = list()
  for monitor in data:
    name = monitor['name']
    monitor_list.append(name)
  return monitor_list
# }}}

def set_background(display, bg): # {{{
  cmd = "output %s bg %s stretch" % (display, bg)
  cmdsize = len(cmd)
  cmd = cmd.encode()
  msg = struct.pack(IPC_HEADER, IPC_MAGIC, cmdsize, 0)
  payload = struct.pack("%ss" % cmdsize, cmd)
  return run_sway_command(msg, payload)
# }}}

def get_bgs(bg_dir, recursive=False, followlinks=False): # {{{
  if recursive:
    files = [os.path.join(_p, f) for _p, _, ff in os.walk(bg_dir, followlinks=followlinks) for f in iter(ff)]
  else:
    #files = [f for f in os.listdir(bg_dir) if os.path.isfile(os.path.join(bg_dir, f))]
    files = [os.path.join(bg_dir, f) for f in os.listdir(bg_dir) if os.path.isfile(os.path.join(bg_dir, f))]

  return files
# }}}
def get_bg(files): # {{{
  #files = get_bgs(bg_dir, recursive)
  bg = ''
  while len(files) > 0 and not is_image(bg):
    if bg:
      print(f'{bg} is not an image.. removing it from backgrounds list..')
    if bg in files:
      files.remove(bg)
    size = len(files)
    #bg = os.path.join(bg_dir, files[random.randint(0, size-1)])
    bg = files[random.randint(0, size-1)]

  if not files and not is_image(bg):
    return False

  return bg
# }}}

def is_image(bg): # {{{
  try:
    # Attempt to open the file using Pillow
    img = Image.open(bg)
    return True
  except:
    return False
# }}}

def swaywm_bg_changer(bg_dir, recursive=False, followlinks=False, notify=False): # {{{
  bgs = get_bgs(bg_dir, recursive, followlinks)
  for output in get_outputs():
    bg = get_bg(bgs)
    data = set_background(output, bg)
    status = data[0]['success']
    if status:
      msg = "Set background for %s to %s" % (output, bg)
      print(msg)
      if notify:
        command = ["notify-send", "-i", bg, "-t", "5000", 'Random Wallpaper', msg]
        subprocess.run(command)
    else:
      msg = "Failed to set %s to %s" % (output, bg)
      print(msg)
      if notify:
        thumbnail='/usr/share/icons/Adwaita/scalable/devices/video-display.svg'
        command = ["notify-send", "-i", thumbnail, "-t", "5000", 'Random Wallpaper', msg]
        subprocess.run(command)
# }}}

def daemon_mode(timeout, bg_dir, recursive=False, followlinks=False, notify=False): # {{{
  with daemon.DaemonContext():
    while True:
      swaywm_bg_changer(bg_dir, recursive, followlinks, notify)
      time.sleep(timeout)
# }}}


def main(): # {{{
  parser = argparse.ArgumentParser()
  parser.add_argument("bg_dir", help="Path to directory containing images")
  parser.add_argument("-d", "--daemon", help="Daemonize the process", action="store_true")
  parser.add_argument("-t", "--timeout", help="How often to change background images in minutes", default=30, type=int)
  parser.add_argument("-r", "--recursive", help="Search for backgrounds recursively", action="store_true")
  parser.add_argument("-F", "--followlinks", help="Follow links", action="store_true")
  parser.add_argument("-n", "--notify", help="Shows a notification", action="store_true")
  args = parser.parse_args()
  d = args.daemon
  t = args.timeout * 60
  r = args.recursive
  F = args.followlinks
  n = args.notify
  bg_dir = args.bg_dir
  if d:
    daemon_mode(t, bg_dir, r, F, n)
  else:
    swaywm_bg_changer(bg_dir, r, F, n)
# }}}

if __name__ == "__main__":
  main()
