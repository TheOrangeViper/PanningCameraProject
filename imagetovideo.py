import cv2
import os

def convert_images_to_video(image_folder, video_name='output_video.avi', fps=20):
    # print(os.listdir(image_folder))
    images = [img for img in os.listdir(image_folder) if img.endswith(".ppm")]
    
    print(images)
    frame = cv2.imread(os.path.join(image_folder, images[0]))
    height, width, layers = frame.shape
    print(frame.shape)
    video = cv2.VideoWriter(video_name, cv2.VideoWriter_fourcc(*'XVID'), fps, (width, height))

    for image in images:
        img_path = os.path.join(image_folder, image)
        frame = cv2.imread(img_path)
        video.write(frame)
        os.remove(img_path)

if __name__ == "__main__":
    image_folder = './'
    convert_images_to_video(image_folder)