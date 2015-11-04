#include <Wire.h>   // Uno: A4 (SDA), A5 (SCL)
                    // Mega: 20 (SDA), 21 (SCL)
#include <AESLib.h>   // https://github.com/DavyLandman/AESLib
#include <SPI.h>
#include <LiquidCrystal.h>

#define I2C_ADDRESS 0x05

#define PIPELINE_PIN1 29 //44
#define PIPELINE_PIN2 27 //46
#define PIPELINE_PIN3 25 //48
#define PIPELINE_PIN4 23 //50
#define PIPELINE_PUMP_PIN 21 //52

#define FLOWMETER_PIN 6

#define FLAG2 "nop" 
#define FLAG3 "nop" 

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
//#define LCD_CONTRAST_PIN  A3
//#define LCD_CONTRAST      1000

boolean FLAG_READY = false;
uint8_t FLAG_KEY[17];
char FLAG_ENC[17];

String lastNews;

/*
 * Flow meter related
 */
// count how many pulses!
volatile uint16_t pulses = 0;
// track the state of the pulse pin
volatile uint8_t lastflowpinstate;
// you can try to keep time of how long it is between pulses
volatile uint32_t lastflowratetimer = 0;
// and use that to calculate a flow rate
volatile float flowrate;
// Interrupt is called once a millisecond, looks for any pulses from the sensor!

SIGNAL(TIMER0_COMPA_vect) {
  uint8_t x = digitalRead(FLOWMETER_PIN);
  
  if (x == lastflowpinstate) {
    lastflowratetimer++;
    return; // nothing changed!
  }
  
  if (x == HIGH) {
    //low to high transition!
    pulses++;
  }
  lastflowpinstate = x;
  flowrate = 1000.0;
  flowrate /= lastflowratetimer;  // in hertz
  lastflowratetimer = 0;
}

void useInterrupt(boolean v) {
  if (v) {
    // Timer0 is already used for millis() - we'll just interrupt somewhere
    // in the middle and call the "Compare A" function above
    OCR0A = 0xAF;
    TIMSK0 |= _BV(OCIE0A);
  } else {
    // do not call the interrupt function COMPA anymore
    TIMSK0 &= ~_BV(OCIE0A);
  }
}

/* setup() */
void setup(void) {
  Serial.begin(9600);

  // initialize i2c as slave
  Wire.begin(I2C_ADDRESS); 
  
  // define callbacks for i2c communication
  Wire.onReceive(i2c_receiveData);
  Wire.onRequest(i2c_sendData);
  
  // Initialize pipeline
  pinMode(PIPELINE_PIN1,OUTPUT);
  pinMode(PIPELINE_PIN2,OUTPUT);
  pinMode(PIPELINE_PIN3,OUTPUT);
  pinMode(PIPELINE_PIN4,OUTPUT);
  pinMode(PIPELINE_PUMP_PIN,OUTPUT);
  digitalWrite(PIPELINE_PIN1,LOW);
  digitalWrite(PIPELINE_PIN2,LOW);
  digitalWrite(PIPELINE_PIN3,LOW);
  digitalWrite(PIPELINE_PIN4,LOW);
  digitalWrite(PIPELINE_PUMP_PIN,HIGH);

  //pinMode(LCD_CONTRAST_PIN, OUTPUT);
  //analogWrite(LCD_CONTRAST_PIN, LCD_CONTRAST);
  
  // set up the LCD's number of columns and rows: 
  lcd.begin(16, 2);
  
  // Print a message to the LCD.
  //lcd.setCursor(0,0);
  //lcd.clear();
  lcd.print("Hackfest 2015");
  lcd.setCursor(0,1);
  lcd.print("Pipeline");  

   pinMode(FLOWMETER_PIN, INPUT);
   digitalWrite(FLOWMETER_PIN, HIGH);
   lastflowpinstate = digitalRead(FLOWMETER_PIN);
   useInterrupt(true);  

  Serial.println("Ready!");
}

/* loop() */
void loop(void) {
  char c;
  String msg;
  char cmd;
  String args;

  // Process serial inputs
  if (Serial.available() > 0) {
    while(Serial.available()) {
      c = (char)Serial.read();
      msg += c;
    }

    // say what you got:
    Serial.print("Received (serial): ");
    Serial.println(msg);

    cmd = msg.substring(0,1).c_str()[0];
    args = msg.substring(1);
  
    do_command(cmd,args);
  }

  // reset pipeline pins to LOW

  updateFlowMeterValue();
}

// callback for received data
void i2c_receiveData(int byteCount){
  char c;
  String msg;
  char cmd;
  String args;
  while(Wire.available()) {
    c = (char)Wire.read();
    msg += c;
  }
  
  Serial.print("Byte Count: ");
  Serial.println(byteCount);
  Serial.print("data received: ");
  Serial.println(msg.c_str());    

  cmd = msg.substring(0,1).c_str()[0];
  args = msg.substring(1);

  do_command(cmd,args);
}

// callback for sending data
void i2c_sendData(){
  if(FLAG_READY){
    Serial.print("Sending flag: ");
    Serial.println(FLAG_ENC);
    Wire.write(FLAG_ENC);
  }else{
    Serial.println("no aes128 key found");
    Wire.write("no aes128 key found");
  }
}

void do_command(char cmd, String args){
  Serial.print("Processing command: ");
  Serial.println(cmd);
  switch (cmd) {
    case 'f': updateFlag(args); break;
    case 'p': setPipelinePin(args); break;
    case 'r': runPipe(args); break;
    default: break;
  }  
}

void updateFlag(String args){
   if(args.length() == 16){
    Serial.print("Updating flag key: ");
    Serial.println(args);
    FLAG_READY = true;
    
    // Converting key
    for(int i=0; i<args.length(); i++){
      FLAG_KEY[i] = (uint8_t)args[i];
    }
    FLAG_KEY[16] = (uint8_t)'\x00';

    // Encrypting flag
    strncpy(FLAG_ENC, FLAG2, 16);
    aes128_enc_single(FLAG_KEY, FLAG_ENC);
  }else{
    Serial.println("Key too small");
  }
}

void setPipelinePin(String args){
  int pin = args.toInt();
  switch (pin) {
    case 10: digitalWrite(PIPELINE_PIN1,LOW); break;  
    case 11: digitalWrite(PIPELINE_PIN1,HIGH); break;  
    case 20: digitalWrite(PIPELINE_PIN2,LOW); break;  
    case 21: digitalWrite(PIPELINE_PIN2,HIGH); break;  
    case 30: digitalWrite(PIPELINE_PIN3,LOW); break;  
    case 31: digitalWrite(PIPELINE_PIN3,HIGH); break;  
    case 40: digitalWrite(PIPELINE_PIN4,LOW); break;  
    case 41: digitalWrite(PIPELINE_PIN4,HIGH); break;
    default: break;
  }
}

void runPipe(String args){
  digitalWrite(PIPELINE_PUMP_PIN,LOW);
  delay(1000);
  digitalWrite(PIPELINE_PUMP_PIN,HIGH);
}

void updateFlowMeterValue(){
  lcd.setCursor(0, 0);
  lcd.clear();
  //lcd.print("Pulses:"); lcd.print(pulses, DEC);
  lcd.print("Flow: "); lcd.print(flowrate); lcd.print("L/hr");
  //lcd.print(flowrate);
  Serial.print("Freq: "); Serial.println(flowrate);
  Serial.print("Pulses: "); Serial.println(pulses, DEC);
  
  // if a plastic sensor use the following calculation
  // Sensor Frequency (Hz) = 7.5 * Q (Liters/min)
  // Liters = Q * time elapsed (seconds) / 60 (seconds/minute)
  // Liters = (Frequency (Pulses/second) / 7.5) * time elapsed (seconds) / 60
  // Liters = Pulses / (7.5 * 60)
  float liters = pulses;
  liters /= 7.5;
  liters /= 60.0;

  /*
    // if a brass sensor use the following calculation
    float liters = pulses;
    liters /= 8.1;
    liters -= 6;
    liters /= 60.0;
  */
  Serial.print(liters); Serial.println(" Liters");
  lcd.setCursor(0, 1);
  lcd.print(liters); lcd.print(" Liters        ");
   
  delay(300);
}

