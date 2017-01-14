#coding = utf-8 

import sys
import os
import subprocess
import time

print "pip start"

#script = "./pip-work.out"
script = "./flv-rtmp"

p = subprocess.Popen(script,shell = True,
        stdin = subprocess.PIPE,
        stdout = subprocess.PIPE,
        stderr = subprocess.STDOUT)
print "writing..."
p.stdin.write("set-filename:/file3\n");
print 'reading...'
output = p.stdout.readline()
print 'read from work:%s'%(output,)
