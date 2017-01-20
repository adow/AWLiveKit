#coding = utf-8 

import sys
import os
import subprocess
import time
import socket

p_pushing = None #(process,url,filename)
p_pulling = [] #(process,url,filename),(process,url,filename),(process,url,filename)

def start_socket():
    unix_domain = '/tmp/flv-rtmp-push'
    s = socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
    server_address = unix_domain 
    print 'connecting'
    s.connect(server_address)
    print 'connected'
    while (True):
        r = raw_input('> ') 
        s.sendall(r + '\n')

if __name__ == '__main__':
    start_socket()
