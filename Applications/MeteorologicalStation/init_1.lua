
FIRMWARE_VER = 1
FIRMWARE_BUILD = 4
DATE = "22.10.2018"
print("\r")
print("Firmware ver."..FIRMWARE_VER.."."..FIRMWARE_BUILD.."\r")
print("Date "..DATE.."\r")
print("\r")

--init.lua
-- WiFi Setings
WIFI_SSID = "TP-LINK_BFC8C4"
WIFI_PASS = "OmManiPadmeHum"

-- IP address and TCP port server thingspeak
SERVER_IP_ADDRESS = '184.106.153.149'
SERVER_TCP_PORT = 80

-- Write API Key thingspeak
TSKEY='YDMRPUENEFI92SNA'

-- DHT config
DAT = 1

-- PORT RAIN INPUT
RAIN = 5
gpio.mode(RAIN, gpio.INPUT)

-- i2c config BMP180
SDA_PIN = 2
SCL_PIN = 3

TimeoutSendData = 60

RAIN_TIMEOUT_ON = 59
RAIN_TIMEOUT_OFF = 59

TimeoutRainOn = RAIN_TIMEOUT_ON
TimeoutRainOff = RAIN_TIMEOUT_OFF

RainLast = 1;
if (gpio.read(RAIN) == 1) then
    RainLast = 0
end
RainSendData = false

TIME_SEND_DATA = 30

OpenConnection = false

function main()

    if (OpenConnection == true) then
        return
    end

    conn = net.createConnection(net.TCP, 0)

    TimeoutSendData = TimeoutSendData - 1
    
    if (TimeoutSendData == 0) then

        OpenConnection = true
        TimeoutSendData = TIME_SEND_DATA * 60
        conn:on("receive", function(conn, payloadout)
                if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                    print("Posted OK");
                end
            end)
        conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)
        
    else
    
        rainCur = gpio.read(RAIN)
        
        if (RainLast ~= rainCur and rainCur == 1) then
            TimeoutRainOff = TimeoutRainOff + 1
            print("TimRainOff: "..TimeoutRainOff.."\r")
            if (TimeoutRainOff > RAIN_TIMEOUT_OFF) then
                TimeoutRainOn = 0
                RainLast = rainCur
                RainSendData = true
                
                OpenConnection = true
                conn:on("receive", function(conn, payloadout)
                        if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                            print("Posted OK");
                        end
                    end)
                conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS) 
            end
        end

        -- zerro TimeoutRainOff
        if (RainLast == rainCur and rainCur == 0) then
            TimeoutRainOff = 0
        end

        if (RainLast ~= rainCur and rainCur == 0) then
            TimeoutRainOn = TimeoutRainOn + 1
            print("TimRainOn: "..TimeoutRainOn.."\r")
            if (TimeoutRainOn > RAIN_TIMEOUT_ON) then
                TimeoutRainOff = 0
                RainLast = rainCur
                RainSendData = true

                OpenConnection = true
                conn:on("receive", function(conn, payloadout)
                        if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                            print("Posted OK");
                        end
                    end)
                conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)       
            end
        end

        -- zerro TimeoutRainOn
        if (RainLast == rainCur and rainCur == 1) then
            TimeoutRainOn = 0
        end
        
    end


--
conn:on("connection", function(conn)

    print("\rSend data...")

    if (RainSendData == false) then 

        tDHT, hDHT = readDHT()
        tBMP, phpBMP, phgBMP = readBMP180()

        print("Temp:"..tBMP.." C")
        print("Pres:"..phgBMP.." mmHg")
        print("Hum:"..hDHT.." %")

        conn:send("GET /update?key="..TSKEY.."&field1="..tBMP.."&field2="..phgBMP.."&field3="..hDHT.."\r\n")
        
    else
    
        if (RainLast == 1) then
            print("Rain Status: false")
            conn:send("GET /update?key="..TSKEY.."&field4=0\r\n")
        else
            print("Rain Status: true")
            conn:send("GET /update?key="..TSKEY.."&field4=1\r\n")
        end
        
    end
end)

conn:on("sent",function(conn)
    conn:close()
    print("Closing connection")
    RainSendData = false
    OpenConnection = false
    collectgarbage();
end)

conn:on("disconnection", function(conn, payloadout)
    conn:close();
    print("Got disconnection...\r")
    TimeoutSendData = 60
    OpenConnection = false
    collectgarbage();
end)
    
end


-----------------------------------------------------------
print("Setting up WIFI...")
wifi.setmode(wifi.STATION)

station_cfg = {}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd = WIFI_PASS
station_cfg.save = false
wifi.sta.config(station_cfg)

wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if (wifi.sta.getip()== nil) then
     print("IP unavaiable, Waiting...")
else
    tmr.stop(1)
    print("MAC: "..wifi.sta.getmac())
    print("IP: "..wifi.sta.getip())

    -- main run every 1sec
    tmr.alarm(0, 1000, tmr.ALARM_AUTO, function() main() end )
end

end)


-- BMP180 config
i2c.setup(0, SDA_PIN, SCL_PIN, i2c.SLOW)
bmp085.setup()

-- read data BMP180
function readBMP180()
    t = bmp085.temperature()
    t = t / 10 ..".".. t % 10
    OSS = 3 -- oversampling
    p = bmp085.pressure(OSS)
    phg = (p * 75 / 10000).."."..((p * 75 % 10000) / 1000)
    return t, p, phg
end


function readDHT()
    status, temp, humi, temp_dec, humi_dec = dht.readxx(DAT)
    if (status == dht.OK) then
        temp=temp.."."..temp_dec
        humi = humi.."."..humi_dec
        return temp, humi
    else
        print("DHT read error:"..status)
    end
end

