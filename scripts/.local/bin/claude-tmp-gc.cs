#!/usr/bin/env -S sh -c 'exec dotnet run --file "$0" -- "$@"'
// claude-tmp-gc: find stale Claude Code session scratch folders and delete them
// through an fzf-style picker.
//
// Claude Code gives every session a folder <root>/<project-slug>/<session-id>
// (root is $TMPDIR/claude-<uid>, usually /tmp/claude-1000). Nothing removes
// those folders when a session ends, so they pile up -- extracted archives,
// builds and experiments can reach gigabytes.
//
// A session counts as
//   live        some process has a file open, or its working directory,
//               inside the folder (a running session keeps tasks/*.output
//               open there);
//   maybe-live  a running `claude` process holds no file in any session folder
//               but runs in this project and started before the folder was
//               last written -- an idle session we cannot pin down exactly;
//   stale       everything else.
// Only stale folders can be marked; live state is checked again right before
// each folder is deleted. Linux only: liveness comes from /proc.
//
// `claude-tmp-gc --help` lists the options and the picker's keys.
//
// The shebang goes through sh to put `--` between the script and its
// arguments: `dotnet file.cs --help` (or -r, -f, -v...) would otherwise be
// taken by `dotnet run` itself.
#:package System.CommandLine@2.0.14
#:package XenoAtom.Terminal.UI@3.11.0
#:property TargetFramework=net11.0
#:property PublishAot=false

using System.Collections.Concurrent;
using System.CommandLine;
using System.CommandLine.Help;
using System.CommandLine.Parsing;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using XenoAtom.Terminal.UI.Commands;
using Group = XenoAtom.Terminal.UI.Controls.Group;
using UiCommand = XenoAtom.Terminal.UI.Commands.Command;
using XenoAtom.Ansi;
using XenoAtom.Terminal;
using XenoAtom.Terminal.UI;
using XenoAtom.Terminal.UI.Controls;
using XenoAtom.Terminal.UI.Input;
using XenoAtom.Terminal.UI.Templating;

return Cli.Run(args);

enum SortKey { Size, Age, Name }

enum OutputFormat { Table, Json, Paths }

enum Liveness { Stale, MaybeLive, Live }

sealed record Options(
    DirectoryInfo Root,
    TimeSpan OlderThan,
    long MinSize,
    string Query,
    SortKey Sort,
    bool ShowLive,
    bool DryRun,
    bool List,
    OutputFormat Format,
    bool DeleteAll);

static class Cli
{
    const string Keys = """
        Picker keys:
          type            fuzzy filter (space-separated terms all match, !term excludes)
          Up/Down PgUp/PgDn  move the cursor
          Tab / Shift+Tab mark or unmark the folder under the cursor and move on
          Ctrl+A          mark all visible stale folders (again: unmark them)
          Ctrl+T          invert the marks of the visible stale folders
          Ctrl+S          cycle the sort order: size, age, name
          Enter           delete the marked folders (or the one under the cursor), after a confirmation
          Esc             clear the filter; with an empty filter, quit
          Ctrl+Q          quit
        """;

    public static int Run(string[] args)
    {
        var root = new Option<DirectoryInfo>("--root", "-r")
        {
            Description = "Claude Code's temp root, holding <project>/<session> folders.",
            HelpName = "dir",
            DefaultValueFactory = _ => new DirectoryInfo(DefaultRoot()),
        };
        root.Validators.Add(result =>
        {
            var dir = result.GetValueOrDefault<DirectoryInfo>();
            if (!dir.Exists)
                result.AddError($"--root: '{dir.FullName}' does not exist or is not a directory.");
            else if (dir.FullName.TrimEnd('/') is "" or "/tmp" or "/" || dir.FullName == Environment.GetFolderPath(Environment.SpecialFolder.UserProfile))
                result.AddError($"--root: refusing '{dir.FullName}'; point it at the claude-<uid> folder, not a system or home directory.");
        });

        var olderThan = new Option<TimeSpan>("--older-than", "-o")
        {
            Description = "Only folders last written longer ago than this: 90s, 30m, 12h, 2d, 1w (decimals allowed).",
            HelpName = "age",
            CustomParser = result => TryParseAge(result.Tokens.Single().Value, out _) ?? default,
        };

        var minSize = new Option<long>("--min-size", "-s")
        {
            Description = "Only folders at least this big: 500K, 100M, 1.5G (1024-based; B suffix optional).",
            HelpName = "size",
            CustomParser = result => TryParseSize(result.Tokens.Single().Value, out _) ?? 0,
        };

        var query = new Option<string>("--query", "-q")
        {
            Description = "Start the picker with this filter (same syntax as typing in it).",
            HelpName = "text",
            DefaultValueFactory = _ => "",
        };

        var sort = new Option<SortKey>("--sort")
        {
            Description = "Initial order, biggest / oldest first, or by project and id.",
            DefaultValueFactory = _ => SortKey.Size,
        };

        var showLive = new Option<bool>("--show-live")
        {
            Description = "Also list live and maybe-live sessions (shown locked; they are never deleted).",
        };

        var dryRun = new Option<bool>("--dry-run", "-n")
        {
            Description = "Report what would be deleted without deleting anything.",
        };

        var list = new Option<bool>("--list", "-l")
        {
            Description = "Print the folders instead of opening the picker.",
        };

        var format = new Option<OutputFormat>("--format", "-f")
        {
            Description = "Output of --list: a table, JSON, or one path per line (for xargs).",
            DefaultValueFactory = _ => OutputFormat.Table,
        };

        var deleteAll = new Option<bool>("--delete-all")
        {
            Description = "Delete every stale folder that passes the filters, without asking (e.g. from a timer).",
        };

        var command = new RootCommand(
            "List stale Claude Code session temp folders and delete them through an fzf-style picker.\n\n" + Keys + """

            Examples:
              claude-tmp-gc                       pick from all stale folders
              claude-tmp-gc -q factorio -s 100M   start filtered to big factorio folders
              claude-tmp-gc -l -o 1d              list folders untouched for a day
              claude-tmp-gc -l -f paths -o 1w     paths only, for scripts
              claude-tmp-gc --delete-all -o 3d -n show what a cleanup timer would delete
            """)
        {
            root, olderThan, minSize, query, sort, showLive, dryRun, list, format, deleteAll,
        };

        command.Validators.Add(result =>
        {
            if (!OperatingSystem.IsLinux())
                result.AddError("This tool reads /proc to tell live sessions apart and runs on Linux only.");
            if (result.GetResult(format) is { Implicit: false } && !result.GetValue(list))
                result.AddError("--format only applies to --list.");
            if (result.GetValue(deleteAll) && result.GetValue(list))
                result.AddError("--delete-all and --list are separate modes; use --delete-all --dry-run to preview.");
            if (result.GetValue(deleteAll) && result.GetValue(showLive))
                result.AddError("--delete-all never deletes live sessions, so --show-live makes no sense with it.");
            if (result.GetValue(deleteAll) && result.GetResult(query) is { Implicit: false })
                result.AddError("--query is the picker's filter; --delete-all takes --older-than and --min-size.");
        });
        command.Options.Remove(command.Options.OfType<VersionOption>().Single());
        command.Options.OfType<HelpOption>().Single().Description = "Show this help.";
        // Custom parsers run lazily, on the first GetValue, too late to report; validators check the same text up front.
        olderThan.Validators.Add(result =>
        {
            if (result.Tokens.Count == 1 && TryParseAge(result.Tokens[0].Value, out var error) is null) result.AddError(error!);
        });
        minSize.Validators.Add(result =>
        {
            if (result.Tokens.Count == 1 && TryParseSize(result.Tokens[0].Value, out var error) is null) result.AddError(error!);
        });

        command.SetAction(parse =>
        {
            var interactive = !parse.GetValue(list) && !parse.GetValue(deleteAll);
            if (interactive && (Console.IsInputRedirected || Console.IsOutputRedirected))
            {
                Console.Error.WriteLine("claude-tmp-gc: the picker needs a terminal; use --list or --delete-all when piping.");
                return 2;
            }
            var options = new Options(
                parse.GetValue(root)!,
                parse.GetValue(olderThan),
                parse.GetValue(minSize),
                parse.GetValue(query) ?? "",
                parse.GetValue(sort),
                parse.GetValue(showLive),
                parse.GetValue(dryRun),
                parse.GetValue(list),
                parse.GetValue(format),
                parse.GetValue(deleteAll));
            return App.Run(options);
        });

        var parsed = command.Parse(args);
        if (parsed.Errors.Count > 0)
        {
            var color = !Console.IsErrorRedirected && Environment.GetEnvironmentVariable("NO_COLOR") is null;
            string Paint(string code, string text) => color ? $"\e[{code}m{text}\e[0m" : text;
            foreach (var error in parsed.Errors)
                Console.Error.WriteLine($"{Paint("1;31", "error:")} {error.Message}");
            Console.Error.WriteLine(Paint("90", "Run claude-tmp-gc --help for the options."));
            return 2;
        }
        return parsed.Invoke(new InvocationConfiguration { EnableDefaultExceptionHandler = false });
    }

    static string DefaultRoot()
    {
        var uid = File.ReadLines("/proc/self/status")
            .Select(l => l.Split('\t', StringSplitOptions.RemoveEmptyEntries))
            .FirstOrDefault(p => p.Length > 1 && p[0] == "Uid:")?[1] ?? "1000";
        var tmp = Environment.GetEnvironmentVariable("TMPDIR") is { Length: > 0 } t ? t : "/tmp";
        return Path.Combine(tmp, $"claude-{uid}");
    }

    static readonly Regex AgePattern = new(@"^(\d+(?:\.\d+)?)\s*(s|m|h|d|w)$", RegexOptions.IgnoreCase);
    static readonly Regex SizePattern = new(@"^(\d+(?:\.\d+)?)\s*([KMGT]?)(?:i?B)?$", RegexOptions.IgnoreCase);

    /// <summary>Parses 90s, 30m, 12h, 2d, 1w (decimals allowed); null with a reason when the text is not one.</summary>
    static TimeSpan? TryParseAge(string token, out string? error)
    {
        error = null;
        var m = AgePattern.Match(token.Trim());
        if (!m.Success)
        {
            error = $"--older-than takes a number and a unit (s, m, h, d, w), like 30m or 2d, not '{token}'.";
            return null;
        }
        var n = double.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture);
        var days = char.ToLowerInvariant(m.Groups[2].Value[0]) switch
        {
            's' => n / 86400, 'm' => n / 1440, 'h' => n / 24, 'd' => n, _ => n * 7,
        };
        if (days > 3650)
        {
            error = $"--older-than {token} is more than ten years; nothing would match.";
            return null;
        }
        return TimeSpan.FromDays(days);
    }

    /// <summary>Parses 500K, 100M, 1.5G (1024-based, optional B or iB); null with a reason when the text is not one.</summary>
    static long? TryParseSize(string token, out string? error)
    {
        error = null;
        var m = SizePattern.Match(token.Trim());
        if (!m.Success)
        {
            error = $"--min-size takes a number with an optional K, M, G or T suffix, like 100M, not '{token}'.";
            return null;
        }
        var n = double.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture);
        var shift = m.Groups[2].Value.ToUpperInvariant() switch { "K" => 10, "M" => 20, "G" => 30, "T" => 40, _ => 0 };
        var bytes = n * Math.Pow(2, shift);
        if (bytes > 1L << 50)
        {
            error = $"--min-size {token} is larger than a petabyte; nothing would match.";
            return null;
        }
        return (long)bytes;
    }
}

/// <summary>One session folder: &lt;root&gt;/&lt;project&gt;/&lt;id&gt;.</summary>
sealed class Session
{
    public required string Path { get; init; }
    public required string ProjectSlug { get; init; }
    public required string Project { get; init; }
    public required string Id { get; init; }
    public long Bytes { get; set; }
    public long Files { get; set; }
    public DateTime LastWrite { get; set; }
    public Liveness Status { get; set; }
    public string? StatusReason { get; set; }
    public List<(string Name, long Bytes)> Largest { get; } = [];
    public State<bool> Marked { get; } = new(false);
    public string Haystack => $"{Project}/{Id}";
    public TimeSpan Age => DateTime.Now - LastWrite;
    public bool Deletable => Status == Liveness.Stale;
}

static class Scanner
{
    /// <summary>Lists session folders under root, without sizes.</summary>
    public static List<Session> List(DirectoryInfo root)
    {
        var sessions = new List<Session>();
        foreach (var project in root.EnumerateDirectories())
        {
            if (project.LinkTarget is not null || !project.Name.StartsWith('-'))
                continue; // session folders live under "-home-..." slugs; skip bash-edit-diff etc.
            var display = ProjectPath(project.Name);
            foreach (var dir in project.EnumerateDirectories())
            {
                if (dir.LinkTarget is not null)
                    continue;
                sessions.Add(new Session
                {
                    Path = dir.FullName,
                    ProjectSlug = project.Name,
                    Project = display,
                    Id = dir.Name,
                    LastWrite = dir.LastWriteTime,
                });
            }
        }
        return sessions;
    }

    /// <summary>Totals size, file count and newest write time, and keeps the five largest top-level entries.</summary>
    public static void Measure(Session s)
    {
        var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true, AttributesToSkip = 0 };
        long total = 0, files = 0;
        var newest = s.LastWrite;
        var children = new List<(string, long)>();
        foreach (var entry in new DirectoryInfo(s.Path).EnumerateFileSystemInfos())
        {
            long size = 0;
            if (entry.LastWriteTime > newest) newest = entry.LastWriteTime;
            if (entry is FileInfo f)
            {
                size = f.Length;
                files++;
            }
            else if (entry is DirectoryInfo d && d.LinkTarget is null)
            {
                try
                {
                    foreach (var e in d.EnumerateFileSystemInfos("*", options))
                    {
                        if (e.LastWriteTime > newest) newest = e.LastWriteTime;
                        if (e is FileInfo ff) { size += ff.Length; files++; }
                    }
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            total += size;
            children.Add((entry.Name + (entry is DirectoryInfo ? "/" : ""), size));
        }
        s.Bytes = total;
        s.Files = files;
        s.LastWrite = newest;
        s.Largest.Clear();
        s.Largest.AddRange(children.OrderByDescending(c => c.Item2).Take(5));
    }

    /// <summary>
    /// Sets each session's Status from /proc: live, maybe-live (idle claude in the project), or stale.
    /// </summary>
    public static void UpdateLiveness(string root, IReadOnlyList<Session> sessions)
    {
        var prefix = root.TrimEnd('/') + "/";
        var owners = new Dictionary<string, string>(); // session path -> reason
        var claudes = new List<(int Pid, string Cwd, DateTime Start)>();
        var bootTime = BootTime();

        foreach (var proc in Directory.EnumerateDirectories("/proc"))
        {
            if (!int.TryParse(System.IO.Path.GetFileName(proc), out var pid))
                continue;
            string comm;
            try { comm = File.ReadAllText($"{proc}/comm").Trim(); }
            catch { continue; }

            var found = false;
            foreach (var target in Targets(proc))
            {
                if (!target.StartsWith(prefix, StringComparison.Ordinal))
                    continue;
                var parts = target[prefix.Length..].Split('/');
                if (parts.Length < 2)
                    continue;
                var key = prefix + parts[0] + "/" + parts[1];
                owners.TryAdd(key, $"{comm} (pid {pid}) has files open here");
                found = true;
            }

            if (comm == "claude" && !found && bootTime is { } boot)
            {
                try
                {
                    var cwd = new FileInfo($"{proc}/cwd").LinkTarget;
                    var stat = File.ReadAllText($"{proc}/stat");
                    var fields = stat[(stat.LastIndexOf(')') + 2)..].Split(' ');
                    var startTicks = long.Parse(fields[19], CultureInfo.InvariantCulture); // field 22 overall
                    if (cwd is not null)
                        claudes.Add((pid, cwd, boot.AddSeconds(startTicks / 100.0)));
                }
                catch { }
            }
        }

        foreach (var s in sessions)
        {
            if (owners.TryGetValue(s.Path, out var why))
            {
                s.Status = Liveness.Live;
                s.StatusReason = why;
                continue;
            }
            var candidate = claudes.FirstOrDefault(c => Slug(c.Cwd) == s.ProjectSlug && s.LastWrite >= c.Start);
            if (candidate.Pid != 0)
            {
                s.Status = Liveness.MaybeLive;
                s.StatusReason = $"claude (pid {candidate.Pid}) idle in this project since {candidate.Start:MMM d HH:mm}; folder written after that";
            }
            else
            {
                s.Status = Liveness.Stale;
                s.StatusReason = null;
            }
        }
    }

    /// <summary>True when some process holds a file or its working directory inside the folder right now.</summary>
    public static string? LiveOwner(string path)
    {
        var prefix = path.TrimEnd('/') + "/";
        foreach (var proc in Directory.EnumerateDirectories("/proc"))
        {
            if (!int.TryParse(System.IO.Path.GetFileName(proc), out var pid))
                continue;
            foreach (var target in Targets(proc))
                if (target.StartsWith(prefix, StringComparison.Ordinal) || target == path)
                    return $"pid {pid}";
        }
        return null;
    }

    static IEnumerable<string> Targets(string proc)
    {
        var list = new List<string>();
        try
        {
            if (new FileInfo($"{proc}/cwd").LinkTarget is { } cwd) list.Add(cwd);
            foreach (var fd in Directory.EnumerateFileSystemEntries($"{proc}/fd")) // fds on directories (tasks/) are dir symlinks
                if (new FileInfo(fd).LinkTarget is { } t) list.Add(t);
        }
        catch { } // other users' processes, or the process exited meanwhile
        return list;
    }

    static DateTime? BootTime()
    {
        try
        {
            var line = File.ReadLines("/proc/stat").First(l => l.StartsWith("btime "));
            return DateTimeOffset.FromUnixTimeSeconds(long.Parse(line[6..], CultureInfo.InvariantCulture)).LocalDateTime;
        }
        catch { return null; }
    }

    /// <summary>Claude Code's project slug: every character that is not a letter or digit becomes '-'.</summary>
    static string Slug(string path) => Regex.Replace(path, "[^A-Za-z0-9]", "-");

    /// <summary>
    /// Turns a slug back into a readable path. A '-' was either '/' or a literal character, so this walks the
    /// filesystem and prefers '/' wherever that names an existing directory; it falls back to the slug.
    /// </summary>
    static string ProjectPath(string slug)
    {
        var parts = slug.TrimStart('-').Split('-');
        string? Walk(string current, int i, string pending)
        {
            if (i == parts.Length)
                return pending.Length == 0 ? current : (Directory.Exists(current + "/" + pending) ? current + "/" + pending : null);
            var seg = pending.Length == 0 ? parts[i] : pending + "-" + parts[i];
            var asDir = current + "/" + seg;
            if (Directory.Exists(asDir) && Walk(asDir, i + 1, "") is { } done)
                return done;
            return Walk(current, i + 1, seg);
        }
        var path = Walk("", 0, "");
        if (path is null)
            return slug;
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return path == home ? "~" : path.StartsWith(home + "/") ? "~" + path[home.Length..] : path;
    }
}

/// <summary>fzf "v1"-style matcher: per term a forward scan for the end, a backward scan for the tightest start.</summary>
static class Fuzzy
{
    public static bool Match(string query, string text, out int score, HashSet<int> hits)
    {
        score = 0;
        hits.Clear();
        foreach (var raw in query.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            var caseSensitive = raw.Any(char.IsUpper);
            var cmp = caseSensitive ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
            if (raw[0] == '!')
            {
                if (raw.Length > 1 && text.Contains(raw[1..], cmp))
                    return false;
                continue;
            }
            if (!Term(raw, text, caseSensitive, out var s, hits))
                return false;
            score += s;
        }
        return true;
    }

    static bool Term(string pattern, string text, bool caseSensitive, out int score, HashSet<int> hits)
    {
        score = 0;
        char Norm(char c) => caseSensitive ? c : char.ToLowerInvariant(c);
        int p = 0, end = -1;
        for (var i = 0; i < text.Length && p < pattern.Length; i++)
            if (Norm(text[i]) == Norm(pattern[p]) && ++p == pattern.Length)
                end = i;
        if (end < 0)
            return false;
        p = pattern.Length - 1;
        var start = end;
        for (var i = end; i >= 0; i--)
            if (Norm(text[i]) == Norm(pattern[p]) && --p < 0) { start = i; break; }

        p = 0;
        var prev = -2;
        for (var i = start; i <= end && p < pattern.Length; i++)
        {
            if (Norm(text[i]) != Norm(pattern[p]))
                continue;
            score += 16;
            if (i == prev + 1) score += 12;                                   // consecutive
            if (i == 0 || "/-_. ".Contains(text[i - 1])) score += 10;         // word start
            if (prev >= 0) score -= Math.Min(i - prev - 1, 8);                 // gap
            hits.Add(i);
            prev = i;
            p++;
        }
        score -= (end - start) / 4;
        return true;
    }
}

static class Fmt
{
    public static string Size(long bytes)
    {
        string[] units = ["B", "K", "M", "G", "T"];
        double v = bytes;
        var u = 0;
        while (v >= 1024 && u < units.Length - 1) { v /= 1024; u++; }
        return u == 0 ? $"{bytes}B" : v >= 100 ? $"{v:0}{units[u]}" : $"{v:0.0}{units[u]}";
    }

    public static string SizeMarkup(long bytes)
    {
        var text = Size(bytes).PadLeft(6);
        return bytes >= 1L << 30 ? $"[bold red]{text}[/]" : bytes >= 100L << 20 ? $"[yellow]{text}[/]" : $"[gray]{text}[/]";
    }

    public static string Age(TimeSpan age) => age.TotalMinutes < 1 ? "now"
        : age.TotalHours < 1 ? $"{(int)age.TotalMinutes}m"
        : age.TotalDays < 1 ? $"{(int)age.TotalHours}h"
        : age.TotalDays < 14 ? $"{(int)age.TotalDays}d"
        : $"{(int)(age.TotalDays / 7)}w";

    public static string AgeMarkup(TimeSpan age)
    {
        var text = Age(age).PadLeft(4);
        return age.TotalDays >= 1 ? $"[cyan]{text}[/]" : age.TotalHours >= 1 ? $"[blue]{text}[/]" : $"[magenta]{text}[/]";
    }

    public static string Status(Liveness l) => l switch
    {
        Liveness.Live => "[bold green]● live [/]",
        Liveness.MaybeLive => "[yellow]◐ maybe[/]",
        _ => "[gray]○ stale[/]",
    };

    /// <summary>Text with the matched characters highlighted.</summary>
    public static string Highlight(string text, HashSet<int> hits, string baseStyle)
    {
        var sb = new StringBuilder($"[{baseStyle}]");
        for (var i = 0; i < text.Length; i++)
        {
            var ch = AnsiMarkup.Escape(text[i].ToString());
            sb.Append(hits.Contains(i) ? $"[bold yellow underline]{ch}[/]" : ch);
        }
        return sb.Append("[/]").ToString();
    }

    public static string Short(string id) => id.Length > 8 ? id[..8] : id;
}

/// <summary>A row in the picker: the session plus the highlight of the current match.</summary>
sealed record Row(Session Session, HashSet<int> Hits, int Score);

static class App
{
    public static int Run(Options o)
    {
        var sessions = Scanner.List(o.Root);
        if (o.List || o.DeleteAll)
            MeasureQuiet(sessions);
        else
            MeasureWithProgress(sessions);
        Scanner.UpdateLiveness(o.Root.FullName, sessions);

        var candidates = sessions
            .Where(s => s.Age >= o.OlderThan && s.Bytes >= o.MinSize && (o.ShowLive || s.Deletable))
            .ToList();
        var hiddenLive = sessions.Count(s => !s.Deletable) - candidates.Count(s => !s.Deletable);

        if (o.List)
            return PrintList(o, candidates, sessions.Count, hiddenLive);
        if (o.DeleteAll)
            return DeleteAll(o, candidates);
        return Picker.Run(o, candidates, sessions.Count, hiddenLive);
    }

    static void MeasureQuiet(List<Session> sessions) =>
        Parallel.ForEach(sessions, new ParallelOptions { MaxDegreeOfParallelism = 8 }, Scanner.Measure);

    static void MeasureWithProgress(List<Session> sessions)
    {
        var done = 0;
        var work = Task.Run(() => Parallel.ForEach(sessions, new ParallelOptions { MaxDegreeOfParallelism = 8 }, s =>
        {
            Scanner.Measure(s);
            Interlocked.Increment(ref done);
        }));
        var task = new ProgressTask($"Measuring {sessions.Count} session folders");
        Terminal.Live(
            new ProgressTaskGroup().Tasks([task]),
            onUpdate: () =>
            {
                task.Value = sessions.Count == 0 ? 1 : (double)Volatile.Read(ref done) / sessions.Count;
                return work.IsCompleted ? TerminalLoopResult.Stop : TerminalLoopResult.Continue;
            });
        work.GetAwaiter().GetResult();
    }

    static int PrintList(Options o, List<Session> list, int total, int hiddenLive)
    {
        list = Sort(list, o.Sort);
        switch (o.Format)
        {
            case OutputFormat.Paths:
                foreach (var s in list) Console.WriteLine(s.Path);
                break;
            case OutputFormat.Json:
                using (var json = new Utf8JsonWriter(Console.OpenStandardOutput(), new JsonWriterOptions { Indented = true }))
                {
                    json.WriteStartArray();
                    foreach (var s in list)
                    {
                        json.WriteStartObject();
                        json.WriteString("path", s.Path);
                        json.WriteString("project", s.Project);
                        json.WriteString("id", s.Id);
                        json.WriteNumber("bytes", s.Bytes);
                        json.WriteNumber("files", s.Files);
                        json.WriteString("lastWrite", s.LastWrite.ToString("O"));
                        json.WriteString("status", s.Status.ToString().ToLowerInvariant());
                        if (s.StatusReason is not null) json.WriteString("reason", s.StatusReason);
                        json.WriteEndObject();
                    }
                    json.WriteEndArray();
                }
                Console.WriteLine();
                break;
            default:
                var sb = new StringBuilder();
                sb.AppendLine($"[bold] status    size  age  project/session[/]");
                foreach (var s in list)
                    sb.AppendLine($" {Fmt.Status(s.Status)} {Fmt.SizeMarkup(s.Bytes)} {Fmt.AgeMarkup(s.Age)}  {AnsiMarkup.Escape(s.Project)}[gray]/{s.Id}[/]");
                var stale = list.Where(s => s.Deletable).ToList();
                sb.Append($"\n[bold]{stale.Count}[/] stale of {total} folders, [bold]{Fmt.Size(stale.Sum(s => s.Bytes))}[/] reclaimable");
                if (hiddenLive > 0) sb.Append($" [gray]({hiddenLive} live hidden; --show-live lists them)[/]");
                Terminal.WriteMarkup(sb.ToString());
                Terminal.WriteLine();
                break;
        }
        return 0;
    }

    static int DeleteAll(Options o, List<Session> list)
    {
        var failed = 0;
        long freed = 0;
        foreach (var s in list)
        {
            var (ok, message) = Deleter.Delete(o, s);
            Console.WriteLine(message);
            if (ok) freed += s.Bytes; else failed++;
        }
        Console.WriteLine($"{(o.DryRun ? "Would free" : "Freed")} {Fmt.Size(freed)} in {list.Count - failed} folders{(failed > 0 ? $"; {failed} skipped" : "")}.");
        return failed > 0 ? 1 : 0;
    }

    public static List<Session> Sort(IEnumerable<Session> list, SortKey key) => key switch
    {
        SortKey.Age => list.OrderBy(s => s.LastWrite).ToList(),
        SortKey.Name => list.OrderBy(s => s.Project, StringComparer.Ordinal).ThenBy(s => s.Id).ToList(),
        _ => list.OrderByDescending(s => s.Bytes).ToList(),
    };
}

static class Deleter
{
    /// <summary>Deletes one session folder after re-checking that it is inside root and not in use.</summary>
    public static (bool Ok, string Message) Delete(Options o, Session s)
    {
        var root = o.Root.FullName.TrimEnd('/');
        var full = Path.GetFullPath(s.Path);
        if (Path.GetDirectoryName(Path.GetDirectoryName(full)) != root)
            return (false, $"skipped {s.Path}: not a <project>/<session> folder under {root}");
        var info = new DirectoryInfo(full);
        if (!info.Exists)
            return (false, $"skipped {s.Path}: already gone");
        if (info.LinkTarget is not null)
            return (false, $"skipped {s.Path}: is a symlink");
        if (Scanner.LiveOwner(full) is { } owner)
            return (false, $"skipped {s.Path}: in use by {owner}");
        if (o.DryRun)
            return (true, $"would delete {s.Path} ({Fmt.Size(s.Bytes)})");
        try
        {
            info.Delete(recursive: true); // does not follow symlinks inside the tree
            return (true, $"deleted {s.Path} ({Fmt.Size(s.Bytes)})");
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return (false, $"failed {s.Path}: {e.Message}");
        }
    }
}

static class Picker
{
    public static int Run(Options o, List<Session> sessions, int total, int hiddenLive)
    {
        var all = sessions;
        var query = new State<string?>(o.Query);
        var sort = new State<SortKey>(o.Sort);
        var busy = new State<bool>(false);
        var results = new ConcurrentQueue<(Session Session, bool Ok, string Message)>();
        var deleted = new List<Session>();
        long freed = 0, batchBytes = 0;
        var batchOk = 0;
        var deferred = new Queue<Action>();
        var exit = false;
        string? lastQuery = null;
        SortKey? lastSort = null;
        var rows = new List<Row>();

        var list = new ListBox<Row>()
            .ItemTemplate(new DataTemplate<Row>(
                Display: static (DataTemplateValue<Row> value, in DataTemplateContext _) =>
                    new Markup(() => RowMarkup(value.GetValue())),
                Editor: null));

        Row? Current() => list.SelectedIndex >= 0 && list.SelectedIndex < list.Items.Count ? list.Items[list.SelectedIndex] : null;

        void Refilter()
        {
            var q = query.Value ?? "";
            var keep = Current()?.Session;
            rows.Clear();
            foreach (var s in all)
            {
                var hits = new HashSet<int>();
                if (q.Trim().Length == 0 || Fuzzy.Match(q, s.Haystack, out var score, hits))
                    rows.Add(new Row(s, hits, q.Trim().Length == 0 ? 0 : Fuzzy.Match(q, s.Haystack, out score, hits) ? score : 0));
            }
            var ordered = App.Sort(rows.Select(r => r.Session), sort.Value)
                .Select((s, i) => (s, i)).ToDictionary(x => x.s, x => x.i);
            var final = q.Trim().Length == 0
                ? rows.OrderBy(r => ordered[r.Session]).ToList()
                : rows.OrderByDescending(r => r.Score).ThenBy(r => ordered[r.Session]).ToList();
            list.Items.Clear();
            foreach (var r in final) list.Items.Add(r);
            var idx = keep is null ? 0 : final.FindIndex(r => r.Session == keep);
            list.SelectedIndex = final.Count == 0 ? -1 : Math.Max(0, idx);
        }

        void Move(int delta)
        {
            if (list.Items.Count == 0) return;
            list.SelectedIndex = Math.Clamp(list.SelectedIndex + delta, 0, list.Items.Count - 1);
        }

        void Toggle(int delta)
        {
            if (Current() is { Session: { Deletable: true } s }) s.Marked.Value = !s.Marked.Value;
            else if (Current() is { } r) ToastService.Warning($"{Fmt.Short(r.Session.Id)} is {r.Session.Status.ToString().ToLowerInvariant()}; it cannot be marked.");
            Move(delta);
        }

        IEnumerable<Session> Visible() => list.Items.Select(r => r.Session).Where(s => s.Deletable);

        var queryBox = new TextBox()
            .Text(query)
            .Placeholder("fuzzy filter: project or session id  (!term excludes)")
            .HorizontalAlignment(Align.Stretch);
        // The editor's own Ctrl+A (select all text) sits closer to focus and would shadow "mark all".
        queryBox.RemoveCommand("TextEditor.SelectAll");

        var details = new Markup(() => DetailsMarkup(Current()?.Session)).Wrap(true);

        var header = new Header()
            .Left(new Markup($"[bold primary]claude-tmp-gc[/] [gray]stale Claude Code session folders[/]"))
            .Right(new Markup($"[gray]{AnsiMarkup.Escape(o.Root.FullName)}[/]{(o.DryRun ? "  [bold warning]DRY RUN[/]" : "")}"));

        var footer = new Footer()
            .Left(new Markup(() =>
            {
                var marked = all.Where(s => s.Marked.Value).ToList();
                var markedText = marked.Count == 0 ? "[gray]nothing marked[/]" : $"[bold accent]{marked.Count} marked · {Fmt.Size(marked.Sum(s => s.Bytes))}[/]";
                return $"{markedText}  [gray]│[/]  {list.Items.Count}/{all.Count} shown  [gray]│[/]  sort: [primary]{sort.Value.ToString().ToLowerInvariant()}[/]"
                    + (busy.Value ? "  [gray]│[/]  [warning]deleting…[/]" : "")
                    + (deleted.Count > 0 ? $"  [gray]│[/]  [success]freed {Fmt.Size(freed)}[/]" : "");
            }))
            .Right(new Markup(() => hiddenLive > 0 && !o.ShowLive
                ? $"[gray]{hiddenLive} live/maybe-live hidden of {total}[/]"
                : $"[gray]{total} folders scanned[/]"));

        var leftPane = new DockLayout()
            .Top(new Group("Filter").Content(queryBox).HorizontalAlignment(Align.Stretch))
            .Content(new Group("Sessions").Content(list).HorizontalAlignment(Align.Stretch).VerticalAlignment(Align.Stretch));

        var body = new Grid()
            .Columns(
                new ColumnDefinition { Width = GridLength.Star(1) },
                new ColumnDefinition { Width = GridLength.Fixed(50) })
            .Rows(new RowDefinition { Height = GridLength.Star(1) })
            .Cell(leftPane, row: 0, column: 0)
            .Cell(new Group("Details").Content(details).HorizontalAlignment(Align.Stretch).VerticalAlignment(Align.Stretch), row: 0, column: 1);

        var root = new ToastHost(
                new DockLayout()
                    .Top(header)
                    .Content(body)
                    .Bottom(new VStack(new CommandBar(), footer).Spacing(0)))
            .Position(ToastPosition.TopRight)
            .MaxVisible(4);

        void Confirm()
        {
            if (busy.Value) { ToastService.Info("Still deleting; wait for it to finish."); return; }
            var targets = all.Where(s => s.Marked.Value).ToList();
            if (targets.Count == 0 && Current() is { Session: { Deletable: true } cur }) targets.Add(cur);
            if (targets.Count == 0) { ToastService.Warning("Nothing to delete: mark stale folders with Tab."); return; }

            Dialog? dialog = null;
            // Closing waits for the next UI tick: the key that confirmed also raises a text-input event,
            // and closing now would hand focus (and that 'y') back to the filter box first.
            void Close() => deferred.Enqueue(() => dialog!.Close());
            void Go()
            {
                Close();
                busy.Value = true;
                Task.Run(() =>
                {
                    foreach (var t in targets)
                    {
                        var (ok, msg) = Deleter.Delete(o, t);
                        results.Enqueue((t, ok, msg));
                    }
                    results.Enqueue((null!, true, "done"));
                });
            }
            var sum = targets.Sum(t => t.Bytes);
            var lines = string.Join("\n", targets.Take(8).Select(t => $"  {Fmt.SizeMarkup(t.Bytes)}  {AnsiMarkup.Escape(t.Project)}[gray]/{Fmt.Short(t.Id)}[/]"));
            if (targets.Count > 8) lines += $"\n  [gray]… and {targets.Count - 8} more[/]";
            dialog = new Dialog()
                .Title(o.DryRun ? "Dry run" : "Delete folders?")
                .IsModal(true)
                .Padding(1)
                .Width(64)
                .Content(new VStack(
                        new Markup($"{(o.DryRun ? "Simulate deleting" : "Permanently delete")} [bold]{targets.Count}[/] folder{(targets.Count == 1 ? "" : "s")}, [bold red]{Fmt.Size(sum)}[/]:"),
                        new Markup(lines),
                        new Markup("[gray]Each folder is checked for open files again right before it is deleted.[/]").Wrap(true),
                        new HStack(
                                new Button(o.DryRun ? "Simulate (y)" : "Delete (y)").Click(Go),
                                new Button("Cancel (n/Esc)").Click(Close))
                            .Spacing(2))
                    .Spacing(1));
            // Commands, not KeyDown: a command consumes the key, so the 'y' does not also reach the
            // filter box that gets focus back when the dialog closes.
            dialog.AddCommand(Cmd("Gc.Confirm", o.DryRun ? "[warning]simulate[/]" : "[error]delete[/]", new KeyGesture('y'), Go));
            dialog.AddCommand(Cmd("Gc.Cancel", "cancel", new KeyGesture('n'), Close));
            dialog.AddCommand(Cmd("Gc.CancelEsc", "cancel", new KeyGesture(TerminalKey.Escape), Close));
            dialog.Show();
        }

        UiCommand Cmd(string id, string label, KeyGesture gesture, Action run, bool show = true) => new()
        {
            Id = id,
            LabelMarkup = label,
            Gesture = gesture,
            Execute = _ => run(),
            Presentation = show ? CommandPresentation.CommandBar : CommandPresentation.None,
        };

        root.AddCommand(Cmd("Gc.Down", "down", new KeyGesture(TerminalKey.Down), () => Move(1), show: false));
        root.AddCommand(Cmd("Gc.Up", "up", new KeyGesture(TerminalKey.Up), () => Move(-1), show: false));
        root.AddCommand(Cmd("Gc.PageDown", "page down", new KeyGesture(TerminalKey.PageDown), () => Move(10), show: false));
        root.AddCommand(Cmd("Gc.PageUp", "page up", new KeyGesture(TerminalKey.PageUp), () => Move(-10), show: false));
        root.AddCommand(Cmd("Gc.Mark", "mark", new KeyGesture(TerminalKey.Tab), () => Toggle(1)));
        root.AddCommand(Cmd("Gc.MarkUp", "mark ↑", new KeyGesture(TerminalKey.Tab, TerminalModifiers.Shift), () => Toggle(-1), show: false));
        root.AddCommand(Cmd("Gc.All", "all", new KeyGesture(TerminalChar.CtrlA, TerminalModifiers.Ctrl), () =>
        {
            var visible = Visible().ToList();
            var value = !visible.All(s => s.Marked.Value);
            foreach (var s in visible) s.Marked.Value = value;
        }));
        root.AddCommand(Cmd("Gc.Invert", "invert", new KeyGesture(TerminalChar.CtrlT, TerminalModifiers.Ctrl), () =>
        {
            foreach (var s in Visible()) s.Marked.Value = !s.Marked.Value;
        }));
        root.AddCommand(Cmd("Gc.Sort", "sort", new KeyGesture(TerminalChar.CtrlS, TerminalModifiers.Ctrl), () =>
            sort.Value = (SortKey)(((int)sort.Value + 1) % 3)));
        root.AddCommand(Cmd("Gc.Delete", "[error]delete[/]", new KeyGesture(TerminalKey.Enter), Confirm));
        root.AddCommand(Cmd("Gc.Escape", "clear/quit", new KeyGesture(TerminalKey.Escape), () =>
        {
            if (!string.IsNullOrEmpty(query.Value)) query.Value = "";
            else exit = true;
        }));

        var started = false;
        Terminal.Run(root, () =>
        {
            if (!started)
            {
                started = true;
                queryBox.App?.Focus(queryBox);
            }
            while (deferred.TryDequeue(out var action))
                action();
            while (results.TryDequeue(out var r))
            {
                if (r.Session is null)
                {
                    busy.Value = false;
                    if (batchOk > 0)
                        ToastService.Success(o.DryRun
                            ? $"Dry run: would delete {batchOk} folder{(batchOk == 1 ? "" : "s")}, {Fmt.Size(batchBytes)}."
                            : $"Deleted {batchOk} folder{(batchOk == 1 ? "" : "s")}, freed {Fmt.Size(batchBytes)}."
                              + (all.Count(s => s.Deletable) == 0 ? " No stale folders left." : ""));
                    batchOk = 0;
                    batchBytes = 0;
                    continue;
                }
                if (r.Ok)
                {
                    batchOk++;
                    batchBytes += r.Session.Bytes;
                }
                if (r.Ok)
                {
                    if (!o.DryRun)
                    {
                        deleted.Add(r.Session);
                        freed += r.Session.Bytes;
                        all.Remove(r.Session);
                        lastQuery = null; // force refilter
                    }
                    r.Session.Marked.Value = false;
                }
                else ToastService.Error(r.Message);
            }
            if (lastQuery != query.Value || lastSort != sort.Value)
            {
                lastQuery = query.Value;
                lastSort = sort.Value;
                Refilter();
            }
            return exit ? TerminalLoopResult.Stop : TerminalLoopResult.Continue;
        });

        if (deleted.Count > 0)
            Terminal.WriteMarkup($"[green]Deleted {deleted.Count} folder{(deleted.Count == 1 ? "" : "s")}, freed {Fmt.Size(freed)}.[/]\n");
        else
            Terminal.WriteMarkup("[gray]Nothing deleted.[/]\n");
        return 0;
    }

    static string RowMarkup(Row r)
    {
        var s = r.Session;
        var mark = !s.Deletable ? "[gray]🔒[/]" : s.Marked.Value ? "[bold red]◉[/]" : "[gray]○[/]";
        var projectLen = s.Project.Length;
        var projectHits = r.Hits.Where(i => i < projectLen).ToHashSet();
        var idHits = r.Hits.Where(i => i > projectLen).Select(i => i - projectLen - 1).ToHashSet();
        var project = Fmt.Highlight(s.Project, projectHits, s.Marked.Value ? "bold" : "default");
        var id = Fmt.Highlight(s.Id, idHits, "gray");
        return $"{mark} {Fmt.SizeMarkup(s.Bytes)} {Fmt.AgeMarkup(s.Age)}  {project}[gray]/[/]{id}";
    }

    static string DetailsMarkup(Session? s)
    {
        if (s is null) return "[gray]No folder matches the filter.[/]";
        var sb = new StringBuilder();
        sb.AppendLine($"[bold]{AnsiMarkup.Escape(s.Project)}[/]");
        sb.AppendLine($"[gray]{s.Id}[/]");
        sb.AppendLine();
        sb.AppendLine($"status     {Fmt.Status(s.Status)}");
        if (s.StatusReason is not null) sb.AppendLine($"[gray]{AnsiMarkup.Escape(s.StatusReason)}[/]");
        sb.AppendLine($"size       {Fmt.SizeMarkup(s.Bytes).Trim()} [gray]in {s.Files:N0} files[/]");
        sb.AppendLine($"last write {s.LastWrite:yyyy-MM-dd HH:mm} [gray]({Fmt.Age(s.Age)} ago)[/]");
        sb.AppendLine();
        sb.AppendLine("[bold]largest entries[/]");
        if (s.Largest.Count == 0) sb.AppendLine("  [gray](empty)[/]");
        foreach (var (name, bytes) in s.Largest)
            sb.AppendLine($"  {Fmt.SizeMarkup(bytes)}  {AnsiMarkup.Escape(name)}");
        sb.AppendLine();
        sb.Append($"[gray]{AnsiMarkup.Escape(s.Path)}[/]");
        return sb.ToString();
    }
}
