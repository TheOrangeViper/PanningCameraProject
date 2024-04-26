import cv2
import os
import subprocess
import time
import numpy as np

#constants
chdkptp_path = "./chdkptp/chdkptp.exe"
image_folder = "D:/Github Projects/PanningCameraProject"

#Video Dimensions
width = 640
height = 360
layers = 3
shape = height, width, layers
lastFrame = np.zeros(shape, np.uint8)

    
#Initial Commands / Startup Procedure
p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

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
    
#Command Execution Function
def executeCommand(command):
    p.stdin.write(command + "\n")
    p.stdin.flush() 

#Camera generate frame
def generateFrame(lastFrame):
    executeCommand('lvdumpimg -vp="frame.ppm" -fps=20')
    try:
        image = [img for img in os.listdir(image_folder) if img.endswith(".ppm")][0]
        img_path = os.path.join(image_folder, image)
        frame = cv2.imread(img_path)
        os.remove(img_path) 
        if frame.shape == shape:
            return frame
        else:
            print("PROBLEM HERE: " + frame.shape)
            raise Exception("Frame shape is not what it should be")
    except:
        return lastFrame
     

#Hand Tracking + Video Output
while True:
    for i in range(50):
        frame = generateFrame(lastFrame)
        try:
            frameRGB = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            lastFrame = frame
        except:
            frameRGB = cv2.cvtColor(lastFrame, cv2.COLOR_BGR2RGB)
        
        cv2.imshow('frame', frame)
        if cv2.waitKey(10) == ord('q'):
            break
    p.terminate()
    p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    p.stdin.flush()
    executeCommand("rec")
