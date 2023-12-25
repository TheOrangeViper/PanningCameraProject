import subprocess
import threading
import time

chdkptp_path = "chdkptp.exe"

p = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# Send input to the process and receive its output
# output, error = p.communicate(input="help")
# print(output + "\n" + error)

# print(p.stdin.write(""))
# print(p.stdin.write("rec"))

# output, error = p.communicate(input="rec")
# print(output + "\n" + error)

# def run_busyproc():
#     pass
    
# if __name__ == "__main__":
#     thread = threading.Thread(target=run_busyproc)
#     print("Starting thread...")
#     thread.start()
#     if thread.is_alive():
#         p1 = subprocess.Popen([chdkptp_path, "-c", "-i"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
#         p1.stdin.write("rec" + "\n")
#         p1.stdin.flush()
#         time.sleep(4)
#         p1.stdin.write(".set_zoom(0)")
#         p1.stdin.flush()
#         time.sleep(4)
        
#         output, error = p1.communicate()
#         print(output)
#         print('\n')
#         print(error)
        
#         time.sleep(2)
#         p2 = subprocess.Popen([chdkptp_path, "-c", "-g"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        