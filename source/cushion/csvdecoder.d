
/*******************************************************************************
 * Decoder for STM of CSV
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion.csvdecoder;

import std.csv, std.array, std.algorithm, std.range, std.format;
import cushion.core, cushion._internal.misc, cushion.stmgen;

/*******************************************************************************
 * Generator from STM of CSV
 */
StmGenerator generatorFromCsv(
	string stmCsvContents, string mapCsvContents, string mapFileName = null, string stmFileName = null,
	string stateKey = "▽", string factoryName = "makeStm")
{
	StmGenerator stmgen;
	string[][] mat;
	string[string] map;
	static struct MapLayout
	{
		string key;
		string val;
	}
	foreach (data; csvReader!string(stmCsvContents))
		mat ~= data.array;
	foreach (data; csvReader!MapLayout(mapCsvContents))
		map[data.key] = data.val;
	
	stmgen.stmFileName = stmFileName;
	stmgen.mapFileName = mapFileName;
	stmgen.stateKey    = stateKey;
	stmgen.map         = map;
	stmgen.nameRaw     = mat[0][0];
	stmgen.statesRaw   = mat[0][1..$];
	stmgen.stactsRaw   = mat[1][1..$];
	stmgen.edactsRaw   = mat[2][1..$];
	stmgen.eventsRaw.length = cast(size_t)(cast(int)mat.length-3);
	stmgen.cellsRaw.length = cast(size_t)(cast(int)mat.length-3);
	foreach (i, r; mat[3..$])
	{
		stmgen.eventsRaw[i] = r[0];
		stmgen.cellsRaw[i]  = r[1..$];
	}
	return stmgen;
}

/*******************************************************************************
 * Decode to D language code from STM of CSV
 * 
 * In the first argument, STM in CSV format is passed as a string.
 * And in the second argument, replacement map in CSV format is passed as a string.
 * This CSV pair will be decoded into the code in D language.
 * 
 * 
 * STM by CSV is converted according to the following rules.
 * 
 * $(UL
 *   $(LI The cell at most top-left is described name of the STM.)
 *   $(LI In the first row cells except the leftmost column, "$(B state)" names are described.)
 *   $(LI Cells of leftmost column in rows 2 and 3 are ignored in program code.)
 *   $(LI "$(B Event)" names are described on the leftmost 4th row and beyond.)
 *   $(LI The 1st line of CSV describes "$(B states)")
 *   $(LI "$(B States)" is always specified a string beginning with "∇" (default character) or `stateKey` that is user defined key character.)
 *   $(LI The 2nd line of CSV describes "$(B start activity)")
 *   $(LI The 3rd line of CSV describes "$(B end activity)")
 *   $(LI "$(B start activity)" and "$(B end activity)" are described by some "$(B processes)")
 *   $(LI When the "$(B state transitions)", the "$(B process)" described in the "$(B start activity)" of the "$(B states)" of after the transition are performed.)
 *   $(LI In the other hand, the "$(B processes)" in the "$(B end activity)" are performed at before the transition.)
 *   $(LI In cell where "$(B state)" and "$(B event)" intersect, "$(B processes)" are described)
 *   $(LI For state transition, specify the state name starting with `stateKey` in the first line of the "$(B processes)" described in the cell)
 *   $(LI A blank cell does not process the event and means to ignore it.)
 *   $(LI Cells written with only `x` assert forbidden event handling.)
 * )
 * 
 * The replacement map is described according to the following specifications.
 * 
 * $(UL
 *   $(LI The replacement target of the replacement map CSV is the "$(B state)", "$(B event)", "$(B state transition)", and "$(B process)" of the STM)
 *   $(LI The first column of CSV describes the string before conversion.)
 *   $(LI The second column of CSV describes the string after conversion.)
 *   $(LI The string in the left column is simply replaced by the string in the right column.)
 *   $(LI After substitution, "$(B process)" must be complete D language code.)
 *   $(LI "$(B event)" must be replaced to enum member of "$(B Event)".)
 *   $(LI "$(B state)" must be replaced to enum member of "$(B State)".)
 *   $(LI And also, "$(B state transition)" that are described together "$(B process)" must be replaced to enum member of "$(B State)".)
 * )
 * 
 * Since the string generated by this function is the source code of the D language, it can be embedded in the actual code after saving it in the file, or it can be used directly by mixin().
 * The "$(B states)" are generated as an enum type named `State`, and the "$(B events)" are generated as an enum type named `Event`.
 * STM instance is generated by executing the generated factory function that name can be specified by `factoryName` with makeStm as its default name.
 */
string decodeStmFromCsv(
	string stmCsvContents, string mapCsvContents, string mapFileName = null, string stmFileName = null,
	string stateKey = "▽", string factoryName = "makeStm")
{
	auto stmgen = generatorFromCsv(stmCsvContents, mapCsvContents, mapFileName, stmFileName, stateKey, factoryName);
	return stmgen.genCode();
}

/*******************************************************************************
 * Example is following.
 * 
 * This case explains how to operate the music player with the start button and the stop button.
 * The players play music when the start button is pressed while stopping.
 * And when you press the start button during playing, the behavior will change and music playback will pause.
 * When the stop button is pressed, the player stops music playback and returns to the initial state.
 * 
 * When this specification is made to STM, the following table can be created.
 * 
 * stmcsv:
 * $(TABLE
 *   $(TR $(TH *MusicPlayer* )$(TH #>stop                   )$(TH #>play                                          )$(TH #>pause                 ) )
 *   $(TR $(TH StartAct.     )$(TD                          )$(TD                                                 )$(TD                         ) )
 *   $(TR $(TH EndAct.       )$(TD                          )$(TD                                                 )$(TD                         ) )
 *   $(TR $(TH onStart       )$(TD #>play$(BR)- Start music )$(TD #>pause$(BR)- Stop music                        )$(TD #>play$(BR)- Start music) )
 *   $(TR $(TH onStop        )$(TD                          )$(TD  #>stop$(BR)- Stop music$(BR)- Return to first  )$(TD #>stop$(BR)- Return to first) )
 * )
 * 
 * In each cell of the table, the transition destination and processing are described in natural language.
 * Representations in natural language are replaced by the following map table and converted into a program expression in D.
 * One line in each cell is subject to replacement. However, those that do not exist in the replacement map are not replaced.
 * 
 * mapcsv:
 * $(TABLE
 *   $(TR $(TD #>stop            )$(TD stop           ) )
 *   $(TR $(TD #>play            )$(TD play           ) )
 *   $(TR $(TD #>pause           )$(TD pause          ) )
 *   $(TR $(TD - Start music     )$(TD startMusic();  ) )
 *   $(TR $(TD - Stop music      )$(TD stopMusic();   ) )
 *   $(TR $(TD - Return to first )$(TD resetMusic();  ) )
 * )
 * 
 * To execute the pair of STM and replacement map as code, see the following code:
 */
@safe unittest
{
	import std.string, std.datetime.stopwatch;
	// STM
	enum stmcsv = `
	*MusicPlayer*,#>stop,#>play,#>pause
	StartAct,,,
	EndAct,,,
	onStart,"#>play\n- Start music","#>pause\n- Stop music","#>play\n- Start music"
	onStop,,"#>stop\n- Stop music\n- Return to first","#>stop\n- Return to first"`
	.strip("\n").outdent.replace(`\n`,"\n");
	
	// replacement mapping data
	enum mapcsv = `
	#>stop,stop
	#>play,play
	#>pause,pause
	- Start music,startMusic();
	- Stop music,stopMusic();
	- Return to first,resetMusic();`
	.strip("\n").outdent.replace(`\n`,"\n");
	
	// Programs to be driven by STM
	string status = "stopped";
	StopWatch playTime;
	void startMusic() { playTime.start(); status = "playing"; }
	void stopMusic()  { playTime.stop();  status = "stopped"; }
	void resetMusic() { playTime.reset(); }
	
	// Generate code from STM(csv data) and mapping data
	enum stmcode = decodeStmFromCsv(stmcsv, mapcsv, null, null, "#>", "makeStm");
	// string mixin. Here the code is expanded.
	// The code contains the enum of State and Event,
	// activity functions and proccess when transtition.
	mixin(stmcode);
	
	// Create StateTransitor instance
	// By executing this function, construction of StateTransitor,
	// registration of various handlers, name setting of the matrix and states / events are performed.
	auto stm = makeStm();
	
	// Initial state is "stop" that most left state.
	assert(stm.currentState == State.stop);
	// At run time, display names of the state are gettable
	assert(stm.getStateName(stm.currentState) == "#>stop");
	// Likewise, event names are also gettable
	// In this case, event names are not replaced by mapcsv datas,
	// this code in following line gets the same string as the enum member of Event.
	assert(stm.getEventName(Event.onStart) == "onStart");
	
	// When the onStart event occurs, based on the STM,
	// it transit to the "#>play" state and play music.
	stm.put(Event.onStart);
	assert(stm.currentState == State.play);
	assert(playTime.running);
	() @trusted { import core.thread; Thread.sleep(10.msecs); }(); // progress in playing...
	assert(playTime.peek != 0.msecs);
	
	// If push the play button again during playing, it pauses.
	stm.put(Event.onStart);
	assert(stm.currentState == State.pause);
	assert(!playTime.running);
	
	// When you press the stop button, the player stops and returns to the first stop state
	stm.put(Event.onStop);
	assert(stm.currentState == State.stop);
	assert(!playTime.running);
	() @trusted { import core.thread; Thread.sleep(10.msecs); }(); // progress in stopped...
	assert(playTime.peek == 0.msecs);
}

/// Following example is case of network communication in Japanese.
@safe unittest
{
	import std.string;
	enum stmcsv = `
	,▽初期,▽接続中,▽通信中,▽切断中
	スタートアクティビティ,,接続要求を開始,,切断要求を開始
	エンドアクティビティ,,接続要求を停止,,切断要求を停止
	接続の開始指示を受けたら,▽接続中,,x,x
	接続の停止指示を受けたら,,▽切断中,▽切断中,
	通信が開始されたら,▽切断中,▽通信中,x,x
	通信が切断されたら,x,▽初期,▽初期,▽初期`
	.strip("\n").outdent.replace(`\n`,"\n");

	enum replaceData = `
	▽初期,init
	▽接続中,connectBeginning
	▽通信中,connecting
	▽切断中,connectClosing
	通信が開始されたら,openedConnection
	通信が切断されたら,closedConnection
	接続の開始指示を受けたら,openConnection
	接続の停止指示を受けたら,closeConnection
	接続要求を開始,startBeginConnect();
	接続要求を停止,endBeginConnect();
	切断要求を開始,startCloseConnect();
	切断要求を停止,endCloseConnect();`
	.strip("\n").outdent.replace(`\n`,"\n");

	enum stmcode = decodeStmFromCsv(stmcsv, replaceData);
	int x;
	void startBeginConnect()
	{
		x = 1;
	}
	void endBeginConnect()
	{
		x = 2;
	}
	void startCloseConnect()
	{
		x = 3;
	}
	void endCloseConnect()
	{
		x = 4;
	}
	
	mixin(stmcode);
	auto stm = makeStm();
	assert(stm.getStateName(State.init) == "▽初期");
	assert(stm.getStateName(stm.currentState) == "▽初期");
	assert(x == 0);
	stm.put(Event.openConnection);
	assert(x == 1);
	assert(stm.getStateName(stm.currentState) == "▽接続中");
	assert(stm.currentState == State.connectBeginning);
	stm.put(Event.openedConnection);
	assert(x == 2);
	assert(stm.getStateName(stm.currentState) == "▽通信中");
	assert(stm.currentState == State.connecting);
	stm.put(Event.closeConnection);
	assert(x == 3);
	assert(stm.getStateName(stm.currentState) == "▽切断中");
	assert(stm.currentState == State.connectClosing);
	stm.put(Event.closedConnection);
	assert(x == 4);
	assert(stm.getStateName(stm.currentState) == "▽初期");
	assert(stm.currentState == State.init);
}

// External State, Event
@safe unittest
{
	import std.string, std.datetime.stopwatch;
	// STM
	enum stmcsv = `
	*MusicPlayer*,#>stop,#>play,#>pause
	StartAct,,,
	EndAct,,,
	onStart,"#>play\n- Start music","#>pause\n- Stop music","#>play\n- Start music"
	onStop,,"#>stop\n- Stop music\n- Return to first","#>stop\n- Return to first"`
	.strip("\n").outdent.replace(`\n`,"\n");
	
	// replacement mapping data
	enum mapcsv = `
	#>stop,stop
	#>play,play
	#>pause,pause
	- Start music,startMusic();
	- Stop music,stopMusic();
	- Return to first,resetMusic();`
	.strip("\n").outdent.replace(`\n`,"\n");
	
	enum State
	{
		stop, play, pause
	}
	enum Event
	{
		onStart, onStop
	}
	// The code that has been generated mixin uses the name "StateTransitor".
	// This name must be defined separately from the one specified in the template parameter.
	alias StateTransitor = .StateTransitor!(State, Event);
	
	// Programs to be driven by STM
	string status = "stopped";
	StopWatch playTime;
	void startMusic() { playTime.start(); status = "playing"; }
	void stopMusic()  { playTime.stop();  status = "stopped"; }
	void resetMusic() { playTime.reset(); }
	
	// Generate code from STM(csv data) and mapping data
	// The generated code differs depending on whether the `StateTransitor`
	// specified in the template parameter is a template or
	// a full-specialized template instance.
	enum stmcode = decodeStmFromCsv(stmcsv, mapcsv, null, null, "#>", "makeStm");
	// string mixin. Here the code is expanded.
	// The code contains the enum of State and Event,
	// activity functions and proccess when transtition.
	mixin(stmcode);
	
	// Create StateTransitor instance
	// By executing this function, construction of StateTransitor,
	// registration of various handlers, name setting of the matrix and states / events are performed.
	auto stm = makeStm();
	
	// Initial state is "stop" that most left state.
	assert(stm.currentState == State.stop);
	// At run time, display names of the state are gettable
	assert(stm.getStateName(stm.currentState) == "#>stop");
	// Likewise, event names are also gettable
	// In this case, event names are not replaced by mapcsv datas,
	// this code in following line gets the same string as the enum member of Event.
	assert(stm.getEventName(Event.onStart) == "onStart");
	
	// When the onStart event occurs, based on the STM,
	// it transit to the "#>play" state and play music.
	stm.put(Event.onStart);
	assert(stm.currentState == State.play);
	assert(playTime.running);
	() @trusted { import core.thread; Thread.sleep(10.msecs); }(); // progress in playing...
	assert(playTime.peek != 0.msecs);
	
	// If push the play button again during playing, it pauses.
	stm.put(Event.onStart);
	assert(stm.currentState == State.pause);
	assert(!playTime.running);
	
	// When you press the stop button, the player stops and returns to the first stop state
	stm.put(Event.onStop);
	assert(stm.currentState == State.stop);
	assert(!playTime.running);
	() @trusted { import core.thread; Thread.sleep(10.msecs); }(); // progress in stopped...
	assert(playTime.peek == 0.msecs);
}

/*******************************************************************************
 * Load CSV file of STM and decode to D code.
 */
string loadStmFromCsvFilePair(string stmFileName, string mapFileName)(
	string stateKey = "▽", string factoryName = "makeStm")
{
	static if (__traits(compiles, import(mapFileName)))
	{
		return decodeStmFromCsv(import(stmFileName), import(mapFileName),
			stmFileName, mapFileName, stateKey, factoryName);
	}
	else
	{
		return decodeStmFromCsv(import(stmFileName), null,
			stmFileName, mapFileName, stateKey, factoryName);
	}
}

/// ditto
string loadStmFromCsv(string name)(
	string stateKey = "▽", string factoryName = "makeStm")
{
	return loadStmFromCsvFilePair!(name ~ ".stm.csv", name ~ ".map.csv")(stateKey, factoryName);
}


/*******************************************************************************
 * Load CSV file of STM and decode to D code.
 */
template CreateStmPolicy(
	string name_,
	alias ST = cushion.core.StateTransitor,
	string stateKey_ = "▽",
	string factoryName_ = "makeStm")
{
	enum string name        = name_;
	enum string stateKey    = stateKey_;
	enum string factoryName = factoryName_;
	alias StateTransitor    = ST;
}


/*******************************************************************************
 * Load CSV file of STM and decode to D code.
 */
auto createStm(string name, ALIASES...)()
{
	return createStm!(CreateStmPolicy!name, ALIASES)();
}

/// ditto
auto createStm(alias basePolicy, ALIASES...)()
	if (__traits(hasMember, basePolicy, "name"))
{
	alias policy = CreateStmPolicy!(
		basePolicy.name,
		getMemberAlias!(basePolicy, "StateTransitor", cushion.core.StateTransitor),
		getMemberValue!(basePolicy, "stateKey",       "▽"),
		getMemberValue!(basePolicy, "factoryName",    "makeStm"));
	
	static if (__traits(identifier, policy.StateTransitor) != "StateTransitor")
		mixin(`alias `~__traits(identifier, policy.StateTransitor)~` = policy.StateTransitor;`);
	alias StateTransitor = policy.StateTransitor;
	
	auto obj = new class
	{
		static foreach (ALIAS; ALIASES)
			mixin(`alias ` ~ __traits(identifier, ALIAS) ~ ` = ALIAS;`);
		pragma(msg, "Compiling STM " ~ policy.name ~ "...");
		mixin(loadStmFromCsv!(policy.name)(policy.stateKey, policy.factoryName));
	};
	return __traits(getMember, obj, policy.factoryName)();
}
