// herdr-load: how much CPU and memory each herdr workspace's processes use,
// shown as tokens in herdr's sidebar on a row under the workspace's name:
//
//   dotfiles
//   ▄ 1.2G
//
// The bar rises with the workspace's share of the machine's CPU, and its
// token (cpu_low, cpu_mid, cpu_high) picks its colour in config.toml; the
// memory is the processes' summed RSS, its token (mem_low, mem_mid, mem_high)
// likewise. See the [ui.sidebar.spaces] rows in herdr's config.toml.
//
// Every process started in a pane inherits HERDR_SOCKET_PATH and
// HERDR_WORKSPACE_ID, so one pass over /proc per tick sums all workspaces at
// once: the cost grows with the number of processes, not of workspaces, and
// herdr hears only of a workspace whose shown value changed.
//
// On WSL, Windows programs a pane starts (git.exe, dotnet.exe, msbuild) run
// outside Linux. herdr-load-win.exe, started next to this file, lists the
// Windows processes; each WSL stand-in (/init /mnt/c/.../git.exe) is matched
// to the Windows process of the same name and age, and Windows processes
// started by a matched one count towards the same workspace.
//
// herdr-load run     report until the herdr server goes away (start.sh)
// herdr-load print   sample once over a tick and print the table, no herdr
#:property PublishAot=true
#:property InvariantGlobalization=true
#:property OptimizationPreference=Size

using System.Buffers;
using System.Diagnostics;
using System.Globalization;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

var socketPath = Environment.GetEnvironmentVariable("HERDR_SOCKET_PATH") ?? "";
switch (args.FirstOrDefault())
{
    case "run" when socketPath != "":
        return new Reporter(socketPath).Run();
    case "print" when socketPath != "":
        new Reporter(socketPath).Print();
        return 0;
    default:
        Console.Error.WriteLine("usage: herdr-load run|print  (HERDR_SOCKET_PATH names the herdr server)");
        return 2;
}

sealed class Reporter(string socketPath)
{
    const int TickMs = 3000;
    // Unchanged tokens are sent again this often, and herdr drops them this
    // long after the last one, so a reporter that dies takes its icons along.
    const int RefreshMs = 60_000;
    const int TtlMs = 180_000;
    const string Source = "herdr-load";

    // Share of the machine's CPU at which the bar rises one step further.
    static readonly double[] CpuSteps = [0.02, 0.10, 0.30, 0.60];
    static readonly string[] CpuGlyphs = ["▁", "▂", "▄", "▆", "█"];
    static readonly string[] CpuTokens = ["cpu_low", "cpu_low", "cpu_mid", "cpu_high", "cpu_high"];
    const long GiB = 1L << 30, MiB = 1L << 20;
    static readonly string[] AllTokens = ["cpu_low", "cpu_mid", "cpu_high", "mem_low", "mem_mid", "mem_high"];

    sealed class Proc
    {
        public long Start;          // clock ticks after boot, /proc/<pid>/stat field 22
        public string? Workspace;
        public long Cpu;            // utime + stime + cutime + cstime, in clock ticks
        public string? StubName;    // a Windows program's WSL stand-in: the program's file name
        public bool IsMatched;      // the stand-in's Windows process has been found
        public bool IsSeen;
    }

    sealed class Shown
    {
        public double Cpu = -1;     // smoothed share of the machine
        public long MemShown = -1;  // the bytes the shown memory text was made from
        public string MemText = "";
        public Dictionary<string, string?> Tokens = [];
        public long SentAt;
        public bool IsSeen;
    }

    readonly Dictionary<int, Proc> procs = [];
    readonly Dictionary<(long Pid, long Create), (string Workspace, long Cpu)> windows = [];
    readonly Dictionary<string, Shown> shown = [];
    readonly long pageSize = Environment.SystemPageSize;
    readonly int cpus = Environment.ProcessorCount;
    readonly WindowsHelper? helper = WindowsHelper.Find();
    long lastWindowsNow;
    bool isFirstScan = true;

    public int Run()
    {
        var stateDir = Environment.GetEnvironmentVariable("HERDR_PLUGIN_STATE_DIR")
            ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local/state/herdr-load");
        Directory.CreateDirectory(stateDir);
        // One reporter per herdr server. FileShare.None takes an flock on
        // Linux, so a second start finds it held and leaves; start.sh reads
        // the pid from the file to stop this one.
        FileStream pidFile;
        try
        {
            pidFile = new FileStream(Path.Combine(stateDir, "reporter" + socketPath.Replace('/', '_') + ".pid"),
                FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        }
        catch (IOException)
        {
            return 0;
        }
        pidFile.SetLength(0);
        pidFile.Write(Encoding.ASCII.GetBytes(Environment.ProcessId + "\n"));
        pidFile.Flush();

        using var stop = new ManualResetEventSlim();
        using var onTerm = PosixSignalRegistration.Create(PosixSignal.SIGTERM, c => { c.Cancel = true; stop.Set(); });
        using var onInt = PosixSignalRegistration.Create(PosixSignal.SIGINT, c => { c.Cancel = true; stop.Set(); });

        var watch = Stopwatch.StartNew();
        var last = watch.Elapsed.TotalSeconds;
        int tick = 0, misses = 0;
        while (!stop.Wait(isFirstScan ? 0 : TickMs))
        {
            var now = watch.Elapsed.TotalSeconds;
            var sums = Sample();
            if (!isFirstScan)
                Report(sums, now - last, (long)(now * 1000));
            isFirstScan = false;
            last = now;
            // The server is gone once its socket file is, or, asked once a
            // minute, it does not answer twice running.
            var isAlive = File.Exists(socketPath) && (++tick % 20 != 0 || Ping());
            misses = isAlive ? 0 : misses + 1;
            if (misses >= 2)
                break;
        }
        if (stop.IsSet)
            foreach (var ws in shown.Keys)
                Send(ws, AllTokens.ToDictionary(t => t, _ => (string?)null));
        helper?.Dispose();
        pidFile.Dispose();
        return 0;
    }

    public void Print()
    {
        Sample();
        isFirstScan = false;
        Thread.Sleep(TickMs);
        var sums = Sample();
        Console.WriteLine($"{"workspace",-12} {"cpu",7} {"memory",9}");
        foreach (var (ws, (cpu, mem)) in sums.OrderBy(s => s.Key))
            Console.WriteLine($"{ws,-12} {cpu / (TickMs / 1000.0) / cpus,7:P1} {Memory(mem).Text,9}");
        helper?.Dispose();
    }

    // CPU seconds since the last sample and resident bytes, per workspace.
    Dictionary<string, (double Cpu, long Mem)> Sample()
    {
        var sums = new Dictionary<string, (double Cpu, long Mem)>();
        void Add(string ws, double cpu, long mem)
        {
            var (c, m) = sums.GetValueOrDefault(ws);
            sums[ws] = (c + cpu, m + mem);
        }

        var uptime = double.Parse(File.ReadAllText("/proc/uptime").Split(' ')[0], CultureInfo.InvariantCulture);
        foreach (var p in procs.Values)
            p.IsSeen = false;
        var stubs = new List<Proc>();
        foreach (var dir in Directory.EnumerateDirectories("/proc"))
        {
            if (!int.TryParse(Path.GetFileName(dir), out var pid))
                continue;
            string stat;
            try { stat = File.ReadAllText(dir + "/stat"); }
            catch (IOException) { continue; }
            catch (UnauthorizedAccessException) { continue; }
            // Fields after the command's closing parenthesis, from field 3 on.
            var f = stat[(stat.LastIndexOf(')') + 2)..].Split(' ');
            if (f.Length < 22)
                continue;
            var start = long.Parse(f[19]);
            var cpu = long.Parse(f[11]) + long.Parse(f[12]) + long.Parse(f[13]) + long.Parse(f[14]);
            var rss = long.Parse(f[21]) * pageSize;

            var isNew = !procs.TryGetValue(pid, out var p) || p.Start != start;
            if (isNew)
            {
                p = new Proc { Start = start, Cpu = isFirstScan ? cpu : 0 };
                ReadIdentity(dir, p);
                procs[pid] = p;
            }
            p!.IsSeen = true;
            if (p.Workspace is null)
                continue;
            // A child's CPU moves into its parent's cutime when the parent
            // reaps it, so the whole of a short-lived child lands here too.
            Add(p.Workspace, (cpu - p.Cpu) / 100.0, rss);
            p.Cpu = cpu;
            if (p.StubName is not null && !p.IsMatched)
                stubs.Add(p);
        }
        // An exited process's last count shows up again in its parent's
        // cutime: take back what was already counted. A process nobody in the
        // workspace reaps leaves the sum short for a tick, hence the floor.
        foreach (var (pid, p) in procs.Where(e => !e.Value.IsSeen).ToList())
        {
            if (p.Workspace is not null)
                Add(p.Workspace, -p.Cpu / 100.0, 0);
            procs.Remove(pid);
        }

        if (helper is not null && (stubs.Count > 0 || windows.Count > 0))
            SampleWindows(stubs, uptime, Add);

        foreach (var ws in sums.Keys.ToList())
            sums[ws] = (Math.Max(0, sums[ws].Cpu), sums[ws].Mem);
        return sums;
    }

    void ReadIdentity(string dir, Proc p)
    {
        try
        {
            string? sock = null, ws = null;
            foreach (var kv in File.ReadAllText(dir + "/environ").Split('\0'))
            {
                if (kv.StartsWith("HERDR_SOCKET_PATH="))
                    sock = kv[18..];
                else if (kv.StartsWith("HERDR_WORKSPACE_ID="))
                    ws = kv[19..];
            }
            if (sock != socketPath || string.IsNullOrEmpty(ws))
                return;
            p.Workspace = ws;
            // WSL runs a Windows program through /init, which stays as its stand-in.
            var argv = File.ReadAllText(dir + "/cmdline").Split('\0');
            if (argv.Length > 1 && argv[0] == "/init" && argv[1].EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                p.StubName = Path.GetFileName(argv[1]);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    void SampleWindows(List<Proc> stubs, double uptime, Action<string, double, long> add)
    {
        var snap = helper!.Snapshot();
        if (snap is null)
            return;
        var (now, list) = snap.Value;
        // Oldest first, so a parent is placed before the children it started.
        list.Sort((a, b) => a.Create.CompareTo(b.Create));
        var byPid = new Dictionary<long, WinProc>();
        foreach (var w in list)
            byPid[w.Pid] = w;

        // A stand-in and its Windows process start together: same file name,
        // ages within a second and a half. Ages, not times, so the two clocks
        // need not agree.
        foreach (var stub in stubs)
        {
            var age = uptime - stub.Start / 100.0;
            WinProc? best = null;
            foreach (var w in list)
            {
                var d = Math.Abs((now - w.Create) / 1e7 - age);
                if (d < 1.5 && string.Equals(w.Name, stub.StubName, StringComparison.OrdinalIgnoreCase)
                    && !windows.ContainsKey((w.Pid, w.Create))
                    && (best is null || d < Math.Abs((now - best.Value.Create) / 1e7 - age)))
                    best = w;
            }
            if (best is { } b)
            {
                windows[(b.Pid, b.Create)] = (stub.Workspace!, StartCpu(b));
                stub.IsMatched = true;
            }
        }

        var alive = new HashSet<(long, long)>();
        foreach (var w in list)
        {
            var key = (w.Pid, w.Create);
            alive.Add(key);
            if (!windows.TryGetValue(key, out var e))
            {
                // Started by a process of a workspace, and not a later one
                // that took over a reused pid.
                if (!byPid.TryGetValue(w.Ppid, out var parent) || parent.Create > w.Create
                    || !windows.TryGetValue((parent.Pid, parent.Create), out var pe))
                    continue;
                e = (pe.Workspace, StartCpu(w));
            }
            add(e.Workspace, (w.Cpu - e.Cpu) / 1e7, w.WorkingSet);
            windows[key] = (e.Workspace, w.Cpu);
        }
        foreach (var key in windows.Keys.Where(k => !alive.Contains(k)).ToList())
            windows.Remove(key);
        lastWindowsNow = now;

        // A process started since the last snapshot counts whole; one found
        // later than that counts from now on.
        long StartCpu(WinProc w) => lastWindowsNow != 0 && w.Create > lastWindowsNow ? 0 : w.Cpu;
    }

    void Report(Dictionary<string, (double Cpu, long Mem)> sums, double seconds, long nowMs)
    {
        foreach (var s in shown.Values)
            s.IsSeen = false;
        foreach (var (ws, (cpu, mem)) in sums)
        {
            if (!shown.TryGetValue(ws, out var s))
                shown[ws] = s = new Shown();
            s.IsSeen = true;
            var share = cpu / seconds / cpus;
            s.Cpu = s.Cpu < 0 ? share : (s.Cpu + share) / 2;
            var level = CpuSteps.Count(step => s.Cpu >= step);

            // A new text only for a change of more than 5 %, so a value on the
            // edge of a step does not flip on every tick.
            if (s.MemShown < 0 || Math.Abs(mem - s.MemShown) > s.MemShown / 20)
            {
                s.MemShown = mem;
                s.MemText = Memory(mem).Text;
            }
            var tokens = AllTokens.ToDictionary(t => t, _ => (string?)null);
            tokens[CpuTokens[level]] = CpuGlyphs[level];
            tokens[Memory(s.MemShown).Token] = s.MemText;

            var isSame = s.Tokens.Count == tokens.Count && tokens.All(t => s.Tokens.GetValueOrDefault(t.Key) == t.Value);
            if (isSame && nowMs - s.SentAt < RefreshMs)
                continue;
            if (Send(ws, tokens))
            {
                s.Tokens = tokens;
                s.SentAt = nowMs;
            }
        }
        // A workspace with no process left: its icons go at once.
        foreach (var (ws, _) in shown.Where(e => !e.Value.IsSeen).ToList())
        {
            Send(ws, AllTokens.ToDictionary(t => t, _ => (string?)null));
            shown.Remove(ws);
        }
    }

    static (string Text, string Token) Memory(long bytes) => bytes switch
    {
        < GiB => ($"{Math.Max(1, (bytes + 5 * MiB) / (10 * MiB)) * 10}M", "mem_low"),
        < 4 * GiB => (((double)bytes / GiB).ToString("0.0", CultureInfo.InvariantCulture) + "G", "mem_mid"),
        < 10 * GiB => (((double)bytes / GiB).ToString("0.0", CultureInfo.InvariantCulture) + "G", "mem_high"),
        _ => ($"{(bytes + GiB / 2) / GiB}G", "mem_high"),
    };

    // One request per connection: herdr answers one line and closes.
    bool Send(string ws, Dictionary<string, string?> tokens)
    {
        var body = new ArrayBufferWriter<byte>();
        using (var w = new Utf8JsonWriter(body))
        {
            w.WriteStartObject();
            w.WriteString("id", Source);
            w.WriteString("method", "workspace.report_metadata");
            w.WriteStartObject("params");
            w.WriteString("workspace_id", ws);
            w.WriteString("source", Source);
            w.WriteNumber("ttl_ms", TtlMs);
            w.WriteStartObject("tokens");
            foreach (var (k, v) in tokens)
                w.WriteString(k, v);
            w.WriteEndObject();
            w.WriteEndObject();
            w.WriteEndObject();
        }
        var answer = Call(body.WrittenSpan.ToArray())?.Trim();
        if (answer is null)
            return false;
        // A process can outlive its workspace (a daemon started there): such
        // a workspace counts as told, and is tried again with the refresh.
        if (answer.Contains("\"result\"") || answer.Contains("\"workspace_not_found\""))
            return true;
        Console.Error.WriteLine($"herdr-load: {ws}: {answer}");
        return false;
    }

    bool Ping() => Call("{\"id\":\"herdr-load\",\"method\":\"workspace.list\",\"params\":{}}"u8.ToArray()) is not null;

    string? Call(byte[] request)
    {
        try
        {
            using var s = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
            s.ReceiveTimeout = 2000;
            s.SendTimeout = 2000;
            s.Connect(new UnixDomainSocketEndPoint(socketPath));
            s.Send(request);
            s.Send("\n"u8);
            var answer = new MemoryStream();
            var buf = new byte[4096];
            int n;
            while ((n = s.Receive(buf)) > 0)
            {
                answer.Write(buf, 0, n);
                if (Array.IndexOf(buf, (byte)'\n', 0, n) >= 0)
                    break;
            }
            return Encoding.UTF8.GetString(answer.ToArray());
        }
        catch (SocketException)
        {
            return null;
        }
    }
}

readonly record struct WinProc(long Pid, long Ppid, long Create, long WorkingSet, long Cpu, string Name);

// herdr-load-win.exe, kept running: a newline on its stdin asks for one
// snapshot, which it answers with "now <filetime>", a line per process and an
// empty line. It exits when its stdin closes, so it never outlives us.
sealed class WindowsHelper(string path) : IDisposable
{
    Process? process;
    long startedAt = -60_000;

    public static WindowsHelper? Find()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "herdr-load-win.exe");
        var isWsl = File.Exists("/proc/sys/fs/binfmt_misc/WSLInterop") || File.Exists("/proc/sys/fs/binfmt_misc/WSLInterop-late");
        return isWsl && File.Exists(path) ? new WindowsHelper(path) : null;
    }

    public (long Now, List<WinProc> List)? Snapshot()
    {
        if (process is null || process.HasExited)
        {
            // Started again at most once a minute, should it keep failing.
            if (Environment.TickCount64 - startedAt < 60_000)
                return null;
            startedAt = Environment.TickCount64;
            process?.Dispose();
            process = Process.Start(new ProcessStartInfo(path)
            {
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
            });
        }
        try
        {
            process!.StandardInput.WriteLine();
            process.StandardInput.Flush();
            var read = Task.Run(() =>
            {
                long now = 0;
                var list = new List<WinProc>();
                while (process.StandardOutput.ReadLine() is { Length: > 0 } line)
                {
                    var f = line.Split(' ', 6);
                    if (f[0] == "now")
                        now = long.Parse(f[1]);
                    else if (f.Length == 6)
                        list.Add(new WinProc(long.Parse(f[0]), long.Parse(f[1]), long.Parse(f[2]), long.Parse(f[3]), long.Parse(f[4]), f[5]));
                }
                return (now, list);
            });
            if (read.Wait(2000) && read.Result.now != 0)
                return read.Result;
        }
        catch (Exception e) when (e is IOException or AggregateException or InvalidOperationException)
        {
        }
        Dispose();
        return null;
    }

    public void Dispose()
    {
        if (process is null)
            return;
        try { if (!process.HasExited) process.Kill(); }
        catch (InvalidOperationException) { }
        process.Dispose();
        process = null;
    }
}
