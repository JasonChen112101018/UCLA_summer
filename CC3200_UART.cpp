/*
  CC3200 UDP to Serial1 Gateway

  This sketch creates a Wi-Fi Access Point and acts as a bridge
  between UDP and UART (Serial1).

  - Data received via UDP is forwarded to Serial1.
  - Data received from Serial1 is forwarded via UDP to the last known remote client.
*/

#ifndef __CC3200R1M1RGC__
#include <SPI.h>
#endif
#include <WiFi.h>
#include <WiFiUdp.h>

// --- Wi-Fi AP Settings ---
char ssid[] = "MyEnergiaAP";
char password[] = "password"; // Must be 8-63 characters

// --- UDP Settings ---
unsigned int localPort = 8080; // Port to listen for UDP packets on
WiFiUDP Udp;

// --- Buffers ---
char packetBuffer[255]; // Buffer for incoming UDP packet
char uartBuffer[255];   // Buffer for incoming UART data

// --- Remote Client Info ---
// We need to store the IP and port of the last UDP client to know where to send UART data
IPAddress remoteUdpIp;
unsigned int remoteUdpPort = 0;

void setup() {
  // 1. Initialize Serial for debugging
  Serial.begin(115200);
  Serial.println("\nUDP <-> UART Gateway starting...");

  // 2. Initialize Serial1 for the external device
  // IMPORTANT: Make sure this baud rate matches your external device
  Serial1.begin(2500);
  Serial.println("Serial1 started at 2500 baud.");

  // 3. Create the Wi-Fi Access Point
  Serial.print("Creating access point named: ");
  Serial.println(ssid);
  WiFi.beginNetwork((char *)ssid, (char *)password);
  while (WiFi.localIP() == INADDR_NONE) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("Access Point created successfully.");
  printWifiStatus();

  // 4. Start the UDP listener
  Udp.begin(localPort);
  Serial.print("Listening for UDP packets on port ");
  Serial.println(localPort);
  Serial.println("---------------------------------------------------------");
}

void loop() {
  // --- Path 1: Check for UDP packets and forward to UART ---
  int packetSize = Udp.parsePacket();
  if (packetSize > 0) {
    remoteUdpIp = Udp.remoteIP();
    remoteUdpPort = Udp.remotePort();
    
    int len = Udp.read(packetBuffer, packetSize); // Read exact packet size
    if (len > 0) {
      packetBuffer[len] = '\0';
      const char* heartbeatMsg = "heartbeat";

      // Check if the received packet is a heartbeat
      if (strcmp(packetBuffer, heartbeatMsg) != 0) {
        Serial.print("Received command, forwarding to Serial1: ");
        Serial.println(packetBuffer);
        Serial1.write((uint8_t*)packetBuffer, len);
      }
    }
  }

  // --- Path 2: Check for UART data and forward to UDP ---
  if (Serial1.available() > 0) {
    // Data has arrived from the external device
    Serial.print("Received data from Serial1. Forwarding to UDP client...");
    
    // Check if we have a valid UDP client to send to
    if (remoteUdpPort == 0) {
      Serial.println(" No UDP client known. Discarding data.");
      while(Serial1.available()) {
        Serial1.read();
      }
    }

    size_t len = Serial1.readBytes(uartBuffer, sizeof(uartBuffer));
    for (int i=0;i<len;i++){
      Serial.print(uartBuffer[i], BIN);  
    }
    Serial.println();
    
    // Send the collected data as a single UDP packet
    Udp.beginPacket(remoteUdpIp, remoteUdpPort);
    Udp.write((uint8_t*)uartBuffer, len);
    Udp.endPacket();
    Serial.print(" Sent ");
    Serial.print(len);
    Serial.print(" byte.");
  }
}

void printWifiStatus() {
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());
  IPAddress ip = WiFi.localIP();
  Serial.print("AP IP Address: ");
  Serial.println(ip);
}