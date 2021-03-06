-- onewire pin3=GPIO0
OWPIN = 3
-- DHT11 config
DAT = 4

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
print("Sending data to thingspeak.com")
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
    t1=getDataOW()
    t2, h = readDHT11()
    print("Temp1:"..t1.." C\n")
    print("Temp2:"..t2.." C\n")
    print("Hum:"..h.." C\n")
    print("Send data...")
    print("GET /update?key=AQBLFGNJKJFJED2P&field1="..t1.."&field2="..h.."\r\n")
    conn:send("GET /update?key=AQBLFGNJKJFJED2P&field1="..t1.."&field2="..h.."\r\n")
end)

conn:on("sent",function(conn)
                      print("Closing connection")
                      conn:close()
                  end)
conn:on("disconnection", function(conn, payloadout)
        conn:close();
        collectgarbage();
        print("Got disconnection...")                                
  end)
end

-- send data every 60000 ms to thing speak
tmr.alarm(0, 60000, 1, function() sendData() end )
