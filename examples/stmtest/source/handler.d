module handler;

import cushion;
import std.datetime.stopwatch;


///
struct Handler(Args...)
{
private:
	void delegate(Args)[] _dgs;
public:
	///
	void connect(void delegate(Args) dg)
	{
		_dgs ~= dg;
	}
	
	///
	void disconnect(void delegate(Args) dg)
	{
		import std.algorithm: remove;
		_dgs = _dgs.remove!(a => a is dg);
	}
	
	///
	void emit(Args args)
	{
		foreach (dg; _dgs)
			dg(args);
	}
	
	///
	void clear()
	{
		_dgs = null;
	}
	
	///
	alias opCall = emit;
}

static assert(isHandler!(Handler!()));
static assert(isHandler!(Handler!(int, int)));
static assert(is(HandlerParameters!(Handler!int)[0] == int));
static assert(is(HandlerReturnType!(Handler!int) == void));

@safe unittest
{
	// Programs to be driven by STM
	string status = "stopped";
	StopWatch playTime;
	void startMusic() { playTime.start(); status = "playing"; }
	void stopMusic()  { playTime.stop();  status = "stopped"; }
	void resetMusic() { playTime.reset(); }
	
	// Create StateTransitor instance
	struct Policy
	{
		enum string name          = "MusicPlayer";
		enum string stateKey      = "#>";
		alias StateTransitor(S,E) = cushion.StateTransitor!(
			S, E, S.init, Handler!(), Handler!Exception, Handler!E, Handler!(S, S));
	}
	auto stm = createStm!(Policy, startMusic, stopMusic, resetMusic);
	// Initial state is "stop" that most left state.
	assert(stm.currentState == stm.State.stop);
	assert(stm.getStateName(stm.currentState) == "#>stop");
	assert(stm.getEventName(stm.Event.onStart) == "onStart");
	assert(status == "stopped");
	
	// onStart event / transit to the "#>play" state
	stm.put(stm.Event.onStart);
	assert(stm.currentState == stm.State.play);
	assert(playTime.running);
	() @trusted { import core.thread: Thread, msecs; Thread.sleep(10.msecs); }(); // progress in playing...
	assert(playTime.peek != 0.msecs);
	assert(status == "playing");
	
	// onStart event / transit to the "#>pause" state
	stm.put(stm.Event.onStart);
	assert(stm.currentState == stm.State.pause);
	assert(!playTime.running);
	assert(status == "stopped");
	
	// onStop event / transit to the "#>stop" state
	stm.put(stm.Event.onStop);
	assert(stm.currentState == stm.State.stop);
	assert(!playTime.running);
	() @trusted { import core.thread: Thread, msecs; Thread.sleep(10.msecs); }(); // progress in stopped...
	assert(playTime.peek == 0.msecs);
}