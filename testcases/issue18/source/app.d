import std;

void main()
{
	if ("test.map.csv".exists)
		std.file.remove("test.map.csv");
	std.file.copy("orig-test.map.csv", "test.map.csv");
	enforce(spawnProcess(["dub", "run", ":update_map", "--root=../..", "--", "test"]).wait == 0);
	auto csv = cast(string)std.file.read("test.map.csv");
	enforce(csv.strip.splitLines == `
		▽状態1,
		▽状態2,
		〇イベント1,ev1
		〇イベント2,ev2
		〇イベント3,
		〇イベントA,
		処理1,
		処理2,
		処理3,
		処理4,proc4();
		処理5,
	`.outdent.strip.splitLines);
}
