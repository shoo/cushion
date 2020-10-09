import std.stdio;

import cushion.helper;

int main(string[] args)
{
	if (args.length != 2)
		return -1;
	
	updateMapFile(args[1] ~ ".stm.csv", args[1] ~ ".map.csv");
	
	return 0;
}
