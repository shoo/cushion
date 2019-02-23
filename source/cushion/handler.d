/*******************************************************************************
 * Handler type traits and operations
 * 
 * Copyright: © 2019, SHOO
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 * Author: SHOO
 */
module cushion.handler;

import std.traits, std.range, std.array;

/*******************************************************************************
 * Judge traits of Handler
 */
enum bool isHandler(Handler) = __traits(compiles,
{
	Handler handler = void;
	HandlerParameters!Handler args = void;
	.call(handler, args);
});

///
@safe unittest
{
	static struct CallableStruct { void opCall(){} }
	static class CallableClass { void opCall(){} }
	
	static assert(isHandler!(void function()));
	static assert(isHandler!(void delegate()));
	static assert(isHandler!(CallableClass));
	static assert(isHandler!(CallableStruct));
	static assert(isHandler!(void function()[]));
	static assert(isHandler!(void delegate()[]));
	static assert(isHandler!(CallableStruct[]));
	static assert(isHandler!(CallableClass[]));
}

@safe unittest
{
	import std.container.array, std.container.slist, std.meta;
	
	static struct CallableStruct { void opCall(){} }
	static class CallableClass { void opCall(){} }
	
	static foreach (Type; AliasSeq!(
		void function(), void delegate(), CallableStruct, CallableClass))
	{
		static assert(isHandler!(Type));
		static assert(isHandler!(Type[]));
		static assert(isHandler!(Array!Type));
		static assert(isHandler!(SList!Type));
	}
}


/*******************************************************************************
 * Judge traits of Handler for operation of adding
 */
enum bool isHandlerAddable(Handler, Func) = __traits(compiles,
{
	Handler handler;
	Func func = void;
	.add(handler, func);
	.remove(handler, func);
	.clear(handler);
});

///
@safe unittest
{
	static struct CallableStruct { void opCall(){} }
	static class CallableClass { void opCall(){} }
	
	static assert(isHandlerAddable!(void function()[], void function()));
	static assert(isHandlerAddable!(void delegate()[], void delegate()));
	static assert(isHandlerAddable!(CallableStruct[],  CallableStruct));
	static assert(isHandlerAddable!(CallableClass[],   CallableClass));
	static assert(isHandlerAddable!(void delegate()[], void function()));
	static assert(isHandlerAddable!(void delegate()[], CallableStruct));
	static assert(isHandlerAddable!(void delegate()[], CallableClass));
}

@safe unittest
{
	import std.container.array, std.container.slist, std.container.dlist, std.meta;
	static struct CallableStruct { void opCall(){} }
	static class CallableClass { void opCall(){} }
	
	static foreach (Type; AliasSeq!(
		void function(), void delegate(), CallableStruct, CallableClass))
	{
		static assert(!isHandlerAddable!(Type, void function()));
		static assert(!isHandlerAddable!(Type, void delegate()));
		static assert(!isHandlerAddable!(Type, CallableStruct));
		static assert(!isHandlerAddable!(Type, CallableClass));
	}
	
	static foreach (Type; AliasSeq!(
		void function(), void delegate(), CallableStruct, CallableClass))
	{
		static assert(isHandlerAddable!(Type[], Type));
		static assert(isHandlerAddable!(SList!Type, Type));
		static assert(isHandlerAddable!(DList!Type, Type));
	}
}

/*******************************************************************************
 * Judge traits of Handler for operation of assign
 */
enum bool isHandlerAssignable(Handler, Func) = __traits(compiles,
{
	Handler handler;
	Func func = void;
	.set(handler, func);
	.clear(handler);
});

///
@safe unittest
{
	static assert(isHandlerAssignable!(void function(), void function()));
	static assert(!isHandlerAssignable!(void function(), void delegate()));
	static assert(isHandlerAssignable!(void function()[], void function()));
	static assert(!isHandlerAssignable!(void function()[], void delegate()));
	static assert(isHandlerAssignable!(void delegate(), void delegate()));
	static assert(isHandlerAssignable!(void delegate(), void function()));
	static assert(isHandlerAssignable!(void delegate()[], void delegate()));
	static assert(isHandlerAssignable!(void delegate()[], void function()));
	
	static assert(!isHandlerAssignable!(void function(), int));
	static assert(!isHandlerAssignable!(void function()[], int));
	static assert(!isHandlerAssignable!(void delegate(), int));
	static assert(!isHandlerAssignable!(void delegate()[], int));
}

/*******************************************************************************
 * Parameter of Handler
 */
template HandlerParameters(Handler)
{
	static if (isCallable!Handler)
	{
		alias HandlerParameters = Parameters!Handler;
	}
	else static if (isIterableHandler!Handler)
	{
		alias HandlerParameters = Parameters!(ForeachType!Handler);
	}
	else static assert(0);
}

///
@safe unittest
{
	import std.meta;
	static assert(is(HandlerParameters!(void function(int)) == AliasSeq!int));
	static assert(is(HandlerParameters!(void function(int)[]) == AliasSeq!int));
	static assert(is(HandlerParameters!(void delegate(int)) == AliasSeq!int));
	static assert(is(HandlerParameters!(void delegate(int)[]) == AliasSeq!int));
}


/*******************************************************************************
 * ReturnTypeOf of Handler
 */
template HandlerReturnType(Handler)
{
	static if (isCallable!Handler)
	{
		alias HandlerReturnType = ReturnType!Handler;
	}
	else static if (isIterableHandler!Handler)
	{
		alias HandlerReturnType = ReturnType!(ForeachType!Handler);
	}
	else static assert(0);
}

///
@safe unittest
{
	static assert(is(HandlerReturnType!(int function()) == int));
	static assert(is(HandlerReturnType!(int function()[]) == int));
	static assert(is(HandlerReturnType!(int delegate()) == int));
	static assert(is(HandlerReturnType!(int delegate()[]) == int));
}


package(cushion):

private template isIterableHandler(Handler)
{
	static if (isIterable!Handler && isCallable!(ForeachType!Handler))
	{
		enum bool isIterableHandler = true;
	}
	else
	{
		enum bool isIterableHandler = false;
	}
}

@safe unittest
{
	static assert(!isIterableHandler!(void function()));
	static assert(isIterableHandler!(void function()[]));
	static assert(!isIterableHandler!(void delegate()));
	static assert(isIterableHandler!(void delegate()[]));
}


/*#*****************************************************************************
 * 
 */
void call(Handler)(ref Handler handler)
{
	static if (isCallable!Handler && is(ReturnType!Handler == void))
	{
		static if (__traits(compiles, {if(handler){}}))
		{
			if (handler)
				handler();
		}
		else
		{
			handler();
		}
	}
	else static if (isIterableHandler!Handler
	             && is(HandlerReturnType!Handler == void))
	{
		foreach (ref h; handler)
		{
			static if (__traits(compiles, {if(h){}}))
			{
				if (h)
					h();
			}
			else
			{
				h();
			}
		}
	}
	else static assert(0);
}


/*#*****************************************************************************
 * 
 */
void add(Handler, Func)(ref Handler handler, Func func)
{
	static if (__traits(compiles, {
		handler ~= func;
	}))
	{
		handler ~= func;
	}
	else static if (__traits(hasMember, handler, "insert") && __traits(compiles, {
		handler.insert(func);
	}))
	{
		handler.insert(func);
	}
	else static if (__traits(hasMember, handler, "connect") && __traits(compiles, {
		handler.connect(func);
	}))
	{
		handler.connect(func);
	}
	else static if (__traits(compiles, {
		import std.functional: toDelegate;
		handler ~= toDelegate(func);
	}))
	{
		import std.functional: toDelegate;
		handler ~= toDelegate(func);
	}
	else static if (__traits(hasMember, handler, "insert") && __traits(compiles, {
		import std.functional: toDelegate;
		handler.insert(toDelegate(func));
	}))
	{
		import std.functional: toDelegate;
		handler.insert(toDelegate(func));
	}
	else static if (__traits(hasMember, handler, "connect") && __traits(compiles, {
		import std.functional: toDelegate;
		handler.connect(toDelegate(func));
	}))
	{
		import std.functional: toDelegate;
		handler.connect(toDelegate(func));
	}
	else static assert(0);
}


/*#*****************************************************************************
 * 
 */
void remove(Handler, Func)(ref Handler handler, Func func)
{
	import std.algorithm;
	static if (__traits(hasMember, handler, "remove") && __traits(compiles, {
		handler.remove(func);
	}))
	{
		handler.remove(func);
	}
	else static if (__traits(hasMember, handler, "disconnect") && __traits(compiles, {
		handler.disconnect(func);
	}))
	{
		handler.disconnect(func);
	}
	else static if (__traits(hasMember, handler, "linearRemoveElement") && __traits(compiles, {
		handler.linearRemoveElement(func);
	}))
	{
		handler.linearRemoveElement(func);
	}
	else static if (__traits(compiles, {
		handler = std.algorithm.remove!(a => a is func)(handler);
	}))
	{
		handler = std.algorithm.remove!(a => a is func)(handler);
	}
	else static if (__traits(hasMember, handler, "remove") && __traits(compiles, {
		import std.functional: toDelegate;
		handler.remove(toDelegate(func));
	}))
	{
		import std.functional: toDelegate;
		handler.remove(toDelegate(func));
	}
	else static if (__traits(hasMember, handler, "disconnect") && __traits(compiles, {
		import std.functional: toDelegate;
		handler.disconnect(toDelegate(func));
	}))
	{
		import std.functional: toDelegate;
		handler.disconnect(toDelegate(func));
	}
	else static if (__traits(hasMember, handler, "linearRemoveElement") && __traits(compiles, {
		import std.functional: toDelegate;
		handler.linearRemoveElement(toDelegate(func));
	}))
	{
		import std.functional: toDelegate;
		handler.linearRemoveElement(toDelegate(func));
	}
	else static if (__traits(compiles, {
		import std.functional: toDelegate;
		auto dg = toDelegate(func);
		handler = std.algorithm.remove!(a => a is dg)(handler);
	}))
	{
		import std.functional: toDelegate;
		auto dg = toDelegate(func);
		handler = std.algorithm.remove!(a => a is dg)(handler);
	}
	else static assert(0);
}


/*#*****************************************************************************
 * 
 */
void clear(Handler)(ref Handler handler)
{
	static if (__traits(hasMember, handler, "clear") && __traits(compiles, {
		handler.clear();
	}))
	{
		handler.clear();
	}
	else static if (!is(Handler == class)
		&& !is(Handler == interface)
		&& !isPointer!Handler
		&& __traits(compiles, { handler = Handler.init; }))
	{
		handler = Handler.init;
	}
	else static assert(0);
}



/*#*****************************************************************************
 * 
 */
void set(Handler, Func)(ref Handler handler, Func func)
{
	static if (__traits(compiles, {
		handler = func;
	}))
	{
		handler = func;
	}
	else static if (__traits(compiles, {
		import std.functional: toDelegate;
		handler = toDelegate(func);
	}))
	{
		import std.functional: toDelegate;
		handler = toDelegate(func);
	}
	else static if (__traits(compiles, {
		handler.clear();
		handler.add(func);
	}))
	{
		handler.clear();
		handler.add(func);
	}
	else static assert(0);
}

@safe unittest
{
	void function() foo1;
	void function()[] foo2;
	void delegate() foo3;
	void delegate()[] foo4;
}
