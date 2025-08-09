from flask import Flask, request, jsonify
import cv2
import numpy as np
import base64

app = Flask(__name__)

def detect_and_annotate_sun(image):
    resized = cv2.resize(image, (640, 480))
    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
    enhanced = clahe.apply(gray)
    
    blurred = cv2.GaussianBlur(enhanced, (11, 11), 0)
    
    thresh_val = 230
    _, thresh = cv2.threshold(blurred, thresh_val, 255, cv2.THRESH_BINARY)
    
    kernel = np.ones((7,7), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
    
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    best_contour = None
    best_score = 0
    
    for cnt in contours:
        (x_c, y_c), radius = cv2.minEnclosingCircle(cnt)
        if radius < 20:
            continue
        
        area = cv2.contourArea(cnt)
        perimeter = cv2.arcLength(cnt, True)
        if perimeter == 0:
            continue
        
        circularity = 4 * np.pi * (area / (perimeter * perimeter))
        if circularity > 0.3 and area > best_score:
            best_score = area
            best_contour = cnt
    
    sun_detected = False
    center_coords = None
    output = image.copy()
    
    if best_contour is not None:
        sun_detected = True
        x, y, w, h = cv2.boundingRect(best_contour)
        scale_x = image.shape[1] / 640
        scale_y = image.shape[0] / 480
        center_x = int((x + w / 2) * scale_x)
        center_y = int((y + h / 2) * scale_y)
        center_coords = [center_x, center_y]

        cv2.rectangle(output, (int(x*scale_x), int(y*scale_y)), 
                      (int((x+w)*scale_x), int((y+h)*scale_y)), 
                      (0, 255, 255), 3)
        cv2.putText(output, "Sun Detected", (int(x*scale_x), int(y*scale_y)-10),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0,255,255), 2)
        cv2.circle(output, (center_x, center_y), 5, (0, 0, 255), -1)

    return sun_detected, center_coords, output

def encode_image_to_base64(image):
    _, buffer = cv2.imencode('.jpg', image)
    img_bytes = buffer.tobytes()
    img_b64 = base64.b64encode(img_bytes).decode('utf-8')
    return img_b64

@app.route('/')
def home():
    return "API running! Use POST /detect_sun with JSON containing base64 image."

@app.route('/detect_sun', methods=['POST'])
def detect_sun():
    data = request.json
    if not data or 'image_base64' not in data:
        return jsonify({'error': 'No image_base64 provided'}), 400
    
    img_b64 = data['image_base64']
    try:
        img_data = base64.b64decode(img_b64)
        img_array = np.frombuffer(img_data, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    except Exception as e:
        return jsonify({'error': f'Failed to decode image: {str(e)}'}), 400
    
    detected, center, annotated_img = detect_and_annotate_sun(img)
    annotated_b64 = encode_image_to_base64(annotated_img)
    
    return jsonify({
        'sun_detected': detected,
        'center': center,
        'annotated_image_base64': annotated_b64
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
    # app.run(host='10.228.187.45', port=5000)
