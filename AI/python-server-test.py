from fastapi import FastAPI, Request, UploadFile, File
import cv2
import numpy as np
import os
import time
from deepface import DeepFace
import threading
import logging
from pydub import AudioSegment
import wave

app = FastAPI()
last_analysis_time = time.time()
save_images = False
start_save_time = 0
save_duration = 10  # 이벤트 발생 후 10초 동안 이미지 저장
buffer_duration = 5  # 이벤트 발생 전 5초 동안 이미지 버퍼 유지
frame_rate = 30
image_buffer = []
audio_buffer = []
analysis_interval = 1  # 1초 간격 분석
current_event_dir = ""  # 현재 이벤트의 디렉토리
dominant_emotion = ""
end_time = 0
frame_intervals = []  # 프레임 간격 저장

# FastAPI 접근 로그 출력 제거
logging.getLogger("uvicorn.access").disabled = True

def get_current_time_str():
    """
    현재 시간을 지정된 형식으로 반환하는 함수.
    """
    return time.strftime("%y%m%d_%H%M")

@app.post("/send")
async def receive_frames(videoFrame: UploadFile = File(...), audioFrame: UploadFile = File(...)):
    global last_analysis_time, save_images, start_save_time, image_buffer, audio_buffer, current_event_dir, dominant_emotion, end_time, frame_intervals
    video_data = await videoFrame.read()
    audio_data = await audioFrame.read()
    
    nparr = np.frombuffer(video_data, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    current_time = time.time()
    
    # 프레임 간격 저장
    if image_buffer:
        frame_intervals.append(current_time - image_buffer[-1][1])
    
    # 이미지 버퍼에 저장
    image_buffer.append((img, current_time))
    if len(image_buffer) > (buffer_duration + save_duration) * frame_rate:  # 30 FPS 기준 버퍼 유지
        image_buffer.pop(0)
    
    # 오디오 버퍼에 저장
    audio_buffer.append((audio_data, current_time))
    if len(audio_buffer) > (buffer_duration + save_duration) * frame_rate:
        audio_buffer.pop(0)
    
    # 이미지 분석
    if not save_images and current_time - last_analysis_time >= analysis_interval:
        last_analysis_time = current_time
        threading.Thread(target=analyze_emotion, args=(img,)).start()
    
    # 이미지 저장
    if save_images:
        save_frame(img, audio_data, current_event_dir, len(image_buffer))
        if current_time >= end_time:
            save_images = False  # 이미지 저장 중지
            create_video_from_frames(current_event_dir, frame_intervals)

    return {"status": "received"}

def analyze_emotion(img):
    global save_images, start_save_time, image_buffer, audio_buffer, current_event_dir, dominant_emotion, end_time
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    try:
        analysis = DeepFace.analyze(img_rgb, actions=['emotion'], enforce_detection=False)
        if isinstance(analysis, list):
            analysis = analysis[0]
        dominant_emotion = analysis['dominant_emotion']
        emotion_scores = analysis['emotion']
        score = emotion_scores[dominant_emotion]
        print(f"감정 인식 결과: {dominant_emotion} - {score:.2f}")  # 표정과 점수를 콘솔에 출력
        if score >= 88:
            save_images = True
            start_save_time = time.time()
            end_time = start_save_time + save_duration
            current_event_dir = os.path.abspath(f'{get_current_time_str()}_{dominant_emotion}')
            os.makedirs(current_event_dir, exist_ok=True)
            os.makedirs(os.path.join(current_event_dir, "frames"), exist_ok=True)
            os.makedirs(os.path.join(current_event_dir, "audio"), exist_ok=True)
            save_frames_from_buffer()
            print(f"녹화 시작: {dominant_emotion} - {score:.2f} (5초 전부터 10초간)")
    except Exception as e:
        print(f"Error in emotion detection: {str(e)}")

def save_frames_from_buffer():
    """
    버퍼에 있는 프레임을 저장하는 함수.
    """
    global save_images, image_buffer, audio_buffer, current_event_dir
    current_time = time.time()
    for idx, ((img, img_time), (audio_data, audio_time)) in enumerate(zip(image_buffer, audio_buffer), 1):
        if current_time - img_time <= buffer_duration + save_duration:
            save_frame(img, audio_data, current_event_dir, idx)
    image_buffer.clear()
    audio_buffer.clear()

def save_frame(img, audio_data, save_dir, idx):
    """
    프레임을 디스크에 저장하는 함수.

    :param img: 저장할 이미지
    :param audio_data: 저장할 오디오 데이터
    :param save_dir: 저장할 디렉토리
    :param idx: 파일 이름에 포함할 인덱스
    """
    try:
        os.makedirs(save_dir, exist_ok=True)  # 디렉토리가 없으면 생성
    except Exception as e:
        print(f"디렉토리 생성 오류: {e}")
        return
    
    image_path = f'{save_dir}/frames/frame{idx:05d}.npy'  # 이미지 파일 경로 생성
    audio_path = f'{save_dir}/audio/audio{idx:05d}.wav'  # 오디오 파일 경로 생성
    
    try:
        np.save(image_path, img)  # 이미지 배열 저장
        with wave.open(audio_path, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(44100)
            wf.writeframes(audio_data)
        print(f"프레임 저장 성공: {image_path}, {audio_path}")
    except Exception as e:
        print(f"프레임 저장 중 예외 발생: {e}")
        print(f"디렉토리 경로: {save_dir}, 이미지 경로: {image_path}, 오디오 경로: {audio_path}")

def create_video_from_frames(event_dir, frame_intervals):
    """
    저장된 프레임 파일들을 모아 동영상 파일로 만드는 함수.
    """
    frame_dir = os.path.join(event_dir, "frames")
    audio_dir = os.path.join(event_dir, "audio")
    
    images = sorted([img for img in os.listdir(frame_dir) if img.endswith(".npy")])
    audios = sorted([aud for aud in os.listdir(audio_dir) if aud.endswith(".wav")])
    
    frame_array = []
    for image in images:
        img_path = os.path.join(frame_dir, image)
        img_array = np.load(img_path)
        frame_array.append(img_array)
    
    if not frame_array:
        print("No frames found")
        return
    
    height, width, layers = frame_array[0].shape
    size = (width, height)
    video_path = os.path.join(frame_dir, "output_video.mp4")
    
    # 평균 프레임 레이트 계산
    if frame_intervals:
        average_interval = sum(frame_intervals) / len(frame_intervals)
        fps = int(1 / average_interval)
    else:
        fps = 30  # 기본값
    
    # VideoWriter 객체 초기화 (프레임 레이트를 동적으로 설정)
    out = cv2.VideoWriter(video_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, size)
    
    for frame in frame_array:
        out.write(frame)
    out.release()
    print(f"동영상 저장 성공: {video_path}, FPS: {fps}")

    combined_audio = AudioSegment.empty()
    for audio in audios:
        audio_path = os.path.join(audio_dir, audio)
        audio_segment = AudioSegment.from_wav(audio_path)
        combined_audio += audio_segment
    
    combined_audio_path = os.path.join(audio_dir, "combined_output.wav")
    combined_audio.export(combined_audio_path, format="wav")
    print(f"오디오 저장 성공: {combined_audio_path}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
