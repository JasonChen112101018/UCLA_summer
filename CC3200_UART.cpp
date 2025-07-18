/*
 * ===================================================================================
 * Hardware UART to WiFi Bridge - FINAL NON-BLOCKING STATE MACHINE VERSION
 *
 * 這是最終的修改版。它使用一個「非阻塞式狀態機」來處理 UART 的接收。
 * 這種設計可以確保 loop() 函式永遠不會被長時間阻塞，從而讓 WiFi 核心
 * 有足夠的 CPU 時間來處理背景網路任務，解決了與阻塞代碼的衝突問題。
 * 這是實現此類橋接器最穩定可靠的軟體架構。
 * ===================================================================================
 */
#include <WiFi.h>
#include <WiFiUdp.h>

// ===== WiFi AP 設定 =====
const char ssid[] = "MyEnergiaAP";
const char password[] = "password";

// ===== UDP Listener 設定 =====
WiFiUDP udp;
const unsigned int udpPort = 8080;

// ===== 遠端客戶端資訊 =====
IPAddress remoteUdpIP;
uint16_t remoteUdpPort = 0;

// ===== Hardware UART (Serial1) 設定 =====
const long C2000_BAUD_RATE = 2500;
const unsigned long C2000_RESPONSE_TIMEOUT_MS = 1000; // 總回應超時 (1秒)

// ===== 傳輸控制碼 =====
#define STX 0x02 // Start of Text
#define ETX 0x03 // End of Text

// ===== 緩衝區 =====
char packetBuffer[255]; // UDP packet buffer

// ===== LED 與連線狀態控制 =====
unsigned long lastPacketTime = 0;
const unsigned long connectionTimeout = 5000;
int currentLED = 0;
unsigned long lastBlinkTime = 0;
const unsigned long blinkInterval = 500;


// =======================================================
// ===== 非阻塞式 UART 接收狀態機 =====
// =======================================================

// 1. 定義接收狀態
enum UartRxState {
  IDLE,               // 閒置狀態，未在等待任何回應
  WAITING_FOR_RESPONSE  // 已發送命令，正在等待回應
};

// 2. 宣告狀態變數
UartRxState uartState = IDLE;
String uartBuffer = "";
unsigned long commandSentTimestamp = 0;

// === 函式原型 ===
void sendToC2000(const String &msg);
void handleUartResponse(); // <--- 新增的狀態機處理函式
void sendToUDPClient(const String &msg);
void handleLEDs();
void handleUDPInput();


void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("\n\nNon-Blocking UART/WiFi Bridge Initializing...");
  Serial.println("==============================================");

  Serial1.begin(C2000_BAUD_RATE);
  Serial.print("Hardware UART (Serial1) started with Baud Rate: ");
  Serial.println(C2000_BAUD_RATE);

  pinMode(RED_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  digitalWrite(RED_LED, LOW);
  digitalWrite(GREEN_LED, LOW);

  Serial.print("Setting up Access Point named: ");
  Serial.println(ssid);
  WiFi.beginNetwork((char *)ssid, (char *)password);

  while (WiFi.localIP() == INADDR_NONE) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("AP active. IP Address: ");
  Serial.println(WiFi.localIP());

  if (udp.begin(udpPort)) {
    Serial.print("UDP Listener started on port ");
    Serial.println(udpPort);
  } else {
    Serial.println("Failed to start UDP Listener.");
  }
}

void loop() {
  handleLEDs();        // 處理 LED (非阻塞)
  handleUDPInput();      // 處理 UDP 輸入 (非阻塞)
  handleUartResponse();  // 處理 UART 回應 (非阻塞) <--- 每次循環都會檢查
}

// ===== 處理 UDP 的輸入 (只發送，不接收) =====
void handleUDPInput() {
  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    lastPacketTime = millis();
    remoteUdpIP = udp.remoteIP();
    remoteUdpPort = udp.remotePort();
    
    int len = udp.read(packetBuffer, 255);
    if (len > 0) packetBuffer[len] = '\0';
    else return;

    char* stxPtr = strchr(packetBuffer, STX);
    char* etxPtr = strchr(packetBuffer, ETX);

    if (stxPtr && etxPtr && etxPtr > stxPtr) {
      *(etxPtr) = '\0';
      String command = String(stxPtr + 1);

      if (command == "heartbeat") {
        // 心跳包，僅維持連線
      } else if (uartState == IDLE) { // 只有在閒置時才能發送新命令
        Serial.print("UDP -> UART: ");
        Serial.println(command);
        sendToC2000(command);
        
        // 發送後，切換到等待狀態，並記錄時間戳
        uartState = WAITING_FOR_RESPONSE;
        commandSentTimestamp = millis();
        uartBuffer = ""; // 清空緩衝區
      } else {
        Serial.println("Warning: A command is already in progress. Ignoring new command.");
      }
    }
  }
}

// ===== 新增: UART 狀態機處理函式 =====
// 這個函式會被 loop() 不斷呼叫，以非阻塞的方式檢查 Serial1
void handleUartResponse() {
  // 只有在 "等待回應" 狀態下才執行此函式
  if (uartState != WAITING_FOR_RESPONSE) {
    return;
  }

  // --- 檢查總超時 ---
  if (millis() - commandSentTimestamp > C2000_RESPONSE_TIMEOUT_MS) {
    Serial.println("\n----------------- !!! DEBUG INFO !!! -----------------");
    Serial.println("Timeout: Failed to receive complete packet from C2000.");
    
    // 【關鍵除錯點】: 印出在超時前，緩衝區裡到底收到了什麼東西
    if (uartBuffer.length() > 0) {
      Serial.print("Partial data received before timeout: [");
      // 逐一印出每個字元的 HEX 值，這樣所有字元(包括控制碼)都看得見
      for (unsigned int i = 0; i < uartBuffer.length(); i++) {
        char c = uartBuffer.charAt(i);
        Serial.print("0x");
        if (c < 16) Serial.print("0"); // 補零
        Serial.print(c, HEX);
        Serial.print(" ");
      }
      Serial.println("]");
    } else {
      Serial.println("No data was received from Serial1 at all.");
    }
    Serial.println("----------------------------------------------------\n");
    
    uartState = IDLE; // 超時，返回閒置狀態
    return;
  }

  // --- 處理接收到的資料 ---
  while (Serial1.available() > 0) {
    char ch = Serial1.read();

    // 如果緩衝區是空的，那麼第一個進來的字元必須是 STX
    if (uartBuffer.length() == 0 && ch != STX) {
      continue; // 忽略封包開始前的任何雜訊
    }
    
    uartBuffer += ch;
    
    // 檢查剛收到的字元是否是結束符
    if (ch == ETX) {
      // 驗證收到的封包是否真的以 STX 開頭
      if (uartBuffer.charAt(0) == STX) {
        // 成功！
        Serial.print("UART -> UDP (Success): ");
        String payload = uartBuffer.substring(1, uartBuffer.length() - 1);
        Serial.println(payload);
        sendToUDPClient(payload);
      } else {
        Serial.println("Error: Received packet ended with ETX but did not start with STX.");
      }
      
      // 處理完畢，返回閒置狀態
      uartState = IDLE;
      return;
    }
  }
}

// ===== 將字串透過 Hardware UART 發送到 C2000 =====
void sendToC2000(const String &msg) {
  Serial1.write(STX);
  Serial1.print(msg);
  Serial1.write(ETX);
}

// ===== 傳送字串給最後一個通訊的 UDP client =====
void sendToUDPClient(const String &msg) {
  if (remoteUdpPort != 0) {
    udp.beginPacket(remoteUdpIP, remoteUdpPort);
    udp.write(STX);
    udp.print(msg);
    udp.write(ETX);
    udp.endPacket();
  }
}

// ===== 處理 LED 閃爍，表示活動狀態 =====
void handleLEDs() {
  if (millis() - lastPacketTime < connectionTimeout) {
    unsigned long now = millis();
    if (now - lastBlinkTime >= blinkInterval) {
      lastBlinkTime = now;
      digitalWrite(RED_LED, LOW);
      digitalWrite(GREEN_LED, LOW);
      currentLED = !currentLED;
      if (currentLED) {
        digitalWrite(RED_LED, HIGH);
      } else {
        digitalWrite(GREEN_LED, HIGH);
      }
    }
  } else {
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, LOW);
    if (remoteUdpPort != 0) {
      Serial.println("Client timed out.");
      remoteUdpPort = 0;
    }
  }
}