lighton = 0
PIN_LED = 5
gpio.mode(PIN_LED,gpio.OUTPUT)
tmr.alarm(1,2000,1,function()
    if (lighton == 0) then
            lighton=1
            gpio.write(PIN_LED,gpio.HIGH)
        else
            lighton=0
            gpio.write(PIN_LED,gpio.LOW)
        end
end)
