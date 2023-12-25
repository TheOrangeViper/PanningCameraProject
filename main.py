import cv2
import subprocess
import os
import numpy as np
import time

global j
# Path to chdkptp executable
chdkptp_path = "chdkptp.exe"

p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# Send initial commands
commands = [
    "rec",
    ".set_zoom(0)",
    ".set_zoom_rel(20)",
    ".set_zoom_rel(-20)",
]
for command in commands:
    p.stdin.write(command + "\n")
    p.stdin.flush() 
    time.sleep(2)

def executeCommand(command):
    p.stdin.write(command + "\n")
    p.stdin.flush() 

j = 0
def repeat():
    global j
    for i in range(100):
        j += 1
        print(j)
        executeCommand('lvdumpimg -vp')
        time.sleep(0.05)


while True:  
    repeat()
    p.terminate()
    p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    p.stdin.write(".set_zoom(15)\n")
    p.stdin.flush()



    # time.sleep(1)
    # executeCommand("shoot -dl -rm")
    
