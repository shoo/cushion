module cushion.stmgen;

import std.array, std.format, std.string, std.algorithm;
import cushion.core;

/*******************************************************************************
 * Generator of STM
 */
package(cushion) struct StmGenerator(alias ST = StateTransitor)
{
	///
	string         stmFileName;
	///
	string         mapFileName;
	
	///
	string[string] map;
	
	///
	string         nameRaw;
	///
	string[]       statesRaw;
	///
	string[]       eventsRaw;
	///
	string[][]     cellsRaw;
	///
	string[]       stactsRaw;
	///
	string[]       edactsRaw;
	
	///
	string[]       states;
	///
	string[]       events;
	///
	string[][][]   procs;
	///
	string[][]     nextsts;
	///
	string[][]     stacts;
	///
	string[][]     edacts;
	
	///
	string         stateKey = "▽";
	///
	string         factoryName = "makeStm";
	
	
	/***************************************************************************
	 * 
	 */
	string genCode()
	{
		auto srcstr = appender!string();
		makeEnumStates(srcstr);
		makeEnumEvents(srcstr);
		makeActivities(srcstr);
		makeProcs(srcstr);
		makeFactory(srcstr);
		return srcstr.data();
	}
private:
	// 状態の書き出し。 State という名前の enum を書き出す
	void makeEnumStates(Range)(ref Range srcstr)
	{
		auto app = appender!(string[])();
		foreach (s; statesRaw)
		{
			auto str = map.get(s, s);
			if (str.length)
				app.put( str );
		}
		
		states = app.data;
		
		srcstr.put("enum State\n{\n");
		srcstr.formattedWrite("%-(\t%s,\n%)", states);
		srcstr.put("\n}\n");
	}
	
	// イベントの書き出し。 Event という名前の enum を書き出す。
	void makeEnumEvents(Range)(ref Range srcstr)
	{
		auto app = appender!(string[])();
		foreach (s; eventsRaw)
		{
			auto str = map.get(s, s);
			if (str.length)
				app.put( str );
		}
		
		events = app.data;
		
		srcstr.put("enum Event\n{\n");
		srcstr.formattedWrite("%-(\t%s,\n%)", events);
		srcstr.put("\n}\n");
	}
	
	static void replaceProcContents(Range)(ref Range srcstr, ref string[] procs, string[string] map)
	{
		auto app = appender!(string[])();
		foreach (s; procs)
		{
			auto str = map.get(s, s);
			if (str.length)
				app.put( str );
		}
		procs = app.data;
	}
	
	// 
	void makeProcs(Range)(ref Range srcstr)
	{
		procs   = new string[][][](events.length, states.length, 0);
		nextsts = new string[][](events.length, states.length);
		foreach (i, rows; cellsRaw)
		{
			foreach (j, cell; rows)
			{
				auto lines = cell.splitLines();
				string nextState;
				string[] proclines;
				if (lines.length && lines[0].startsWith(stateKey))
				{
					nextState = map.get(lines[0], lines[0]);
					assert(nextState.length);
					proclines = lines[1..$];
				}
				else
				{
					nextState = states[j];
					proclines = lines;
				}
				
				replaceProcContents(srcstr, proclines, map);
				procs[i][j] = proclines;
				nextsts[i][j] = nextState;
				if (proclines.length == 0 || proclines[0] == "x")
				{
					continue;
				}
				srcstr.formattedWrite("void _stmProcE%dS%d()\n{\n", i, j);
				srcstr.formattedWrite("%-(\t%s\n%)", proclines);
				srcstr.put("\n}\n");
			}
		}
	}
	
	// アクティビティ用の関数を作成する _stmStEdActivity という関数名で作成
	void makeActivities(Range)(ref Range srcstr)
	{
		auto apped = appender!string();
		auto appst = appender!string();
		
		stacts.length = stactsRaw.length;
		edacts.length = edactsRaw.length;
		
		appst.put("\tswitch (newsts)\n\t{\n");
		foreach (i, act; stactsRaw)
		{
			auto proclines = act.splitLines();
			if (proclines.length == 0)
				continue;
			auto name = format("_stmStartActS%d", i);
			srcstr.put("void ");
			srcstr.put(name);
			srcstr.put("()\n{\n");
			replaceProcContents(srcstr, proclines, map);
			srcstr.formattedWrite("%-(\t%s\n%)", proclines);
			srcstr.put("\n}\n");
			appst.formattedWrite(
				"\tcase cast(typeof(newsts))%d:\n"
				 ~ "\t\t%s();\n"
				 ~ "\t\tbreak;\n", i, name);
			stacts[i] = proclines;
		}
		appst.put(
			"\tdefault:\n"
			 ~ "\t}\n");
		
		apped.put("\tswitch (oldsts)\n\t{\n");
		foreach (i, act; edactsRaw)
		{
			auto proclines = act.splitLines();
			if (proclines.length == 0)
				continue;
			auto name = format("_stmEndActS%d", i);
			srcstr.put("void ");
			srcstr.put(name);
			srcstr.put("()\n{\n");
			replaceProcContents(srcstr, proclines, map);
			srcstr.formattedWrite("%-(\t%s\n%)", proclines);
			srcstr.put("\n}\n");
			apped.formattedWrite(
				"\tcase cast(typeof(oldsts))%d:\n"
				 ~ "\t\t%s();\n"
				 ~ "\t\tbreak;\n", i, name);
			edacts[i] = proclines;
		}
		apped.put(
			"\tdefault:\n"
			 ~ "\t}\n");
		if (appst.data.length != 0 || apped.data.length != 0)
		{
			srcstr.put(
				"void _onStEdActivity(State oldsts, State newsts)\n"
				 ~ "{\n"
				 ~ "\tif (oldsts == newsts)\n"
				 ~ "\t\treturn;\n");
			srcstr.put( apped.data );
			srcstr.put( appst.data );
			srcstr.put("}\n");
		}
	}
	
	
	// 
	void makeFactory(Range)(ref Range srcstr)
	{
		auto app = appender!(string[][])();
		auto app2 = appender!(string[])();
		
		foreach (i; 0..events.length)
		{
			app2.shrinkTo(0);
			foreach (j; 0..states.length)
			{
				string proc;
				if (procs[i][j].length == 0)
				{
					proc = "ignoreHandler";
				}
				else if (procs[i][j].length == 1 && procs[i][j][0] == "x")
				{
					proc = "forbiddenHandler";
				}
				else
				{
					proc = format("&_stmProcE%dS%d", i, j);
				}
				app2.put(format("C(State.%s, %s)", nextsts[i][j], proc));
			}
			app.put(app2.data.dup);
		}
		srcstr.formattedWrite(
			"auto " ~ factoryName ~ "()\n"
			 ~ "{\n"
			 ~ "\timport cushion.core;\n"
			 ~ "\talias "~ __traits(identifier, ST) ~"!(State, Event).Cell C;\n"
			 ~ "\tauto stm = "~ __traits(identifier, ST) ~"!(State, Event)([\n"
			 ~ "\t\t%([%-(%s, %)]%|, \n\t\t%)]);\n", app.data);
		alias existsAct = reduce!"a | (b.length != 0)";
		if (existsAct(false, stacts) || existsAct(false, edacts))
		{
			srcstr.put("\tstm.setStateChangedHandler(&_onStEdActivity);\n");
		}
		srcstr.formattedWrite(
			"\tstm.matrixName = `%s`;\n", nameRaw);
		srcstr.formattedWrite(
			"\tstm.stateNames = %s;\n", statesRaw);
		srcstr.formattedWrite(
			"\tstm.eventNames = %s;\n", eventsRaw);
		srcstr.put(
			"\treturn stm;\n"
			 ~ "}\n");
	}
	
}

