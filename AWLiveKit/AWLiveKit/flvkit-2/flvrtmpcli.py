#!/usr/bin/python
#coding = utf-8 

import sys
import os
import subprocess
import time
import socket

pull_script = {
        #"243":"./flv-rtmp-pull -f \"/Users/reynoldqin/Downloads/243.flv\" -u \"rtmp://m.push.wifiwx.com:1935/live/wifiwx-243\" -l \"/Users/reynoldqin/Downloads/pull-243.log\"",
        "243":"./flv-rtmp-pull -f \"/Users/reynoldqin/Downloads/243.flv\" -u \"rtmp://m.push.wifiwx.com:1935/live/wifiwx-243\"",
        #"245":"./flv-rtmp-pull -f \"/Users/reynoldqin/Downloads/245.flv\" -u \"rtmp://m.push.wifiwx.com:1935/live/wifiwx-245\" -l \"/Users/reynoldqin/Downloads/pull-245.log\"",
        "245":"./flv-rtmp-pull -f \"/Users/reynoldqin/Downloads/245.flv\" -u \"rtmp://m.push.wifiwx.com:1935/live/wifiwx-245\"",
        }

#push_script = "./flv-rtmp-push -f \"/Users/reynoldqin/Downloads/243.flv\" -u \"rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84\"  -l \"/Users/reynoldqin/Downloads/push.log\""
push_script = "./flv-rtmp-push -f \"/Users/reynoldqin/Downloads/243.flv\" -u \"rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84\""

p_pushing = None #(process,url,filename)
p_pulling = {}


def run_connect():
    unix_domain = '/tmp/flv-rtmp-push'
    s = socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
    server_address = unix_domain 
    print 'connecting'
    s.connect(server_address)
    print 'connected'
    while (True):
        r = raw_input('> ')
        s.sendall(r + '\n') 

def run_push():
    # push
    print 'pushing'
    print '\t',push_script
    p_pushing =subprocess.Popen(push_script, shell = True)


def run_pull():
    # pull
    print 'pulling'
    for (name,script) in pull_script.items():
        print '\t',script
        p =subprocess.Popen(script, shell = True) 
        p_pulling[name] = p

def run_push_setfile():
    if len(sys.argv) < 3:
        print 'no filename'
        print sys.argv
        return
    filename = sys.argv[2]
    if not filename:
        print 'no filename'
        return
    print 'filnename:',filename
    unix_domain = '/tmp/flv-rtmp-push'
    s = socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
    server_address = unix_domain 
    print 'connecting'
    s.connect(server_address)
    print 'connected'
    s.sendall('push-set-filename:%s\n'%(filename,)) 
    time.sleep(3)
    s.close()

def run_stop():
    script = "killall flv-rtmp-pull flv-rtmp-push"
    subprocess.Popen(script,shell = True)

def help():
    print 'python flvrtmpcli.py pull'
    print 'python flvrtmpcli.py push'
    print 'python flvrtmpcli.py connect'
    print 'python flvrtmpcli.py stop'
    print 'python flvrtmpcli.py push-set-filename'

if __name__ == '__main__':
    #start_socket()
    #run_scripts()
    cmd = ''
    if len(sys.argv) < 2:
        help()
    else:
        cmd = sys.argv[1]
        print cmd
        {'pull':run_pull,
         'push':run_push,
         'connect':run_connect,
         'push-set-filename':run_push_setfile,
         'stop':run_stop}.get(cmd,help)()
