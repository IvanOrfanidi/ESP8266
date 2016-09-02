
TSKEY='3A07W8TZ0F1DQYPP'

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
    t, php, phg = readBMP180()
    print("Temp:"..t.." C\n")
    print("Pres:"..php.."kPa, "..phg.."mmHg\n")
    print("Send data...")
    print("GET /update?key="..TSKEY.."&field1="..t.."&field2="..phg.."\r\n")
    conn:send("GET /update?key="..TSKEY.."&field1="..t.."&field2="..phg.."\r\n")
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
