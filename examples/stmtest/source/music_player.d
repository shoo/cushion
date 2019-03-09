module music_player;

import cushion;
import std.datetime.stopwatch;

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
		enum string name        = "MusicPlayer";
		enum string stateKey    = "#>";
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
	() @trusted { import core.thread; Thread.sleep(10.msecs); }(); // progress in playing...
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
	() @trusted { import core.thread; Thread.sleep(10.msecs); }(); // progress in stopped...
	assert(playTime.peek == 0.msecs);
}