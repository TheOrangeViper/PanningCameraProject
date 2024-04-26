import cv2
import os
import subprocess
import time
import numpy as np
import mediapipe.python.solutions.hands as mpHands
import mediapipe.python.solutions.drawing_utils as mpDraw

#constants
chdkptp_path = "./chdkptp/chdkptp.exe"
image_folder = "D:/Github Projects/PanningCameraProject"

#Video Dimensions
width = 640
height = 360
layers = 3
shape = height, width, layers
lastFrame = np.zeros(shape, np.uint8)

#Hand Tracking Constants
# Notice the import statements
hands = mpHands.Hands()

    
#Initial Commands / Startup Procedure
p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

commands = [
    "rec",
    ".set_zoom(0)",
    ".set_zoom_rel(20)",
    ".set_zoom_rel(-20)",
    ".set_lcd_display(0)"
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
    executeCommand('lvdumpimg -vp="frame.ppm"')
    try:
        image = [img for img in os.listdir(image_folder) if img.endswith(".ppm")][0]
        img_path = os.path.join(image_folder, image)
        frame = cv2.imread(img_path)
        os.remove(img_path) 
        if frame.shape == shape:
            return frame
        else:
            print("PROBLEM HERE")
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
        
        results = hands.process(frameRGB)
        
        #Hand Tracking
        if results.multi_hand_landmarks:
            for handLms in results.multi_hand_landmarks:
                mpDraw.draw_landmarks(frame, handLms, mpHands.HAND_CONNECTIONS)
                WRIST = (handLms.landmark[0].x * width, handLms.landmark[0].y * height)
                print("Wrist: " + str(WRIST))
                THUMB_TIP = (handLms.landmark[4].x * width, handLms.landmark[4].y * height)
                print("Thumb: " + str(THUMB_TIP))
                INDEX_FINGER_TIP = (handLms.landmark[8].x * width, handLms.landmark[8].y * height)
                print("Index: " + str(INDEX_FINGER_TIP))
                MIDDLE_FINGER_TIP = (handLms.landmark[12].x * width, handLms.landmark[12].y * height)
                print("Middle: " + str(MIDDLE_FINGER_TIP))
                RING_FINGER_TIP = (handLms.landmark[16].x * width, handLms.landmark[16].y * height)
                print("Ring: " + str(RING_FINGER_TIP))
                PINKY_TIP = (handLms.landmark[20].x * width, handLms.landmark[20].y * height)
                print("Pinky: " + str(PINKY_TIP))
                executeCommand(".set_zoom_rel(10)")
                
                # Hand Landmark Locations
                # WRIST = 0
                # THUMB_CMC = 1
                # THUMB_MCP = 2
                # THUMB_IP = 3
                # THUMB_TIP = 4
                # INDEX_FINGER_MCP = 5
                # INDEX_FINGER_PIP = 6
                # INDEX_FINGER_DIP = 7
                # INDEX_FINGER_TIP = 8
                # MIDDLE_FINGER_MCP = 9
                # MIDDLE_FINGER_PIP = 10
                # MIDDLE_FINGER_DIP = 11
                # MIDDLE_FINGER_TIP = 12
                # RING_FINGER_MCP = 13
                # RING_FINGER_PIP = 14
                # RING_FINGER_DIP = 15
                # RING_FINGER_TIP = 16
                # PINKY_MCP = 17
                # PINKY_PIP = 18
                # PINKY_DIP = 19
                # PINKY_TIP = 20
        
        cv2.imshow('frame', frame)
        if cv2.waitKey(10) == ord('q'):
            break
    p.terminate()
    p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    p.stdin.flush()
    executeCommand("rec")
