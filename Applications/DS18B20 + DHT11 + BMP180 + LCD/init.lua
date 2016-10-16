--init.lua
SSID_NETWORK = 'HomeInternet'
PASSWORD_NETWORK= 'OmMaNiPadmeHum'
--Write API Key
TSKEY='3A07W8TZ0F1DQYPP'

timeout = 60
print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
--modify according your wireless router settings
wifi.sta.config(SSID_NETWORK, PASSWORD_NETWORK)
wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if (wifi.sta.getip()== nil) then 
print("IP unavaiable, Waiting...") 
timeout = timeout - 1
print("Timeout Connect "..timeout)
if(timeout == 0) then
       --node.dsleep(1800000000)
end
else 
tmr.stop(1)
print("MAC: "..wifi.sta.getmac())      -- print current mac address
print("IP: "..wifi.sta.getip())      -- print current IP address
msg = "IP:"..wifi.sta.getip()
prit_lcd(msg)

tmr.alarm(0, 5000, 1, function() main() end )
end 
end)

--   HD44780
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
   --tmr.delay(1)
   i2c.stop(id)
end  
function prit_lcd(str)
     -- init
    rs = 0
    send({0x30})
    tmr.delay(4000)
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
DAT = 2

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


function main()
    print("Run Appl")
    --msg = "Hello World!1234567890          "
    status, temp, humi, temp_dec, humi_dec = dht.read(DAT)
    -- Integer firmware using this example
    msg = "T1: "..temp.."C, H1: "..humi.."%"
    print(msg)
    prit_lcd(msg)
    print("Stop Appl")
end