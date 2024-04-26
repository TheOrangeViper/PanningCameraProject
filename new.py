import cv2
import os
import subprocess
import time
import numpy as np

# Path to chdkptp executable
chdkptp_path = "./chdkptp/chdkptp.exe"
image_folder = "D:/Github Projects/PanningCameraProject"
# result = subprocess.run([chdkptp_path, "-c", "-g"])
p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

#Video Dimensions
width = 1920
height = 1080
layers = 3
shape = height, width, layers
lastFrame = np.zeros(shape, np.uint8)


# Send commands and read output
commands = [
    "rec",
    ".set_zoom(0)",
]


def executeCommand(command):
    p.stdin.write(command + "\n")
    p.stdin.flush()

def generateFrame(lastFrame):
    try:
        image = [img for img in os.listdir(image_folder) if img.endswith(".jpg")][0]
        img_path = os.path.join(image_folder, image)
        frame = cv2.imread(img_path)
        os.remove(img_path)
        print(frame.shape)
        if frame.shape == shape:
            return frame
        else:
            print("PROBLEM HERE")
            raise Exception("Frame shape is not what it should be")
    except:
        return lastFrame


for command in commands:
    p.stdin.write(command + "\n")
    p.stdin.flush() 
    time.sleep(2)

# print('hey')

executeCommand('remoteshoot -cont=10000')
while True:
    for i in range(100):
        frame = generateFrame(lastFrame)
        try:
            frameRGB = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            lastFrame = frame
        except:
            frameRGB = cv2.cvtColor(lastFrame, cv2.COLOR_BGR2RGB)
        
        cv2.imshow('frame', frame)
        if cv2.waitKey(10) == ord('q'):
            break
    # p.terminate()
    # p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    # p.stdin.flush()
    # executeCommand("rec")



# executeCommand('remoteshoot -cont=1000')
