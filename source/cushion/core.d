/*******************************************************************************
 * Core module for state transion
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion.core;


import std.traits, std.range, std.meta, std.container;
import cushion.handler;


private template isStraight(int start, Em...)
{
	static if (Em.length == 1)
	{
		enum isStraight = Em[0] == start;
	}
	else
	{
		enum isStraight = Em[0] == start && isStraight!(start+1, Em[1..$]);
	}
}


private template isStraightEnum(E)
	if (is(E == enum))
{
	enum isStraightEnum = isStraight!(EnumMembers!(E)[0], EnumMembers!E);
}



/*******************************************************************************
 * Judge StateTransitor's Event
 */
template isEvent(Event)
{
	enum bool isEvent = isStraightEnum!Event;
}

/*******************************************************************************
 * Judge StateTransitor's State
 */
template isState(State)
{
	enum bool isState = isStraightEnum!State;
}

/*******************************************************************************
 * Judge StateTransitor's ProcHandler
 */
template isProcessHandler(Handler)
{
	static if (isHandler!Handler
	        && is(HandlerReturnType!Handler == void)
	        && is(HandlerParameters!Handler == AliasSeq!()))
	{
		enum bool isProcessHandler = true;
	}
	else
	{
		enum bool isProcessHandler = false;
	}
}

/*******************************************************************************
 * Judge StateTransitor's ExceptionHandler
 */
template isExceptionHandler(Handler)
{
	static if (isHandler!Handler
	        && is(HandlerReturnType!Handler == void)
	        && ( is(HandlerParameters!Handler == AliasSeq!(Exception))
	          || is(HandlerParameters!Handler == AliasSeq!(Throwable))))
	{
		enum bool isExceptionHandler = true;
	}
	else
	{
		enum bool isExceptionHandler = false;
	}
}

///
@safe unittest
{
	static assert(isExceptionHandler!(void delegate(Exception)@safe[]));
}


/*******************************************************************************
 * Judge StateTransitor's EventHandler
 */
template isEventHandler(Handler, Event)
{
	static if (isHandler!Handler
	        && is(HandlerReturnType!Handler == void)
	        && is(HandlerParameters!Handler == AliasSeq!(Event)))
	{
		enum bool isEventHandler = true;
	}
	else
	{
		enum bool isEventHandler = false;
	}
}


/*******************************************************************************
 * Judge StateTransitor's EventHandler
 */
template isStateChangedHandler(Handler, State)
{
	static if (isHandler!Handler
	        && is(HandlerReturnType!Handler == void)
	        && is(HandlerParameters!Handler == AliasSeq!(State, State)))
	{
		enum bool isStateChangedHandler = true;
	}
	else
	{
		enum bool isStateChangedHandler = false;
	}
}

///
@safe unittest
{
	enum State {a, b, c}
	static assert(isStateChangedHandler!(void delegate(State,State), State));
}




private void insertBack(E)(ref SList!E list, E e)
{
	list.insertAfter(list[], e);
}

private void insertBack(E)(ref E[] ary, E e)
{
	ary ~= e;
}
private void insert(E)(ref E[] ary, E e)
{
	ary ~= e;
}
private void removeFront(E)(ref E[] ary)
{
	ary = ary[1..$];
}

private void removeFront(E)(ref Array!E ary)
{
	ary.moveAt(0);
	ary.removeBack();
}

/*******************************************************************************
 * Judge StateTransitor's EventContainer
 */
template isEventContainer(Container)
{
	static if (__traits(compiles, {
		import std.array;
		Container list = void;
		auto e = list.front;
		list.insertBack(e);
		list.insert(e);
		list.removeFront();
		if (list.empty) {}
	}))
	{
		enum bool isEventContainer = true;
	}
	else
	{
		enum bool isEventContainer = false;
	}
}

///
@system unittest
{
	enum E {a, b, c}
	static assert(isEventContainer!(E[]));
	static assert(isEventContainer!(SList!E));
	static assert(isEventContainer!(DList!E));
	static assert(isEventContainer!(Array!E));
}



private class EventCancelException: Exception
{
	this() { super(null, null, 0); }
}

/*******************************************************************************
 * 
 */
void cancelEvent()
{
	throw new EventCancelException;
}


private class ForbiddenException: EventCancelException
{
}

/***************************************************************************
 * Get a default forbidden handler
 */
void delegate() forbiddenHandler() @safe
{
	static struct Dummy
	{
		void forbidden()
		{
			throw new ForbiddenException;
		}
	}
	static Dummy dummy;
	return &dummy.forbidden;
}

/***************************************************************************
 * Get a default ignore handler
 */
void delegate() ignoreHandler() @safe
{
	return null;
}

/***************************************************************************
 * Consume mode
 */
enum ConsumeMode
{
	
	/***************************************************************************
	 * Events are consumed at the same time as addition.
	 * 
	 * Add an event with the put method, since the put method consumes events on
	 * the fly, we automatically call the consume method.
	 */
	combined,
	
	/***************************************************************************
	 * Events are consumed at separate timing from the of addition
	 * 
	 * Need to add an event with the put method and call the consume method for
	 * consumption.
	 */
	separate
}

/*******************************************************************************
 * StateTransitor
 */
struct StateTransitor(
	StateType, EventType, StateType defaultStateParameter = StateType.init,
	ProcHandler         = void delegate()[],
	ExceptionHandler    = void delegate(Exception)[],
	EventHandler        = void delegate(EventType)[],
	StateChangedHandler = void delegate(StateType newSts, StateType oldSts)[],
	ConsumeMode consumeMode = ConsumeMode.combined,
	EventContainer = SList!EventType)
{
	static assert(isState!StateType);
	static assert(isEvent!EventType);
	static assert(isProcessHandler!ProcHandler);
	static assert(isExceptionHandler!ExceptionHandler);
	static assert(isEventHandler!(EventHandler, EventType));
	static assert(isStateChangedHandler!(StateChangedHandler, StateType));
	
	/***************************************************************************
	 * State type of this StateTransitor
	 */
	alias State = StateType;
	
	/***************************************************************************
	 * State type of this StateTransitor
	 */
	alias Event = EventType;
	
	/***************************************************************************
	 * Count of kind of state in this StateTransitor
	 */
	enum size_t stateCount = EnumMembers!(State).length;
	
	/***************************************************************************
	 * Count of kind of event in this StateTransitor(Not a count of unconsumed event)
	 */
	enum size_t eventCount = EnumMembers!(Event).length;
	
	/***************************************************************************
	 * Default state of this StateTransitor
	 */
	enum State defaultState = defaultStateParameter;
	
	/***************************************************************************
	 * Cell of table
	 */
	static struct Cell
	{
		/// next state
		State       nextState = defaultState;
		/// handler
		ProcHandler handler;
		/// Constructor
		pragma(inline) this(State s, ProcHandler h)
		{
			nextState = s;
			handler   = h;
		}
		/// ditto
		pragma(inline) this(Func)(State s, Func h)
			if (isHandlerAddable!(ProcHandler, Func))
		{
			nextState = s;
			cushion.handler.set(handler, h);
		}
	}
private:
	Cell[stateCount][eventCount] _table;
	State                        _currentState = defaultState;
	string                       _matrixName;
	string[stateCount]           _stateNames;
	string[eventCount]           _eventNames;
	ExceptionHandler             _exceptionHandler;
	EventHandler                 _eventHandler;
	StateChangedHandler          _stateChangedHandler;
	EventContainer               _events;
	
public:
	
	/***************************************************************************
	 * Constractor
	 */
	pragma(inline) this(Cell[stateCount][eventCount] tbl)
	{
		initialize(tbl);
	}
	
	/***************************************************************************
	 * Initialize of table
	 */
	pragma(inline) void initialize(Cell[stateCount][eventCount] tbl)
	{
		import std.algorithm;
		move(tbl, _table);
		cushion.handler.clear(_exceptionHandler);
		cushion.handler.clear(_stateChangedHandler);
		cushion.handler.clear(_eventHandler);
		_events.clear();
	}
	
	/***************************************************************************
	 * Get/Set matrix name
	 */
	void matrixName(string str) @safe @nogc nothrow pure @property
	{
		_matrixName = str;
	}
	
	/// ditto
	string matrixName() @safe @nogc nothrow pure const @property
	{
		return _matrixName;
	}
	
	/***************************************************************************
	 * Set/Get event names
	 */
	void setEventName(Event ev, string evname) @safe @nogc nothrow pure
	{
		assert(ev < _eventNames.length);
		_eventNames[ev] = evname;
	}
	
	/// ditto
	string getEventName(Event ev) @safe @nogc pure const
	{
		assert(ev < _eventNames.length);
		return _eventNames[ev];
	}
	
	/// ditto
	void eventNames(in string[eventCount] names) @safe @nogc nothrow pure @property
	{
		_eventNames[] = names[];
	}
	
	/// ditto
	const(string)[] eventNames() @safe @nogc nothrow pure const @property
	{
		return _eventNames;
	}
	
	
	/***************************************************************************
	 * Set/Get state names
	 */
	void setStateName(State st, string stname) @safe @nogc nothrow pure
	{
		assert(st < _stateNames.length);
		_stateNames[st] = stname;
	}
	
	/// ditto
	string getStateName(State st) @safe @nogc pure const
	{
		assert(st < _stateNames.length);
		return _stateNames[st];
	}
	
	/// ditto
	void stateNames(in string[stateCount] names) @safe @nogc nothrow pure @property
	{
		_stateNames[] = names[];
	}
	
	/// ditto
	const(string)[] stateNames() @safe nothrow pure const @property
	{
		return _stateNames;
	}
	
	
	/***************************************************************************
	 * Check current state
	 */
	State currentState() @safe @nogc nothrow pure const @property
	{
		return _currentState;
	}
	
	
	/***************************************************************************
	 * Change current state enforcely
	 */
	void enforceState(State sts) @system @nogc nothrow pure
	{
		_currentState = sts;
	}
	
	
	/***************************************************************************
	 * Set next state
	 * 
	 * If the state is `s` and event `e` is consumed, the next state will be `nextState`
	 */
	void setNextState(State s, Event e, State nextState)
	{
		_table[s][e].nextState = nextState;
	}
	
	/***************************************************************************
	 * Set handler
	 * 
	 * If the state is `s` and event `e` is consumed, the `handler` will be called.
	 * If other handler has already been set, the other handler is no longer used and replaced by `handler` instead.
	 */
	void setHandler(Func)(State s, Event e, Func handler)
		if (isHandlerAssignable!(ProcHandler, Func))
	{
		cushion.handler.set(_table[s][e].handler, handler);
	}
	
	/***************************************************************************
	 * Add handler
	 * 
	 * If the state is `s` and event `e` is consumed, the `handler` will be called.
	 * If other handler has already been set, `handler` will be added to the other handler and executed.
	 */
	void addHandler(Func)(State s, Event e, Func handler)
		if (isHandlerAddable!(ProcHandler, Func))
	{
		cushion.handler.add(_table[s][e].handler, handler);
	}
	
	
	/***************************************************************************
	 * Remove handler related `s` and `e`.
	 */
	void removeHandler(Func)(State s, Event e, Func handler)
		if (isHandlerAddable!(ProcHandler, Func))
	{
		cushion.handler.remove(_table[s][e].handler, handler);
	}
	
	/***************************************************************************
	 * Remove all handler related `s` and `e`.
	 */
	void clearHandler(State s, Event e)
	{
		cushion.handler.clear(_table[s][e].handler);
	}
	
	
	/***************************************************************************
	 * Set exception handler
	 * 
	 * If other handler has already been set, the other handler is no longer used and replaced by `handler` instead.
	 */
	void setExceptionHandler(Func)(Func handler)
		if (isHandlerAssignable!(ExceptionHandler, Func))
	{
		cushion.handler.set(_exceptionHandler, handler);
	}
	
	/***************************************************************************
	 * Add exception handler
	 * 
	 * If other handler has already been set, `handler` will be added to the other handler and executed.
	 */
	void addExceptionHandler(Func)(Func handler)
		if (isHandlerAddable!(ExceptionHandler, Func))
	{
		cushion.handler.add(_exceptionHandler, handler);
	}
	
	/***************************************************************************
	 * Remove exception handler.
	 */
	void removeExceptionHandler(Func)(Func handler)
		if (isHandlerAddable!(ExceptionHandler, Func))
	{
		cushion.handler.remove(_exceptionHandler, handler);
	}
	
	/***************************************************************************
	 * Remove all exception handler.
	 */
	void clearExceptionHandler()
	{
		cushion.handler.clear(_exceptionHandler);
	}
	
	
	/***********************************************************************
	 * Set event handler
	 * 
	 * If other handler has already been set, the other handler is no longer used and replaced by `handler` instead.
	 */
	void setEventHandler(Func)(Func handler)
		if (isHandlerAssignable!(EventHandler, Func))
	{
		cushion.handler.set(_eventHandler, handler);
	}
	
	/***********************************************************************
	 * Add event handler
	 * 
	 * If other handler has already been set, `handler` will be added to the other handler and executed.
	 */
	void addEventHandler(Func)(Func handler)
		if (isHandlerAddable!(EventHandler, Func))
	{
		cushion.handler.add(_eventHandler, handler);
	}
	
	/***********************************************************************
	 * Remove event handler.
	 */
	void removeEventHandler(Func)(Func handler)
		if (isHandlerAddable!(EventHandler, Func))
	{
		cushion.handler.remove(_eventHandler, handler);
	}
	
	/***********************************************************************
	 * Remove all event handler.
	 */
	void clearEventHandler()
	{
		cushion.handler.clear(_eventHandler);
	}
	
	
	/***************************************************************************
	 * Set state changed handler
	 * 
	 * If other handler has already been set, the other handler is no longer used and replaced by `handler` instead.
	 */
	void setStateChangedHandler(Func)(Func handler)
		if (isHandlerAssignable!(StateChangedHandler, Func))
	{
		cushion.handler.set(_stateChangedHandler, handler);
	}
	
	/***************************************************************************
	 * Add state changed handler
	 * 
	 * If other handler has already been set, `handler` will be added to the other handler and executed.
	 */
	void addStateChangedHandler(Func)(Func handler)
		if (isHandlerAddable!(StateChangedHandler, Func))
	{
		cushion.handler.add(_stateChangedHandler, handler);
	}
	
	/***************************************************************************
	 * Remove state changed handler.
	 */
	void removeStateChangedHandler(Func)(Func handler)
		if (isHandlerAddable!(StateChangedHandler, Func))
	{
		cushion.handler.remove(_stateChangedHandler, handler);
	}
	
	/***********************************************************************
	 * Remove all state changed handler.
	 */
	void clearStateChangedHandler()
	{
		cushion.handler.clear(_stateChangedHandler);
	}
	
	/***************************************************************************
	 * Add a event
	 */
	void put(Event e) @safe
	{
		if (!_events.empty)
		{
			_events.insertBack(e);
			return;
		}
		else
		{
			_events.insert(e);
		}
		while (consumeMode == ConsumeMode.combined && !_events.empty)
			consume();
	}
	
	/***************************************************************************
	 * Consume a event
	 */
	void consume() @safe
	{
		if (_events.empty)
			return;
		try
		{
			auto ev = _events.front;
			bool cancel;
			try
			{
				cushion.handler.call(_eventHandler, ev);
				cushion.handler.call(_table[ev][_currentState].handler);
			}
			catch (EventCancelException e)
			{
				cancel = true;
			}
			if (!cancel)
			{
				auto oldstate = _currentState;
				_currentState = _table[ev][_currentState].nextState;
				cushion.handler.call(_stateChangedHandler, oldstate, _currentState);
			}
		}
		catch (HandlerParameters!ExceptionHandler[0] e)
		{
			cushion.handler.call(_exceptionHandler, e);
		}
		// _eventsが空でなければ、必ずremoveFrontできなければならない。
		// できないならば、それはおかしい。
		() @trusted
		{
			assert(!_events.empty);
			try
			{
				_events.removeFront();
			}
			catch (Throwable e)
			{
				assert(0);
			}
		}();
	}
	
	/***************************************************************************
	 * Check for unconsumed events
	 */
	bool emptyEvents() const @property
	{
		return _events.empty;
	}
}

///
@safe unittest
{
	enum State { a, b }
	enum Event { e1, e2, e3 }
	
	alias Stm = StateTransitor!(State, Event);
	
	alias C = Stm.Cell;
	string msg;
	// 状態遷移表
	auto sm = Stm([
		// イベント  状態A                           状態B
		/* e1:   */ [C(State.b, {msg = "a-1";}), C(State.b, forbiddenHandler)],
		/* e2:   */ [C(State.a, ignoreHandler),  C(State.a, {msg = "b-2";})],
		/* e3:   */ [C(State.a, {msg = "a-3";}), C(State.a, forbiddenHandler)]
	]);
	static assert(isOutputRange!(typeof(sm), Event));
	
	assert(sm.currentState == State.a);
	std.range.put(sm, Event.e1);
	assert(sm.currentState == State.b);
	assert(msg == "a-1");
	sm.put(Event.e2);
	assert(sm.currentState == State.a);
	assert(msg == "b-2");
	sm.put(Event.e3);
	assert(sm.currentState == State.a);
	assert(msg == "a-3");
	sm.put(Event.e2);
	assert(sm.currentState == State.a);
	assert(msg == "a-3");
	sm.put(Event.e1);
	assert(sm.currentState == State.b);
	assert(msg == "a-1");
}


@safe unittest
{
	enum S { sa, sb }
	enum E { ea, eb, ec }
	StateTransitor!(S, E) st;
	int x;
	void inc() { x++; }
	void inc2() { x++;x++; }
	void dec() { x++; }
	void ex(Exception e) {}
	void ex2(Exception e) {}
	void ev(E e) {}
	void ev2(E e) {}
	void sch(S a, S b) {}
	void sch2(S a, S b) {}
	st.setHandler(S.sa, E.ea, &inc);
	st.addHandler(S.sa, E.ea, &inc2);
	st.addHandler(S.sa, E.eb, &dec);
	st.setNextState(S.sa, E.eb, S.sb);
	st.removeHandler(S.sa, E.ea, &inc);
	st.clearHandler(S.sa, E.ea);
	
	st.setExceptionHandler(&ex);
	st.addExceptionHandler(&ex2);
	st.removeExceptionHandler(&ex);
	st.clearExceptionHandler();
	
	st.setEventHandler(&ev);
	st.addEventHandler(&ev2);
	st.removeEventHandler(&ev);
	st.clearEventHandler();
	
	st.setStateChangedHandler(&sch);
	st.addStateChangedHandler(&sch2);
	st.removeStateChangedHandler(&sch);
	st.clearStateChangedHandler();
}
