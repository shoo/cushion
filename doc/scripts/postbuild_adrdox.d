import std.exception, std.algorithm, std.conv, std.process, std.path, std.file, std.stdio, std.algorithm, std.array;
	

void main(string[] args)
{
	auto workDir = environment.get("DUB_PACKAGE_DIR").buildPath("adrdox");
	
	if (auto adrdox = searchPath("adrdox", [workDir]))
	{
		// adrdox found
		exec([adrdox] ~ args[1..$], workDir);
	}
	else
	{
		// need build
		if (!workDir.exists)
			workDir.mkdirRecurse();
		auto adrdoxDir = workDir.buildPath("adrdox");
		if (!adrdoxDir.exists || !adrdoxDir.isDir)
		{
			exec(["git", "clone", "--depth", "1", "https://github.com/adamdruppe/adrdox.git"], workDir);
		}
		else
		{
			exec(["git", "pull", "--ff-only"], adrdoxDir);
		}
		exec(["dub", "upgrade"], adrdoxDir);
		exec(["dub", "build"], adrdoxDir);
		
		// copy
		foreach (de; dirEntries(adrdoxDir, "*.{css,js,html}", SpanMode.shallow))
			copy(de.name, workDir.buildPath(de.name.baseName));
		auto adrdoxTempBin = searchPath("adrdox", [adrdoxDir.buildPath("build")]);
		auto adrdoxBin = workDir.buildPath(adrdoxTempBin.baseName);
		copy(adrdoxTempBin, adrdoxBin);
		
		exec([adrdoxBin] ~ args[1..$], workDir);
	}
}

private void exec(string[] args, string workDir)
{
	auto pid = spawnProcess(args, stdin, stdout, stderr, null, Config.none, workDir);
	enforce(pid.wait() == 0);
}

private string searchPath(in char[] executable, in string[] additional = null)
{
	if (executable.exists)
		return executable.dup;
	version (Windows)
	{
		char separator = ';';
		string execFileName = executable.setExtension(".exe");
	}
	else
	{
		char separator = ':';
		string execFileName = executable.dup;
	}
	
	string execPath;
	if (execFileName.isAbsolute())
		return execFileName;
	
	string check(in string[] paths...)
	{
		foreach (p; paths)
		{
			if (p.exists)
			{
				if (p.isFile)
					return p;
				if (p.isDir)
				{
					if (auto f = check(p.buildPath(execFileName)))
						return f;
				}
			}
		}
		return null;
	}
	if (auto f = check(additional[]))
		return f;
	
	if (auto f = check(thisExePath.dirName))
		return f;
	
	if (auto f = check(getcwd()))
		return f;
	
	auto paths = environment.get("PATH", environment.get("Path", environment.get("path")));
	if (auto f = check(paths.splitter(separator).array))
		return f;
	
	return null;
}
