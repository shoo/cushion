/*******************************************************************************
 * Helper programs
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion.helper;

import cushion.csvdecoder;

/*******************************************************************************
 * 
 */
string[] getMapKeysFromStmCsv(string stmCsvContents, string stateKey = "▽") @trusted
{
	import std.algorithm: canFind, startsWith;
	import std.string: splitLines;
	
	string[] ret;
	auto stmgen = generatorFromCsv(stmCsvContents, null, null, null, stateKey);
	
	foreach (s; stmgen.statesRaw)
		ret ~= s;
	foreach (s; stmgen.eventsRaw)
		ret ~= s;
	
	void add(string s)
	{
		if (!canFind(ret, s))
			ret ~= s;
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

@safe unittest
{
	import std.string: outdent, strip;
	auto mapKeys = getMapKeysFromStmCsv(`
		,▽A,▽B,▽C
		st,sa,sb,sc
		ed,ea,eb,ec
		〇A,p1,p1,p2
		〇B,p2,p3,p4
	`.outdent.strip);
	assert(mapKeys == ["▽A","▽B","▽C","〇A","〇B","sa","sb","sc","ea","eb","ec","p1","p2","p3","p4"]);
}


/*******************************************************************************
 * 
 */
string[2][] getMapFromStmCsv(string csvContents, string stateKey = "▽", in string[string] oldMap = null)
{
	string[2][] ret;
	auto keys = getMapKeysFromStmCsv(csvContents, stateKey);
	foreach (k; keys)
		ret ~= [k, oldMap.get(k, null)];
	return ret;
}
/// ditto
string[2][] getMapFromStmCsvFile(string csvFile, string stateKey = "▽", string[string] oldMap = null)
{
	import std.file;
	return getMapFromStmCsv(cast(string)std.file.read(csvFile), stateKey, oldMap);
}



/*******************************************************************************
 * 
 */
void updateMapFile(string stmCsvFile, string mapCsvFile, string stateKey = "▽")
{
	import std.file, std.csv;
	string[string] map;
	static struct MapLayout
	{
		string key;
		string val;
	}
	MapLayout[] pairs;
	if (mapCsvFile.exists)
	{
		auto oldMapCsvContents = cast(string)std.file.read(mapCsvFile);
		auto pairs = csvReader!MapLayout(oldMapCsvContents).array;
		foreach (data; pairs)
			map[data.key] = data.val;
	}
	auto keymap = getMapFromStmCsv(cast(string)std.file.read(stmCsvFile), stateKey, map);
	string escapeCSV(string txt)
	{
		import std.string, std.array;
		if (txt.indexOfAny(",\"\r\n") != -1)
			return `"` ~ txt.replace("\"", "\"\"") ~ `"`;
		return txt;
	}
	string toCSV(string[2][] mat)
	{
		import std.algorithm, std.format;
		return format!"%-(%-(%-s,%)\n%)"(
			mat.map!(row => row[].map!escapeCSV));
	}
	std.file.write(mapCsvFile, toCSV(keymap));
}
