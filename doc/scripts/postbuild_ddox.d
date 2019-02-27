import std.exception, std.algorithm, std.conv, std.process, std.path, std.file, std.stdio, std.algorithm, std.array, std.string;
	

void main(string[] args)
{
	auto workDir = environment.get("DUB_PACKAGE_DIR").buildPath("ddox");
	
	if (auto ddox = searchPath("ddox", [workDir]))
	{
		// ddox found
		exec(["dub", "fetch", "ddox"], ".");
		
		auto ddoxDir = execute(["dub", "describe", "ddox", "--data-list", "--data=target-path"]).output.chomp;
		copyFiles(ddoxDir.buildPath("public"), workDir, "*.{css,js,html}");
		
		execDdox(ddox, args[1..$], ".");
	}
	else
	{
		// need build
		if (!workDir.exists)
			workDir.mkdirRecurse();
		exec(["dub", "fetch", "ddox"], ".");
		exec(["dub", "upgrade", "ddox"], ".");
		string[] exArgs;
		exArgs ~= "-a=" ~ getDdoxBuildArch();
		exec(["dub", "build", "ddox"] ~ exArgs, ".");
		
		// copy
		auto ddoxDir = execute(["dub", "describe", "ddox", "--data-list", "--data=target-path"]).output.chomp;
		copyFiles(ddoxDir.buildPath("public"), workDir, "*.{css,js,html}");
		auto ddoxTempBin = searchPath("ddox", [ddoxDir]);
		auto ddoxBin = workDir.buildPath(ddoxTempBin.baseName);
		copy(ddoxTempBin, ddoxBin);
		
		execDdox(ddoxBin, args[1..$], ".");
	}
}

private string getDdoxBuildArch()
{
	auto arch = environment.get("DUB_ARCH");
	version (Windows)
	{
		if (arch == "x86" || arch == "x86_64")
		{
			return "x86_mscoff";
		}
	}
	return arch;
}

private void copyFiles(string fromDir, string toDir, string pattern)
{
	auto src = fromDir.absolutePath();
	auto dst = toDir.absolutePath();
	foreach (de; dirEntries(src, pattern, SpanMode.depth))
	{
		auto dstPath = dst.buildPath(de.name.relativePath(src));
		if (!dstPath.dirName.exists)
			dstPath.dirName.mkdirRecurse();
		copy(de.name, dstPath);
	}
}

private void execDdox(string bin, string[] args, string workDir)
{
	string json;
	if ((args.length > 1) && (args[0].extension == ".json"))
	{
		json = args[0];
		args = args[1..$];
	}
	else
	{
		json = "docs.json";
	}
	exec([bin, "filter", json, "--min-protection", "Protected"], workDir);
	exec([bin, "generate-html", json] ~ args, workDir);
	if (exists("__dummy.html"))
		std.file.remove("__dummy.html");
	if (exists(json))
		std.file.remove(json);
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
