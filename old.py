import cv2
import subprocess
import os
import numpy as np
import time

# Path to chdkptp executable
chdkptp_path = "chdkptp.exe"
# result = subprocess.run([chdkptp_path, "-c", "-g"])
p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# Send commands and read output
commands = [
    "rec",
    ".set_zoom(0)",
]

for command in commands:
    p.stdin.write(command + "\n")
    p.stdin.flush() 
    time.sleep(2)

def executeCommand(command):
    p.stdin.write(command + "\n")
    p.stdin.flush()

i = 0
while True:
    executeCommand('lvdumpimg -vp="dumpVideoFeed.ppm" -fps=30')
    time.sleep(0.1)
    i += 1
    print(i)





# Wait for the process to finish and collect any remaining output
output, error = p.communicate()
print(output)
print('\n')
print(error)