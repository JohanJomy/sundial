

<img src="./assests/banner.png" width="3188" height="1202"><br>
<em>Useless Projects 2.0 Banner</em>


# Sun Dial

## Basic Details

### Team Name
Chumma Oru Team

### Team Members
- Johan Jomy Kuruvilla – Saintgits College of Engineering
- Sejith R Nath – Saintgits College of Engineering

### Project Description
Sun Dial is a fun and experimental app that tells the time using the position of the sun captured by your phone’s camera. The app calculates the azimuth angle by considering the direction the phone is facing, latitude, longitude, and the phone’s tilt (pitch and roll). The frontend is built with Flutter and Dart, while the backend uses Python and OpenCV for sun detection. Communication between Dart and Python is handled via a Flask API.

### The Problem (That Doesn't Exist)
It's apparently "too hard" to check the time using your phone or watch, since you have to raise your hand.

### The Solution (That Nobody Asked For)
We engineered a revolutionary solution: just point your camera at the sun, and our app will calculate the time of day using sensor data and image processing. No need to look at your watch!

---

## How to Use

### Step 1: Install Required Packages

**Python Libraries**
```bash
pip install Flask
pip install numpy
pip install opencv-python
```

**Running the API Server**
1. Go to the `server_python` folder.
2. Open `sun_detect.py`.
3. Make sure the last line is:
   ```python
   app.run(host='0.0.0.0', port=5000)
   ```
   Replace `0.0.0.0` with your computer's IP address (find it using `ipconfig` in the terminal).
4. Run the Python file. You should see something like:
   ```
   * Running on http://192.168.1.8:5000/
   ```
5. Copy this link and paste it in `lib/camera.dart` as the `apiId`.

**Running the Flutter App**
1. Connect your mobile device to your PC.
2. Run:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
   Make sure Flutter and Dart are installed on your PC.

**Allow Camera Access**
- The app will request permission to use your camera. Click **"Allow"**. This is required for sun detection.

**Allow Location Access**
- The app will request permission to use your location. Click **"Allow"**. This is required for calculating the azimuth angle.

**Take a Picture**
- For best results, ensure the sun is clearly visible to the camera and there are no obstructions.
- The picture will be sent to the Flask API, processed in Python with OpenCV, and the result will be sent back to Dart for time calculation.

### Step 2: Have Fun!

You're ready to start using Sun Dial! Enjoy finding the time using your phone's camera and sensors.

---

## Technical Details

### Technologies/Components Used

**Software:**
- **Languages:** Dart (Flutter), Python
- **Tools:**
  - Code editor (e.g., VS Code)
  - Local web server/API (Python Flask)

**Hardware:**
- Mobile camera
- Accelerometer
- Magnetometer
- GPS

### How It Works

1. The app captures an image of the sun using your phone's camera.
2. Sensor data (magnetometer, accelerometer, GPS) is collected to determine device orientation and location.
3. The image is sent to the Python backend via a Flask API.
4. Python uses OpenCV to detect the sun and annotate the image.
5. The backend returns the sun's position and an annotated image.
6. The app calculates the time based on the sun's position and device orientation.

---

## Screenshots

Screenshots will be added soon—once we get some sunny images during the daytime!

---

## Disclaimer

This app is for fun and educational purposes. It is not a replacement for a real