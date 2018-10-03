
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
RAIN =  5
gpio.mode(RAIN, gpio.INPUT)

-- i2c config BMP180
SDA_PIN = 2
SCL_PIN = 3

timeout = 60
timeoutRainOff = 0

RainLast = 1;
if(gpio.read(RAIN) == 1) then
    RainLast = 0
end
RainSendData = false

TIME_SEND_DATA = 30

-- Sending data to server thingspeak
function main()

    conn = net.createConnection(net.TCP, 0)

    timeout = timeout - 1
    
    if(timeout == 0) then
        timeout = (TIME_SEND_DATA - 1) * 60
        -- conection to thingspeak.com
        --print("Sending data to thingspeak.com")
        conn:on("receive", function(conn, payloadout)
                if(string.find(payloadout, "Status: 200 OK") ~= nil) then
                    print("Posted OK");
                end
            end)
        -- api.thingspeak.com 184.106.153.149
        conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)
    else
        rainCur = gpio.read(RAIN)
        
        if(rainCur == 0) then
			timeoutRainOff = timeoutRainOff + 1
        end

        if(RainLast ~= rainCur) then
            
            RainLast = rainCur
            RainSendData = true
            -- conection to thingspeak.com
            --print("Sending data to thingspeak.com")
            conn:on("receive", function(conn, payloadout)
                    if(string.find(payloadout, "Status: 200 OK") ~= nil) then
                        print("Posted OK");
                    end
                end)
            -- api.thingspeak.com 184.106.153.149
            conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)
        end
    end


--
conn:on("connection", function(conn)

    print("\rSend data...")

    if(RainSendData == false) then    -- Checking rain

        -- Read Sensor humidity and temperature
        tDHT, hDHT = readDHT()

        -- Read Sensor pressure and temperature
        tBMP, phpBMP, phgBMP = readBMP180()
    
        --Vbat = adc.readvdd33(0)
        --Vbat = (Vbat * 3) / 1,024
        --Vbat = (Vbat * 1000) /  687
        
        --print("System voltage:"..Vbat.." mV")
        print("Temp DHT:"..tDHT.." C")
        print("Hum:"..hDHT.." %")
        print("Temp BMP:"..tBMP.." C")
        print("Pres BMP:"..phgBMP.." mmHg")

        --Fon
        fDOS = 15

        conn:send("GET /update?key="..TSKEY.."&field1="..tBMP.."&field2="..phgBMP.."&field3="..hDHT.."&field4="..fDOS.."\r\n")
    else
        if(RainLast == 1) then
            print("Rain Status: false")
            conn:send("GET /update?key="..TSKEY.."&field5=0\r\n")
        else
            print("Rain Status: true")
            conn:send("GET /update?key="..TSKEY.."&field5=1\r\n")
        end
    end
end)

--
conn:on("sent",function(conn)
                print("Closing connection")
                RainSendData = false
                conn:close()
            end)


--
conn:on("disconnection", function(conn, payloadout)
        conn:close();
        collectgarbage();
        print("Got disconnection...\r")
        RainSendData = false
        -- D0 to RESET
        --print("Deep sleep 30 min")
        --node.dsleep(1800000000)
    end)
end


-----------------------------------------------------------
print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
--modify according your wireless router settings
station_cfg = {}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd = WIFI_PASS
station_cfg.save = false
wifi.sta.config(station_cfg)

wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if(wifi.sta.getip()== nil) then
     print("IP unavaiable, Waiting...")
    -- dec timeout
    --timeout = timeout - 1
    --print("Timeout Connect "..timeout)
    if(timeout == 0) then
        -- D0 to RESET
        --print("Deep sleep 30 min")
        --node.dsleep(1800000000)
    end
else
    tmr.stop(1)
    timeout = 1
    print("MAC: "..wifi.sta.getmac())   -- print current mac address
    print("IP: "..wifi.sta.getip())     -- print current IP address

    -- main run every 1sec
    tmr.alarm(0, 1000, tmr.ALARM_AUTO, function() main() end )
end

end)


-- BMP180 config
OSS = 3 -- oversampling
i2c.setup(0, SDA_PIN, SCL_PIN, i2c.SLOW)
bmp085.setup()

-- read data BMP180
function readBMP180()
    t = bmp085.temperature()
    -- add decimal point
    t = t / 10 ..".".. t % 10
    --print("BMP180 temperature: "..t)
    p = bmp085.pressure(OSS)
    --print("BMP180 pressure hPA: "..p)
    -- converp Pa to mmHg
    phg = (p * 75 / 10000).."."..((p * 75 % 10000) / 1000)
    --print("BMP180 pressure mmHg: "..phg)
    return t, p, phg
end


function readDHT()
    status, temp, humi, temp_dec, humi_dec = dht.readxx(DAT)
    if(status == dht.OK) then
        temp=temp.."."..temp_dec
        --print("DHT temperature: "..temp)
        humi = humi.."."..humi_dec
        --print("DHT humidity: "..humi)
        return temp, humi
    else
        print("DHT read error:"..status)
    end
end

