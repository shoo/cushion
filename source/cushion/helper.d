/*******************************************************************************
 * Helper programs
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion.helper;

import std.algorithm, std.array;
import cushion.csvdecoder;

/*******************************************************************************
 * Mapping information datas
 */
struct MapData
{
	/// Type of mapping pairs
	enum Type
	{
		/// Type of States
		state,
		/// Type of Events
		event,
		/// Type of Processes
		proc
	}
	/// ditto
	Type type;
	/// Key of mapping pairs
	string key;
	/// Value of mapping pairs
	string value;
}

/*******************************************************************************
 * Get map data information from CSV contents for STM
 * 
 * Params:
 *      stmCsvContents = Contents of CSV for STM
 *      csvStmFile     = Csv file for STM
 *      csvMapFile     = Csv file for mappings
 *      stateKey       = State keys used in STM
 *      oldMap         = Associative array of old mappings
 * Returns:
 *      Returns an array of MapData, sorted according to the order in which they are defined in STM.
 *      The order is defined by the order of states, events and processes.
 *      In addition, the processes are ordered by event.
 */
MapData[] getMapDataFromStmCsv(string stmCsvContents, string stateKey = "▽", in string[string] oldMap = null) @safe
{
	import std.algorithm: canFind, startsWith;
	import std.string: splitLines;
	
	MapData[] ret;
	auto stmgen = generatorFromCsv(stmCsvContents, null, null, null, stateKey);
	
	foreach (s; stmgen.statesRaw)
		ret ~= MapData(MapData.Type.state, s, oldMap.get(s, null));
	foreach (s; stmgen.eventsRaw)
		ret ~= MapData(MapData.Type.event, s, oldMap.get(s, null));
	
	void add(string s)
	{
		if (!ret.canFind!(a => a.key == s) && s != "x")
			ret ~= MapData(MapData.Type.proc, s, oldMap.get(s, null));
	}
	void addLines(string[] lines)
	{
		foreach (line; lines)
			add(line);
	}
	
	foreach (s; stmgen.stactsRaw)
		addLines(s.splitLines);
	foreach (s; stmgen.edactsRaw)
		addLines(s.splitLines);
	
	foreach (i, rows; stmgen.cellsRaw)
	{
		foreach (j, cell; rows)
		{
			auto lines = cell.splitLines;
			if (lines.length && lines[0].startsWith(stmgen.stateKey))
				lines = lines[1..$];
			addLines(lines);
		}
	}
	
	return ret;
}

///
@safe unittest
{
	import std.string: outdent, strip;
	auto mapKeys = getMapDataFromStmCsv(`
		,▽A,▽B,▽C
		st,sa,sb,sc
		ed,ea,eb,ec
		〇A,p1,p1,p2
		〇B,p3,x,p4
	`.outdent.strip).map!(a => a.key).array;
	assert(mapKeys == ["▽A","▽B","▽C","〇A","〇B","sa","sb","sc","ea","eb","ec","p1","p2","p3","p4"]);
}


/// ditto
MapData[] getMapDataFromStmCsvFile(string csvStmFile, string stateKey = "▽", string[string] oldMap = null)
{
	import std.file;
	return getMapDataFromStmCsv(cast(string)std.file.read(csvStmFile), stateKey, oldMap);
}

/// ditto
MapData[] getMapDataFromCsvFiles(string csvStmFile, string csvMapFile,
	string stateKey = "▽", string[string] oldMap = null)
{
	import std.file, std.csv;
	string[string] map;
	static struct MapLayout
	{
		string key;
		string val;
	}
	foreach (data; csvReader!MapLayout(cast(string)std.file.read(csvMapFile)))
		map[data.key] = data.val;
	return getMapDataFromStmCsv(cast(string)std.file.read(csvStmFile), stateKey, oldMap);
}


/*******************************************************************************
 * Update map data information from CSV contents for STM
 * 
 * Params:
 *      stmCsvContent = Contents of CSV for STM
 *      mapCsvContent = Contents of CSV for mapping datas
 *      stateKey       = State keys used in STM
 * Returns:
 *      Get the updated MapData. MapDatas keep a historical order for the state, events, and processing sections.
 *      The added map data is added at the end of each State, Event and Processing section.
 */
MapData[] updateMapData(string stmCsvContent, string mapCsvContent, string stateKey = "▽") @safe
{
	import std.csv, std.string;
	string[string] map;
	static struct MapLayout
	{
		string key;
		string val;
	}
	auto pairs = csvReader!MapLayout(mapCsvContent).array;
	foreach (data; pairs)
		map[data.key] = data.val;
	auto mapDatas = getMapDataFromStmCsv(stmCsvContent, stateKey, map);
	mapDatas.sort!((a, b)
		=> (a.type < b.type)
		|| (a.type == b.type
			? (cast(ulong)pairs.countUntil!(c => c.key == a.key) < cast(ulong)pairs.countUntil!(c => c.key == b.key))
			: false),
		SwapStrategy.stable)();
	return mapDatas;
}

///
@safe unittest
{
	import std.string: outdent, strip;
	auto mapKeys = updateMapData(`
		□状態遷移表,▽状態1,▽状態2
		StartAct.,,処理3
		EndAct.,処理4,
		〇イベント1,処理1,"処理1
		処理2"
		〇イベントA,x,処理5
		〇イベント2,処理2,
		〇イベント3,処理4,"処理3
		処理4"
	`.outdent.strip, `
		▽状態1,st1
		▽状態2,
		〇イベント1,ev1
		〇イベント2,ev2
		〇イベント3,
		処理1,
		処理2,
		処理3,
		処理4,proc4();
	`.outdent.strip).map!(a => [a.key, a.value]).array;
	assert(mapKeys == [
		["▽状態1", "st1"],["▽状態2", null],
		["〇イベント1", "ev1"],["〇イベント2", "ev2"],["〇イベント3", null],["〇イベントA", null],
		["処理1", null], ["処理2", null], ["処理3", null], ["処理4", "proc4();"], ["処理5", null]]);
}
