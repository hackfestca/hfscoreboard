
/*
 iHack 2015 electronic challenge
 @Author: Martin Dubé <martin.dube [at] gmail.com>


 The circuit
 -----------

 LCD: 
 * LCD RS pin to digital pin 12
 * LCD Enable pin to digital pin 11
 * LCD D4 pin to digital pin 5
 * LCD D5 pin to digital pin 4
 * LCD D6 pin to digital pin 3
 * LCD D7 pin to digital pin 2
 * LCD R/W pin to ground
 * 10K resistor:
 * ends to +5V and ground
 * wiper to LCD VO pin (pin 3)

 Bit Shifter (74HC595):
 * Vcc pin to +5V
 * SER pin to pin 8
 * OE pin to ground
 * RCLK pin to pin 9
 * SRCLK pin to pin 10
 * SRCLR pin to +5V
 * Qb pin to LED1
 * Qd pin to LED2
 * Qf pin to LED3
 * Qh pin to LED4

 Button 1:
 * 
 
 Button 2: 
 *
 
 Potentiometer:
 *
 
 LED 1 to 4:
 *
 
 LM35 (temperature sensor):
 *
 
 IR Sensor: 
 *
 
 Photocell sensor:
 *


Docs
----
  
 * Temperature sensor: http://datasheets.maximintegrated.com/en/ds/DS18B20.pdf
 * Temperature sensor tuto: http://bildr.org/2011/07/ds18b20-arduino/
 * Photocell tuto: http://arduinobasics.blogspot.ca/2011/06/arduino-uno-photocell-sensing-light.html
 * LCD tuto: http://www.arduino.cc/en/Tutorial/LiquidCrystal
 * printf: http://playground.arduino.cc/Main/Printf

*/

#include <LiquidCrystal.h>
#include <OneWire.h>
#include <IRremote.h>
#include <TimerOne.h>

#define number_of_74hc595s 1 
#define numOfRegisterPins number_of_74hc595s * 8

// Bit shifter
boolean registers[numOfRegisterPins];

// All devices pins
const int potPin = 0;    // potentiometer pin
const int lightPin = 1;  // light sensor pin
const int irPin = 6;     //set D13 as input signal pin
const int buttonPin = 7; // Switch button pin
const int serPin = 8;   //pin 14 on the 75HC595
const int rclkPin = 9;  //pin 12 on the 75HC595
const int srclkPin = 10; //pin 11 on the 75HC595
const int dsPin = 13;    // pin for the temperature

// LCD
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

// IR Remote
IRrecv irrecv(irPin);
decode_results signals;

// Temperature
OneWire  ds(dsPin);  // on pin 13 (a 4.7K resistor is necessary)

const int LED_CLOCK = 1;
const int LCD_BTN = 3;
const int LED_FLAG = 5;
const int LED_IR = 7;

// Counters
volatile unsigned int clockCount = 0;
volatile unsigned int flagClockCount = 0;

// Variable states
int clockLedState = HIGH;
int flagLedState = LOW;
int buttonState;
int lastButtonState = LOW;

// Debounce vars
long lastDebounceTime = 0;  // the last time the output pin was toggled
long debounceDelay = 50;    // the debounce time; increase if the output flickers

// All devices value
volatile unsigned int potValue = 0;     // Potentiometer value (0-1023)
volatile unsigned int tempValue = 0;    // Temperature value (celcius)
volatile unsigned int lightValue = 0;   // Light sensor value (0-1023)
volatile unsigned long irValue = 0;     // Last Infra Red message read on the sensor (32bit)
volatile char flagValue[16];            // Flag currently displayed

// Flags (max 11 for LCD)
const char FLAG_1[] = "???";  // Lock Challenge
const char FLAG_2[] = "???";  // IR Challenge
const char FLAG_3[] = "???";  // Turn all lights on
const char FLAG_4[] = "???";  // Race condition Challenge
const char FLAG_5[] = "???";  // Serial Challenge
const char FLAG_6[] = "???";  // Temperature sensor (bonus)

// Challenges related
char* LCD_FMT_STR[] = { "Electro Chal", 
                         "Pot: %i",
                         "Temp: %i C", 
                         "Light: %i%",
                         "IR: %lX", 
                         "Flag:%s"};
int LCD_MSG_INDEX = 0;

int LOCK_INDEX_MODE = 0;
int CHAL2_INDEX_MODE = 0;

int LOCK_CHAL_COMBIN[][2] = {{0,20}, {40,60}, {20,40}};
int LOCK_CHAL_INDEX;                // A number from 0 to 2
int LOCK_CHAL_USER_INPUT[3];        // Saved attempts by a user

long IR_CHAL_VALUES[] = {0xFF6897, 0xFF5AA5, 0xFF18E7, 0xFFFFFFFF};
int IR_CHAL_INDEX;                 // A number from 0 to 7
long IR_CHAL_USER_INPUT[4];        // Saved attempts by a user

int RC_CHAL_USER_INPUT[][2] = {{0,0},{0,0},{0,0},{0,0},{0,0}};
int RC_CHAL_INDEX;                 // A number from 0 to 4

/*
    Setup function
*/
void setup(void) {
  Serial.begin(9600);

  // set up the LCD
  lcd.begin(16, 2);
  lcd.print("iHack 2015");
  lcd.setCursor(0,1);
  lcd.print("Electro Chal");

  // IR Remote
  irrecv.enableIRIn(); // enable input from IR receiver

  // LED Shifter
  pinMode(serPin, OUTPUT);
  pinMode(rclkPin, OUTPUT);
  pinMode(srclkPin, OUTPUT);

  //reset all register pins
  clearRegisters();
  writeRegisters();

  // Switch button
  pinMode(buttonPin, INPUT);

  Timer1.initialize(500000);
  Timer1.attachInterrupt(timerCallback,500000); // timerCallback every 0.5 sec.
}

/*
    Function called every 0.5 second (timer)
*/
void timerCallback(void)
{
  if (clockCount % 4 == 0){
    Serial.print("Clock count: ");
    Serial.println(clockCount);
  }
  
  updateDevicesValue();
  
  // Blink the clock light
  if (clockCount % 4 == 0 and clockLedState == LOW) {
    clockLedState = HIGH;
  } else {
    clockLedState = LOW;
  }
  setRegisterPin(LED_CLOCK, clockLedState);

  // Validate lock challenge
  if (clockCount % 4 == 0){
    updateLockChallenge();
    if (lockIsValid()) {
      printLockFlag();
      flagClockCount = clockCount;
    }
  }  
  
  // Validate IR challenge
  if (clockCount % 4 == 0){
    updateIRChallenge();
    if (irIsValid()) {
      printIRFlag();
      flagClockCount = clockCount;
    }
  }  
  
  // Validate Christmas Tree challengema
  if (christmasTreeIsValid()){
    printChristmasTreeFlag();
    flagClockCount = clockCount;
  }
  
  // Validate RC challenge
  if (clockCount % 4 == 0){
    updateRCChallenge();
    if (rcIsValid()) {
      printRCFlag();
      flagClockCount = clockCount;
    }
  }  
  
  // Validate temp challenge
  if (clockCount % 4 == 0){
    if (tempValue > 60){
      printTempFlag();
      flagClockCount = clockCount;
    } 
  }
 
  // Update LCD 
  updateLCD(); 
  
  clockCount = clockCount + 1;

  // Reset flag after 15 seconds
  if (flagClockCount != 0 && flagClockCount + 30 < clockCount){ 
    Serial.println("Removing flag from LCD");
    setRegisterPin(LED_FLAG, LOW);
    flagValue[0] = '\0';
    flagClockCount = 0;
  }
  
  // Serial flag
  if (clockCount % 60 == 0){
     Serial.print("Flag: ");
     Serial.println(FLAG_5);
  }
}

/*
    Read values of all connected devices (temp, light, pot, etc.)
*/
void updateDevicesValue(void){
  int itmp = 0;
  unsigned long ltmp = 0;
  potValue = analogRead(potPin);
  lightValue = analogRead(lightPin);
  
  if (clockCount % 2 == 0){
    itmp = getTemp();   
    if (itmp != 0){
      tempValue = itmp; 
    }
  }   

  ltmp = getIR();
  if (ltmp != 0){
    irValue = ltmp;
  }
}

/*
    Update the lock challenge values. 
    Read the value of the potentiometer and update LOCK_CHAL_USER_INPUT circular array.
*/
void updateLockChallenge(void){
  int i;
  int val = map(potValue, 0, 1023, 0, 100);
  
  LOCK_CHAL_USER_INPUT[LOCK_CHAL_INDEX] = val;
  LOCK_CHAL_INDEX = (LOCK_CHAL_INDEX + 1) % 3;
  Serial.print("Updating Lock Challenge. index=");
  Serial.println(LOCK_CHAL_INDEX);
  Serial.print("Lock Challenge values: ");
  for (int i = 0; i < sizeof(LOCK_CHAL_USER_INPUT) / sizeof(int); i++){
    Serial.print("a[");
    Serial.print(i);
    Serial.print("]=");
    Serial.print(LOCK_CHAL_USER_INPUT[i]);
    Serial.print(" ");
  }
  Serial.println("");
}

/*
    Return true if the lock challenge was successfully solved
*/
boolean lockIsValid(void){
  for (int i = 0; i < 3; i++){
     if (LOCK_CHAL_USER_INPUT[0] > LOCK_CHAL_COMBIN[i][0] &&
          LOCK_CHAL_USER_INPUT[0] < LOCK_CHAL_COMBIN[i][1] &&
          LOCK_CHAL_USER_INPUT[1] > LOCK_CHAL_COMBIN[(i+1)%3][0] &&
          LOCK_CHAL_USER_INPUT[1] < LOCK_CHAL_COMBIN[(i+1)%3][1] &&
          LOCK_CHAL_USER_INPUT[2] > LOCK_CHAL_COMBIN[(i+2)%3][0] &&
          LOCK_CHAL_USER_INPUT[2] < LOCK_CHAL_COMBIN[(i+2)%3][1]) {
        return true; 
     }
  }
  
  return false; 
}

/*
    Update IR challenge values
    Read the value of the IR receiver and update IR_CHAL_USER_INPUT circular array
*/
void updateIRChallenge(void){
  int i;
  
  IR_CHAL_USER_INPUT[IR_CHAL_INDEX] = irValue;
  IR_CHAL_INDEX = (IR_CHAL_INDEX + 1) % 4;
  Serial.print("Updating IR Challenge. index=");
  Serial.println(IR_CHAL_INDEX);
  Serial.print("IR Challenge values: ");
  for (int i = 0; i < sizeof(IR_CHAL_USER_INPUT) / sizeof(long); i++){
    Serial.print("a[");
    Serial.print(i);
    Serial.print("]=");
    Serial.print(IR_CHAL_USER_INPUT[i],HEX);
    Serial.print(" ");
  }
  Serial.println("");
}

/*
    Return true if the IR challenge was successfuly solved
*/
boolean irIsValid(void){
  int potVal = map(potValue,0,1023,0,100);
  for (int i = 0; i < 4; i++){
     if (IR_CHAL_USER_INPUT[0] == IR_CHAL_VALUES[i] &&
          IR_CHAL_USER_INPUT[1] == IR_CHAL_VALUES[(i+1)%4] &&
          IR_CHAL_USER_INPUT[2] == IR_CHAL_VALUES[(i+2)%4] &&
          IR_CHAL_USER_INPUT[3] == IR_CHAL_VALUES[(i+3)%4]){
        if (lightValue > 300 && potVal == 50){
          return true;
        }        
        Serial.println("Almost!");
        return false;
     }
  }
  
  return false; 
}

/*
    Return true if the Christmas Tree challenge was successfuly solved
*/
boolean christmasTreeIsValid(void){
  if (clockCount % 4 == 0){
    Serial.print("Registers state. ");
    for (int i = 1; i < 8; i=i+2){
      Serial.print("reg[");
      Serial.print(i);
      Serial.print("]=");
      Serial.print(registers[i]);
      Serial.print(" ");
    }
    Serial.println("");
  }
  
  for (int i = 1; i < 8; i=i+2){
    if (registers[i] != HIGH){
      return false;
    }
  }
  
  return true; 
}

/*
    Update Race condition challenge with user input
*/
void updateRCChallenge(void){
  int i;
  
  RC_CHAL_USER_INPUT[RC_CHAL_INDEX][0] = potValue;
  RC_CHAL_USER_INPUT[RC_CHAL_INDEX][1] = lightValue; 
  RC_CHAL_INDEX = (RC_CHAL_INDEX + 1) % 5;
  Serial.print("Updating RC Challenge. index=");
  Serial.println(RC_CHAL_INDEX);
  Serial.print("RC Challenge values: ");
  for (int i = 0; i < sizeof(RC_CHAL_USER_INPUT) / sizeof(int) / 2; i++){
    Serial.print("a[");
    Serial.print(i);
    Serial.print("]=");
    Serial.print(RC_CHAL_USER_INPUT[i][0]);
    Serial.print("-");
    Serial.print(RC_CHAL_USER_INPUT[i][1]);
    Serial.print(" ");
  }
  Serial.println("");
}

/*
    Return true if the RC challenge is solved
*/
boolean rcIsValid(void){
  int startIndex = 0;
  int endIndex = 4;
  int tolerance = 2;
  int i;
  
  // Find smallest value as startIndex
  for (i = 0; i < 5; i++){
    if (RC_CHAL_USER_INPUT[i][0] < RC_CHAL_USER_INPUT[startIndex][0]){
      startIndex = i; 
    }
  }
  endIndex = (startIndex+4)%5;
  
  // First value must be 0
  if (RC_CHAL_USER_INPUT[startIndex][0] != 0 && RC_CHAL_USER_INPUT[startIndex][1] != 0){
    return false;
  }
  
  // Last value must be < 950
  if (RC_CHAL_USER_INPUT[endIndex][0] > 950 && RC_CHAL_USER_INPUT[endIndex][1] > 950){
    return false;
  }
  
  // All values must be different
  for (i = 0; i < 4; i++){
    if (!(RC_CHAL_USER_INPUT[i%5][0] != RC_CHAL_USER_INPUT[(i+1)%5][0] && 
        RC_CHAL_USER_INPUT[i%5][1] != RC_CHAL_USER_INPUT[(i+1)%5][1])){
      return false;
    }
  }

  // All values between potentiometer and light sensor must be equal, +/- tolerance 
  for (i = startIndex; i < (startIndex + 5); i++){
    if (!(RC_CHAL_USER_INPUT[i%5][0] <= RC_CHAL_USER_INPUT[i%5][1] + tolerance &&
        RC_CHAL_USER_INPUT[i%5][0] >= RC_CHAL_USER_INPUT[i%5][1] - tolerance)){
      return false;
    }
  }
  
  return true; 
}

/*
    Flag printer functions
*/
void printLockFlag(void){
  setRegisterPin(LED_FLAG, HIGH);
  for (int i = 0; i < sizeof(FLAG_1) - 1; i++){
    flagValue[i] = FLAG_1[i];
  }
  Serial.println("Lock Flag was printed");
}
void printIRFlag(void){
  setRegisterPin(LED_FLAG, HIGH);
  for (int i = 0; i < sizeof(FLAG_2) - 1; i++){
    flagValue[i] = FLAG_2[i];
  }
  Serial.println("IR Flag was printed");
}
void printChristmasTreeFlag(void){
  setRegisterPin(LED_FLAG, HIGH);
  for (int i = 0; i < sizeof(FLAG_3) - 1; i++){
    flagValue[i] = FLAG_3[i];
  }
  Serial.println("Christmas tree Flag was printed");
}
void printRCFlag(void){
  setRegisterPin(LED_FLAG, HIGH);
  for (int i = 0; i < sizeof(FLAG_4) - 1; i++){
    flagValue[i] = FLAG_4[i];
  }
  Serial.println("Race condition Flag was printed");
}
void printTempFlag(void){
  setRegisterPin(LED_FLAG, HIGH);
  for (int i = 0; i < sizeof(FLAG_6) - 1; i++){
    flagValue[i] = FLAG_6[i];
  }
  Serial.println("Temperature Flag was printed");
}

/*
    Determine actual temperature in celcius
*/
int getTemp(void) {
  byte i;
  byte present = 0;
  byte type_s;
  byte data[12];
  byte addr[8];
  float celsius, fahrenheit;
  
  if ( !ds.search(addr)) {
    Serial.println("No more addresses.");
    ds.reset_search();
    return 0;
  }
  
  if (OneWire::crc8(addr, 7) != addr[7]) {
      Serial.println("CRC is not valid!");
      return 0;
  }
 
  // Determine chip type
  switch (addr[0]) {
    case 0x10:
      type_s = 1;
      break;
    case 0x28:
      type_s = 0;
      break;
    case 0x22:
      type_s = 0;
      break;
    default:
      return 0;
  } 

  ds.reset();
  ds.select(addr);
  ds.write(0x44, 1); // start conversion, with parasite power on at the end
  
  present = ds.reset();
  ds.select(addr);    
  ds.write(0xBE);   // Read Scratchpad

  for ( i = 0; i < 9; i++) {           // we need 9 bytes
    data[i] = ds.read();
  }

  // Convert the data to actual temperature
  // because the result is a 16 bit signed integer, it should
  // be stored to an "int16_t" type, which is always 16 bits
  // even when compiled on a 32 bit processor.
  int16_t raw = (data[1] << 8) | data[0];
  if (type_s) {
    raw = raw << 3; // 9 bit resolution default
    if (data[7] == 0x10) {
      // "count remain" gives full 12 bit resolution
      raw = (raw & 0xFFF0) + 12 - data[6];
    }
  } else {
    byte cfg = (data[4] & 0x60);
    // at lower res, the low bits are undefined, so let's zero them
    if (cfg == 0x00) raw = raw & ~7;  // 9 bit resolution, 93.75 ms
    else if (cfg == 0x20) raw = raw & ~3; // 10 bit res, 187.5 ms
    else if (cfg == 0x40) raw = raw & ~1; // 11 bit res, 375 ms
    //// default is 12 bit resolution, 750 ms conversion time
  }
  celsius = (float)raw / 16.0;
  fahrenheit = celsius * 1.8 + 32.0;

  return celsius;
}

/*
    Read a message on the IR sensor
*/
long getIR(void) {
  char buf[16];
  if (irrecv.decode(&signals)) {
    long ret = signals.value;
    translateIR(buf, signals.value);
    
    Serial.print("IR Value: ");
    Serial.print(ret, HEX);
    Serial.print(" DecodeType: ");
    Serial.print(signals.decode_type);
    Serial.print(" Str: ");
    Serial.println(buf);
    irrecv.resume(); // get the next signal

    setRegisterPin(LED_IR, HIGH);
    return ret;
  }
  setRegisterPin(LED_IR, LOW);
  return 0;
}

/*
    translate an IR numeric message into a human readable message
*/
void translateIR(char* buf, int value) {
 
  switch(value) {

    case 0xFFA25D:  
      strcpy(buf,"POWER");
      break;
  
    case 0xFF629D:  
      strcpy(buf,"MODE");
      break;
  
    case 0xFFE21D:  
      strcpy(buf,"MUTE");
      break;
  
    case 0xFF22DD:  
      strcpy(buf,"PLAY/PAUSE");
      break;
  
    case 0xFF02FD:  
      strcpy(buf,"PREV");
      break;
  
    case 0xFFC23D:  
      strcpy(buf,"NEXT");
      break;
  
    case 0xFFE01F:  
      strcpy(buf,"EQ");
      break;
  
    case 0xFFA857:  
      strcpy(buf,"VOL-");
      break;
  
    case 0xFF906F:  
      strcpy(buf,"VOL+");
      break;
  
    case 0xFF6897:  
      strcpy(buf,"0");
      break;
  
    case 0xFF9867:  
      strcpy(buf,"100+");
      break;
  
    case 0xFFB04F:  
      strcpy(buf,"200+");
      break;
  
    case 0xFF30CF:  
      strcpy(buf,"1");
      break;
  
    case 0xFF18E7:  
      strcpy(buf,"2");
      break;
  
    case 0xFF7A85:  
      strcpy(buf,"3");
      break;
  
    case 0xFF10EF:  
      strcpy(buf,"4");
      break;
  
    case 0xFF38C7:  
      strcpy(buf,"5");
      break;
  
    case 0xFF5AA5:  
      strcpy(buf,"6");
      break;
  
    case 0xFF42BD:  
      strcpy(buf,"7");
      break;
  
    case 0xFF4AB5:  
      strcpy(buf,"8");
      break;
  
    case 0xFF52AD:  
      strcpy(buf,"9");
      break;
  
    default: 
      strcpy(buf,"other button");
  }
}

/*
    Bit shifter functions
*/
void writeRegisters(){
  int val;
  digitalWrite(rclkPin, LOW);

  for(int i = numOfRegisterPins - 1; i >=  0; i--){
    digitalWrite(srclkPin, LOW);

    val = registers[i];

    digitalWrite(serPin, val);
    digitalWrite(srclkPin, HIGH);
  }
  digitalWrite(rclkPin, HIGH);
}
void clearRegisters(){
  for(int i = numOfRegisterPins - 1; i >=  0; i--){
     registers[i] = LOW;
  }
} 
void setRegisterPin(int index, int value){
  registers[index] = value;
  writeRegisters();
}

/*
    Determine if the switch button (B2) is pressed. This function manage debouncing.
*/
boolean isButtonPressed(void) {
  int reading = digitalRead(buttonPin);
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  } 
  
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != buttonState) {
      buttonState = reading;
      if (buttonState == HIGH) {
        lastButtonState = reading;
        setRegisterPin(LCD_BTN, HIGH);
        return true;
      }else{
        setRegisterPin(LCD_BTN, LOW);
      }
    }
  }

  lastButtonState = reading;
  return false;
}

/*
    LCD functions
*/
void printModeToLCD(char* msg){
  lcd.setCursor(0,1);
  lcd.print("                ");
  lcd.setCursor(0,1);
  lcd.print(msg); 
}
char* getLCDMsg(char* buf, int index){
  switch(index) {

    // Electro
    case 0:  
      sprintf(buf, LCD_FMT_STR[index]);
      break;  
      
    // Potentiometer
    case 1:  
      sprintf(buf, LCD_FMT_STR[index], potValue);
      break;  
      
    // Temperature
    case 2:  
      sprintf(buf, LCD_FMT_STR[index], tempValue);
      break;  
      
    // Light
    case 3:  
      sprintf(buf, LCD_FMT_STR[index], lightValue);
      break;  
      
    // IR
    case 4:  
      sprintf(buf, LCD_FMT_STR[index], irValue);
      break;
      
    // Flag
    case 5:  
      sprintf(buf, LCD_FMT_STR[index], flagValue);
      break;
  } 

  if (clockCount % 4 == 0){  
    Serial.print("Menu index: ");
    Serial.println(index);
  }
}
void updateLCD(void){
  char buf[32];
  getLCDMsg(buf, LCD_MSG_INDEX);
  printModeToLCD(buf);  
}

/*
    Change the circuit "mode" (mostly what's printed on LCD). 
*/
void changeMode(void){
  Serial.println("Changing mode");
  Serial.print("From: ");
  Serial.println(LCD_MSG_INDEX);
  LCD_MSG_INDEX = (LCD_MSG_INDEX + 1) % (sizeof(LCD_FMT_STR) / sizeof(char*));
  Serial.print("To: ");
  Serial.println(LCD_MSG_INDEX);
  updateLCD();
}

/* 
    Program's main loop
*/
void loop(void) {
  noInterrupts();
  if (isButtonPressed()){
    changeMode();
  }
  interrupts();
}
