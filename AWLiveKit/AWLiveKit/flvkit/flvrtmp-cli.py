#coding = utf-8 

import sys
import os
import subprocess
import time

p_pushing = None #(process,url,filename)
p_pulling = [] #(process,url,filename),(process,url,filename),(process,url,filename)


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
            'push-set-filename':_cmd_push_set_filename,
            'pull-start':_cmd_pull_start,
            'pull-stop':_cmd_pull_stop,}.get(cmd,_cmd_help)(par)

def _cmd_quit(args):
    '''quit'''
    global p_pushing
    global p_pulling 
    if p_pushing:
        (p,url,filename) = p_pushing
        p.kill()
    p_pushing = None
    for pull_item in p_pulling:
        (p,url,filename) = pull_item
        p.kill()
    p_pulling = []
    return False 

def _cmd_push_start(args):
    '''push-start $url $filename'''
    global p_pushing 
    if p_pushing:
        print "push has been started"
        return True
    url = args[0]
    filename = ''
    if len(args) > 1:
        filename = args[1]
    print 'url:%s, filename:%s'%(url,filename,)
    script = './flv-rtmp push -u \"%s\"'%(url,)
    if filename:
        script = script + ' -f \"' + filename + '\"'
    print script 
    p =subprocess.Popen(script, shell = True,
        stdin = subprocess.PIPE,
        stdout = subprocess.PIPE,
        stderr = subprocess.STDOUT)
    p_pushing = (p,url,filename)
    return True

def _cmd_push_stop(args):
    '''push-stop'''
    global p_pushing 
    if p_pushing:
        (p,url,filename) = p_pushing
        p.kill()
    p_pushing = None
    return True

def _cmd_push_set_filename(args):
    '''push-set-filename $filename'''
    global p_pushing 
    if not p_pushing:
        print "push has not been started"
        return True
    if not args:
        print 'push-set-filename $filename'
    new_filename = args[0]
    (p,url,filename) = p_pushing 
    script = 'push-set-filename:%s\n'%(new_filename,)
    p.stdin.write(script)
    p_pushing = (p,url,new_filename) 
    print 'pushing filename changed to %s'%(new_filename,)
    return True

def _cmd_pull_start(args):
    '''pull-start $url $filename'''
    global p_pulling 
    if len(args) < 2:
        print 'pull-start $url $filename'
        return True
    url = args[0] 
    filename = args[1]
    script = './flv-rtmp pull -u \"%s\" -f \"%s\"'%(url, filename,)
    print script
    p = subprocess.Popen(script, shell = True, 
            stdin = subprocess.PIPE,
            stdout = subprocess.PIPE,
            stderr = subprocess.STDOUT)
    pull_item = (p,url,filename)
    p_pulling.append(pull_item)
    return True

def _cmd_pull_stop(args):
    '''pull-stop $index'''
    global p_pulling
    if len(args) < 1:
        print 'pull-stop $index'
        return True
    i = int(args[0])
    if i < len(p_pulling):
        pull_item = p_pulling[i]
        (p,url,filename) = pull_item
        p.kill()
        p_pulling.remove(pull_item)
        print '%d stopped:(%s) %s, %s'%(i,str(p.pid),url,filename,)
    else:
        print '%d not found'%(i,)
    return True

def _cmd_status(args):
    '''status'''
    print 'pushing:'
    if p_pushing:
        (p,url,filename) = p_pushing
        print '\t(%s) %s, %s'%(str(p.pid),url,filename,)
    print 'pulling:'
    for (i,pull_item) in enumerate(p_pulling):
        (p,url,filename) = pull_item
        print '\t%d:(%s) %s, %s'%(i,str(p.pid),url, filename,) 
    return True

# cmd-help
def _cmd_help(args):
    print 'rtmp-flv-cli commands:'
    l = [_cmd_push_start,
            _cmd_push_stop,
            _cmd_push_set_filename,
            _cmd_pull_start,
            _cmd_pull_stop,
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
