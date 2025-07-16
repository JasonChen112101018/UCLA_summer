#include <WiFi.h>

// ===== WiFi AP 設定 =====
const char ssid[] = "MyEnergiaAP";
const char password[] = "password";

// ===== TCP Server =====
WiFiServer tcpServer(8080);
WiFiClient tcpClient;

// ===== UART 設定（ESP32 可用 Serial1/Serial2）=====
#define C2000_SERIAL Serial1
#define C2000_BAUDRATE 115200

// ===== 傳輸控制碼 =====
#define STX 0x02
#define ETX 0x03

// ===== 緩衝區和旗標 =====
String tcpBuffer = "";
bool receivingTCP = false;

String uartBuffer = "";
bool receivingUART = false;

int currentLED = 0;
unsigned long lastBlinkTime = 0;
const unsigned long blinkInterval = 500;

void setup() {
  Serial.begin(115200);
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

  while (WiFi.localIP() == INADDR_NONE) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("AP active. IP: ");
  Serial.println(WiFi.localIP());

  // 啟動 TCP 伺服器
  tcpServer.begin();
  Serial.println("TCP Server started on port 8080");
}

void loop() {
  handleLEDs();
  acceptNewTCPClient();
  handleTCPInput();        // TCP → UART
  handleUARTResponse();    // UART → TCP
  delay(10);
}

// ===== 處理 LED 閃爍，表示連線狀態 =====
void handleLEDs() {
  if (tcpClient && tcpClient.connected()) {
    unsigned long now = millis();
    if (now - lastBlinkTime >= blinkInterval) {
      lastBlinkTime = now;
      digitalWrite(RED_LED, LOW);
      digitalWrite(GREEN_LED, LOW);

      currentLED = (currentLED + 1) % 2;
      switch (currentLED) {
        case 0: digitalWrite(RED_LED, HIGH); break;
        case 1: digitalWrite(GREEN_LED, HIGH); break;
      }
    }
  } else {
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, LOW);
  }
}

// ===== 接受新的 TCP client（只保留一個）=====
void acceptNewTCPClient() {
  WiFiClient newClient = tcpServer.available();
  if (newClient && (!tcpClient || !tcpClient.connected())) {
    tcpClient = newClient;
    tcpClient.setTimeout(10);
    Serial.println("New TCP client connected");
  }
}

// ===== 處理 TCP client 的輸入資料並傳給 C2000 (UART) =====
void handleTCPInput() {
  if (tcpClient && tcpClient.connected()) {
    while (tcpClient.available()) {
      char ch = tcpClient.read();

      if (ch == STX) {
        receivingTCP = true;
        tcpBuffer = "";
      } else if (ch == ETX && receivingTCP) {
        receivingTCP = false;
        Serial.print("TCP -> UART: ");
        Serial.println(tcpBuffer);
        sendToC2000(tcpBuffer);
      } else if (receivingTCP) {
        tcpBuffer += ch;
      }
    }
  }
}

// ===== 將字串送到 C2000 (UART) =====
void sendToC2000(const String &msg) {
  C2000_SERIAL.write(STX);
  C2000_SERIAL.print(msg);
  C2000_SERIAL.write(ETX);
}

// ===== 處理從 C2000 回傳的 UART 訊息並轉發給 TCP client =====
void handleUARTResponse() {
  while (C2000_SERIAL.available()) {
    char ch = C2000_SERIAL.read();

    if (ch == STX) {
      receivingUART = true;
      uartBuffer = "";
    } else if (ch == ETX && receivingUART) {
      receivingUART = false;
      Serial.print("UART -> TCP: ");
      Serial.println(uartBuffer);
      sendToTCPClient(uartBuffer);
    } else if (receivingUART) {
      uartBuffer += ch;
    }
  }
}

// ===== 傳送字串給 TCP client =====
void sendToTCPClient(const String &msg) {
  if (tcpClient && tcpClient.connected()) {
    tcpClient.write(STX);
    tcpClient.print(msg);
    tcpClient.write(ETX);
  }
}
