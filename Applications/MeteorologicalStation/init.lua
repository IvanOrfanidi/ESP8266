
--init.lua
timeout = 60
print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
--modify according your wireless router settings
wifi.sta.config("TP-LINK_BFC8C4","OmManiPadmeHum")
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
    timeout = 29
	print("MAC: "..wifi.sta.getmac())   -- print current mac address
	print("IP: "..wifi.sta.getip())     -- print current IP address
 
	-- main run every 1min
	tmr.alarm(0, (60 * 1000), tmr.ALARM_AUTO, function() main() end )
	--tmr.alarm(0, 1000, tmr.ALARM_SINGLE, function() sendData() end )
end

end)


--Write API Key
TSKEY='YDMRPUENEFI92SNA'

-- onewire
OWPIN = 4

-- DHT config
DAT = 1

-- PORT INPUT
RAIN =  5
gpio.mode(RAIN, gpio.INPUT)

-- i2c config BMP180
SDA_PIN = 2
SCL_PIN = 3

-- BMP180 config
OSS = 1 -- oversampling
bmp180 = require("bmp085")
bmp180.init(SDA_PIN, SCL_PIN)


-- read data BMP180
function readBMP180()
	t = bmp180.temperature()
	-- add decimal point
	t = t / 10 ..".".. t % 10
	print("BMP180 temperature: "..t)
	p = bmp180.pressure(OSS)
	print("BMP180 pressure hPA: "..p)
	-- converp Pa to mmHg
	phg = (p * 75 / 10000).."."..((p * 75 % 10000) / 1000)
	print("BMP180 pressure mmHg: "..phg)
	return t, p, phg
end


-- read data DS18B20
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


function readDHT()
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


RainLast = 1;
if(gpio.read(RAIN) == 1) then
    RainLast = 0
end
RainSendData = false
RainSentData = false

-- Sending data to server thingspeak
function main()

    timeout = timeout - 1
    
    conn = nil
    conn = net.createConnection(net.TCP, 0) 
    
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
    

conn:on("connection", function(conn)
    -- Checking rain
    if (RainSendData == false) then
    	ow.setup(OWPIN)
    	tDS=getDataOW()
    	tDHT, hDHT = readDHT()
    	tBMP, phpBMP, phgBMP = readBMP180()
    
        Vbat = adc.readvdd33(0)
        --Vbat = (Vbat * 3) / 1,024
        --Vbat = (Vbat * 1000) /  687
        
        print("\r")
        print("System voltage:"..Vbat.." mV")
    	print("Temp DS:"..tDS.." C")
    	print("Temp DHT11:"..tDHT.." C")
    	print("Hum:"..hDHT.." %")
    	print("Temp BMP180:"..tBMP.." C")
    	print("Pres BMP180:"..phgBMP.." mmHg,"..(phpBMP/1000).."kPa")
    
    	print("Send data...")
    	conn:send("GET /update?key="..TSKEY.."&field1="..tDS.."&field2="..phgBMP.."&field3="..hDHT.."&field4="..Vbat.."&field6="..tBMP.."&field7="..tDHT.."\r\n")
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
        RainSentData = true
    end
end)

--
conn:on("sent",function(conn)
				print("Closing connection")
				conn:close()
			end)


--
conn:on("disconnection", function(conn, payloadout)
		conn:close();
		collectgarbage();
		print("Got disconnection...\r")
        if (RainSentData == true) then
            RainSendData = false
        end
		-- D0 to RESET
		--print("Deep sleep 30 min")
		--node.dsleep(1800000000)
	end)
end
