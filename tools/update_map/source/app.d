/*******************************************************************************
 * Tools for updating map files
 */
module app;

import std.array, std.algorithm, std.file, std.format, std.string;
import cushion.helper;


/*******************************************************************************
 * Function to update the file by updateMapData
 */
void updateMapFile(string csvStmFile, string csvMapFile, string stateKey = "▽")
{
	auto csvStmFileContents = csvStmFile.exists ? cast(string)std.file.read(csvStmFile) : null;
	auto csvMapFileContents = csvMapFile.exists ? cast(string)std.file.read(csvMapFile) : null;
	auto mapDatas = updateMapData(csvStmFileContents, csvMapFileContents, stateKey);
	string escapeCSV(string txt)
	{
		if (txt.indexOfAny(",\"\r\n") != -1)
			return `"` ~ txt.replace("\"", "\"\"") ~ `"`;
		return txt;
	}
	string toCSV(MapData[] mat)
	{
		return format!"%-(%-(%-s,%)\n%)"(
			mat.map!(row => [row.key, row.value].map!escapeCSV));
	}
	std.file.write(csvMapFile, toCSV(mapDatas));
}

/*******************************************************************************
 * Application to create/update the mapping file("*.map.csv")
 * 
 * ```
 * update_map <name>
 * ```
 * 
 * | option | description |
 * |:-------|:------------|
 * | name   | Name of STM | 
 * 
 * Params:
 *      args = Name of STM
 */
int main(string[] args)
{
	if (args.length != 2)
		return -1;
	
	updateMapFile(args[1] ~ ".stm.csv", args[1] ~ ".map.csv");
	
	return 0;
}
