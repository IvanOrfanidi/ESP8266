year = 0;
mon = 0;
day = 0;
hour = 0;
min = 0;
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

wifi.setmode(wifi.STATIONAP)
--ESP SSID generated wiht its chipid
wifi.ap.config({ssid="Mynode-"..node.chipid()
, auth=wifi.OPEN})
enduser_setup.manual(true)
enduser_setup.start(
  function()
    enduser_setup.stop()
    wifi.setmode(wifi.STATION)
    
    sntp.sync('pool.ntp.org',sync_ok, sync_err)

    --Get current Station configuration (OLD FORMAT)
    ssid, password, bssid_set, bssid=wifi.sta.getconfig()
    print("\nCurrent Station configuration:\nSSID : "..ssid
    .."\nPassword  : "..password
    .."\nBSSID_set  : "..bssid_set
    .."\nBSSID: "..bssid.."\n")
    ssid, password, bssid_set, bssid=nil, nil, nil, nil
  end,
  function(err, str)
    print("enduser_setup: Err #" .. err .. ": " .. str)
  end
);
