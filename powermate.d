module powermate;

import std.stdio, std.conv, std.string, std.algorithm, std.exception;

version(linux) {
	static ushort EV_SYN = 0; // Synchronization events
	static ushort EV_KEY = 1; // Button push events
	static ushort EV_REL = 2; // Relative axis change events
	static ushort EV_MSC = 4; // Misc events

	static ushort SYN_REPORT = 0; // Reports

	static ushort BTN_MISC = 0x100; // Miscellaneous button pushes

	static ushort REL_DIAL = 7; // Dial rotated

	static ushort MSC_PULSELED = 1; // Pulse an LED

	uint EVIOCGNAME(ulong len) {
			return cast(uint)((1<<(31)) | ('E'<<(8)) | 6 | (len<<(16)));
	}

	struct timeval {
		long tv_sec;
		long tv_usec;
	}

	struct input_event {
		timeval time;
		ushort type;
		ushort code;
		int value;
	}
}
class PowerMate {
	private File handle;
	public ubyte Brightness = 0x80;
	public ushort PulseSpeed = 255;
	public ubyte PulseTable = 0;
	public bool PulseAsleep = false;
	public bool PulseAwake = true;
	enum Events { BUTTONDOWN, BUTTONUP, CLOCKWISE, COUNTERCLOCKWISE };
	private void delegate(Events event)[] ButtonDownEvents;
	private void delegate(Events event)[] ButtonUpEvents;
	private void delegate(Events event)[] ClockwiseEvents;
	private void delegate(Events event)[] CounterclockwiseEvents;
	invariant() {
		enforce(PulseTable < 3, "Invalid pulse table specified");
		enforce(PulseSpeed < 511, "Pulse Speed too high!");
	}
	this(File input) {
		handle = input;
	}
	void registerEventHandler(void delegate(Events event) eventHandler, Events event) {
		if (event == Events.BUTTONDOWN)
			ButtonDownEvents ~= eventHandler;
		if (event == Events.BUTTONUP)
			ButtonUpEvents ~= eventHandler;
		if (event == Events.CLOCKWISE)
			ClockwiseEvents ~= eventHandler;
		if (event == Events.COUNTERCLOCKWISE)
			CounterclockwiseEvents ~= eventHandler;
	}
	void registerEventHandler(void function(Events event) eventHandler, Events event) {
		import std.functional;
		registerEventHandler(toDelegate(eventHandler), event);
	}
	void readEvents() {
		while (true)
			readNextEvent();
	}
	void readNextEvent() {
		version(linux) {
			input_event[1] t;
			while (true) {
				handle.rawRead(t);
				void delegate(Events event)[] handlers;
				Events event;
				if ((t[0].type == EV_KEY) && (t[0].code == BTN_MISC)) {
					if (t[0].value == 1)
						event = Events.BUTTONDOWN;
					else if (t[0].value == 0)
						event = Events.BUTTONUP;
				}
				else if ((t[0].type == EV_REL) && (t[0].code == REL_DIAL)) {
					if (t[0].value >= 1)
						event = Events.CLOCKWISE;
					else if (t[0].value <= -1)
						event = Events.COUNTERCLOCKWISE;
				}
				else if ((t[0].type == EV_SYN) && (t[0].code == SYN_REPORT)) {
					break;
				}
				else {
					debug writeln("Unhandled: ", t[0]);
					continue;
				}
				switch(event) {
					case Events.BUTTONDOWN: handlers = ButtonDownEvents; break;
					case Events.BUTTONUP: handlers = ButtonUpEvents; break;
					case Events.CLOCKWISE: handlers = ClockwiseEvents; break;
					case Events.COUNTERCLOCKWISE: handlers = CounterclockwiseEvents; break;
					default: throw new Exception("Unhandled event!");
				}
				foreach (handler; handlers)
					handler(event);
			}
		}
	}
	public void update() {
		version(linux) {
			input_event t;
			t.type = EV_MSC;
			t.code = MSC_PULSELED;
			t.value = Brightness | (PulseSpeed << 8) | (PulseTable << 17) | (PulseAsleep << 19) | (PulseAwake << 20);
			debug writefln("Brightness: %d\nPulse Speed: %d\nPulse Table: %d\nPulse Asleep: %s\nPulse Awake: %s", Brightness, PulseSpeed, PulseTable, PulseAsleep, PulseAwake);
			handle.rawWrite([t]);
		}
	}
}

PowerMate findPowerMate() {
	version(linux) {
		import core.sys.posix.sys.ioctl;
		import std.file;
		bool couldNotOpen = false;
		bool isPowerMate(File inFile) {
			char[255] name;
			if (ioctl(inFile.fileno(), EVIOCGNAME(name.length), &name) < 0) {
				return false;
			}
			string fixedName = name[0..countUntil(to!string(name), "\0")].idup;
			if (fixedName == "Griffin PowerMate")
				return true;
			return false;
		}
		foreach (string eventfile; dirEntries("/dev/input", "event*", SpanMode.shallow)) {
			try {
				File testFile = File(eventfile, "r+");
				if (isPowerMate(testFile))
					return new PowerMate(testFile);
			} catch (ErrnoException e) {
				couldNotOpen = true;
			}
		}
		if (couldNotOpen)
			throw new Exception("Could not open some event files");
	}
	throw new Exception("Powermate not found");
}

unittest {
	int clicks = 0;
	int unclicks = 0;
	int clockwiseturns = 0;
	int counterclockwiseturns = 0;
	void testHandler(PowerMate.Events event) {
		if (event == PowerMate.Events.BUTTONDOWN)
			clicks++;
		else if (event == PowerMate.Events.BUTTONUP)
			unclicks++;
		else if (event == PowerMate.Events.CLOCKWISE)
			clockwiseturns++;
		else if (event == PowerMate.Events.COUNTERCLOCKWISE)
			counterclockwiseturns++;
	}
	version(linux) {
		import std.file;
		scope(exit) if (exists("testEventData")) remove("testEventData");
		scope(exit) if (exists("testOutput")) remove("testOutput");
		auto t1file = File("testEventData", "w+");
		auto tmpStruct = [input_event(),input_event()];
		tmpStruct[0].type = EV_KEY; tmpStruct[0].code = BTN_MISC; tmpStruct[0].value = 1;
		tmpStruct[1].type = EV_SYN; tmpStruct[1].code = SYN_REPORT;
		t1file.rawWrite(tmpStruct);
		tmpStruct[0].type = EV_KEY; tmpStruct[0].code = BTN_MISC; tmpStruct[0].value = 0;
		tmpStruct[1].type = EV_SYN; tmpStruct[1].code = SYN_REPORT;
		t1file.rawWrite(tmpStruct);
		tmpStruct[0].type = EV_REL; tmpStruct[0].code = REL_DIAL; tmpStruct[0].value = 1;
		tmpStruct[1].type = EV_SYN; tmpStruct[1].code = SYN_REPORT;
		t1file.rawWrite(tmpStruct);
		tmpStruct[0].type = EV_REL; tmpStruct[0].code = REL_DIAL; tmpStruct[0].value = -1;
		tmpStruct[1].type = EV_SYN; tmpStruct[1].code = SYN_REPORT;
		t1file.rawWrite(tmpStruct);
		t1file.close();
		auto powermate = new PowerMate(File("testEventData", "r"));
		powermate.registerEventHandler(&testHandler, PowerMate.Events.BUTTONDOWN);
		powermate.registerEventHandler(&testHandler, PowerMate.Events.BUTTONUP);
		powermate.registerEventHandler(&testHandler, PowerMate.Events.CLOCKWISE);
		powermate.registerEventHandler(&testHandler, PowerMate.Events.COUNTERCLOCKWISE);
		foreach (i; 0..4)
			powermate.readNextEvent();
		assert(clicks == 1, "Clicks mismatch");
		assert(unclicks == 1, "Click releases mismatch");
		assert(clockwiseturns == 1, "Clockwise Turns mismatch");
		assert(counterclockwiseturns == 1, "Counterclockwise Turns mismatch");
		auto t2file = File("testOutput", "w+");
		auto powermate2 = new PowerMate(t2file);
		powermate2.Brightness = 127;
		powermate2.PulseSpeed = 255;
		powermate2.PulseTable = 1;
		powermate2.PulseAwake = true;
		powermate2.PulseAsleep = true;
		powermate2.update();
		ubyte[24] buffer;
		t2file.seek(0);
		t2file.rawRead(buffer);
		assert(buffer == [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x7f, 0xff, 0x1a, 0x00], "Output Mismatch");
	}
}

