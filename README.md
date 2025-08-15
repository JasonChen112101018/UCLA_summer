# wireless Motor Controller Project
This repository showcases a highly adaptable framework for the real-time, remote control of hardware devices.

The architecture integrates a cross-platform mobile interface built with Flutter, a low-latency UDP communication link over WiFi, and a flexible embedded systems backend. It is designed to be a versatile platform capable of controlling a wide range of mechatronic systems, such as a robotic arm,or a Wireless Sensing Capsule (WSC). This advanced application demonstrates the system's potential in the field of non-invasive medical diagnostics, offering a glimpse into the future of internal medicine. 

This repository contains four main components:
1.  A **Flutter application** that serves as a remote controller.
2.  An **Energia IDE sketch** for a CC3200 board that acts as a UDP-UART bidirectional gateway.
3.  **MATLAB Simulink models** for a C2000 F28379D microcontroller for motor control and sensor data acquisition.
---
## 1. Flutter Mobile Application

### Getting Started with Flutter
This project was developed using Flutter. If you are new to Flutter, the official documentation is the best place to start:

- [Flutter Official Documentation](https://docs.flutter.dev/get-started)

### Installation and Setup
1.  **Clone the Repository**
2.  **Install Dependencies(get into your flutter app folder)**
    ```sh
    flutter pub get
    ```

3.  **Configure Target IP**
    The CC3200 runs in Access Point (AP) mode, and its IP is typically **192.168.1.1**. If you change this, update the IP in the Flutter app:
    * **File**: `lib/services/pills_connection_service.dart`
    * **Code**: Modify the `targetIp` constant.

4.  **Run the App**
    Connect your mobile device to the CC3200's WiFi network (`MyEnergiaAP`) and run the app:
    ```sh
    flutter run
    ```
### structure of app

lib/

├── main.dart               #App entry point, handles service initialization and app lifecycle

├── services/

│   └── pills_connection_service.dart #Core service: Handles all UDP communication, data packing/parsing logic

└── ui/

├── controller_screen.dart  #Main screen: Assembles all UI components, acts as a bridge between UI and service layers

└── widgets/

├── joystick_right.dart #The right-side joystick widget

└── throttle.dart     #The left-side throttle widget

---
## 2. CC3200 Firmware (Energia IDE)
The provided code configures the CC3200 board to function as a wireless gateway. It creates a WiFi Access Point and forwards UDP packets to its UART serial port (and vice-versa).

### Environment Setup
1.  **IDE**: Install [**Energia IDE**](http://energia.nu/download/), which is a fork of Arduino IDE for Texas Instruments microcontrollers.

### Configuration and Upload
1.  **Open the Sketch**: Open the `CC3200_UART.cpp` file in the Energia IDE.
2.  **Configure WiFi (Optional)**: If you wish to change the WiFi network name or password, modify these lines at the top of the file:
    ```cpp
    char ssid[] = "MyEnergiaAP";
    char password[] = "password";
    ```
3.  **Upload**: Connect your CC3200 board to your computer, select the correct board and COM port in the Energia IDE, and click the "Upload" button. The board will then create the specified WiFi network and begin listening for UDP connections.

---
## 3. C2000 F28379D Firmware (MATLAB Simulink)

This section contains Simulink models designed for the TI C2000 F28379D MCU.

⚠ **Status: Work-in-Progress**
Please note that these models are currently in development, may not function correctly, and have not yet been integrated into a final, unified firmware.

### Models
1.  **wifi-sci-receive.slx**: Receives commands via UART (from the CC3200) to control a motor.
2.  **i2c_example.slx**: A separate model for acquiring data from an MPU6050 sensor.(may have something wrong in the model)

### Environment Setup
2.  **Hardware**: TI C2000 F28379D LaunchPad development board、motion tracking device(mpu6050)、driver(DRV8833)、motor

### Usage
Open the `.slx` files in MATLAB Simulink. Use the Embedded Coder to generate code and flash it to the F28379D LaunchPad.

---
## License
This project is distributed under the MIT License.
