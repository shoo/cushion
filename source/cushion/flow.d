/*******************************************************************************
 * Flow module for state transion
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion.flow;

import cushion.handler, cushion._internal.misc;

private interface FlowHandler(Commands)
{
protected:
	///
	void _onEnterChild(Commands child) @safe;
	///
	void _onExitChild(Commands child) @safe;
	///
	void _onEnter() @safe;
	///
	void _onExit() @safe;
}

/*******************************************************************************
 * Flow template class
 * 
 * Flow is a template class that holds the state based on the 'state pattern'.
 * The interface of the command set whose behavior changes depending on the state is given by the Commands parameter.
 * The default base class of this template class is Object, but it can be specified by `Base`.
 * The initial state of the concrete instance of Commands is given to the constructor of this template class,
 * and transition is made according to the return value of each command.
 * If the command returns null, the transition is ended.
 */
template Flow(Commands, Base = Object,
	EnterChildHandler = void delegate(Commands, Commands)[],
	ExitChildHandler  = void delegate(Commands, Commands)[],
	EndFlowHandler    = void delegate(Commands)[])
	if (is(Commands == interface)
	 && isHandler!EnterChildHandler
	 && isHandler!ExitChildHandler
	 && isHandler!EndFlowHandler)
{
	alias FlowHandler = .FlowHandler!Commands;
	///
	abstract class FlowBase: Base
	{
	private:
		import std.container;
		SList!Commands _stsStack;
		Commands _next;
		//
		void _onEnterChild(Commands parent, Commands child) @safe
		{
			if (auto p = trustedCast!FlowHandler(parent))
			{
				p._onEnterChild(child);
			}
			if (auto c = trustedCast!FlowHandler(child))
			{
				c._onEnter();
			}
			onEnterChild.call(parent, child);
		}
		//
		void _onExitChild(Commands parent, Commands child) @safe
		{
			if (auto c = trustedCast!FlowHandler(child))
			{
				c._onExit();
			}
			if (auto p = trustedCast!FlowHandler(parent))
			{
				p._onExitChild(child);
			}
			onExitChild.call(parent, child);
		}
		//
		void _onEndFlow(Commands last) @safe
		{
			onEndFlow.call(last);
		}
	public:
		///
		EnterChildHandler onEnterChild;
		///
		ExitChildHandler  onExitChild;
		///
		EndFlowHandler    onEndFlow;
		
		///
		this(Commands root) @safe
		{
			_stsStack.insertFront(root);
			_next = trustedCast!Commands(this);
		}
		///
		final inout(Commands) current() @trusted inout @property
		{
			return _stsStack.empty ? null : cast(inout)(*cast(SList!Commands*)&_stsStack).front;
		}
	protected:
		/// internal
		final Commands _transit(Commands curr, Commands nxt) @safe
		{
			if (nxt is null)
			{
				_stsStack.removeFront();
				if (_stsStack.empty)
				{
					_onEndFlow(curr);
				}
				else
				{
					_onExitChild(_stsStack.front, curr);
				}
			}
			else if (trustedCast!Object(curr) !is trustedCast!Object(nxt))
			{
				_stsStack.insertFront(nxt);
				_onEnterChild(curr, nxt);
			}
			else
			{
				// Do nothing
			}
			return _next;
		}
	}
	
	import std.traits: ReturnType;
	import std.typecons: AutoImplement;
	enum generateTransferFunction(C, alias fun) =
	`
		auto curr = current;
		auto res = curr.` ~ __traits(identifier, fun) ~ `(args);
		return _transit(curr, res);
	`;
	
	enum isEventDistributor(alias func) = is(ReturnType!func: Commands);
	
	alias Flow = AutoImplement!(Commands, FlowBase, generateTransferFunction, isEventDistributor);
}


/// ditto
template Flow(alias Policy)
	if (!is(Policy == interface)
	&& __traits(hasMember, Policy, "Commands")
	&& is(Policy.Commands == interface))
{
	alias Commands = Policy.Commands;
	alias Flow = .Flow!(Commands,
		getMemberAlias!(Policy, "Base", Object),
		getMemberAlias!(Policy, "EnterChildHandler", void delegate(Commands, Commands)[]),
		getMemberAlias!(Policy, "ExitChildHandler", void delegate(Commands, Commands)[]),
		getMemberAlias!(Policy, "EndFlowHandler", void delegate(Commands)[]));
}

///
@safe unittest
{
	interface TestCommand
	{
		TestCommand command(string cmd) @safe;
		TestCommand update() @safe;
	}
	string msg;
	
	TestCommand test1;
	TestCommand test2;
	
	test1 = new class TestCommand
	{
		TestCommand command(string cmd) @safe
		{
			msg = cmd;
			// not transit
			return this;
		}
		TestCommand update() @safe
		{
			msg = "";
			// transit to child(test2)
			return test2;
		}
	};
	test2 = new class TestCommand
	{
		TestCommand command(string cmd) @safe
		{
			msg = cmd ~ "!";
			// not transit
			return this;
		}
		TestCommand update() @safe
		{
			msg = "!";
			// transit to parent(test1)
			return null;
		}
	};
	
	auto sts = new Flow!TestCommand(test1);
	
	// not transit
	sts.command("test");
	assert(msg == "test");
	
	// transit to child(test2)
	sts.update();
	assert(msg == "");
	
	// not transit
	sts.command("test");
	assert(msg == "test!");
	
	// transit to parent(test1)
	sts.update();
	assert(msg == "!");
	
	// not transit
	sts.command("test");
	assert(msg == "test");
}

@safe unittest
{
	interface TestCommand
	{
		TestCommand command(string cmd) @safe;
		TestCommand update() @safe;
	}
	string msg;
	
	TestCommand test1;
	TestCommand test2;
	
	struct Policy
	{
		alias Commands = TestCommand;
		alias EnterChildHandler = void delegate(Commands, Commands);
	}
	
	test1 = new class TestCommand
	{
		TestCommand command(string cmd)
		{
			msg = cmd;
			// not transit
			return this;
		}
		TestCommand update()
		{
			msg = "";
			// transit to child(test2)
			return test2;
		}
	};
	test2 = new class TestCommand
	{
		TestCommand command(string cmd)
		{
			msg = cmd ~ "!";
			// not transit
			return this;
		}
		TestCommand update()
		{
			msg = "!";
			// transit to parent(test1)
			return null;
		}
	};
	
	auto sts = new Flow!Policy(test1);
	
	// not transit
	sts.command("test");
	assert(msg == "test");
	
	// transit to child(test2)
	sts.update();
	assert(msg == "");
	
	// not transit
	sts.command("test");
	assert(msg == "test!");
	
	// transit to parent(test1)
	sts.update();
	assert(msg == "!");
	
	// not transit
	sts.command("test");
	assert(msg == "test");
}





/*******************************************************************************
 * Base template class of state derived Commands
 * 
 * This template class provides several convenience handlers and methods.
 * To use this, instantiate this template class with Commands and inherit.
 * In derived classes, the return value of each method of Commands is obtained by
 * transferring the processing to the super class.
 */
template State(Commands, Base=Object,
	EnterChildHandler = void delegate(Commands)[],
	ExitChildHandler  = EnterChildHandler,
	EnterHandler      = void delegate()[],
	ExitHandler       = EnterHandler)
	if (is(Commands == interface)
	 && isHandler!EnterChildHandler
	 && isHandler!ExitChildHandler
	 && isHandler!EnterHandler
	 && isHandler!ExitHandler)
{
	///
	abstract class StateBase: Base, Commands, FlowHandler!Commands
	{
	private:
		Commands _next;
	protected:
		/// internal
		Commands _getNext() pure nothrow @nogc @safe
		{
			scope (exit)
				_next = this;
			return _next;
		}
		/// ditto
		void _onEnterChild(Commands child) @safe
		{
			onEnterChild.call(child);
		}
		/// ditto
		void _onExitChild(Commands child) @safe
		{
			onExitChild.call(child);
		}
		/// ditto
		void _onEnter() @safe
		{
			onEnter.call();
		}
		/// ditto
		void _onExit() @safe
		{
			onExit.call();
		}
	public:
		/// Constructor
		this() pure nothrow @nogc @safe
		{
			_next = this;
		}
		/// Handler that will be called back when flow enter child state
		EnterChildHandler onEnterChild;
		/// Handler that will be called back when flow exit child state
		ExitChildHandler  onExitChild;
		/// Handler that will be called back when flow enter this state
		EnterHandler      onEnter;
		/// Handler that will be called back when flow exit this state
		ExitHandler       onExit;
		/// Indicates the next state. The specified state becomes a child of this state.
		void setNext(Commands cmd) pure nothrow @nogc @safe
		{
			_next = cmd;
		}
	}
	
	import std.traits: ReturnType;
	import std.typecons: AutoImplement;
	enum generateCommandFunction(C, alias fun) = `return _getNext();`;
	enum isEventDistributor(alias func) = is(ReturnType!func: Commands);
	alias State = AutoImplement!(Commands, StateBase, generateCommandFunction, isEventDistributor);
}

/// ditto
template State(alias Policy)
	if (!is(Policy == interface)
	 && __traits(hasMember, Policy, "Commands")
	 && is(Policy.Commands == interface))
{
	alias Commands = Policy.Commands;
	alias State = .State!(Commands,
		getMemberAlias!(Policy, "Base", Object),
		getMemberAlias!(Policy, "EnterChildHandler", void delegate(Commands)),
		getMemberAlias!(Policy, "ExitChildHandler",  void delegate(Commands)),
		getMemberAlias!(Policy, "EnterHandler",      void delegate()),
		getMemberAlias!(Policy, "ExitHandler",       void delegate()));
}



///
@safe unittest
{
	interface TestCommand
	{
		TestCommand command(string cmd) @safe;
		TestCommand update() @safe;
	}
	string msg;
	
	TestCommand test1;
	TestCommand test2;
	
	static struct StatePolicy
	{
		alias Commands = TestCommand;
		alias ExitChildHandler = void delegate(Commands);
	}
	static struct FlowPolicy
	{
		alias Commands = TestCommand;
		alias EnterChildHandler = void delegate(Commands, Commands);
	}
	test1 = new class State!StatePolicy
	{
		override TestCommand command(string cmd)
		{
			msg = cmd;
			// not transit
			return super.command(cmd);
		}
		override TestCommand update()
		{
			msg = "";
			// transit to child(test2)
			setNext(test2);
			return super.update();
		}
	};
	test2 = new class State!TestCommand
	{
		override TestCommand command(string cmd)
		{
			msg = cmd ~ "!";
			// not transit
			return super.command(cmd);
		}
		override TestCommand update()
		{
			msg = "!";
			// transit to parent(test1)
			setNext(test1);
			return super.update();
		}
	};
	
	auto sts = new Flow!FlowPolicy(test1);
	
	// not transit
	sts.command("test");
	assert(msg == "test");
	
	// transit to child(test2)
	sts.update();
	assert(msg == "");
	
	// not transit
	sts.command("test");
	assert(msg == "test!");
	
	// transit to parent(test1)
	sts.update();
	assert(msg == "!");
	
	// not transit
	sts.command("test");
	assert(msg == "test");
}

