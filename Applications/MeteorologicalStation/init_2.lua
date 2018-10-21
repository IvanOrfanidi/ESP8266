
--init.lua
-- WiFi Setings
WIFI_SSID = "TP-LINK_BFC8C4"
WIFI_PASS = "OmManiPadmeHum"

-- IP address and TCP port server thingspeak
SERVER_IP_ADDRESS = '184.106.153.149'
SERVER_TCP_PORT = 80

-- Write API Key thingspeak
TSKEY='GIGXPJGKU2EOUQ8S'

TimeoutSendData = 1

station_cfg = {}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd = WIFI_PASS
station_cfg.save = false


conn = net.createConnection(net.TCP, 0)


function main()

    
    
    TimeoutSendData = TimeoutSendData - 1

    if(TimeoutSendData == 0) then

        print("Setting up WIFI...")
        wifi.setmode(wifi.STATION)

        --modify according your wireless router settings
        wifi.sta.config(station_cfg)
        wifi.sta.connect()

        wifi.sta.connect()

        tmr.alarm(1, 1000, 1, function() 
            if (wifi.sta.getip() == nil) then
                 print("IP unavaiable, Waiting...")
            else
                tmr.stop(1)
                print("MAC: "..wifi.sta.getmac())   -- print current mac address
                print("IP: "..wifi.sta.getip())     -- print current IP address
                
                TimeoutSendData = 30

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
    -- api.thingspeak.com 184.106.153.149
    conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)
end


--
conn:on("connection", function(conn)

print("\rSend data...")
    conn:send("GET /update?key="..TSKEY.."&field1=15\r\n")
end)

--
conn:on("sent",function(conn)
    print("Closing connection")
    conn:close()
    wifi.setmode(wifi.NULLMODE)
end)


--
conn:on("disconnection", function(conn, payloadout)
    conn:close();
    collectgarbage();
    print("Got disconnection...\r")
    TimeoutSendData = 30
end)


-- main run every 1sec
tmr.alarm(0, 1000, tmr.ALARM_AUTO, function() main() end)