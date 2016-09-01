--init.lua
print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
--modify according your wireless router settings
wifi.sta.config("Xiaomi_D36F","xiaomixiaomi")
wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if wifi.sta.getip()== nil then 
print("IP unavaiable, Waiting...") 
else 
tmr.stop(1)
print(wifi.sta.getmac())                            -- print current mac address
print("Config done, IP is "..wifi.sta.getip())      -- print current IP address
dofile("httpsender.lua")
end 
end)
