# Python 이미지 사용
FROM python:3.8

# 작업 디렉토리 설정
WORKDIR /app

# pip 업그레이드 및 필요한 패키지 설치
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 애플리케이션 복사
COPY . .

# 애플리케이션 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
