//Temp README.txt//

Here are the docs I used:
https://chdk.fandom.com/wiki/CHDK_Scripting_Cross_Reference_Page
https://developers.google.com/mediapipe/solutions/vision/hand_landmarker/python


The following lua commands are important:

imrm : Deletes all images and videos from DCIM on the camera.

remoteshoot -quick=5 : Shoots 5 quick images and saves it on the root folder where chdkptp.exe is located, DOES not save to sd card.

remoteshoot -cont=50 : Shoots 50 images, camera must be in continuous mode. Does not save to SDcard.