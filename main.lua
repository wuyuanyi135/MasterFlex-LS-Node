ID = "PC"..node.chipid()
offtime = 0
offtmr = tmr.create()
pinTacho = 5
pinStart = 1
pinDirection = 2

gpio.mode(pinTacho,gpio.INT, gpio.PULLUP)
gpio.mode(pinStart, gpio.OUTPUT)
gpio.mode(pinDirection, gpio.OUTPUT)

tacho = 0;
gpio.trig(pinTacho, "both", function(level, when, eventcount)
    tacho = tacho + 1;
end)


function start(en)
    if en > 0 then
        gpio.write(pinStart,gpio.LOW)
        tacho = 0;
    else
        gpio.write(pinStart,gpio.HIGH)
    end
end
function direction(ccw)
    if ccw > 0 then
        gpio.write(pinDirection,gpio.LOW)
    else
        gpio.write(pinDirection,gpio.HIGH)
    end
end
function stopAndWaitTacho(fcn)
    start(0)
    local tachoWaitTimer = tmr.create()
    local lastTacho = 0
    tachoWaitTimer:register(50, tmr.ALARM_AUTO, function() 
        if lastTacho == tacho then
            tachoWaitTimer:unregister()
            fcn(lastTacho)
        end
        lastTacho = tacho
    end)
    tachoWaitTimer:start()
end
----------------------------------------
station_cfg={}
station_cfg.ssid="DCHost"
station_cfg.pwd="dchost000000"
station_cfg.got_ip_cb = function(ip, mask, gateway)
    print("Got ip")
    m = mqtt.Client(ID, 60)
    m:on("message", function(client, topic, data)
        print(topic, data)
        if topic == ID.."/direction" then
            direction(tonumber(data))
        end
        if topic == ID.."/offtime" then
            offtime = tonumber(data)
        end
        if topic == ID.."/start" then
            s = (tonumber(data))
            if s > 0 then
                start(1)
                if offtime > 0 then
                    offtmr:register(offtime, tmr.ALARM_SINGLE, function (t) 
                        stopAndWaitTacho(function(t)
                            m:publish(ID.."/tacho", tostring(t), 0, 0)
                        end)
                    end)
                    offtmr:start()
                end
            else
                if offtime == 0 then
                    stopAndWaitTacho(function(t)
                        m:publish(ID.."/tacho", tostring(t), 0, 0)
                    end)
                end
            end
        end
    end)

    m:connect("192.168.43.1", 1883, false, function()
        print("MQTT Connected")
        m:subscribe(ID.."/direction", 0)
        m:subscribe(ID.."/start", 0)
        m:subscribe(ID.."/offtime", 0)
    end, function(client, reason)
        print("failed reason: " .. reason)
        node.restart()
    end)

end
wifi.setmode(wifi.STATION, true)
wifi.sta.config(station_cfg)
