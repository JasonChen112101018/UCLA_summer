#include <WiFi.h>
#include <WiFiUdp.h> // 引入 UDP 函式庫

// ===== WiFi AP 設定 =====
const char ssid[] = "MyEnergiaAP";
const char password[] = "password";

// ===== UDP Listener 設定 =====
WiFiUDP udp;
const unsigned int udpPort = 8080;

// ===== 遠端客戶端資訊 =====
// 用於儲存最後一個與我們通訊的 App 的 IP 和 Port
IPAddress remoteUdpIP;
uint16_t remoteUdpPort = 0; // Port 為 0 表示尚未收到任何封包

// ===== UART 設定 =====
#define C2000_SERIAL Serial1
#define C2000_BAUDRATE 115200

// ===== 傳輸控制碼 =====
#define STX 0x02 // Start of Text
#define ETX 0x03 // End of Text

// ===== 緩衝區 =====
// UDP 封包緩衝區，大小可以根據最大指令長度調整
char packetBuffer[255];
String uartBuffer = "";
bool receivingUART = false;

// ===== LED 與連線狀態控制 =====
unsigned long lastPacketTime = 0;
// 5秒沒收到任何封包 (包括心跳) 就視為離線
const unsigned long connectionTimeout = 5000; 
int currentLED = 0;
unsigned long lastBlinkTime = 0;
const unsigned long blinkInterval = 500;


void setup() {
  // 初始化與電腦的序列埠，用於監控和除錯
  Serial.begin(115200);

  // 初始化與 C2000 設備通訊的硬體序列埠
  C2000_SERIAL.begin(C2000_BAUDRATE);

  // LED 初始化
  pinMode(RED_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  digitalWrite(RED_LED, LOW);
  digitalWrite(GREEN_LED, LOW);

  // 建立 WiFi AP
  Serial.print("Setting up Access Point named: ");
  Serial.println(ssid);
  WiFi.beginNetwork((char *)ssid, (char *)password);

  // 等待 WiFi AP 啟動並取得 IP
  while (WiFi.localIP() == INADDR_NONE) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("AP active. IP Address: ");
  Serial.println(WiFi.localIP());

  // 啟動 UDP 監聽
  if (udp.begin(udpPort)) {
    Serial.print("UDP Listener started on port ");
    Serial.println(udpPort);
  } else {
    Serial.println("Failed to start UDP Listener.");
  }
}

void loop() {
  handleLEDs();         // 處理 LED 狀態顯示
  handleUDPInput();     // 處理來自 UDP 的資料
  handleUARTResponse();   // 處理來自 UART (C2000) 的資料
}

// ===== 處理 LED 閃爍，表示活動狀態 =====
void handleLEDs() {
  // 如果在 connectionTimeout 時間內有收到過封包，則視為「活動中」
  if (millis() - lastPacketTime < connectionTimeout) {
    unsigned long now = millis();
    if (now - lastBlinkTime >= blinkInterval) {
      lastBlinkTime = now;
      digitalWrite(RED_LED, LOW);
      digitalWrite(GREEN_LED, LOW);

      // 交替閃爍紅綠燈
      currentLED = !currentLED;
      if(currentLED) {
        digitalWrite(RED_LED, HIGH);
      } else {
        digitalWrite(GREEN_LED, HIGH);
      }
    }
  } else {
    // 如果超時，關閉所有 LED，並清除遠端資訊
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, LOW);
    if (remoteUdpPort != 0) {
      Serial.println("Client timed out.");
      remoteUdpPort = 0; // 重置遠端 Port，表示沒有活動中的客戶端
    }
  }
}


// ===== 處理 UDP 的輸入資料並傳給 C2000 (UART) =====
void handleUDPInput() {
  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    // 收到任何封包，都代表連線活躍，更新時間戳和遠端客戶端資訊
    lastPacketTime = millis();
    remoteUdpIP = udp.remoteIP();
    remoteUdpPort = udp.remotePort();

    // 讀取封包內容
    int len = udp.read(packetBuffer, 255);
    if (len > 0) {
      packetBuffer[len] = '\0'; // 加上字串結束符
    } else {
      return; // 空封包則忽略
    }

    // 從封包中解析出 STX 和 ETX 之間的內容
    char* stxPtr = strchr(packetBuffer, STX);
    char* etxPtr = strchr(packetBuffer, ETX);

    if (stxPtr != nullptr && etxPtr != nullptr && etxPtr > stxPtr) {
      // 找到 STX 和 ETX，提取中間的內容
      *(etxPtr) = '\0'; // 將 ETX 位置設為字串結束符，巧妙地截斷字串
      String command = String(stxPtr + 1);
      
      // 判斷是否為心跳包
      if (command == "heartbeat") {
        // Serial.println("Heartbeat received."); // 可選的除錯訊息
        // 對於心跳包，我們只更新時間，不需做任何事
      } else {
        // 對於其他真實指令，才轉發給 C2000
        Serial.print("UDP -> UART: ");
        Serial.println(command);
        sendToC2000(command);
      }
    }
  }
}


// ===== 將字串透過 UART 發送到 C2000 =====
void sendToC2000(const String &msg) {
  C2000_SERIAL.write(STX);
  C2000_SERIAL.print(msg);
  C2000_SERIAL.write(ETX);
}


// ===== 處理從 C2000 回傳的 UART 訊息並轉發給 UDP client =====
void handleUARTResponse() {
  while (C2000_SERIAL.available()) {
    char ch = C2000_SERIAL.read();

    if (ch == STX) {
      receivingUART = true;
      uartBuffer = ""; // 開始接收，清空緩衝區
    } else if (ch == ETX && receivingUART) {
      receivingUART = false; // 接收結束
      Serial.print("UART -> UDP: ");
      Serial.println(uartBuffer);
      sendToUDPClient(uartBuffer); // 將收到的資料轉發給 UDP client
    } else if (receivingUART) {
      uartBuffer += ch; // 將字元加入緩衝區
    }
  }
}


// ===== 傳送字串給最後一個通訊的 UDP client =====
void sendToUDPClient(const String &msg) {
  // 必須知道回傳對象 (Port 不為 0)
  if (remoteUdpPort != 0) {
    udp.beginPacket(remoteUdpIP, remoteUdpPort);
    udp.write(STX);
    udp.print(msg);
    udp.write(ETX);
    udp.endPacket();
  }
}