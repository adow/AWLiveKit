#coding = utf-8 

import sys
import os
import subprocess
import time

print "pip start"

p = subprocess.Popen('./pip-work.out',shell = True,
        stdin = subprocess.PIPE,
        stdout = subprocess.PIPE,
        stderr = subprocess.STDOUT)
print "writing..."
p.stdin.write("hello from parent\n");
print 'reading...'
output = p.stdout.readline()
print 'read from work:%s'%(output,)
