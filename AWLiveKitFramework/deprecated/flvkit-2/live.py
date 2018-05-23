#!/usr/bin/python
#coding = utf-8 

import sys
import os
import subprocess
import time
import socket


push_script = './flv-rtmp-push -u  "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84" -f "/Users/reynoldqin/Downloads/239-%d.flv" '

pull_script = './flv-rtmp-pull -u "rtmp://m.push.wifiwx.com:1935/live/wifiwx-239"  -f "/Users/reynoldqin/Downloads/239-%d.flv" '

def run_pull(live_id):
    script = pull_script%(live_id,)
    print script
    subprocess.Popen(script, shell = True) 

def run_push(live_id):
    script = push_script%(live_id,)
    print script
    subprocess.Popen(script, shell = True)

if __name__ == '__main__':
    cmd = ''
    if len(sys.argv) < 3:
        print './live.py pull 1'
        print './live.py push 1'
    else:
        cmd = sys.argv[1]
        live_id = int(sys.argv[2])
        print cmd,live_id
        {'pull':run_pull,
         'push':run_push}.get(cmd,help)(live_id)
