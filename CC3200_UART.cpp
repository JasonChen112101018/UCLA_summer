/*
  CC3200 Asynchronous UDP <-> UART Gateway
  - Corrected for non-blocking UART receive and baud rate match.
  - Forwards all non-heartbeat UDP packets to Serial1.
  - Forwards all complete Serial1 data packets (delimited by STX/ETX)
    to the last known UDP client.
*/

#ifndef __CC3200R1M1RGC__
#include <SPI.h>
#endif
#include <WiFi.h>
#include <WiFiUdp.h>

// --- Wi-Fi & UDP Settings ---
char ssid[] = "MyEnergiaAP";
char password[] = "password";
unsigned int localPort = 8080;
WiFiUDP Udp;

// --- Buffers ---
char packetBuffer[255]; // For incoming UDP packets
char uartBuffer[255];   // For assembling incoming UART data
size_t uartBufferIndex = 0; // Index for the UART buffer

// --- Remote Client Info ---
IPAddress remoteUdpIp;
unsigned int remoteUdpPort = 0; // Starts at 0, populated by the first UDP packet

// =================================================================
// SETUP FUNCTION
// =================================================================
void setup() {
  // Start the primary serial port for debugging output
  Serial.begin(115200);
  Serial.println("\nAsync UDP <-> UART Gateway starting...");

  // Start the secondary serial port for communication with the C2000
  // CORRECTED BAUD RATE to match C2000
  Serial1.begin(100000);
  Serial.println("Serial1 started at 100000 baud.");

  // Configure Wi-Fi as an Access Point
  WiFi.beginNetwork((char *)ssid, (char *)password);
  Serial.print("Creating access point...");
  while (WiFi.localIP() == INADDR_NONE) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nAccess Point Ready.");
  printWifiStatus();

  // Begin listening for UDP packets
  Udp.begin(localPort);
  Serial.print("Listening on UDP port ");
  Serial.println(localPort);
  Serial.println("------------------------------------");
  Serial.println("Waiting for first packet from client to establish return address...");
}

// =================================================================
// MAIN LOOP
// =================================================================
void loop() {
  // --- Path 1: App -> C2000 (UDP -> UART) ---
  int packetSize = Udp.parsePacket();
  if (packetSize > 0) {
    // Store the client's address to know where to send replies
    remoteUdpIp = Udp.remoteIP();
    remoteUdpPort = Udp.remotePort();

    int len = Udp.read(packetBuffer, packetSize);
    if (len > 0) {
      packetBuffer[len] = '\0'; // Null-terminate for string functions
      const char* heartbeatMsg = "\x02heartbeat\x03";

      // Ignore heartbeat messages, forward everything else
      if (strcmp(packetBuffer, heartbeatMsg) != 0) {
        // Forward the valid command to the C2000
        Serial.print("UDP -> UART: ");
        Serial.println(packetBuffer);
        Serial1.write((uint8_t*)packetBuffer, len);
      }
    }
  }

  // --- Path 2: C2000 -> App (UART -> UDP) ---
  // This is the new, non-blocking logic to prevent latency.
  while (Serial1.available() > 0) {
    // Don't process if we don't know who the client is yet
    if (remoteUdpPort == 0) {
        while(Serial1.available()) { Serial1.read(); } // Discard data
        return; 
    }

    char receivedChar = (char)Serial1.read();

    // Check for Start of Text (STX) character to begin a new packet
    if (receivedChar == '\x02') {
      // Reset buffer for a new packet
      uartBufferIndex = 0; 
    } 
    // Check for End of Text (ETX) character to finalize the packet
    else if (receivedChar == '\x03') {
      if (uartBufferIndex > 0) { // Ensure the packet is not empty
        
        // --- A complete packet has been received ---

        // For debugging: null-terminate and print the received string
        uartBuffer[uartBufferIndex] = '\0';
        Serial.print("UART -> UDP: ");
        Serial.println(uartBuffer);
        
        // Send the packet to the app via UDP
        Udp.beginPacket(remoteUdpIp, remoteUdpPort);
        Udp.write((uint8_t*)uartBuffer, uartBufferIndex);
        Udp.endPacket();
      }
      // Reset buffer index for the next packet, whether it was empty or not
      uartBufferIndex = 0;
    } 
    // It's a regular data character
    else {
      // Add the character to our assembly buffer if there's space
      if (uartBufferIndex < (sizeof(uartBuffer) - 1)) {
        uartBuffer[uartBufferIndex] = receivedChar;
        uartBufferIndex++;
      } else {
        // Buffer overflow protection: something is wrong, reset.
        uartBufferIndex = 0;
      }
    }
  }
}

// =================================================================
// HELPER FUNCTION
// =================================================================
void printWifiStatus() {
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());
  IPAddress ip = WiFi.localIP();
  Serial.print("AP IP Address: ");
  Serial.println(ip);
}