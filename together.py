import cv2
import os
import subprocess
import time
import numpy as np

chdkptp_path = "chdkptp.exe"
image_folder = "D:\Desktop\Projects\PanningCameraProject"

#Video Dimensions
height = 360
width = 640
layers = 3

cap = cv2.VideoCapture(0)

images = [img for img in os.listdir(image_folder) if img.endswith(".ppm")][-1]


# while True:
#     ret, frame = cap.read()
#     cv2.imshow('frame', frame)
#     print(frame)
#     if cv2.waitKey(1) == ord('q'):
#         break