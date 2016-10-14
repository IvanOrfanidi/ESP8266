--   PCF8574
--   P7   P6   P5   P4    P3      P2   P1   P0
--   D7   D6   D5   D4   (BL)   EN   RW   RS
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
   tmr.delay(1)
   i2c.stop(id)
end

-- init
rs = 0
send({0x30})
tmr.delay(4100)
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
str = "Hello World!"
for i = 1, #str do
   local char = string.byte(string.sub(str, i, i))
   send({
      nibble[string.sub(string.format("%x", char), 1, -2)],
      nibble[string.sub(string.format("%x", char), 2)]
   })
end
print(str)
