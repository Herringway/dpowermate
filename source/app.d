import powermate, std.getopt, std.stdio, std.conv;

void main(string[] args) {
        if (args.length == 1) {
                stderr.writefln("Usage: %s [--brightness n] [--pulsetable n] [--pulsespeed n] [--pulseasleep on/off] [--pulseawake on/off]", args[0]);
                return;
        }
        auto powermate = findPowerMate();
        void setBrightness(ubyte brightness) {
                powermate.Brightness = brightness;
        }
        void setPulseTable(ubyte pulsetable) {
                powermate.PulseStyle = cast(PowerMate.PulseStyles)pulsetable;
        }
        void setPulseSpeed(ushort pulsespeed) {
                powermate.PulseSpeed = pulsespeed;
        }
        void setPulseAsleep(bool on) {
                powermate.PulseAsleep = on;
        }
        void setPulseAwake(bool on) {
                powermate.PulseAwake = on;
        }
        void setPowerMate(string option, string value) {
                try {
                switch(option) {
                        case "brightness|b": setBrightness(to!ubyte(value)); break;
                        case "pulsetable|t": setPulseTable(to!ubyte(value)); break;
                        case "pulsespeed|p": setPulseSpeed(to!ushort(value)); break;
                        case "pulseasleep|s": setPulseAsleep(to!bool(value)); break;
                        case "pulseawake|w": setPulseAwake(to!bool(value)); break;
                        default: throw new Exception("Unknown option: "~option);
                }
                } catch (Exception e) {
                        stderr.writeln(e.msg);
                }
        }
        getopt(args, "brightness|b", &setPowerMate, "pulsetable|t", &setPowerMate, "pulsespeed|p", &setPowerMate, "pulseasleep|s", &setPowerMate, "pulseawake|w", &setPowerMate);
        powermate.update();
}
