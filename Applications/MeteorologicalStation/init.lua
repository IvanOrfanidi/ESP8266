
--init.lua
-- WiFi Setings
WIFI_SSID = "TP-LINK_BFC8C4"
WIFI_PASS = "OmManiPadmeHum"

--Write API Key thingspeak
TSKEY='YDMRPUENEFI92SNA'

-- DHT config
DAT = 1

-- PORT INPUT
RAIN =  5
gpio.mode(RAIN, gpio.INPUT)

-- i2c config BMP180
SDA_PIN = 2
SCL_PIN = 3

timeout = 60

RainLast = 1;
if(gpio.read(RAIN) == 1) then
    RainLast = 0
end
RainSendData = false


-- Sending data to server thingspeak
function main()

    conn = net.createConnection(net.TCP, 0)

    timeout = timeout - 1
    
    if (timeout == 0) then            
        timeout = 29
        -- conection to thingspeak.com
        print("Sending data to thingspeak.com")
        conn:on("receive", function(conn, payloadout)
                if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                    print("Posted OK");
                end
            end)
        -- api.thingspeak.com 184.106.153.149
        conn:connect(80,'184.106.153.149')
    else
        rainCur = gpio.read(RAIN)
        if (RainLast ~= rainCur) then
            RainLast = rainCur
            RainSendData = true
            -- conection to thingspeak.com
            print("Sending data to thingspeak.com")
            conn:on("receive", function(conn, payloadout)
                    if (string.find(payloadout, "Status: 200 OK") ~= nil) then
                        print("Posted OK");
                    end
                end)
            -- api.thingspeak.com 184.106.153.149
            conn:connect(80,'184.106.153.149')
        end
    end

    print("Timeout Send Data "..timeout.. " min.")

--
conn:on("connection", function(conn)
    -- Checking rain
    if (RainSendData == false) then

        tDHT, hDHT = readDHT()

        tBMP, phpBMP, phgBMP = readBMP180()
    
        Vbat = adc.readvdd33(0)
        --Vbat = (Vbat * 3) / 1,024
        --Vbat = (Vbat * 1000) /  687
        
        print("\r")
        print("System voltage:"..Vbat.." mV")
        print("Temp DHT:"..tDHT.." C")
        print("Hum:"..hDHT.." %")
        print("Temp BMP180:"..tBMP.." C")
        print("Pres BMP180:"..phgBMP.." mmHg")
    
        print("Send data...")
        conn:send("GET /update?key="..TSKEY.."&field1="..tBMP.."&field2="..phgBMP.."&field3="..hDHT.."&field4="..Vbat.."&field6="..tDHT.."\r\n")
    else
        print("\r")
        print("Send data...")
        if (RainLast == 1) then
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
station_cfg={}
station_cfg.ssid = WIFI_SSID
station_cfg.pwd= WIFI_PASS
station_cfg.save=false
wifi.sta.config(station_cfg)

wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if (wifi.sta.getip()== nil) then
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
 
	-- main run every 1min
	tmr.alarm(0, (60 * 1000), tmr.ALARM_AUTO, function() main() end )
	--tmr.alarm(0, 1000, tmr.ALARM_SINGLE, function() sendData() end )
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
	print("BMP180 temperature: "..t)
	p = bmp085.pressure(OSS)
	print("BMP180 pressure hPA: "..p)
	-- converp Pa to mmHg
	phg = (p * 75 / 10000).."."..((p * 75 % 10000) / 1000)
	print("BMP180 pressure mmHg: "..phg)
	return t, p, phg
end


function readDHT()
	status, temp, humi, temp_dec, humi_dec = dht.readxx(DAT)
	if(status == dht.OK) then
		temp=temp.."."..temp_dec
		print("DHT temperature: "..temp)
		humi=humi.."."..humi_dec
		print("DHT humidity: "..humi)
		return temp, humi
	else
		print("DHT read error:"..status)
	end
end

