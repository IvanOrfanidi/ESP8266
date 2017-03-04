
--Write API Key
TSKEY='3A07W8TZ0F1DQYPP'

--GPIO Init
KEY = 3
BUZ = 2
gpio.mode(BUZ, gpio.OUTPUT)
gpio.mode(KEY, gpio.INPUT)
tmr.alarm(2, 100, 1, function() read_key() end)

wifi.setmode(wifi.STATIONAP)
--ESP SSID generated wiht its chipid
wifi.ap.config({ssid="ESP-"..node.chipid()
, auth=wifi.OPEN})
enduser_setup.manual(true)
enduser_setup.start(
  function()
    if wifi.sta.getip() ~= nil then
        enduser_setup.stop()
        wifi.setmode(wifi.STATION)
        
        sntp.sync('pool.ntp.org',sync_ok, sync_err)
        
        tmr.alarm(0, 1000, 1, function() main() end )
        --Get current Station configuration (OLD FORMAT)
        ssid, password, bssid_set, bssid=wifi.sta.getconfig()
        print("\nCurrent Station configuration:\nSSID : "..ssid
        .."\nPassword  : "..password
        .."\nBSSID_set  : "..bssid_set
        .."\nBSSID: "..bssid.."\n")
        ssid, password, bssid_set, bssid=nil, nil, nil, nil
    end
  end,
  function(err, str)
    print("enduser_setup: Err #" .. err .. ": " .. str)
  end
);


-- i2c config
SDA_PIN = 6
SCL_PIN = 5
-- BMP180 config
OSS = 1 -- oversampling
bmp180 = require("bmp085")
bmp180.init(SDA_PIN, SCL_PIN)

function readBMP180()
  t = bmp180.temperature()
  -- add decimal point
  t = t / 10 ..".".. t % 10
  --print("BMP180 temperature: "..t)
  p = bmp180.pressure(OSS)
  --print("BMP180 pressure hPA: "..p)
  -- converp Pa to mmHg
  phg=(p * 75 / 10000).."."..((p * 75 % 10000) / 1000)
  --print("BMP180 pressure mmHg: "..phg)
  return t, p, phg
end


--   HD44780
COLUMN_LCD = 16
LINE_LCD = 2
id = 0
sda = 6      -- GPIO2
scl = 5      -- GPIO14
dev = 0x27   -- PCF8574
reg = 0x00    -- write
i2c.setup(id, sda, scl, i2c.SLOW)

function send(data)
   local bl = 0x08      -- 0x08 = back light on

   local value = {}
   for i = 1, #data do
      table.insert(value, data[i] + bl + 0x04 + rs)
      table.insert(value, data[i] + bl + rs)      -- fall edge to write
   end
   
   i2c.start(id)
   i2c.address(id, dev, i2c.TRANSMITTER)
   i2c.write(id, reg, value)
   i2c.stop(id)
end  

function print_lcd(str)
     -- init
    rs = 0
    send({0x30})
    tmr.delay(1000)
    send({0x30})
    tmr.delay(100)
    send({0x30})
    send({0x20, 0x20, 0x80})   -- 4 bit, 2 line
    send({0x00, 0x10})            -- display clear
    send({0x00, 0xf0})            -- display on
    
    nibble = {
       ["0"] = 0x00,
       ["1"] = 0x10,
       ["2"] = 0x20,
       ["3"] = 0x30,
       ["4"] = 0x40,
       ["5"] = 0x50,
       ["6"] = 0x60,
       ["7"] = 0x70,
       ["8"] = 0x80,
       ["9"] = 0x90,
       ["a"] = 0xa0,
       ["b"] = 0xb0,
       ["c"] = 0xc0,
       ["d"] = 0xd0,
       ["e"] = 0xe0,
       ["f"] = 0xf0
    }
    
    rs = 1
    now_line = 0
    for i = 1, #str do
       if( (i>16) and (now_line == 0) ) then
           now_line = 1
           for n=1, 24 do
                local char = string.byte(string.sub(str, i, i))
                send({nibble[string.sub(string.format("%x", char), 1, -2)], nibble[string.sub(string.format("%x", char), 2)]})
           end
       end
    
       local char = string.byte(string.sub(str, i, i))
       send({nibble[string.sub(string.format("%x", char), 1, -2)], nibble[string.sub(string.format("%x", char), 2)]})
    end

end

-- DHT11 config
DAT = 4

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
    tDHT, hDHT = readDHT11()
    
    tBMP, phpBMP, phgBMP = readBMP180()
    phgBMP = (phpBMP * 75) / 10000
    
    print("Temp DHT11:"..tDHT.." C")
    print("Hum:"..hDHT.." %")
    print("Send data...")
    conn:send("GET /update?key="..TSKEY.."&field1="..hDHT.."&field2="..tDHT.."&field3="..phgBMP.."&field4="..tBMP.."\r\n")
end)

conn:on("sent",function(conn)
                      print("Closing connection")
                      conn:close()
                  end)
conn:on("disconnection", function(conn, payloadout)
        conn:close();
        collectgarbage();
        print("Got disconnection...\r")               
  end)
end


function updateLCD()
    tDS = 0
    
    status, tDHT, hDHT, temp_dec, humi_dec = dht.read(DAT)
    
	Time = rtctime.get()
    tm = rtctime.epoch2cal(Time)

    year = (string.format("%04d", tm["year"]))
    mon = (string.format("%02d", tm["mon"]))
    day = (string.format("%02d", tm["day"]))
    hour = (string.format("%02d", tm["hour"]))
    min = (string.format("%02d", tm["min"]))
    tBMP, phpBMP, phgBMP = readBMP180();
    phgBMP = (phpBMP * 75) / 10000

    msg = hour..":"..min.." P: "..phgBMP.."mmHgT: "..tBMP.."C, H: "..hDHT.."%"

    while string.len(msg) < (COLUMN_LCD * LINE_LCD) - 1  do
        msg = msg.." "
    end
    print(msg)
    print_lcd(msg)
end

year = 0;
mon = 0;
day = 0;
hour = 0;
min = 0;
one_update_lcd = 0;
function sync_ok(offsec, offusec,serv)
  print('Sync OK: '..tostring(offsec)..','..tostring(offusec)..','..tostring(serv))
  time_ntp = offsec + 10800
  tm = rtctime.epoch2cal(time_ntp)
  rtctime.set(time_ntp, 0)
  print(string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))

  if one_update_lcd == 0 then
    one_update_lcd = 1
    updateLCD()
  end
end

function sync_err(errcode)
  print('Sync ERR: '..tostring(errcode))
  if errcode == 1 then print('1: DNS lookup failed') end
  if errcode == 2 then print('2: Memory allocation failure') end
  if errcode == 3 then print('3: UDP send failed') end
  if errcode == 4 then print('4: Timeout, no NTP response received') end
  insync=0
end


buz_on = 0;
time_update = 1
 
function main()

	tm = rtctime.epoch2cal(rtctime.get())
	sec = (string.format("%02d", tm["sec"]))
	
	if sec == "00" then
	
		updateLCD()
		
		if time_update == 1 then 
			sendData()
		end
		if time_update == 40 then 
			sendData()
		end
		
		if time_update == 60 then 
			sntp.sync('pool.ntp.org',sync_ok, sync_err)
		end
		
		time_update = time_update + 1;
		
		if time_update > 80 then 
		 time_update = 1;
		end
	end
end


timer_buz_on = 0;
update_buz = 0;
function read_key()

    if min == "40" then
        if hour == "10" then
            if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
        if hour == "11" then
            if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
        if hour == "12" then
            if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
        if hour == "14" then
             if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
        if hour == "15" then
             if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
        if hour == "16" then
            if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
        if hour == "17" then
            if update_buz == 0 then
                buz_on = 1;
                update_buz = 1
            end
        end
    else
        update_buz = 0;
    end
    
    if buz_on == 1 then
        gpio.write(BUZ, gpio.HIGH)
        --print("BUZ ON\r")
        if timer_buz_on == 0 then 
            timer_buz_on = 80;
        end
    else
       gpio.write(BUZ, gpio.LOW)
       --print("BUZ OFF\r")
    end

    if gpio.read(KEY) == 0 then
        timer_buz_on = 0;
        buz_on = 0;
    end

     
    if timer_buz_on <= 1 then
        buz_on = 0;
        timer_buz_on = 0;
        gpio.write(BUZ, gpio.LOW)
        --print("BUZ OFF\r")
    else
        timer_buz_on = timer_buz_on - 1;
        print("timer_buz_on "..timer_buz_on)
    end
end

print_lcd("Setting  up WIFI")
