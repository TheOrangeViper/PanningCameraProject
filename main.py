import cv2
import subprocess
import os
import numpy as np

# Path to chdkptp executable
chdkptp_path = "chdkptp.exe"
# process1 = subprocess.Popen([chdkptp_path, "-c"], capture_output = True, text = True)
result = subprocess.run([chdkptp_path, "-c", "-i"], capture_output = True, text = True)

print(result.stdout)