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
	mixin(loadStmFromCsv!"MusicPlayer"("#>"));
	auto stm = makeStm();
	
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



@safe unittest
{
	// Programs to be driven by STM
	string status = "stopped";
	StopWatch playTime;
	void startMusic() { playTime.start(); status = "playing"; }
	void stopMusic()  { playTime.stop();  status = "stopped"; }
	void resetMusic() { playTime.reset(); }
	void delay(uint tim) @trusted
	{
		import core.thread: Thread, msecs;
		Thread.sleep(tim.msecs);
	}

	// Create StateTransitor instance
	mixin(decodeStmFromCsv(import("MusicPlayer.stm.csv"),
	                       import("MusicPlayer.map.csv"),
	                       "MusicPlayer.stm.csv",
	                       "MusicPlayer.map.csv",
	                       "#>",
	                       "makeStm"));
	auto stm = makeStm();

	// Initial state is "stop" that most left state.
	assert(stm.currentState == stm.State.stop);
	assert(stm.getStateName(stm.currentState) == "#>stop");
	assert(stm.getEventName(stm.Event.onStart) == "onStart");
	assert(status == "stopped");

	// onStart event / transit to the "#>play" state
	stm.put(stm.Event.onStart);
	assert(stm.currentState == stm.State.play);
	assert(playTime.running);
	delay(10); // progress in playing...
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
	delay(10); // progress in stopped...
	assert(playTime.peek == 0.msecs);
}