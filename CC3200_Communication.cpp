/*
 * CC3200 Communication Bridge
 * UI ↔ CC3200 ↔ TI2837xD Bidirectional Communication
 * 
 * Functions:
 * 1. receiveFromUI_sendTo2837xD() - Forward commands from UI to TI2837xD
 * 2. receiveFrom2837xD_sendToUI() - Send feedback from TI2837xD to UI
 */

#include <WiFi.h>
#include <WiFiServer.h>
#include <WiFiClient.h>

// Network Configuration
char ssid[] = "YourWiFiNetwork";
char password[] = "YourPassword";
WiFiServer server(80);
WiFiClient client;

// Communication Buffers
String uiCommand = "";
String ti2837xdResponse = "";
bool commandReady = false;
bool responseReady = false;

// Pin Definitions
#define LED_PIN RED_LED
#define STATUS_PIN GREEN_LED

void setup() {
  Serial.begin(115200);   // USB Serial for debugging
  Serial1.begin(9600);    // UART to TI2837xD
  
  pinMode(LED_PIN, OUTPUT);
  pinMode(STATUS_PIN, OUTPUT);
  
  // Initialize WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
    digitalWrite(LED_PIN, !digitalRead(LED_PIN)); // Blink while connecting
  }
  
  server.begin();
  digitalWrite(STATUS_PIN, HIGH); // Connected indicator
  Serial.println("CC3200 Bridge Ready!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Handle WiFi client connections
  client = server.available();
  
  if (client) {
    receiveFromUI_sendTo2837xD();
  }
  
  receiveFrom2837xD_sendToUI();
  
  delay(10); // Small delay for stability
}

/*
 * Function 1: Receive commands from UI and forward to TI2837xD
 * Protocol: JSON-like format {"cmd":"command","data":"value"}
 */
void receiveFromUI_sendTo2837xD() {
  if (client.connected()) {
    String httpRequest = "";
    
    // Read HTTP request from UI
    while (client.available()) {
      char c = client.read();
      httpRequest += c;
      
      // Check for complete HTTP request
      if (httpRequest.endsWith("\r\n\r\n")) {
        break;
      }
    }
    
    // Parse command from HTTP request
    if (httpRequest.length() > 0) {
      Serial.println("Received from UI: " + httpRequest);
      
      // Extract command from HTTP GET/POST
      String command = parseCommand(httpRequest);
      
      if (command.length() > 0) {
        // Forward to TI2837xD via UART
        Serial1.print("START:");
        Serial1.print(command);
        Serial1.println(":END");
        
        Serial.println("Sent to TI2837xD: " + command);
        
        // Send acknowledgment to UI
        sendHTTPResponse("Command sent: " + command);
        
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
      }
    }
  }
}

/*
 * Function 2: Receive feedback from TI2837xD and send to UI
 * Continuously monitors UART for responses
 */
void receiveFrom2837xD_sendToUI() {
  static String serialBuffer = "";
  
  // Read from TI2837xD
  while (Serial1.available()) {
    char inChar = Serial1.read();
    serialBuffer += inChar;
    
    // Check for complete message (ending with newline)
    if (inChar == '\n') {
      // Process complete message
      String response = serialBuffer;
      response.trim();
      
      if (response.startsWith("RESPONSE:") && response.endsWith(":END")) {
        // Extract actual response data
        String responseData = response.substring(9, response.length() - 4);
        
        Serial.println("Received from TI2837xD: " + responseData);
        
        // Store for next UI request or send via WebSocket/HTTP
        ti2837xdResponse = responseData;
        responseReady = true;
        
        // If client is still connected, send immediate response
        if (client && client.connected()) {
          sendHTTPResponse("TI2837xD Response: " + responseData);
        }
        
        // Blink status LED
        digitalWrite(STATUS_PIN, LOW);
        delay(50);
        digitalWrite(STATUS_PIN, HIGH);
      }
      
      serialBuffer = ""; // Clear buffer
    }
  }
}

/*
 * Helper Functions
 */

// Parse command from HTTP request
String parseCommand(String httpRequest) {
  String command = "";
  
  // Look for GET parameters
  int cmdStart = httpRequest.indexOf("cmd=");
  if (cmdStart != -1) {
    cmdStart += 4; // Skip "cmd="
    int cmdEnd = httpRequest.indexOf("&", cmdStart);
    if (cmdEnd == -1) {
      cmdEnd = httpRequest.indexOf(" ", cmdStart);
    }
    
    if (cmdEnd != -1) {
      command = httpRequest.substring(cmdStart, cmdEnd);
      command = urlDecode(command);
    }
  }
  
  // Alternative: Look for JSON in POST body
  if (command.length() == 0) {
    int jsonStart = httpRequest.indexOf("{");
    int jsonEnd = httpRequest.lastIndexOf("}");
    
    if (jsonStart != -1 && jsonEnd != -1) {
      String jsonData = httpRequest.substring(jsonStart, jsonEnd + 1);
      command = parseJSONCommand(jsonData);
    }
  }
  
  return command;
}

// Simple JSON parser for {"cmd":"value"}
String parseJSONCommand(String json) {
  int cmdStart = json.indexOf("\"cmd\":");
  if (cmdStart != -1) {
    cmdStart = json.indexOf("\"", cmdStart + 6) + 1;
    int cmdEnd = json.indexOf("\"", cmdStart);
    if (cmdEnd != -1) {
      return json.substring(cmdStart, cmdEnd);
    }
  }
  return "";
}

// Send HTTP response to UI
void sendHTTPResponse(String message) {
  if (client && client.connected()) {
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Connection: close");
    client.println();
    
    // JSON response
    client.print("{\"status\":\"success\",\"message\":\"");
    client.print(message);
    client.print("\",\"timestamp\":");
    client.print(millis());
    client.println("}");
    
    client.stop();
  }
}

// Simple URL decoder
String urlDecode(String str) {
  String decoded = "";
  char temp[] = "0x00";
  unsigned int len = str.length();
  unsigned int i = 0;
  
  while (i < len) {
    char decodedChar;
    if (str[i] == '%') {
      temp[2] = str[i + 1];
      temp[3] = str[i + 2];
      decodedChar = strtol(temp, NULL, 16);
      i += 3;
    } else if (str[i] == '+') {
      decodedChar = ' ';
      i++;
    } else {
      decodedChar = str[i];
      i++;
    }
    decoded += decodedChar;
  }
  
  return decoded;
}

/*
 * Additional Utility Functions for Enhanced Communication
 */

// Get latest response for polling-based UI
String getLatestResponse() {
  if (responseReady) {
    responseReady = false;
    return ti2837xdResponse;
  }
  return "No new data";
}

// Send specific command types to TI2837xD
void sendCommandToTI2837xD(String cmdType, String data) {
  String formattedCmd = "CMD:" + cmdType + ":" + data + ":END";
  Serial1.println(formattedCmd);
  Serial.println("Formatted command sent: " + formattedCmd);
}

// Health check function
bool checkTI2837xDConnection() {
  Serial1.println("PING:END");
  delay(1000);
  
  // Wait for PONG response
  unsigned long startTime = millis();
  while (millis() - startTime < 3000) { // 3 second timeout
    if (Serial1.available()) {
      String response = Serial1.readString();
      if (response.indexOf("PONG") != -1) {
        return true;
      }
    }
  }
  return false;
}