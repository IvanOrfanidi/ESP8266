FIRMWARE_VER = 1
FIRMWARE_BUILD = 7
DATE = "12.05.2020"
print("\r")
print("Firmware ver."..FIRMWARE_VER.."."..FIRMWARE_BUILD.."\r")
print("Date "..DATE.."\r")
print("\r")

-- WiFi Setings
WIFI_SSID = "TP-LINK_BFC8C4"
WIFI_PASS = "OmManiPadmeHum"

-- IP address and TCP port server thingspeak
SERVER_IP_ADDRESS = '192.168.109.25'
SERVER_TCP_PORT = 35000

-- Write API Key thingspeak
TSKEY='YDMRPUENEFI92SNA'

TIME_TO_SEND_DATA_IN_MIN = 10

-- DHT config
DAT = 1

-- i2c config BMP180
SDA_PIN = 2
SCL_PIN = 3

--modify according your wireless router settings
station_cfg = {}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd = WIFI_PASS
station_cfg.save = false

conn = net.createConnection(net.TCP, 0)

timeout_send = 30
open_connection = false

-- MAIN
function main()

    if(open_connection == true) then
        return
    end

    timeout_send = timeout_send - 1

    if(timeout_send == 0) then
        open_connection = true
        print("Setting up WIFI...")
        wifi.setmode(wifi.STATION)
        wifi.sta.config(station_cfg)
        wifi.sta.connect()

        tmr.alarm(1, 1000, 1, function() 
            if (wifi.sta.getip() == nil) then
                 print("IP unavaiable, Waiting...")
            else
                tmr.stop(1)
                print("MAC: "..wifi.sta.getmac())
                print("IP: "..wifi.sta.getip())
                SendData()
            end
        end)
    end
end


function SendData()
conn:on("receive", function(conn, payloadout)
            if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                print("Posted OK");
            end
        end)
    conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)
end


conn:on("connection", function(conn)
    print("\rSend data...")
    tDHT, hDHT = readDHT()
    tBMP, phpBMP, phgBMP = readBMP180()
    print("Temp:"..tBMP.." C")
    print("Pres:"..phgBMP.." mmHg")
    print("Hum:"..hDHT.." %")
    conn:send("GET /update?key="..TSKEY.."&field1="..tBMP.."&field2="..phgBMP.."&field3="..hDHT.."\r\n")
end)


conn:on("sent",function(conn)
    conn:close()
    print("Closing connection")
    timeout_send = TIME_TO_SEND_DATA_IN_MIN * 60
    open_connection = false
    collectgarbage();
end)


conn:on("disconnection", function(conn, payloadout)
    conn:close()
    print("Got disconnection...\r")
    timeout_send = 60
    open_connection = false
    collectgarbage();
end)



-- BMP180 config
i2c.setup(0, SDA_PIN, SCL_PIN, i2c.SLOW)
bmp085.setup()

-- read data BMP180
function readBMP180()
    t = bmp085.temperature()
    t = t / 10 ..".".. t % 10
    OSS = 3
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


----------------------------------------------------------------------
tmr.alarm(0, 1000, tmr.ALARM_AUTO, function() main() end )
