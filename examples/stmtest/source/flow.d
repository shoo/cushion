module flow;


import std.range, std.algorithm, std.array, std.format;
import cushion;


/***************************************************************
 * Interface defines the method of the state
 * 
 * This interface has an update method, that does anything
 * and returns the next state.
 */
interface TestFlow
{
	///
	TestFlow update() @safe;
}


/***************************************************************
 * Base class of state pattern
 * 
 * This class is a class that inherits from the TestFlow interface,
 * which is the base class for state patterns.
 * TestFlow has a primitive implementation by passing through State.
 * This provides an implementation for the `update` declared in
 * the interface to return the next state specified in `setNext`.
 * And some handlers [`onEnter`, `onExit`, `onEnterChild`, `onExitChild`]
 * are available.
 */
abstract class BaseTestFlow: State!TestFlow
{
	///
	abstract string name() const @property;
}

/***************************************************************
 * Concrete class of state pattern named `Child1Stm`
 * 
 * This class is a concrete class of state pattern.
 * The implementation of the behavior that should be done by
 * the `update` is complete, and STM is driven internally.
 */
class Child1Stm: BaseTestFlow
{
private:
	mixin(loadStmFromCsv!("flow-child1", StateTransitor)("#>"));
	Event[][] _stepData;
	Event[]   _step;
public:
	///
	StateTransitor!(State, Event) _stm;
	/// ditto
	alias _stm this;
	///
	this() @safe
	{
		_stm = makeStm();
		with (Event)
			_stepData = [[b],[b]];
	}
	///
	final void initialize() @safe
	{
		_step = _stepData.front;
		_stepData.popFront();
	}
	///
	override TestFlow update() @safe
	{
		if (emptyEvents)
		{
			_stm.put(_step.front);
			_step.popFront();
		}
		consume();
		return super.update();
	}
	///
	override string name() const @property
	{
		return _stm.matrixName;
	}
}

/***************************************************************
 * Concrete class of state pattern named `Child2Stm`
 * 
 * Implement a different state from `Child1Stm`
 */
class Child2Stm: BaseTestFlow
{
private:
	mixin(loadStmFromCsv!("flow-child2", StateTransitor)("#>"));
	Event[][] _stepData;
	Event[]   _step;
public:
	///
	StateTransitor!(State, Event) _stm;
	/// ditto
	alias _stm this;
	///
	this() @safe
	{
		_stm = makeStm();
		with (Event)
			_stepData = [[b],[a]];
	}
	///
	final void initialize() @safe
	{
		_step = _stepData.front;
		_stepData.popFront();
	}
	///
	override TestFlow update() @safe
	{
		if (emptyEvents)
		{
			_stm.put(_step.front);
			_step.popFront();
		}
		consume();
		return super.update();
	}
	///
	override string name() const @property
	{
		return _stm.matrixName;
	}
}

/***************************************************************
 * Concrete class of state pattern named `MainStm`
 * 
 * Implement a different state from `Child1Stm` / `Child2Stm`.
 * This class acts as a parent to `Child1Stm` and `Child2Stm`.
 * The `update` method of this class may return the child class
 * `Child1Stm` or `Child2Stm` as the next state.
 * This class is also "previous state", which backs when
 * `Child1Stm` or `Child2Stm` ends.
 * Also, in this class, there is a gimmick that can record the
 * transition of state using each handler and output the result.
 */
class MainStm: BaseTestFlow
{
private:
	Child1Stm _child1;
	Child2Stm _child2;
	
	mixin(loadStmFromCsv!("flow-main", StateTransitor)("#>"));
	Event[] _step;
public:
	///
	StateTransitor!(State, Event) _stm;
	/// ditto
	alias _stm this;
	///
	void delegate() onError;
	///
	Appender!string message;
	///
	this() @safe
	{
		_stm = makeStm();
		_child1 = new Child1Stm;
		_child2 = new Child2Stm;
		
		void setMsgEv(Stm, Ev)(Stm stm, Ev e)
		{
			message.formattedWrite(
				"[%s-%s]onEvent:%s(%s)\n",
				stm.name, stm.stateNames[stm.currentState], stm.eventNames[e], e);
		}
		void setMsgSt(Stm, St)(Stm stm, St oldSt, St newSt)
		{
			message.formattedWrite(
				"[%s-%s]onStateChanged:%s(%s)->%s(%s)\n",
				stm.name, stm.stateNames[stm.currentState], stm.stateNames[oldSt], oldSt, stm.stateNames[newSt], newSt);
		}
		void setMsgEntCh(StmP, StmC)(StmP p, StmC c)
		{
			message.formattedWrite("[%s-%s]onEnterChild:>>>%s\n", p.name, p.stateNames[p.currentState], c.name);
		}
		void setMsgExitCh(StmP, StmC)(StmP p, StmC c)
		{
			message.formattedWrite("[%s-%s]onExitChild:<<<%s\n", p.name, p.stateNames[p.currentState], c.name);
		}
		
		addEventHandler(          (Event e)                  { setMsgEv(this, e); } );
		addStateChangedHandler(   (State oldSt, State newSt) { setMsgSt(this, oldSt, newSt); } );
		onEnterChild           ~= (TestFlow child)           { setMsgEntCh(this, cast(BaseTestFlow)child); };
		onExitChild            ~= (TestFlow child)           { setMsgExitCh(this, cast(BaseTestFlow)child); };
		
		_child1.addEventHandler( (Child1Stm.Event e)        { setMsgEv(_child1, e); });
		_child1.addStateChangedHandler((Child1Stm.State oldSt, Child1Stm.State newSt) { setMsgSt(_child1, oldSt, newSt); });
		
		_child2.addEventHandler( (Child2Stm.Event e)        {setMsgEv(_child2, e); });
		_child2.addStateChangedHandler((Child2Stm.State oldSt, Child2Stm.State newSt) { setMsgSt(_child2, oldSt, newSt); });
		
		onError     = ()
		{
			put(_stm, Event.test);
			// end
			setNext(null);
		};
		_child1.onExit ~= () { _stm.put(Event.stm1exit); };
		_child2.onExit ~= ()
		{
			if (_child2.currentState == _child2.State.init)
			{
				_stm.put(Event.stm2exit);
			}
			else
			{
				_stm.put(Event.stm2err);
			}
		};
		
		initialize();
	}
	///
	final void initialize() @safe
	{
		with (Event)
			_step = [test, test];
	}
	///
	override TestFlow update() @safe
	{
		if (emptyEvents)
		{
			_stm.put(_step.front);
			_step.popFront();
		}
		consume();
		return super.update();
	}
	///
	override string name() const @property
	{
		return _stm.matrixName;
	}
	///
	override string toString() const @safe
	{
		return message.data;
	}
}

///
@safe unittest
{
	// Create a MainStm
	auto stm = new MainStm;
	
	// Create a context class of TestFlow
	auto stFlow = new Flow!TestFlow(stm);
	
	// Iterate until `stFlow.current` is null.
	// This process advances the state transition in `stFlow`.
	while (stFlow.current)
	{
		stFlow.update();
	}
	
	// Finally check the result
	assert(stm.toString() == import("flow-result.txt"));
}
