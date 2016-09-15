--init.lua
timeout = 60
print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
--modify according your wireless router settings
wifi.sta.config("Xiaomi_D36F","xiaomixiaomi")
wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if (wifi.sta.getip()== nil) then 
print("IP unavaiable, Waiting...") 
timeout = timeout - 1
print("Timeout Connect "..timeout)
if(timeout == 0) then
       print("Deep sleep 30 min")
       node.dsleep(1800000000)
end
else 
tmr.stop(1)
print("MAC: "..wifi.sta.getmac())      -- print current mac address
print("IP: "..wifi.sta.getip())      -- print current IP address
--dofile("httpsender.lua")
-- send data every 10min to thing speak
tmr.alarm(0, 100, tmr.ALARM_SINGLE, function() sendData() end )
end 
end)


--Write API Key
TSKEY='3A07W8TZ0F1DQYPP'

-- onewire pin3=GPIO0
OWPIN = 1

-- DHT11 config
DAT = 2

-- i2c config
SDA_PIN = 4
SCL_PIN = 3
-- BMP180 config
OSS = 1 -- oversampling
bmp180 = require("bmp085")
bmp180.init(SDA_PIN, SCL_PIN)

function readBMP180()
  t = bmp180.temperature()
  -- add decimal point
  t = t / 10 ..".".. t % 10
  print("BMP180 temperature: "..t)
  p = bmp180.pressure(OSS)
  print("BMP180 pressure hPA: "..p)
  -- converp Pa to mmHg
  phg=(p * 75 / 10000).."."..((p * 75 % 10000) / 1000)
  print("BMP180 pressure mmHg: "..phg)
  return t, p, phg
end

function getDataOW()
count = 0
repeat
  count = count + 1
  addr = ow.reset_search(OWPIN)
  addr = ow.search(OWPIN)
  tmr.wdclr()
until((addr ~= nil) or (count > 100))
if (addr == nil) then
  print("No more addresses.")
else
  print(addr:byte(1,8))
  crc = ow.crc8(string.sub(addr,1,7))
  if (crc == addr:byte(8)) then
    if ((addr:byte(1) == 0x10) or (addr:byte(1) == 0x28)) then
      print("Device is a DS18S20 family device.")
        repeat
          ow.reset(OWPIN)
          ow.select(OWPIN, addr)
          ow.write(OWPIN, 0x44, 1)
          tmr.delay(1000000)
          present = ow.reset(OWPIN)
          ow.select(OWPIN, addr)
          ow.write(OWPIN,0xBE,1)
          print("P="..present)  
          data = nil
          data = string.char(ow.read(OWPIN))
          for i = 1, 8 do
            data = data .. string.char(ow.read(OWPIN))
          end
          print(data:byte(1,9))
          crc = ow.crc8(string.sub(data,1,8))
          print("CRC="..crc)
          if (crc == data:byte(9)) then
             t = (data:byte(1) + data:byte(2) * 256)

             -- handle negative temperatures
             if (t > 0x7fff) then
                t = t - 0x10000
             end

             if (addr:byte(1) == 0x28) then
                t = t * 625  -- DS18B20, 4 fractional bits
             else
                t = t * 5000 -- DS18S20, 1 fractional bit
             end
             t1 = t / 10000
             t2 = t % 10000
             print("Temperature= "..t1.."."..t2.." Centigrade")
             return t1.."."..t2
          end                   
          tmr.wdclr()
        until false
    else
      print("Device family is not recognized.")
    end
  else
    print("CRC is not valid!")
  end
end
end

function readDHT11()
  status, temp, humi, temp_dec, humi_dec = dht.read(DAT)
  if status == dht.OK then
    temp=temp.."."..temp_dec
    print("DHT temperature: "..temp)
    humi=humi.."."..humi_dec
    print("DHT humidity: "..humi)
    return temp, humi
  else
    print("DHT read error:"..status)
  end
end


function sendData()
-- conection to thingspeak.com
print("\r\nSending data to thingspeak.com\r\n")
-- in you init.lua:
if adc.force_init_mode(adc.INIT_ADC)
then
  node.restart()
  return -- don't bother continuing, the restart is scheduled
end
-- in you init.lua:
--adc.force_init_mode(adc.INIT_ADC)
conn=nil
conn=net.createConnection(net.TCP, 0) 
conn:on("receive", function(conn, payloadout)
        if (string.find(payloadout, "Status: 200 OK") ~= nil) then
            print("Posted OK");
        end
    end)
-- api.thingspeak.com 184.106.153.149
conn:connect(80,'184.106.153.149')

conn:on("connection", function(conn)
    ow.setup(OWPIN)
    tDS=getDataOW()
    tDHT, hDHT = readDHT11()
    tBMP, phpBMP, phgBMP = readBMP180()
    Vbat = adc.read(0)
    Vbat = (Vbat * 3) / 1,024
    Vbat = (Vbat * 1000) /  687
    print("\r")
    print("System voltage:"..Vbat.." mV")
    print("Temp DS:"..tDS.." C")
    print("Temp DHT11:"..tDHT.." C")
    print("Hum:"..hDHT.." %")
    print("Temp BMP180:"..tDHT.." C")
    print("Pres BMP180:"..phgBMP.." mmHg")
    print("Send data...")
    print("GET /update?key="..TSKEY.."&field1="..tBMP.."&field2="..phgBMP.."&field3="..tDS.."&field4="..tDHT.."&field5="..hDHT.."&field6="..Vbat.."\r\n")
    conn:send("GET /update?key="..TSKEY.."&field1="..tBMP.."&field2="..phgBMP.."&field3="..tDS.."&field4="..tDHT.."&field5="..hDHT.."&field6="..Vbat.."\r\n")
end)

conn:on("sent",function(conn)
                      print("Closing connection")
                      conn:close()
                  end)
conn:on("disconnection", function(conn, payloadout)
        conn:close();
        collectgarbage();
        print("Got disconnection...\r") 
        print("Deep sleep 30 min")
        node.dsleep(1800000000)                     
  end)
end
