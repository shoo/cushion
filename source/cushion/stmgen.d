module cushion.stmgen;

import std.array, std.format, std.string, std.algorithm;
import cushion.core;

/*******************************************************************************
 * Generator of STM
 */
package(cushion) struct StmGenerator
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
		srcstr.formattedWrite!(q{
			static import cushion.core;
			static import std.traits;
			static if (__traits(compiles, StateTransitor)
			        && std.traits.isInstanceOf!(cushion.core.StateTransitor, StateTransitor)
			        && !__traits(compiles, State)
			        && is(State == enum))
			{
				static assert([__traits(allMembers, StateTransitor.State)] == [
			%-(		"%s"%|,
			%)]);
				alias State = StateTransitor.State;
			}
			else static if (__traits(compiles, State) && is(State == enum))
			{
				static assert([__traits(allMembers, State)] == [
			%-(		"%s"%|,
			%)]);
			}
			else
			{
				enum State
				{
			%-(		%s,
			%)
				}
			}
		}.outdent)(states, states, states);
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
		srcstr.formattedWrite!(q{
			static import cushion.core;
			static import std.traits;
			static if (__traits(compiles, StateTransitor)
			        && std.traits.isInstanceOf!(cushion.core.StateTransitor, StateTransitor)
			        && !__traits(compiles, Event)
			        && is(Event == enum))
			{
				static assert([__traits(allMembers, StateTransitor.Event)] == [
			%-(		"%s"%|,
			%)]);
				alias Event = StateTransitor.Event;
			}
			else static if (__traits(compiles, Event) && is(Event == enum))
			{
				static assert([__traits(allMembers, Event)] == [
			%-(		"%s"%|,
			%)]);
			}
			else
			{
				enum Event
				{
			%-(		%s,
			%)
				}
			}
		}.outdent)(events, events, events);
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
		alias existsAct = reduce!"a | (b.length != 0)";
		string setActHandler;
		if (existsAct(false, stacts) || existsAct(false, edacts))
			setActHandler = "stm.setStateChangedHandler(&_onStEdActivity);";
		srcstr.formattedWrite!(q{
			auto %s() @safe
			{
				static import cushion.core;
				static import std.traits;
				static if (__traits(compiles, StateTransitor)
				        && std.traits.isInstanceOf!(cushion.core.StateTransitor, StateTransitor))
				{
					alias _ST = StateTransitor;
				}
				else static if (__traits(compiles, StateTransitor))
				{
					alias _ST = StateTransitor!(State, Event);
				}
				else
				{
					alias _ST = cushion.core.StateTransitor!(State, Event);
				}
				alias _ST.Cell C;
				auto stm = _ST([
					%([%-(%s, %)]%|,
					%)]);
				%s
				stm.matrixName = `%s`;
				stm.stateNames = %s;
				stm.eventNames = %s;
				return stm;
			}
		}.outdent)(factoryName, app.data, setActHandler, nameRaw, statesRaw, eventsRaw);
	}
	
}

