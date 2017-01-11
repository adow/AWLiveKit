#coding= utf-8

from __future__ import print_function
import os
import sys
import logging
import struct
import binascii

def get_bit(i, start,length):
    s = bin(i)[2:]
    s = max(8-len(s),0) * '0' + s
    s_find = s[start:start+length]
    s_output = '0b' + s_find
    return int(s_output,2)

def get_bit2(x,p,n):
    return ( x >> (p + 1 -n)) & ~(~0 << n)

def print_flv_file_hex(filename,limits = 100):
    f = open(filename)

    counter = 0
    while True:
        c = f.read(2)
        if not c or (limits and counter >= limits):
            break
        else:
            print (c.encode('hex'),end = ' ')
            counter = counter + 1
            if counter % 8 == 0 :
                print ('')
    f.close()
    print ('')

def print_flv_file_tag(filename,limits = 0):
    f = open(filename,'rb')

    # flv header
    signature = f.read(3)
    version = f.read(1)
    flags = f.read(1)
    header_size = f.read(4)
    
    print ('signature:' + signature.encode('hex'))
    print ('version:' + version.encode('hex')) 
    print ('flags:' + flags.encode('hex'))
    print ('header_size:' + header_size.encode('hex')) 

    counter = 0
    # flv body
    while True:
        print ('-' * 30 + 'TAG:%d'%(counter,) + '-' * 30)
        # previous_tag_size
        previous_tag_size = f.read(4)
        if not previous_tag_size:
            break
        previous_tag_size_s = previous_tag_size.encode('hex')
        previous_tag_size_int = int(previous_tag_size_s,16)
        print ('previous_tag_size:%s,%d'%(previous_tag_size_s,previous_tag_size_int,))
        # tag header
        tag_header_type = f.read(1)
        if not tag_header_type:
            break
        tag_header_type_s = tag_header_type.encode('hex')
        tag_header_type_int = int(tag_header_type_s,16)
        tag_header_type_name = {0x08:'audio',
                0x09:'video',
                0x12:'script'}.get(tag_header_type_int,'unknown')
        tag_header_data_size = f.read(3)
        tag_header_data_size_s = tag_header_data_size.encode('hex')
        tag_header_data_size_int = int(tag_header_data_size_s,16)
        tag_header_timestamp = f.read(3)
        tag_header_timestamp_s = tag_header_timestamp.encode('hex')
        tag_header_timestamp_int = int(tag_header_timestamp_s,16)
        tag_header_timestamp_ex = f.read(1)
        tag_header_stream_id = f.read(3)
        print ('tag_header_type:%s,%s'%(tag_header_type_s, tag_header_type_name,))
        print ('tag_header_data_size:%s,%d'%(tag_header_data_size_s,tag_header_data_size_int,))
        print ('tag_header_timestamp:%s,%d'%(tag_header_timestamp_s, tag_header_timestamp_int,))
        print ('tag_header_timestamp_ex:' + tag_header_timestamp_ex.encode('hex'))
        print ('tag_header_stream_id:' + tag_header_stream_id.encode('hex'))
        # tag data
        tag_data = f.read(tag_header_data_size_int)
        #print ('tag_data')
        #print (tag_data.encode('hex'))

        # audio tag data
        if tag_header_type_int == 0x08:
            audio_tag_data_meta = tag_data[0]
            audio_tag_data_meta_s = audio_tag_data_meta.encode('hex')
            audio_tag_data_meta_int = int(audio_tag_data_meta_s,16)
            audio_tag_data_body = tag_data[1:]
            print ('\taudio_tag_data_meta:%s,%s'%(audio_tag_data_meta_s,bin(audio_tag_data_meta_int),))
            audio_tag_data_meta_encoder = get_bit(audio_tag_data_meta_int,0,4)
            audio_tag_data_meta_bitrate = get_bit(audio_tag_data_meta_int,3,2)
            audio_tag_data_meta_precise = get_bit(audio_tag_data_meta_int,6,1)
            audio_tag_data_meta_type = get_bit(audio_tag_data_meta_int,7,1)
            print ('\taudio_encoder:%d,audio_bitrate:%d, audio_precise:%d, audio_type:%d'%(audio_tag_data_meta_encoder,
                audio_tag_data_meta_bitrate,
                audio_tag_data_meta_precise,
                audio_tag_data_meta_type,))
            #print ('\taudio_tag_data_body:' + audio_tag_data_body.encode('hex'))
        elif tag_header_type_int == 0x09:
            video_tag_data_meta = tag_data[0]
            video_tag_data_meta_s = video_tag_data_meta.encode('hex')
            video_tag_data_meta_int = int(video_tag_data_meta_s,16)
            print ('\tvideo_tag_data_meta:%s,%s'%(video_tag_data_meta_s,bin(video_tag_data_meta_int),))
            video_tag_data_meta_type = get_bit(video_tag_data_meta_int,0,4)
            video_tag_data_meta_encoder = get_bit(video_tag_data_meta_int,4,4)
            print ('\tvideo_type:%d,video_encoder:%d'%(video_tag_data_meta_type,video_tag_data_meta_encoder,))

            video_tag_data_body = tag_data[1:]
            #print ('\tvideo_tag_data_body:' + video_tag_data_body.encode('hex'))
        elif tag_header_type_int == 0x12:
            #print (tag_data.encode('hex'))
            # amf_1
            amf_1_type = tag_data[0]
            amf_1_length = tag_data[1:3]
            amf_1_length_s = amf_1_length.encode('hex')
            amf_1_length_int = int(amf_1_length_s,16)
            amf_1_data = tag_data[3:3 + amf_1_length_int]
            print ('\tamf_1_type:' + amf_1_type.encode('hex'))
            print ('\tamf_1_length:%s,%d'%(amf_1_length_s, amf_1_length_int,))
            print ('\tamf_1_data:' + amf_1_data.encode('hex'))
            # amf_2
            pos_amf_2 = 3 + amf_1_length_int 
            amf_2_type = tag_data[pos_amf_2]
            amf_2_count = tag_data[pos_amf_2 + 1: pos_amf_2 + 5]
            amf_2_count_s = amf_2_count.encode('hex')
            amf_2_count_int = int(amf_2_count_s,16)
            print ('\tamf_2_type:' + amf_2_type.encode('hex'))
            print ('\tamf_2_length:%s,%d'%(amf_2_count_s,amf_2_count_int,))
            pos_amf_2_data = pos_amf_2 + 5
            print ('\tpos_amf_2_data:%d'%(pos_amf_2_data,))
            amf_2_data = tag_data[pos_amf_2_data:]
            print ('\tamf_2_data:' + amf_2_data.encode('hex'))
            print ('\t',amf_2_data)


        counter = counter + 1
        if limits and counter >= limits:
            break

    f.close()


#print_flv_file_hex('/Users/reynoldqin/Downloads/1.flv')
print_flv_file_tag('/Users/reynoldqin/Downloads/1.flv',0)
#print(get_bit2(0xaf,0,4))
#print(get_bit(0x17,0,4))
#print(get_bit(0x17,4,4))
