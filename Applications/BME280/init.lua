alt=10 -- altitude of the measurement place

sda, scl = 3, 4
i2c.setup(0, sda, scl, i2c.SLOW) -- call i2c.setup() only once
bme280.setup()

T, P, H, QNH = bme280.read(alt)
hm = (P * 75) / 100
local Tsgn = (T < 0 and -1 or 1); T = Tsgn*T
print(string.format("T=%s%d.%02d", Tsgn<0 and "-" or "", T/100, T%100))
print(string.format("QFE=%d.%03d", hm/1000, hm%1000))
print(string.format("humidity=%d.%03d%%", H/1000, H%1000))
D = bme280.dewpoint(H, T)
local Dsgn = (D < 0 and -1 or 1); D = Dsgn*D
print(string.format("dew_point=%s%d.%02d", Dsgn<0 and "-" or "", D/100, D%100))

-- altimeter function - calculate altitude based on current sea level pressure (QNH) and measure pressure
P = bme280.baro()
curAlt = bme280.altitude(P, QNH)
local curAltsgn = (curAlt < 0 and -1 or 1); curAlt = curAltsgn*curAlt
print(string.format("altitude=%s%d.%02d", curAltsgn<0 and "-" or "", curAlt/100, curAlt%100))