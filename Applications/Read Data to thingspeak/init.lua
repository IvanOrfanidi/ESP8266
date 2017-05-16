--init.lua
--print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
--modify according your wireless router settings
wifi.sta.config("Xiaomi_D36F","xiaomixiaomi")
wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
if (wifi.sta.getip()== nil) then 
--print("IP unavaiable, Waiting...") 
else 
tmr.stop(1)
--print("MAC: "..wifi.sta.getmac())      -- print current mac address
--print("IP: "..wifi.sta.getip())      -- print current IP address

tmr.alarm(0, 30000, tmr.ALARM_AUTO, function() acceptData() end )
end 
end)


Channel_ID = 114905
------------------------------------------------------------------
function acceptData()
tmr.wdclr()
conn=nil
conn=net.createConnection(net.TCP, 0) 
conn:on("receive", function(conn, payloadout)
        print(payloadout) -- opcode is 1 for text message, 2 for binary
    end)
-- api.thingspeak.com 184.106.153.149
conn:connect(80,'184.106.153.149')

conn:on("connection", function(conn)
    conn:send("GET /channels/"..Channel_ID.."/feeds.json?results=1\r\n")
end)

conn:on("sent",function(conn)
                      --print("Closing connection")
                      --conn:close()
                  end)
conn:on("disconnection", function(conn, payloadout)
        conn:close();
        collectgarbage();
        --print("Got disconnection...\r")               
  end)
  
end