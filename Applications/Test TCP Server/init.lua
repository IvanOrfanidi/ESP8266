FIRMWARE_VER = 1
FIRMWARE_BUILD = 0
DATE = "16.04.2020"
print("\r")
print("Firmware ver."..FIRMWARE_VER.."."..FIRMWARE_BUILD.."\r")
print("Date "..DATE.."\r")
print("\r")


-- WiFi Setings
WIFI_SSID = "TP-LINK_BFC8C4"
WIFI_PASS = "OmManiPadmeHum"

--modify according your wireless router settings
station_cfg = {}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd = WIFI_PASS
station_cfg.save = true

-- IP address and TCP port server thingspeak
SERVER_IP_ADDRESS = '192.168.109.5'
SERVER_TCP_PORT = 35000

TIMEOUT_SEND_DATA = 120
TIMEOUT_RESTART_SEND_DATA = 10

-- Write API Key thingspeak
TSKEY='CMK9M12C53U5WSFX'

g_open_connection = false
g_timeout_send = TIMEOUT_RESTART_SEND_DATA

conn = net.createConnection(net.TCP, 0)

-- MAIN
function main()

    if(g_open_connection == true) then
        return
    end

    g_timeout_send = g_timeout_send - 1

    if(g_timeout_send == 0) then

        g_open_connection = true
    
        print("Setting up WIFI...")
        wifi.setmode(wifi.STATION)
        wifi.sta.config(station_cfg)
        wifi.sta.connect()
    
        tmr.alarm(1, 1000, 1, function()
            if (wifi.sta.getip() == nil) then
                 print("IP unavaiable, Waiting...")
            else
                tmr.stop(1)
                print("MAC: "..wifi.sta.getmac())   -- print current mac address
                print("IP: "..wifi.sta.getip())     -- print current IP address
                
                send_data()
                
                g_timeout_send = TIMEOUT_SEND_DATA
            end
        end)
    end
end

function send_data()
conn:on("receive", function(conn, payloadout)
            if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                print("Posted OK");
            end
        end)
    conn:connect(SERVER_TCP_PORT, SERVER_IP_ADDRESS)
end


conn:on("connection", function(conn)

    print("\rSend data...")
    a = 10
    b = 20
    c = 30
    d = 40
    e = 50
    f = 60
    g = 70
    h = 80
    conn:send("GET /update?key="..TSKEY.."&field1="..a.."&field2="..b.."&field3="..c.."&field4="..d.."&field5="..e.."&field6="..f.."&field7="..g.."&field8="..h.."\r\n")
end)


conn:on("sent",function(conn)
    conn:close()
    print("Closing connection")
    wifi.setmode(wifi.NULLMODE)
    g_open_connection = false
    collectgarbage();
end)


conn:on("disconnection", function(conn, payloadout)
    print("Got disconnection...\r")
    wifi.setmode(wifi.NULLMODE)
    g_timeout_send = TIMEOUT_RESTART_SEND_DATA
    g_open_connection = false
    collectgarbage();
end)

----------------------------------------------------------------------
tmr.alarm(0, 1000, tmr.ALARM_AUTO, function() main() end )
