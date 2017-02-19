--init.lua
SSID_NETWORK = 'Xiaomi_D36F'
PASSWORD_NETWORK= 'xiaomixiaomi'


timeout = 60
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
       node.restart()
end
else 
tmr.stop(1)
print("MAC: "..wifi.sta.getmac())      -- print current mac address
print("IP: "..wifi.sta.getip())      -- print current IP address
sntp.sync('pool.ntp.org',sync_ok, sync_err)
tmr.alarm(0, 1000, 1, function() main() end )
end 
end)

--pin3=GPIO0
sda = 4      -- GPIO2
scl = 3      -- GPIO0
dev_addr = 0x00   -- PCF8574
i2c.setup(0, sda, scl, i2c.SLOW)

function sync_ok(offsec, offusec,serv)
  print('Sync OK: '..tostring(offsec)..','..tostring(offusec)..','..tostring(serv))
  time_ntp = offsec + 10800
  tm = rtctime.epoch2cal(time_ntp)
  rtctime.set(time_ntp, 0)
  print(string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
end

function sync_err(errcode)
  print('Sync ERR: '..tostring(errcode))
  if errcode == 1 then print('1: DNS lookup failed') end
  if errcode == 2 then print('2: Memory allocation failure') end
  if errcode == 3 then print('3: UDP send failed') end
  if errcode == 4 then print('4: Timeout, no NTP response received') end
  insync=0
end

function main()
    --sntp.sync('pool.ntp.org',sync_ok, sync_err)
    tm = rtctime.epoch2cal(rtctime.get())
    year = (string.format("%04d", tm["year"]))
    mon = (string.format("%02d", tm["mon"]))
    day = (string.format("%02d", tm["day"]))
    hour = (string.format("%02d", tm["hour"]))
    min = (string.format("%02d", tm["min"]))
    sec = (string.format("%02d", tm["sec"]))
    
    msg = hour..";"..min..";"..sec..";"..day..";"..mon..";"..year..";"
    print(msg)
    
    i2c.start(0)
    i2c.address(0, dev_addr, i2c.TRANSMITTER)
    i2c.write(0, msg)
    i2c.stop(0)
    
    --print(string.format("%04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
    
end

