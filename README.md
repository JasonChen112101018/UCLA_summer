## Getting Started with Flutter

This project was developed using Flutter. If you are new to Flutter, here are some resources to help you get started:

- [To install flutter](https://docs.flutter.dev/get-started/install)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

# Pills WiFi Controller

This is a UDP controller application developed with Flutter, designed for remotely operating custom hardware (e.g., a CC3200-based MCU) over a WiFi network.

## About The Project

This application provides a responsive touch interface, including a virtual joystick and a throttle slider, allowing users to precisely control a target device. The app converts user actions into a specific data format, sends it to the hardware via the UDP protocol, and simultaneously receives and displays real-time status data from the hardware (such as motor RPM, acceleration, etc.).

The project features a clean architecture that completely separates the UI from the backend network communication service and properly manages the app's lifecycle to ensure efficient resource usage.

### Key Features

* **Real-time UDP Communication**: Implements efficient UDP packet transmission and reception based on `dart:io`'s `RawDatagramSocket`.
* **Bidirectional Data Flow**: Capable of not only sending control commands but also receiving and parsing return data from the hardware.
* **Dynamic Control Logic**: The final control output is the product of the joystick's position and the throttle's intensity, enabling finer control.
* **Responsive UI Controls**:
    * A virtual joystick with a configurable coordinate system.
    * A "set-and-forget" throttle slider for adjusting overall power.
* **Real-time Data Dashboard**: Displays real-time data from the MCU (RPM, 3-axis acceleration) at the top of the UI.
* **Clean Project Architecture**: The UI layer is separated from the service layer, making the project easy to maintain and extend.
* **App Lifecycle Management**: Automatically closes the network connection when the app enters the background to save battery and automatically reconnects when it returns to the foreground.

## Screenshots

*Insert a screenshot of the app's main screen here. This will make your project description much more engaging!*

![App Screenshot](https://via.placeholder.com/300x650.png?text=Your+App+Screenshot+Here)

## Running Locally

This section will guide you on how to set up and run the project locally.

### Prerequisites

Ensure you have the Flutter development environment set up.
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (Latest stable version is recommended)

### Installation & Execution Steps

1.  **Clone the Repository**
    ```sh
    git clone [https://github.com/your_username/your_repository.git](https://github.com/your_username/your_repository.git)
    ```
    *(Please replace `your_username/your_repository` with your own GitHub path)*

2.  **Navigate to the Project Directory**
    ```sh
    cd your_repository
    ```

3.  **Install Dependencies**
    ```sh
    flutter pub get
    ```

4.  **Run the App**
    Connect your phone to your computer, ensure the phone and the hardware device are on the same local network, and then run:
    ```sh
    flutter run
    ```

## Project Architecture

This project adopts the Separation of Concerns design principle, with code organized into the following main directories:

lib/
├── main.dart               # App entry point, handles service initialization and app lifecycle
├── services/
│   └── pills_connection_service.dart # Core service: Handles all UDP communication, data packing/parsing logic
└── ui/
├── controller_screen.dart  # Main screen: Assembles all UI components, acts as a bridge between UI and service layers
└── widgets/
├── joystick_right.dart # The right-side joystick widget
└── throttle.dart     # The left-side throttle widget


## Technical Details & Configuration

If you need to adjust the app's core communication parameters, here are the file locations and code snippets you need to know. **All relevant settings are centralized in the `lib/services/pills_connection_service.dart` file.**

### 1. Communication Address (IP & Port)

You can find and modify the target device's IP address and port number at the top of this file.

```dart
// At the top of lib/services/pills_connection_service.dart

final String targetIp = '192.168.1.1'; // <-- Change the IP address here
final int targetPort = 8080;          // <-- Change the Port here
2. Sending Frequency
The app uses a timer to send data periodically. You can adjust the sending frequency by modifying the fps (Frames Per Second) constant.

Location: Inside the _startSendLoop() method.

Description: fps = 5 means data is sent 5 times per second (i.e., every 200 milliseconds).

Dart

// In the _startSendLoop() method

const int fps = 5; // <-- Change this number to alter the sending frequency
const int intervalMs = 1000 ~/ fps;

_sendLoopTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
  _executeSendLogic();
});
3. Communication Protocol
App -> MCU (Sending Format)
The app packages joystick and throttle data into a specific string format. If you need to modify this format (e.g., add or change fields), you can do so in the _buildMessage() method.

Location: Inside the _buildMessage() method.

Current Format: \x02[X-axis value][Y-axis value]\x03 (e.g., \x02+0.85-0.21\x03)

Dart

// In the _buildMessage() method's 'move' case

// ...
final String x = xFormatter.format(data['x'] ?? 0.0);
final String y = yFormatter.format(data['y'] ?? 0.0);
return '\x02$x$y\x03'; // <-- Modify the string combination logic here
MCU -> App (Parsing Logic)
The app listens for return data from the MCU and uses a regular expression to parse it. If your hardware's return format changes, you will need to modify the RegExp in the _parseMcuMessage() method.

Location: Inside the _parseMcuMessage() method.

Current Format: \x02[RPM][AccelX][AccelY][AccelZ]\x03 (e.g., \x02+20.00+0.00-0.00+8.23\x03)

Dart

// In the _parseMcuMessage() method

// This RegExp is used to match all numbers in the "+0.00" or "-12.34" format
final RegExp regex = RegExp(r'([+-][0-9]+\.[0-9]{2})'); // <-- Modify this RegExp to adapt to a new format
final List<Match> matches = regex.allMatches(payload).toList();

if (matches.length == 4) { // <-- If the number of fields changes, modify this number as well
  // ...
}
License
Distributed under the MIT License. See the LICENSE file for more information.
(Reminder: It is recommended to add a file named LICENSE to your project containing the contents of the MIT License.)
