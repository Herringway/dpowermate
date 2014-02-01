# DPowermate - A D library for interfacing with the Griffin Powermate

## Supported platforms
* Linux
 * Supports setting LED parameters, dial, button
 * Cannot query device for current parameters (No system call available?)
* Windows
 * No support implemented yet

## Example usage
```D
auto powermate = new Powermate("/dev/input/event0"); //Open PowerMate device with read and write access
auto powermate = new Powermate(File("/dev/input/event0", "r")); //read-only access, only event handlers will be available
powermate.Brightness = 0xFF; //Set brightness to maximum
powermate.PulseSpeed = 0xFF; //Set pulse speed to maximum
powermate.PulseTable = 1; //Use alternate pulse style
powermate.PulseStyle = Powermate.PulseStyles.STYLE2; //Same as above
powermate.PulseAsleep = true; //Pulse when PC is asleep
powermate.PulseAwake = false; //Do not pulse when PC is awake
powermate.update(); //Sets LED parameters
powermate.registerEventHandler((x) => writeln(x), PowerMate.Event.BUTTONDOWN); //Register a button push event handler: writes to stdout when button is pushed
powermate.readNextEvent(); //Wait until an input event occurs, then execute associated event handlers
powermate.readEvents(); //Read events & execute event handlers until thread is destroyed
```

## Todo:
* Implement Windows support
* Determine if querying device for current device parameters is truly impossible
