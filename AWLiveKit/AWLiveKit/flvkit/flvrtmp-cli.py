#coding = utf-8 

import sys
import os
import subprocess
import time

p_push = None

p_receives = []
receiving_items = [] #[(url,filename),(url,filename),(url,filename)]


# cmd
def analisys_cmd(r):
    # cmd par_1, par_2, par3
    # push-start rtmp://m.push.wifiwx.com/wxlive/live-1 /root/downloads/1.flv
    col = r.split(' ')
    col = [s for s in col if s]
    if not col:
        return None
    if len(col) == 1:
        return (col[0],[])
    elif len(col) > 1:
        return (col[0], col[1:])
    else:
        return None

def run_cmd(r):
    ''' return continue'''
    (cmd, par) = analisys_cmd(r)
    return {'quit':_cmd_quit,
            'status':_cmd_status,
            'push-start':_cmd_push_start,
            'push-stop':_cmd_push_stop,
            'receive-start':_cmd_receive_start,
            'receive-stop':_cmd_receive_stop,}.get(cmd,_cmd_help)(par)

def _cmd_quit(args):
    '''quit'''
    global p_push
    global p_receives
    if p_push:
        p_push.kill()
        p_push = None
    for p in p_receives:
        p.kill()
    p_receives = []
    return False 

def _cmd_push_start(args):
    '''push-start $url $filename'''
    global p_push 
    url = args[0]
    filename = ''
    if len(args) > 1:
        filename = args[1]
    print 'url:%s, filename:%s'%(url,filename,)
    script_push_start = './flv-rtmp push -u \"%s\"'%(url,)
    print script_push_start
    '''
    p_push =subprocess.Popen(script_push_start, shell = True,
        stdin = subprocess.PIPE,
        stdout = subprocess.PIPE,
        stderr = subprocess.STDOUT)
    '''
    return True

def _cmd_push_stop(args):
    '''push-stop'''
    global p_push 
    if p_push:
        p_push.kill()
    p_push = None
    return True

def _cmd_receive_start(args):
    '''receive-start $url $filename'''
    global p_receives,receiving_items
    if len(args) < 2:
        print 'receive-start $url $filename'
        return True
    url = args[0] 
    filename = args[1]
    script = './flv-rtmp receive -u \"%s\" -f \"%s\"'%(url, filename,)
    print script
    p = subprocess.Popen(script, shell = True, 
            stdin = subprocess.PIPE,
            stdout = subprocess.PIPE,
            stderr = subprocess.STDOUT)
    p_receives.append(p) 
    item = (url,filename)
    receiving_items.append(item)
    return True

def _cmd_receive_stop(args):
    '''receive-stop $index'''
    global p_receives,receiving_items
    if len(args) < 1:
        print 'receive-stop $index'
        return True
    i = int(args[0])
    if i < len(p_receives):
        p = p_receives[i]
        p.kill()
        p_receives.remove(p)
        item = receiving_items[i]
        receiving_items.remove(item)
        print '%d stopped'%(i,)
    else:
        print '%d not found'%(i,)
    return True

def _cmd_status(args):
    '''status'''
    print 'pushing:'
    if p_push:
        print '0:push'
    print 'receiving:'
    for (i,p) in enumerate(p_receives):
        item = receiving_items[i]
        print '\t%d:(%s) %s, %s'%(i,str(p.pid),item[0], item[1],) 
    return True

# cmd-help
def _cmd_help(args):
    print 'rtmp-flv-cli commands:'
    l = [_cmd_push_start,
            _cmd_push_stop,
            _cmd_receive_start,
            _cmd_receive_stop,
            _cmd_status,
            _cmd_help,]
    for f in l:
        if f.__doc__:
            print f.__doc__
    return True


def run_loop():
    while (True):
        r = raw_input('> ') 
        if not run_cmd(r):
            break

if __name__ == '__main__':
    print "rtmp-flv-cli starts\n"
    _cmd_help([])
    run_loop()
