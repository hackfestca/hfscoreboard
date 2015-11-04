#include <Wire.h>   // Uno: A4 (SDA), A5 (SCL)
                    // Mega: 20 (SDA), 21 (SCL)

#include <SPI.h>    // Uno: 11 (MOSI), 12 (MISO), 13 (SCK)
                    // Mega: 51 (MOSI), 50 (MISO), 52 (SCK)

#include <Adafruit_MotorShield.h>
#include "utility/Adafruit_PWMServoDriver.h"

#define SCK_PIN       13
#define MISO_PIN      12
#define MOSI_PIN      11
#define SS_PIN        10
#define PHOTOCELL_PIN 1

#define M1 0
#define M2 1
#define M3 2
#define M4 3

#define FLAG5 "nop"
#define FLAG6 "nop"

Adafruit_MotorShield AFMS = Adafruit_MotorShield();
Adafruit_DCMotor *myMotor[4];

// motor related
char cmd = 'x';
char lastCmd = 'x';
unsigned long lastSent;
boolean isMoving = false;

// light level sensor
int lightLevel = 0;

void setup(void) {
  Serial.begin(9600);

  myMotor[M1] = AFMS.getMotor(1);
  myMotor[M2] = AFMS.getMotor(2);
  myMotor[M3] = AFMS.getMotor(3);
  myMotor[M4] = AFMS.getMotor(4);
  AFMS.begin();

  // SPI
  spi_SlaveInit();
  lastSent = millis();

  Serial.println("Ready!");
}

void loop(void) {
  // Process serial inputs
  if (Serial.available() > 0) {
    // read the incoming byte:
    cmd = Serial.read();

    // say what you got:
    Serial.print("Received (serial): ");
    Serial.println(cmd, DEC);

    do_command(cmd);
  }

  // Process SPI inputs
  if (digitalRead(SS_PIN) == LOW) {
    Serial.println("Pin 10 low...");
    cmd = spi_ReadByte();
    Serial.print("Received (SPI): ");
    Serial.println(cmd);
    lastSent = millis();
    lastCmd = cmd;
    
    do_command(cmd);
  }

  // Stop conditions. 
  // 1- Stop if the same command was invoked but left in the last 200ms
  // 2- Stop if a different command is invoked
  if(isMoving){
    if(cmd == lastCmd && (millis() - 200) > lastSent){
      stopMotor();
    }
  
    if(cmd != lastCmd){
      stopMotor();
    }
  }

  //delay(1000);
}

void spi_SlaveInit(void) {
  // Set MISO output, all others input
  pinMode(SCK_PIN, INPUT);
  pinMode(MOSI_PIN, INPUT);
  pinMode(MISO_PIN, OUTPUT);
  pinMode(SS_PIN, INPUT);

  // Enable SPI
  SPCR = B00000000;
  SPCR = (1 << SPE);
}

byte spi_ReadByte(void) {
  while (!(SPSR & (1 << SPIF)));
  return SPDR;
}

void spi_WriteByte(byte value) {
  SPDR = value;
  while (!(SPSR & (1 << SPIF)));
  return;
}

void do_command(char x) {
  Serial.print("Processing command: ");
  Serial.println(x);
  switch (x) {
    case 'w': runMotor(M1, FORWARD); break;
    case 's': runMotor(M1, BACKWARD); break;
    case 'a': runMotor(M2, FORWARD); break;
    case 'd': runMotor(M2, BACKWARD); break;    
    case 'i': runMotor(M3, FORWARD); break;
    case 'k': runMotor(M3, BACKWARD); break;
    case 'j': runMotor(M4, FORWARD); break;
    case 'l': runMotor(M4, BACKWARD); break;        
    case '_': sendFlag(); break;
    default: break;
  }
}

void runMotor(int m, int d) {
  isMoving = true;
  Serial.print("Running motor ");
  Serial.print(m);
  Serial.print(" in direction ");
  Serial.println(d);
  myMotor[m]->setSpeed(100);
  myMotor[m]->run(d);
  delay(150);
  //myMotor[m]->run(RELEASE); // Was removed for more fluidity
}

void stopMotor(){
  isMoving = false;
  Serial.println("Stopping motors");
  for(int i=0; i<4; i++){
    myMotor[i]->run(RELEASE);
  }
}

void sendFlag(){
  String flagValue;

  if(lightLevel < 800){
    flagValue = FLAG5;    
  }else{
    flagValue = FLAG6;
  }
  Serial.println("Sending flag!");
  SPI.transfer((void*)flagValue.c_str(),flagValue.length());
}


