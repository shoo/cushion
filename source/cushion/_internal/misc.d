module cushion._internal.misc;

package(cushion):

// If name member of x is exists, this template returns that member otherwise returns defaultVal
template getMemberAlias(alias x, string name, defaultVal...)
{
	static if (__traits(hasMember, x, name))
		alias getMemberAlias = __traits(getMember, x, name);
	else
		alias getMemberAlias = defaultVal[0];
}

/// ditto
template getMemberValue(alias x, string name, defaultVal...)
{
	static if (__traits(hasMember, x, name))
		enum getMemberValue = __traits(getMember, x, name);
	else
		enum getMemberValue = defaultVal[0];
}


//
pragma(inline) T trustedCast(T, Arg)(Arg arg) @trusted
{
	return cast(T)arg;
}
