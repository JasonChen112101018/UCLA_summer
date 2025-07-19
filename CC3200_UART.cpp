/*
 * ===================================================================================
 * Hardware UART to WiFi Bridge - FINAL NON-BLOCKING STATE MACHINE VERSION
 *
 * 【雙向通訊升級版】
 * 這個版本被修改為一個真正的全雙工橋接器。
 * 它不僅能處理從 WiFi -> UART 的請求/回應流程，
 * 還能隨時接收並轉發由 UART 端主動發送的任何訊息。
 *
 * 主要改動：
 * - 使用一個通用的 `handleUartInput()` 函式取代了原來的 `handleUartResponse()`。
 * - 這個新的函式會持續監聽 UART，無論系統處於何種狀態。
 * - 當收到 UART 訊息後，它會判斷這是一個「主動訊息」還是「回應」，
 * 並相應地更新狀態機，實現了真正的雙向非阻塞通訊。
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
// ===== 主狀態機 (控制指令流) =====
// =======================================================
enum UartTxState {
  IDLE,                 // 閒置狀態，可接受來自 WiFi 的新指令
  WAITING_FOR_RESPONSE  // 已發送命令，正在等待 C2000 回應
};
UartTxState uartState = IDLE;
unsigned long commandSentTimestamp = 0;
const unsigned long C2000_RESPONSE_TIMEOUT_MS = 1000; // 總回應超時 (1秒)


// =======================================================
// ===== 新增: UART 接收器狀態變數 =====
// =======================================================
// 這些變數專門用來處理 UART 的即時數據接收
String uartRxBuffer = "";          // 用於組裝來自 UART 的封包
bool isReceivingUartPacket = false; // 標記是否正在接收一個封包 (收到STX後為true)
unsigned long uartPacketStartTime = 0;   // 記錄開始接收封包的時間，用於處理不完整的封包超時
const unsigned long UART_INCOMPLETE_PACKET_TIMEOUT_MS = 200; // 如果封包開始後200ms內沒結束，就丟棄


// === 函式原型 ===
void sendToC2000(const String &msg);
void handleUartInput(); // <--- 已修改為通用的 UART 輸入處理器
void sendToUDPClient(const String &msg);
void handleLEDs();
void handleUDPInput();


void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("\n\nBidirectional Non-Blocking UART/WiFi Bridge Initializing...");
  Serial.println("==========================================================");

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
  handleLEDs();       // 處理 LED (非阻塞)
  handleUDPInput();   // 處理 UDP 輸入 (非阻塞)
  handleUartInput();  // 處理 UART 輸入 (非阻塞) <--- 每次循環都會檢查，實現雙向通訊
  
  // 檢查從 WiFi 發送指令後，C2000 是否超時未回應
  if (uartState == WAITING_FOR_RESPONSE && millis() - commandSentTimestamp > C2000_RESPONSE_TIMEOUT_MS) {
    Serial.println("Timeout: Failed to receive response from C2000.");
    sendToUDPClient("TIMEOUT"); // 可以選擇性地通知客戶端超時
    uartState = IDLE; // 超時，返回閒置狀態，準備接收新指令
  }
}

// ===== 處理 UDP 的輸入 =====
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
      } else {
        Serial.println("Warning: A command is already in progress. Ignoring new command.");
        // 可以選擇性地回傳一個 "BUSY" 訊息給客戶端
        // sendToUDPClient("BUSY");
      }
    }
  }
}

// ===== 修改後: 通用的 UART 輸入處理函式 =====
// 這個函式會被 loop() 不斷呼叫，以非阻塞的方式檢查並處理所有來自 Serial1 的訊息
void handleUartInput() {
  // --- 1. 處理接收到的資料 ---
  while (Serial1.available() > 0) {
    char ch = Serial1.read();

    // 如果還沒開始接收，就等待 STX 的出現
    if (!isReceivingUartPacket) {
      if (ch == STX) {
        isReceivingUartPacket = true;
        uartPacketStartTime = millis(); // 開始計時
        uartRxBuffer = ""; // 清空緩衝區
      }
      // 如果不是STX，就忽略
      continue;
    }

    // 如果已經在接收中
    if (ch == ETX) {
      // 收到結束符，一個完整的封包接收完畢
      Serial.print("UART -> WiFi (Success): ");
      Serial.println(uartRxBuffer);
      sendToUDPClient(uartRxBuffer);
      
      // 【關鍵】如果系統正在等待回應，那麼這個封包就是我們要的回應
      // 將狀態切換回 IDLE，這樣 WiFi 端才能發送下一個指令
      if (uartState == WAITING_FOR_RESPONSE) {
        Serial.println("Info: Response received, system is now IDLE.");
        uartState = IDLE;
      }

      // 重置接收狀態
      isReceivingUartPacket = false;
      uartRxBuffer = "";
      
    } else {
      // 是一般的資料位元，將其加入緩衝區
      uartRxBuffer += ch;
    }
  }

  // --- 2. 處理不完整的封包超時 ---
  if (isReceivingUartPacket && millis() - uartPacketStartTime > UART_INCOMPLETE_PACKET_TIMEOUT_MS) {
    Serial.println("\n--- UART RX Error ---");
    Serial.println("Error: Received STX but no ETX within timeout.");
    Serial.print("Discarded partial data: [");
    Serial.print(uartRxBuffer);
    Serial.println("]\n");

    // 重置接收狀態，丟棄不完整的封包
    isReceivingUartPacket = false;
    uartRxBuffer = "";
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