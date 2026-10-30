// git-verify-rebase: before a force-push, checks that a rebased branch still
// makes the changes its pushed version made. Behind the git aliases
// `verify-rebase` and `rbv`; `git verify-rebase -h` lists the options (with
// --help git looks for a man page instead).
//
// Two checks, neither of which touches the work tree or the index:
//
//   content   the pushed commits' changes (old fork point -> pushed tip) are
//             replayed onto the new fork point with `git merge-tree`, and the
//             result is compared with the rebased tip, file by file. Equal
//             means the rebase moved the branch and changed nothing else.
//   commits   pushed and rebased commits are paired by their patch -- zero
//             context and no line numbers, so a hunk that moved is the same
//             patch -- then by subject, and reported as same, reworded,
//             changed, squashed, already upstream, dropped or added, with the
//             files whose changes differ.
//
// The fork points are the merge-bases of either tip with --base (origin/HEAD
// unless given). With --stack, or several branches, the branches are a stack
// of merge requests, each checked as one on the branch below it: its pushed
// version starts at the version of that branch it was built on -- `git
// merge-base --fork-point` finds that in the reflogs, even once it was
// force-pushed -- and is replayed onto that branch as rebased.
//
// merge-tree --write-tree leaves the replayed trees in the object store,
// unreferenced, for gc to collect. Needs git 2.40, for merge-tree
// --merge-base. On WSL a repository on a Windows drive is handed to Windows'
// git.exe, as the wsl-git shim does; WSL_GIT and WINDOWS_GIT work as there.
#:package System.CommandLine@2.0.14
#:package Spectre.Console@0.57.2
#:property PublishAot=false

using System.CommandLine;
using System.CommandLine.Help;
using System.CommandLine.Invocation;
using System.CommandLine.Parsing;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Spectre.Console;
using Spectre.Console.Rendering;

return Cli.Run(args);

// ─── command line ────────────────────────────────────────────────────────────

static class ExitCodes
{
    public const int Same = 0, Differs = 1, Error = 2;
}

sealed record Settings(
    IReadOnlyList<string> Branches, bool Stack, string? Remote, string? Base, string? OldBase, string? NewBase,
    string Repo, bool Diff, int Context, bool Strict, bool CheckRemote, bool Verbose)
{
    // Several branches are a stack too.
    public bool IsStack => Stack || Branches.Count > 1;
}

static class Cli
{
    public const string Name = "git verify-rebase";

    public static int Run(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        // The parser's own messages in English, like the rest.
        CultureInfo.CurrentUICulture = CultureInfo.InvariantCulture;
        var defaults = new Dictionary<Symbol, string>();

        var local = new Argument<string[]>("local")
        {
            Description = "The rebased branch or commit to check. Several branches are a stack of merge requests, named bottom first: see --stack.",
            Arity = ArgumentArity.ZeroOrMore,
            DefaultValueFactory = _ => ["HEAD"],
        };
        defaults[local] = "HEAD, the checked-out branch";

        var stack = new Option<bool>("--stack")
        {
            Description = "Check a stack of merge requests: <local> as the top one, and below it the local branches with a pushed version, down to --base. "
                + "Each is checked as a merge request on the branch below it, so its report shows only what the rebase changed in it.",
        };

        var remote = new Option<string?>("--remote", "-r")
        {
            Description = "The pushed version from before the rebase: what --force-with-lease would overwrite.",
            HelpName = "ref",
        };
        defaults[remote] = "the push destination of <local>, else origin/<branch>, else its upstream";

        var @base = new Option<string?>("--base", "-b")
        {
            Description = "The branch <local> was rebased onto -- for a stack, the one its bottom merge request targets. Both versions' fork points are their merge-bases with it.",
            HelpName = "ref",
        };
        defaults[@base] = "<remote>/HEAD, else <remote>/main, <remote>/master, main, master";

        var oldBase = new Option<string?>("--old-base")
        {
            Description = "Where the pushed version starts, when its merge-base with --base is not it -- e.g. after a rebase --onto another branch.",
            HelpName = "commit",
        };
        defaults[oldBase] = "merge-base of --remote and --base";

        var newBase = new Option<string?>("--new-base")
        {
            Description = "Where the rebased version starts, when its merge-base with --base is not it.",
            HelpName = "commit",
        };
        defaults[newBase] = "merge-base of <local> and --base";

        var diff = new Option<bool>("--diff", "-d")
        {
            Description = "Show what differs: each differing file as the rebased branch has it against a clean replay, each changed commit's old patch against its new one.",
        };

        var context = new Option<int>("--context", "-U")
        {
            Description = "Lines of context around each change in the --diff output.",
            HelpName = "lines",
            DefaultValueFactory = _ => 3,
            CustomParser = result =>
            {
                var token = result.Tokens.Single().Value;
                if (!int.TryParse(token, out var lines))
                    result.AddError($"--context takes a number of lines, not '{token}'.");
                else if (lines is < 0 or > 10_000)
                    result.AddError($"--context must be between 0 and 10000 lines, not {lines}.");
                return lines;
            },
        };
        defaults[context] = "3";

        var strict = new Option<bool>("--strict", "-s")
        {
            Description = "Also fail when the content matches but the commits do not: squashed, split, reordered, dropped or added commits, or changed patches.",
        };

        var checkRemote = new Option<bool>("--check-remote")
        {
            Description = "Ask the remote (git ls-remote) whether the branch is still where your last fetch saw it. If someone pushed since, the lease is stale and the push would be rejected.",
        };

        var repo = new Option<string>("--repo", "-C")
        {
            Description = "The repository to work in.",
            HelpName = "path",
            DefaultValueFactory = _ => ".",
        };
        defaults[repo] = "the current directory";

        var noColor = new Option<bool>("--no-color")
        {
            Description = "Plain output without colors; NO_COLOR in the environment does the same.",
        };

        var verbose = new Option<bool>("--verbose", "-v")
        {
            Description = "Print every git command as it runs, with its exit code and duration.",
        };

        var root = new RootCommand(
            "Checks that a rebased branch still makes the changes its pushed version made, before you force-push it.")
        {
            local, stack, remote, @base, oldBase, newBase, diff, context, strict, checkRemote, repo, noColor, verbose,
        };
        root.Options.Remove(root.Options.OfType<VersionOption>().Single());
        root.Options.OfType<HelpOption>().Single().Description = "Show this help.";

        foreach (var (option, example) in new[] { (remote, "origin/feature"), (@base, "origin/main"), (oldBase, "a1b2c3d"), (newBase, "a1b2c3d") })
            option.Validators.Add(result =>
            {
                var value = result.GetValueOrDefault<string?>();
                if (string.IsNullOrWhiteSpace(value))
                    result.AddError($"{option.Name} needs a ref, e.g. {option.Name} {example}.");
                else if (value.StartsWith('-'))
                    result.AddError($"{option.Name} needs a ref, and '{value}' looks like an option: e.g. {option.Name} {example}.");
            });
        repo.Validators.Add(result =>
        {
            var path = result.GetValueOrDefault<string>();
            if (!Directory.Exists(FromCaller(path)))
                result.AddError($"--repo: there is no directory '{path}'. Pass a directory inside the repository, or leave --repo out to use the current one.");
        });
        // Here rather than on <local>, whose validators do not run once it takes several values.
        root.Validators.Add(result =>
        {
            var branches = result.GetValue(local)!;
            foreach (var value in branches)
                if (value.StartsWith('-'))
                    result.AddError($"Unknown option '{value}'.{Suggest(value, root)}");
                else if (string.IsNullOrWhiteSpace(value))
                    result.AddError("<local> is empty: name a branch or commit, or leave it out to check HEAD.");
            if (result.GetResult(context) is { Implicit: false } && !result.GetValue(diff))
                result.AddError("--context only shapes the --diff output: add --diff, or leave --context out.");
            // An unknown option is no second branch.
            if (!result.GetValue(stack) && branches.Count(b => !b.StartsWith('-')) < 2) return;
            foreach (var (option, what) in new[]
            {
                (remote, "names one branch's pushed version; in a stack each branch's is found by its name"),
                (oldBase, "says where one branch's pushed version starts; in a stack each starts where it was built on the branch below it"),
                (newBase, "says where one rebased branch starts; in a stack each starts at the branch below it"),
            })
                if (result.GetResult(option) is { Implicit: false })
                    result.AddError($"{option.Name} {what}. Leave it out, or check that branch alone: {Name} <branch> {option.Name} <{option.HelpName}>.");
        });

        root.Options.OfType<HelpOption>().Single().Action = new HelpPage(root, defaults);
        root.SetAction(result => Verifier.Run(new Settings(
            result.GetValue(local)!, result.GetValue(stack), result.GetValue(remote), result.GetValue(@base),
            result.GetValue(oldBase), result.GetValue(newBase), FromCaller(result.GetValue(repo)!),
            result.GetValue(diff), result.GetValue(context), result.GetValue(strict),
            result.GetValue(checkRemote), result.GetValue(verbose))));

        Ui.Configure(noColor: args.Contains("--no-color"));
        try
        {
            var parsed = root.Parse(args);
            if (parsed.Action is ParseErrorAction)
            {
                Ui.UsageErrors(parsed.Errors.Select(e => Explain(e, root)));
                return ExitCodes.Error;
            }
            return parsed.Invoke(new InvocationConfiguration { EnableDefaultExceptionHandler = false });
        }
        catch (Exception error)
        {
            Ui.Crash(error, args.Contains("--verbose") || args.Contains("-v"));
            return ExitCodes.Error;
        }
    }

    // The parser's message, or a plainer one where it only says what is wrong.
    static string Explain(ParseError error, Command command)
    {
        if (error.SymbolResult is OptionResult { Option: var option } result
            && result.Tokens.Count == 0 && option.ValueType != typeof(bool))
            return $"{option.Name} needs a value: {option.Name} <{option.HelpName}>.";
        var unmatched = Regex.Match(error.Message, "^Unrecognized command or argument '(-.*)'");
        if (!unmatched.Success) return error.Message;
        var token = unmatched.Groups[1].Value;
        return $"Unknown option '{token}'.{Suggest(token, command)}";
    }

    // A git alias starts in the top of the repository and says in GIT_PREFIX
    // where it was run, which is what a relative --repo is relative to.
    static string FromCaller(string path) =>
        Path.GetFullPath(Path.Combine(Environment.GetEnvironmentVariable("GIT_PREFIX") ?? "", path));

    // " Did you mean --diff?" for a mistyped option, or "" when nothing is close.
    static string Suggest(string token, Command command)
    {
        var name = token.Split('=', 2)[0];
        var best = command.Options
            .SelectMany(o => o.Aliases.Prepend(o.Name))
            .Where(a => a.StartsWith('-'))
            .Select(a => (Alias: a, Distance: Levenshtein(name, a)))
            .OrderBy(x => x.Distance)
            .FirstOrDefault();
        return best.Alias is not null && best.Distance <= Math.Max(2, name.Length / 3)
            ? $" Did you mean {best.Alias}?"
            : $" Run '{Name} -h' for the options.";
    }

    static int Levenshtein(string a, string b)
    {
        var row = Enumerable.Range(0, b.Length + 1).ToArray();
        for (var i = 1; i <= a.Length; i++)
        {
            var diagonal = row[0];
            row[0] = i;
            for (var j = 1; j <= b.Length; j++)
            {
                var above = row[j];
                row[j] = Math.Min(Math.Min(row[j] + 1, row[j - 1] + 1), diagonal + (a[i - 1] == b[j - 1] ? 0 : 1));
                diagonal = above;
            }
        }
        return row[b.Length];
    }
}

sealed class HelpPage(RootCommand root, IReadOnlyDictionary<Symbol, string> defaults) : SynchronousCommandLineAction
{
    public override int Invoke(ParseResult parseResult)
    {
        var c = Ui.Out;
        c.WriteLine();
        c.MarkupLine($"[bold deepskyblue1]{Cli.Name}[/] [grey]· is the rebased branch still the branch you pushed?[/]");
        c.WriteLine();
        c.Write(new Padder(new Markup(Markup.Escape(root.Description ?? "")), new Padding(2, 0, 0, 0)));

        Section(c, "Usage");
        var usage = Table();
        foreach (var (command, rest, what) in new[]
        {
            (Cli.Name, " [<local>] [options]", ""),
            (Cli.Name, " --stack [<top>] [options]", "a stack of merge requests, found below <top>"),
            (Cli.Name, " <bottom> … <top> [options]", "a stack of merge requests, named bottom first"),
            ("git rbv", " …", "the same, shorter"),
        })
            usage.AddRow(new Markup($"[bold]{command}[/]{Markup.Escape(rest)}"), new Markup($"[grey]{Markup.Escape(what)}[/]"));
        c.Write(usage);

        Section(c, "Arguments");
        var arguments = Table();
        foreach (var argument in root.Arguments)
            arguments.AddRow(
                new Markup($"[bold]<{Markup.Escape(argument.Name)}>{(argument.Arity.MaximumNumberOfValues > 1 ? "…" : "")}[/]"),
                Describe(argument, argument.Description));
        c.Write(arguments);

        Section(c, "Options");
        var options = Table();
        foreach (var option in root.Options.Where(o => !o.Hidden))
        {
            var aliases = option is HelpOption
                ? ["-h", "--help"]
                : option.Aliases.Prepend(option.Name).OrderBy(a => a.StartsWith("--")).ToArray();
            var value = option.ValueType != typeof(bool) && option is not HelpOption ? $" [grey]<{Markup.Escape(option.HelpName ?? "value")}>[/]" : "";
            options.AddRow(new Markup($"[bold]{string.Join(", ", aliases)}[/]{value}"), Describe(option, option.Description));
        }
        c.Write(options);

        Section(c, "How it decides");
        Numbered(c,
            "The fork points are the merge-bases of the pushed and the rebased tip with --base. "
                + "The pushed commits run from the old one to --remote, the rebased ones from the new one to <local>.",
            "[bold]Content[/]: the pushed changes are replayed onto the new fork point with `git merge-tree`, without "
                + "touching the work tree, and the result is compared with <local> file by file. Equal means the rebase "
                + "moved the branch and changed nothing else.",
            "[bold]Commits[/]: pushed and rebased commits are paired by their patch -- zero context, no line numbers, so "
                + "a hunk that moved is still the same patch -- then by subject. Reworded commits pass; changed, squashed, "
                + "dropped, added and reordered ones are listed with the files whose changes differ.",
            "[bold]Stacks[/]: with --stack, or several branches, each branch is checked as a merge request on the one below "
                + "it. Its pushed version starts at the version of that branch it was built on -- `git merge-base --fork-point` "
                + "finds it in the reflogs, even once it was force-pushed -- and is replayed onto that branch as rebased, so each "
                + "report shows only what the rebase changed in that merge request. The exit code is the worst of them.");

        Section(c, "Exit codes");
        var codes = Table();
        codes.AddRow(new Markup("[green bold]0[/]"), new Markup(
            "The content and the commits match (rewording aside), or nothing was rewritten. With the content equal but the "
            + "commits not, also 0 -- unless --strict."));
        codes.AddRow(new Markup("[red bold]1[/]"), new Markup(
            "Something differs: files, lost commits, conflict resolutions to review, a remote that moved (--check-remote), "
            + "or with --strict the commits."));
        codes.AddRow(new Markup("[red bold]2[/]"), new Markup(
            "Could not verify: an invalid command line, an unknown ref, no repository, or git failed. The message says what to do."));
        c.Write(codes);

        Section(c, "Examples");
        foreach (var (command, what) in new[]
        {
            ($"{Cli.Name}", "the checked-out branch against what you pushed"),
            ($"{Cli.Name} --diff", "the same, and show what differs"),
            ($"{Cli.Name} feature -b origin/develop", "feature, which was rebased onto develop"),
            ($"{Cli.Name} --stack -b origin/develop", "the stack of merge requests below the checked-out branch, the bottom one into develop"),
            ($"{Cli.Name} mr-1 mr-2 mr-3 --diff", "a stack named bottom first, and show what differs"),
            ($"{Cli.Name} -r origin/feature-v1", "against a branch pushed under another name"),
            ($"{Cli.Name} --old-base v1.2 -b origin/main", "after git rebase --onto origin/main v1.2"),
            ($"{Cli.Name} --strict --check-remote", "fail on any commit difference, and on a stale lease"),
        })
        {
            c.MarkupLine($"  [deepskyblue1]{Markup.Escape(command)}[/]");
            c.MarkupLine($"      [grey]{Markup.Escape(what)}[/]");
        }

        Section(c, "Environment");
        var environment = Table();
        environment.AddRow(new Markup("[bold]NO_COLOR[/]"), new Markup("Set to anything: no colors, as --no-color."));
        environment.AddRow(new Markup("[bold]COLUMNS[/]"), new Markup(
            "The width of output that goes to a file or a pipe, which is otherwise 80 columns; a terminal has its own."));
        environment.AddRow(new Markup("[bold]WSL_GIT[/]"), new Markup(
            "On WSL, [bold]windows[/] or [bold]linux[/] picks the git to run. Unset, a repository under /mnt/<drive> "
            + "gets Windows' git.exe, which is much faster there, and any other Linux's git."));
        environment.AddRow(new Markup("[bold]WINDOWS_GIT[/]"), new Markup(
            "Windows' git.exe, if not at /mnt/c/Program Files/Git/cmd/git.exe."));
        c.Write(environment);
        c.WriteLine();
        return ExitCodes.Same;
    }

    IRenderable Describe(Symbol symbol, string? description)
    {
        var text = Ui.Code(description ?? "");
        if (defaults.TryGetValue(symbol, out var value)) text += $"\n[grey]default: {Markup.Escape(value)}[/]";
        return new Markup(text);
    }

    static Grid Table()
    {
        var grid = new Grid();
        grid.AddColumn(new GridColumn().NoWrap().PadLeft(2).PadRight(3));
        grid.AddColumn(new GridColumn());
        return grid;
    }

    static void Section(IAnsiConsole c, string title)
    {
        c.WriteLine();
        c.MarkupLine($"[bold yellow]{title.ToUpperInvariant()}[/]");
    }

    static void Numbered(IAnsiConsole c, params string[] items)
    {
        var grid = Table();
        for (var i = 0; i < items.Length; i++)
            grid.AddRow(new Markup($"[bold]{i + 1}.[/]"), new Markup(Ui.Code(items[i], escape: false)));
        c.Write(grid);
    }
}

// ─── console ─────────────────────────────────────────────────────────────────

class UserError(string message, string? detail = null, params string[] hints) : Exception(message)
{
    public string? Detail { get; } = detail;
    public string[] Hints { get; } = hints;
}

static class Ui
{
    public static IAnsiConsole Out { get; private set; } = AnsiConsole.Console;
    public static IAnsiConsole Err { get; private set; } = AnsiConsole.Console;

    public static void Configure(bool noColor)
    {
        var colors = noColor ? ColorSystemSupport.NoColors : ColorSystemSupport.Detect;
        Out = AnsiConsole.Create(new AnsiConsoleSettings { ColorSystem = colors, Out = new AnsiConsoleOutput(Console.Out) });
        Err = AnsiConsole.Create(new AnsiConsoleSettings { ColorSystem = colors, Out = new AnsiConsoleOutput(Console.Error) });
        // Piped, the output is 80 columns wide, unless COLUMNS says otherwise.
        if (int.TryParse(Environment.GetEnvironmentVariable("COLUMNS"), out var columns) && columns > 0)
        {
            if (Console.IsOutputRedirected) Out.Profile.Width = columns;
            if (Console.IsErrorRedirected) Err.Profile.Width = columns;
        }
    }

    public static string E(string text) => Markup.Escape(text);

    public static string Short(string sha) => sha[..Math.Min(8, sha.Length)];

    // Escapes the text for markup and highlights its `code` spans.
    public static string Code(string text, bool escape = true) =>
        Regex.Replace(escape ? Markup.Escape(text) : text, "`([^`]+)`", m => $"[deepskyblue1]{m.Groups[1].Value}[/]");

    public static void UsageErrors(IEnumerable<string> errors)
    {
        var rows = new List<IRenderable> { new Markup("[bold]The command line is not valid.[/]") };
        rows.AddRange(errors.Distinct().Select(e => new Markup($"[red]•[/] {E(e)}")));
        rows.Add(new Markup($"[yellow]→[/] [deepskyblue1]{Cli.Name} -h[/] lists the options, with examples."));
        Err.Write(Box("✘ invalid usage", Color.Red, rows));
    }

    public static void Fail(UserError error) => Err.Write(ErrorBox(error));

    public static Panel ErrorBox(UserError error)
    {
        var rows = new List<IRenderable> { new Markup($"[bold]{E(error.Message)}[/]") };
        if (!string.IsNullOrWhiteSpace(error.Detail))
            rows.Add(new Padder(new Text(error.Detail.Trim(), new Style(Color.Grey)), new Padding(2, 0, 0, 0)));
        rows.AddRange(error.Hints.Select(h => new Markup($"[yellow]→[/] {Code(h)}")));
        return Box("✘ cannot verify", Color.Red, rows);
    }

    // A command to copy, on one line however long: the terminal wraps it, so
    // that a copy of it is still one line, with no box border in it.
    public static void Command(IAnsiConsole c, string command)
    {
        var width = c.Profile.Width;
        c.Profile.Width = Math.Max(width, command.Length + 4);
        c.MarkupLine($"   [deepskyblue1]{E(command)}[/]");
        c.Profile.Width = width;
    }

    public static void Crash(Exception error, bool verbose)
    {
        Err.Write(Box("✘ unexpected error", Color.Red, [
            new Markup($"[bold]{E(error.GetType().Name)}: {E(error.Message)}[/]"),
            new Markup(verbose
                ? "[yellow]→[/] This is a bug in git-verify-rebase; the stack trace follows."
                : "[yellow]→[/] Run again with [deepskyblue1]--verbose[/] for the git commands and a stack trace."),
        ]));
        if (verbose) Err.WriteException(error, ExceptionFormats.ShortenPaths);
    }

    public static Panel Box(string title, Color color, IEnumerable<IRenderable> rows) =>
        new Panel(new Rows(rows))
            .Header($"[bold {color.ToMarkup()}] {E(title)} [/]")
            .Border(BoxBorder.Rounded)
            .BorderColor(color)
            .Padding(1, 0, 1, 0)
            .Expand();
}

// ─── git ─────────────────────────────────────────────────────────────────────

sealed record GitResult(IReadOnlyList<string> Args, int ExitCode, string Out, string Err);

sealed class GitError(GitResult result) : UserError(
    $"git {result.Args.FirstOrDefault()} failed with exit code {result.ExitCode}.",
    result.Err,
    HintFor(result.Err))
{
    static string[] HintFor(string stderr) => stderr switch
    {
        _ when stderr.Contains("dubious ownership") =>
            ["git does not trust a repository another user owns; its message above says how to mark it safe."],
        _ when stderr.Contains("not a git repository") =>
            ["Run this inside the repository, or point to it with `--repo <path>`."],
        _ => ["Run again with `--verbose` to see every git command and its output."],
    };
}

sealed class Git
{
    static readonly Version Required = new(2, 40);
    readonly bool _verbose;

    public string Exe { get; }
    public string Dir { get; }
    public Version Version { get; private set; } = new();

    Git(string exe, string dir, bool verbose) => (Exe, Dir, _verbose) = (exe, dir, verbose);

    public static Git Open(string dir, bool verbose)
    {
        var full = Path.GetFullPath(dir);
        var git = new Git(PickExecutable(full), full, verbose);

        var version = Regex.Match(git.Run("version").Out, @"(\d+)\.(\d+)(?:\.(\d+))?");
        git.Version = version.Success
            ? new Version(int.Parse(version.Groups[1].Value), int.Parse(version.Groups[2].Value),
                version.Groups[3].Success ? int.Parse(version.Groups[3].Value) : 0)
            : new Version();
        if (git.Version < Required)
            throw new UserError(
                $"{git.Exe} is version {git.Version}; this needs git {Required} or newer, for `git merge-tree --merge-base`.",
                null,
                "Update git -- on Ubuntu: `sudo add-apt-repository ppa:git-core/ppa && sudo apt install git`.");

        var repository = git.Try("rev-parse", "--git-dir");
        if (repository.ExitCode != 0)
            throw new UserError(
                $"{full} is not inside a git repository.",
                repository.Err,
                "Run this inside the repository of the rebased branch, or point to it with `--repo <path>`.");
        return git;
    }

    // Windows' git.exe for a repository on a Windows drive under WSL, as the
    // wsl-git shim picks it; Linux git reads those drives over 9p, slowly.
    static string PickExecutable(string dir)
    {
        if (!OperatingSystem.IsLinux() || !File.Exists("/proc/sys/fs/binfmt_misc/WSLInterop")) return "git";
        var mode = Environment.GetEnvironmentVariable("WSL_GIT") ?? "auto";
        var windowsGit = Environment.GetEnvironmentVariable("WINDOWS_GIT") ?? "/mnt/c/Program Files/Git/cmd/git.exe";
        var onWindowsDrive = Regex.IsMatch(dir, "^/mnt/[a-zA-Z](/|$)");
        return mode != "linux" && File.Exists(windowsGit) && (mode == "windows" || onWindowsDrive) ? windowsGit : "git";
    }

    public GitResult Run(params IEnumerable<string> args)
    {
        var result = Try(args);
        return result.ExitCode == 0 ? result : throw new GitError(result);
    }

    public GitResult Try(params IEnumerable<string> args) => Try(args.ToList(), null);

    public GitResult Try(IReadOnlyList<string> args, TimeSpan? timeout)
    {
        var start = new ProcessStartInfo(Exe)
        {
            WorkingDirectory = Dir,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = new UTF8Encoding(false),
            StandardErrorEncoding = new UTF8Encoding(false),
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        // Paths as they are, no colors whatever the config says, no signature checks in the log.
        foreach (var arg in (string[])["-c", "core.quotePath=false", "-c", "color.ui=false", "-c", "log.showSignature=false"])
            start.ArgumentList.Add(arg);
        foreach (var arg in args) start.ArgumentList.Add(arg);
        // No credential prompt can hang ls-remote; git.exe sees the variable only through WSLENV.
        start.Environment["GIT_TERMINAL_PROMPT"] = "0";
        start.Environment["WSLENV"] = string.Join(':', new[] { Environment.GetEnvironmentVariable("WSLENV"), "GIT_TERMINAL_PROMPT" }.Where(v => !string.IsNullOrEmpty(v)));

        var watch = Stopwatch.StartNew();
        Process process;
        try
        {
            process = Process.Start(start)!;
        }
        catch (Win32Exception e)
        {
            throw new UserError(
                $"Could not start git ({Exe}).",
                e.Message,
                Exe == "git"
                    ? "Install git, and make sure it is on PATH."
                    : "Point `WINDOWS_GIT` to git.exe, or set `WSL_GIT=linux` to use Linux's git instead.");
        }
        using (process)
        {
            // git.exe reads all of its stdin; an empty one keeps it from waiting for input.
            process.StandardInput.Close();
            var stdout = process.StandardOutput.ReadToEndAsync();
            var stderr = process.StandardError.ReadToEndAsync();
            if (!process.WaitForExit(timeout ?? Timeout.InfiniteTimeSpan))
            {
                process.Kill(entireProcessTree: true);
                throw new UserError(
                    $"`git {string.Join(' ', args)}` gave no answer within {timeout!.Value.TotalSeconds:0} seconds.",
                    null,
                    "Check the network, VPN and credentials for the remote.");
            }
            process.WaitForExit();
            var result = new GitResult(args, process.ExitCode, stdout.Result, stderr.Result);
            if (_verbose)
                Ui.Err.MarkupLine($"[grey]$ {Ui.E(Display(args))}  [/][{(result.ExitCode == 0 ? "grey" : "yellow")}]exit {result.ExitCode}, {watch.ElapsedMilliseconds} ms[/]");
            return result;
        }
    }

    string Display(IEnumerable<string> args) =>
        string.Join(' ', args.Prepend(Exe == "git" ? "git" : Path.GetFileName(Exe))
            .Select(a => a.Length == 0 || a.Any(char.IsWhiteSpace) ? $"'{a}'" : a));

    // The commit a rev names, or null when it names none.
    public string? Commit(string rev)
    {
        var result = Try("rev-parse", "--verify", "--quiet", "--end-of-options", rev + "^{commit}");
        return result.ExitCode == 0 ? result.Out.Trim() : null;
    }

    public bool IsAncestor(string ancestor, string descendant) =>
        Try("merge-base", "--is-ancestor", ancestor, descendant).ExitCode == 0;

    public int Count(params IEnumerable<string> revs) =>
        int.Parse(Run(revs.Prepend("--count").Prepend("rev-list")).Out.Trim());

    // Pathspecs that match these paths exactly, from the top of the repository.
    public static IEnumerable<string> Pathspecs(IEnumerable<string> paths) =>
        paths.Distinct().Select(p => ":(top,literal)" + p);
}

// ─── patches ─────────────────────────────────────────────────────────────────

sealed class FilePatch
{
    public string Path = "";
    public string? OldPath;
    public char Kind = 'M';
    public bool Binary;
    public int Added, Removed;
    public string Fingerprint = "";
    public readonly List<string> Raw = [];

    public IEnumerable<string> Paths => OldPath is null ? [Path] : [Path, OldPath];

    public bool HasConflictMarkers =>
        Raw.Any(l => l.StartsWith("+<<<<<<< ", StringComparison.Ordinal) || l.StartsWith("+>>>>>>> ", StringComparison.Ordinal));
}

static class PatchParser
{
    static readonly Regex HunkHeader = new(@"^@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@", RegexOptions.Compiled);

    // Splits git's patch output into files. A file's fingerprint covers what
    // it changes -- the removed and added lines, modes, renames, a binary's
    // new blob -- and not where: no line numbers, no context, no index line.
    public static List<FilePatch> Parse(string text)
    {
        var files = new List<FilePatch>();
        var lines = text.Split('\n');
        FilePatch? file = null;
        var print = new StringBuilder();
        string? header = null, minus = null, plus = null, from = null, to = null, blob = null;

        void Finish()
        {
            if (file is null) return;
            file.Path = to ?? plus ?? minus ?? header ?? "";
            if (to is not null) file.OldPath = from;
            if (file.Binary) print.Append("binary ").Append(blob).Append('\n');
            file.Fingerprint = Hash(print.ToString());
            files.Add(file);
            file = null;
            print.Clear();
            header = minus = plus = from = to = blob = null;
        }

        for (var i = 0; i < lines.Length; i++)
        {
            var line = lines[i];
            if (line.StartsWith("diff --git ", StringComparison.Ordinal))
            {
                Finish();
                file = new FilePatch();
                file.Raw.Add(line);
                header = HeaderPath(line["diff --git ".Length..]);
                continue;
            }
            if (file is null || (line.Length == 0 && i == lines.Length - 1)) continue;
            file.Raw.Add(line);

            var hunk = HunkHeader.Match(line);
            if (hunk.Success)
            {
                // The counts say where the hunk ends, so a content line that
                // looks like a header ("--- x", "diff --git") is still content.
                var oldLeft = hunk.Groups[1].Success ? int.Parse(hunk.Groups[1].Value) : 1;
                var newLeft = hunk.Groups[2].Success ? int.Parse(hunk.Groups[2].Value) : 1;
                print.Append("@@\n");
                while (i + 1 < lines.Length && (oldLeft > 0 || newLeft > 0 || lines[i + 1].StartsWith('\\')))
                {
                    var body = lines[++i];
                    file.Raw.Add(body);
                    switch (body.Length > 0 ? body[0] : ' ')
                    {
                        case '-': oldLeft--; file.Removed++; print.Append(body).Append('\n'); break;
                        case '+': newLeft--; file.Added++; print.Append(body).Append('\n'); break;
                        case '\\': print.Append(body).Append('\n'); break;
                        default: oldLeft--; newLeft--; break;
                    }
                }
                continue;
            }

            if (line.StartsWith("--- ", StringComparison.Ordinal)) minus = DiffPath(line[4..]);
            else if (line.StartsWith("+++ ", StringComparison.Ordinal)) plus = DiffPath(line[4..]);
            else if (line.StartsWith("index ", StringComparison.Ordinal))
                blob = line["index ".Length..].Split(' ')[0].Split("..").Last();
            else if (line.StartsWith("Binary files ", StringComparison.Ordinal)) file.Binary = true;
            else if (line.StartsWith("rename from ", StringComparison.Ordinal) || line.StartsWith("copy from ", StringComparison.Ordinal))
            {
                from = Unquote(line[(line.IndexOf(" from ", StringComparison.Ordinal) + 6)..]);
                file.Kind = line[0] == 'r' ? 'R' : 'C';
                print.Append(line).Append('\n');
            }
            else if (line.StartsWith("rename to ", StringComparison.Ordinal) || line.StartsWith("copy to ", StringComparison.Ordinal))
            {
                to = Unquote(line[(line.IndexOf(" to ", StringComparison.Ordinal) + 4)..]);
                print.Append(line).Append('\n');
            }
            else if (line.StartsWith("new file mode ", StringComparison.Ordinal) || line.StartsWith("deleted file mode ", StringComparison.Ordinal))
            {
                file.Kind = line[0] == 'n' ? 'A' : 'D';
                print.Append(line).Append('\n');
            }
            else if (line.StartsWith("old mode ", StringComparison.Ordinal) || line.StartsWith("new mode ", StringComparison.Ordinal))
                print.Append(line).Append('\n');
        }
        Finish();
        return files;
    }

    public static string Hash(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)))[..16];

    // "a/x" from the --- and +++ lines; null for /dev/null.
    static string? DiffPath(string value)
    {
        value = value.TrimEnd('\t');
        if (value == "/dev/null") return null;
        value = Unquote(value);
        return value.Length > 2 && value[1] == '/' ? value[2..] : value;
    }

    // The path in "diff --git a/P b/P", for a file without --- and +++ lines
    // (a mode change, an empty file). A rename has "rename to" instead.
    static string? HeaderPath(string value)
    {
        if (value.StartsWith('"') || value.EndsWith('"'))
        {
            var second = value.EndsWith('"') ? value[value.LastIndexOf(" \"", StringComparison.Ordinal)..].Trim() : value[(value.LastIndexOf(' ') + 1)..];
            var path = Unquote(second);
            return path.Length > 2 ? path[2..] : null;
        }
        if (value.Length % 2 == 0) return null;
        var half = value.Length / 2;
        var (a, b) = (value[..half], value[(half + 1)..]);
        return a.Length > 2 && a[2..] == b[2..] ? b[2..] : null;
    }

    // Undoes git's C-style quoting of a path: "dir/\303\244 \"x\"".
    static string Unquote(string value)
    {
        if (value.Length < 2 || value[0] != '"' || value[^1] != '"') return value;
        var bytes = new List<byte>();
        for (var i = 1; i < value.Length - 1; i++)
        {
            var c = value[i];
            if (c != '\\')
            {
                bytes.AddRange(Encoding.UTF8.GetBytes(c.ToString()));
                continue;
            }
            c = value[++i];
            if (c is >= '0' and <= '7')
            {
                bytes.Add(Convert.ToByte(value.Substring(i, 3), 8));
                i += 2;
                continue;
            }
            bytes.Add(c switch
            {
                'a' => 7, 'b' => 8, 't' => 9, 'n' => 10, 'v' => 11, 'f' => 12, 'r' => 13,
                _ => (byte)c,
            });
        }
        return Encoding.UTF8.GetString(bytes.ToArray());
    }
}

// ─── commits ─────────────────────────────────────────────────────────────────

sealed record Commit(string Sha, string Author, string Subject, string Message, IReadOnlyList<FilePatch> Files)
{
    public string Fingerprint { get; } = PatchParser.Hash(string.Join('\n',
        Files.OrderBy(f => f.Path, StringComparer.Ordinal).Select(f => $"{f.Path}\0{f.Fingerprint}")));

    public static List<Commit> Load(Git git, string range, IReadOnlyCollection<string>? paths = null)
    {
        // A nonce marks where a commit starts and its message ends; no patch
        // line can start with it, as every content line starts with -, + or a space.
        var nonce = Guid.NewGuid().ToString("N")[..12];
        var (start, end) = ($"\x1e{nonce} ", $"\x1d{nonce}");
        var args = new List<string>
        {
            "log", "--reverse", "--no-merges", "--no-color", "--no-ext-diff", "--no-textconv", "-p", "-U0", "-M",
            "--full-index", "--src-prefix=a/", "--dst-prefix=b/", "--encoding=UTF-8",
            $"--format=%x1e{nonce} %H%x1f%an <%ae>%x1f%s%x1f%B%x1d{nonce}", range,
        };
        if (paths is not null)
        {
            // Commits that touch these paths, with all of their changes.
            args.Insert(1, "--full-diff");
            args.Add("--");
            args.AddRange(Git.Pathspecs(paths));
        }
        var output = git.Run(args).Out;

        var starts = new List<int>();
        for (var at = output.IndexOf(start, StringComparison.Ordinal); at >= 0; at = output.IndexOf(start, at + 1, StringComparison.Ordinal))
            if (at == 0 || output[at - 1] == '\n') starts.Add(at);
        starts.Add(output.Length);

        var commits = new List<Commit>();
        for (var k = 0; k < starts.Count - 1; k++)
        {
            var record = output[starts[k]..starts[k + 1]];
            var close = record.IndexOf(end, StringComparison.Ordinal);
            var fields = record[start.Length..close].Split('\x1f', 4);
            commits.Add(new Commit(fields[0], fields[1], fields[2], fields[3].TrimEnd(), PatchParser.Parse(record[(close + end.Length)..])));
        }
        return commits;
    }
}

enum RowStatus { Same, Reworded, Changed, Squashed, Upstream, Dropped, Added }

enum DeltaKind { Differs, OnlyOld, OnlyNew }

sealed record FileDelta(string Path, DeltaKind Kind);

sealed class CommitRow
{
    public Commit? Old, New;
    public int OldIndex = -1, NewIndex = -1;
    public RowStatus Status;
    public bool Moved, AuthorChanged;
    public double Order;
    public List<FileDelta> Files = [];
    public Commit? Upstream;
    public CommitRow? Into;

    // How the rebased commit's changes differ from the pushed one's, per file.
    public static List<FileDelta> Compare(Commit? old, Commit? @new)
    {
        var before = (old?.Files ?? []).GroupBy(f => f.Path).ToDictionary(g => g.Key, g => g.First().Fingerprint);
        var after = (@new?.Files ?? []).GroupBy(f => f.Path).ToDictionary(g => g.Key, g => g.First().Fingerprint);
        return before.Keys.Union(after.Keys).Order(StringComparer.Ordinal)
            .Select(path => (path, before: before.GetValueOrDefault(path), after: after.GetValueOrDefault(path)))
            .Where(f => f.before != f.after)
            .Select(f => new FileDelta(f.path, f.before is null ? DeltaKind.OnlyNew : f.after is null ? DeltaKind.OnlyOld : DeltaKind.Differs))
            .ToList();
    }
}

static class Pairing
{
    public static List<CommitRow> Pair(IReadOnlyList<Commit> old, IReadOnlyList<Commit> @new)
    {
        var match = Enumerable.Repeat(-1, old.Count).ToArray();
        var used = new bool[@new.Count];
        void Match(Func<Commit, Commit, bool> same)
        {
            for (var i = 0; i < old.Count; i++)
                for (var j = 0; match[i] < 0 && j < @new.Count; j++)
                    if (!used[j] && same(old[i], @new[j]))
                        (match[i], used[j]) = (j, true);
        }
        Match((a, b) => a.Fingerprint == b.Fingerprint && a.Subject == b.Subject);
        Match((a, b) => a.Fingerprint == b.Fingerprint);
        Match((a, b) => a.Subject == b.Subject);

        var rows = new List<CommitRow>();
        var previous = -1;
        for (var i = 0; i < old.Count; i++)
        {
            var j = match[i];
            if (j < 0)
            {
                // Shown where it was: after the rebased partner of the commit before it.
                rows.Add(new CommitRow { Old = old[i], OldIndex = i, Status = RowStatus.Dropped, Order = previous + 0.5 + i * 1e-6, Files = CommitRow.Compare(old[i], null) });
                continue;
            }
            previous = j;
            var row = new CommitRow { Old = old[i], New = @new[j], OldIndex = i, NewIndex = j, Order = j };
            row.Status = old[i].Fingerprint != @new[j].Fingerprint ? RowStatus.Changed
                : old[i].Message != @new[j].Message ? RowStatus.Reworded
                : RowStatus.Same;
            row.AuthorChanged = old[i].Author != @new[j].Author;
            row.Files = CommitRow.Compare(old[i], @new[j]);
            rows.Add(row);
        }
        for (var j = 0; j < @new.Count; j++)
            if (!used[j])
                rows.Add(new CommitRow { New = @new[j], NewIndex = j, Status = RowStatus.Added, Order = j, Files = CommitRow.Compare(null, @new[j]) });
        rows.Sort((a, b) => a.Order.CompareTo(b.Order));
        MarkMoved(rows.Where(r => r.Old is not null && r.New is not null).ToList());
        return rows;
    }

    // Pairs that keep their order form the longest run of rising old indexes
    // in the new order; the others moved.
    static void MarkMoved(List<CommitRow> paired)
    {
        var length = new int[paired.Count];
        var before = new int[paired.Count];
        for (var i = 0; i < paired.Count; i++)
        {
            (length[i], before[i]) = (1, -1);
            for (var k = 0; k < i; k++)
                if (paired[k].OldIndex < paired[i].OldIndex && length[k] + 1 > length[i])
                    (length[i], before[i]) = (length[k] + 1, k);
        }
        var kept = new HashSet<int>();
        for (var i = paired.Count == 0 ? -1 : Array.IndexOf(length, length.Max()); i >= 0; i = before[i]) kept.Add(i);
        for (var i = 0; i < paired.Count; i++) paired[i].Moved = !kept.Contains(i);
    }

    // A dropped commit whose patch the new base already has went upstream.
    public static void FindUpstream(Git git, List<CommitRow> rows, string oldBase, string newBase)
    {
        var dropped = rows.Where(r => r.Status == RowStatus.Dropped && r.Old!.Files.Count > 0).ToList();
        if (dropped.Count == 0 || oldBase == newBase) return;
        var paths = dropped.SelectMany(r => r.Old!.Files.SelectMany(f => f.Paths)).ToList();
        var upstream = Commit.Load(git, $"{oldBase}..{newBase}", paths)
            .GroupBy(c => c.Fingerprint).ToDictionary(g => g.Key, g => g.First());
        foreach (var row in dropped)
            if (upstream.TryGetValue(row.Old!.Fingerprint, out var commit))
                (row.Status, row.Upstream, row.Files) = (RowStatus.Upstream, commit, []);
    }

    // A dropped "fixup! X" went into X; a dropped commit whose subject is a
    // line of a rebased commit's message was squashed into that one.
    public static void FindSquashed(List<CommitRow> rows)
    {
        foreach (var row in rows.Where(r => r.Status == RowStatus.Dropped))
        {
            var subject = row.Old!.Subject;
            var fixup = Regex.Match(subject, @"^(?:(?:fixup|squash|amend)! )+(.+)$");
            var into = fixup.Success
                ? rows.FirstOrDefault(r => r.New is not null && (r.Old?.Subject == fixup.Groups[1].Value || r.New.Subject == fixup.Groups[1].Value))
                : rows.FirstOrDefault(r => r.New is not null && r.New.Subject != subject
                    && r.New.Message.Split('\n').Any(l => l.Trim() == subject));
            if (into is null) continue;
            (row.Status, row.Into) = (RowStatus.Squashed, into);
        }
    }
}

// ─── analysis ────────────────────────────────────────────────────────────────

sealed record RefInfo(string Label, string Sha, string? Why = null, string? Branch = null, string? RemoteName = null, string? RemoteBranch = null);

enum Relation { Same, Ahead, Behind, Diverged }

sealed record ContentFile(FilePatch Patch, bool Conflict, CommitRow? AddedBy, CommitRow? DroppedBy);

sealed record CommitDiff(CommitRow Row, string Path, IReadOnlyList<string> Old, IReadOnlyList<string> New);

sealed record RemoteCheck(string? Sha);

sealed class Analysis
{
    public required Git Git;
    // Onto is what Local was rebased onto: --base, --new-base, or in a stack
    // the branch below, which makes it Stacked.
    public required RefInfo Local, Remote, Onto;
    public bool Stacked;
    public string OldBase = "", NewBase = "";
    public int UpstreamAhead, UpstreamBehind;
    public Relation Relation;
    public int Distance;
    public List<Commit> OldCommits = [], NewCommits = [];
    public int OldMerges, NewMerges;
    public List<CommitRow> Rows = [];
    public HashSet<string> Conflicts = [];
    public List<ContentFile> Content = [];
    public List<FilePatch> ContentDiffs = [];
    public List<CommitDiff> CommitDiffs = [];
    public RemoteCheck? RemoteCheck;

    public bool ContentSame => Content.Count == 0;
    public bool CommitsSame => Rows.All(r => r.Status is RowStatus.Same or RowStatus.Reworded or RowStatus.Upstream && !r.Moved);
    public bool RemoteMoved => RemoteCheck is not null && RemoteCheck.Sha != Remote.Sha;
}

// A verdict: its box, its exit code, and -- when a push is to be offered --
// what to say before it.
sealed record Outcome(Color Color, string Title, int ExitCode, IReadOnlyList<string> Lines, string? PushPrefix = null);

// A branch of a stack, with its pushed version -- none if it was never
// pushed -- and, once checked, what was found.
sealed class Layer(RefInfo local, RefInfo? remote)
{
    public RefInfo Local { get; } = local;
    public RefInfo? Remote { get; } = remote;
    public Analysis? Analysis;
    public UserError? Error;
    public Outcome? Outcome;
}

// The branches of a stack, bottom first, on --base; Found when they were
// looked up rather than named.
sealed record StackInfo(RefInfo Base, IReadOnlyList<Layer> Layers, bool Found);

static class Verifier
{
    public static int Run(Settings settings)
    {
        try
        {
            var git = Git.Open(settings.Repo, settings.Verbose);
            if (settings.IsStack) return RunStack(git, settings);
            var analysis = Spin(settings, "Resolving refs…", status => Analyze(git, settings, status));
            return Report.Render(analysis, settings);
        }
        catch (UserError error)
        {
            Ui.Fail(error);
            return ExitCodes.Error;
        }
        catch (Exception error)
        {
            Ui.Crash(error, settings.Verbose);
            return ExitCodes.Error;
        }
    }

    // The work under a spinner that says what it does, when someone watches.
    static T Spin<T>(Settings s, string first, Func<Action<string>, T> work) =>
        s.Verbose || !Ui.Out.Profile.Capabilities.Interactive
            ? work(_ => { })
            : Ui.Out.Status()
                .Spinner(Spinner.Known.Dots)
                .SpinnerStyle(new Style(Color.DeepSkyBlue1))
                .Start(first, ctx => work(message => ctx.Status(message)));

    // Each branch of the stack, reported as soon as it is checked, then the whole.
    static int RunStack(Git git, Settings s)
    {
        var stack = Spin(s, "Finding the stack…", status => ResolveStack(git, s, status));
        var asked = s.CheckRemote
            ? Spin(s, "Asking the remote…", status => AskRemote(git, stack.Layers.Select(l => l.Remote).OfType<RefInfo>(), status))
            : null;
        Report.Intro(stack);
        for (var i = 0; i < stack.Layers.Count; i++)
        {
            var layer = stack.Layers[i];
            if (layer.Remote is not null)
                try
                {
                    layer.Analysis = Spin(s, $"Checking {layer.Local.Label}…",
                        status => AnalyzeLayer(git, stack, i, s, asked, message => status($"{layer.Local.Label}: {message}")));
                }
                catch (UserError error)
                {
                    layer.Error = error;
                }
            layer.Outcome = Report.RenderLayer(stack, i, s);
        }
        return Report.Summary(stack, s);
    }

    static Analysis Analyze(Git git, Settings s, Action<string> status)
    {
        RejectRebaseInProgress(git);
        var local = ResolveLocal(git, s.Branches[0]);
        var remote = ResolveRemote(git, s.Remote, local);
        // --base is only needed for a fork point not given.
        var @base = s.OldBase is null || s.NewBase is null || s.Base is not null
            ? ResolveBase(git, s.Base, remote.RemoteName, remote.Label)
            : null;
        var onto = s.NewBase is { } newBase ? new RefInfo(newBase, Require(git, newBase, "--new-base"), "--new-base") : @base!;
        var a = new Analysis { Git = git, Local = local, Remote = remote, Onto = onto };

        a.OldBase = s.OldBase is { } oldBase ? Require(git, oldBase, "--old-base") : MergeBase(git, remote, @base!, "--old-base");
        a.NewBase = s.NewBase is null ? MergeBase(git, local, @base!, "--new-base") : onto.Sha;
        var baseLabel = @base?.Label ?? "<base>";
        if (!git.IsAncestor(a.OldBase, remote.Sha))
            throw new UserError(
                $"--old-base {Ui.Short(a.OldBase)} is not in the history of {remote.Label}.",
                null,
                $"Pass the commit {remote.Label} was branched from, e.g. the one `git merge-base {remote.Label} {baseLabel}` prints.");
        if (!git.IsAncestor(a.NewBase, local.Sha))
            throw new UserError(
                $"--new-base {Ui.Short(a.NewBase)} is not in the history of {local.Label}.",
                null,
                $"Pass the commit {local.Label} was rebased onto, e.g. the one `git merge-base {local.Label} {baseLabel}` prints.");

        if (s.CheckRemote)
        {
            if (remote.RemoteName is null)
                throw new UserError(
                    $"--check-remote asks a remote, and {remote.Label} is not a remote-tracking branch.",
                    null,
                    "Pass the pushed branch as `--remote <remote>/<branch>`, e.g. `--remote origin/feature`.");
            a.RemoteCheck = AskRemote(git, [remote], status)[remote];
        }
        Compare(git, a, s, status);
        return a;
    }

    // The pushed and the rebased version compared, once their fork points are known.
    static void Compare(Git git, Analysis a, Settings s, Action<string> status)
    {
        var (local, remote) = (a.Local, a.Remote);
        if (a.OldBase != a.NewBase)
        {
            a.UpstreamAhead = git.Count($"{a.OldBase}..{a.NewBase}");
            a.UpstreamBehind = git.Count($"{a.NewBase}..{a.OldBase}");
        }

        a.Relation = local.Sha == remote.Sha ? Relation.Same
            : git.IsAncestor(remote.Sha, local.Sha) ? Relation.Ahead
            : git.IsAncestor(local.Sha, remote.Sha) ? Relation.Behind
            : Relation.Diverged;
        if (a.Relation == Relation.Same) return;
        if (a.Relation == Relation.Ahead)
        {
            a.Distance = git.Count($"{remote.Sha}..{local.Sha}");
            return;
        }
        if (a.Relation == Relation.Behind) a.Distance = git.Count($"{local.Sha}..{remote.Sha}");

        status("Reading the pushed and the rebased commits…");
        a.OldCommits = Commit.Load(git, $"{a.OldBase}..{remote.Sha}");
        a.NewCommits = Commit.Load(git, $"{a.NewBase}..{local.Sha}");
        a.OldMerges = git.Count("--merges", $"{a.OldBase}..{remote.Sha}");
        a.NewMerges = git.Count("--merges", $"{a.NewBase}..{local.Sha}");

        status("Pairing the commits…");
        a.Rows = Pairing.Pair(a.OldCommits, a.NewCommits);
        Pairing.FindUpstream(git, a.Rows, a.OldBase, a.NewBase);
        Pairing.FindSquashed(a.Rows);

        status("Replaying the pushed changes onto the new base…");
        var expected = Replay(git, a);
        status("Comparing the files…");
        a.Content = PatchParser.Parse(git.Run(DiffTree(0, expected, local.Sha)).Out)
            .Select(f => new ContentFile(
                f,
                f.Paths.Any(a.Conflicts.Contains),
                a.Rows.FirstOrDefault(r => r.Status == RowStatus.Added && r.Files.Any(d => f.Paths.Contains(d.Path))),
                a.Rows.FirstOrDefault(r => r.Status == RowStatus.Dropped && r.Files.Any(d => f.Paths.Contains(d.Path)))))
            .ToList();

        if (s.Diff)
        {
            status("Preparing the diffs…");
            if (a.Content.Count > 0) a.ContentDiffs = PatchParser.Parse(git.Run(DiffTree(s.Context, expected, local.Sha)).Out);
            foreach (var row in a.Rows.Where(r => r.Status is RowStatus.Changed or RowStatus.Dropped or RowStatus.Added))
            {
                var paths = row.Files.Select(f => f.Path).ToList();
                var old = CommitPatches(git, row.Old, paths, s.Context);
                var @new = CommitPatches(git, row.New, paths, s.Context);
                foreach (var path in paths)
                    a.CommitDiffs.Add(new CommitDiff(row, path, Normalize(old.GetValueOrDefault(path)), Normalize(@new.GetValueOrDefault(path))));
            }
        }
    }

    // The stack's branches, bottom first, each with its pushed version if it has one.
    static StackInfo ResolveStack(Git git, Settings s, Action<string> status)
    {
        RejectRebaseInProgress(git);
        var named = new List<RefInfo>();
        foreach (var spec in s.Branches)
        {
            var info = ResolveLocal(git, spec);
            if (info.Branch is null)
                throw spec == "HEAD"
                    ? new UserError("HEAD is detached, so it is no branch of a stack.", null,
                        $"Name the top branch of the stack: `{Cli.Name} --stack <branch>`.")
                    : new UserError($"'{spec}' is not a local branch, and each merge request of a stack is one.", null,
                        "`git branch` lists the local branches.");
            if (named.Any(n => n.Branch == info.Branch))
                throw new UserError($"{info.Branch} is named twice.", null, "Name each branch of the stack once, bottom first.");
            named.Add(info);
        }
        for (var i = 1; i < named.Count; i++)
            if (!git.IsAncestor(named[i - 1].Sha, named[i].Sha))
                throw new UserError(
                    $"{named[i].Label} is not on top of {named[i - 1].Label}: {named[i - 1].Label} is not in its history.",
                    null,
                    git.IsAncestor(named[i].Sha, named[i - 1].Sha)
                        ? $"Name the branches bottom first: `{Cli.Name} {string.Join(' ', Enumerable.Reverse(named).Select(n => n.Label))}`."
                        : "Name the branches of one stack, bottom first, each on top of the one before -- or only the top one, with `--stack`, to have the others found.");

        var top = named[^1];
        var topPushed = FindPushed(git, top.Branch!);
        var @base = ResolveBase(git, s.Base, topPushed?.RemoteName, topPushed?.Label);
        var found = named.Count == 1;
        if (found) status($"Finding the branches between {@base.Label} and {top.Label}…");
        var layers = found
            ? Discover(git, top, topPushed, @base)
            : named.Select(n => new Layer(n, FindPushed(git, n.Branch!))).ToList();
        if (layers.All(l => l.Remote is null))
            throw found
                ? new UserError(
                    $"Found no branch with a pushed version between {@base.Label} and {top.Label}, and {top.Label} was never pushed either: a push would overwrite nothing.",
                    null,
                    "Is the stack on another branch? Name it: `--base <ref>`.",
                    "Never pushed? Then a plain `git push` publishes it.")
                : new UserError("None of these branches was pushed, so a push would overwrite nothing.", null,
                    "A plain `git push` publishes them.");
        return new StackInfo(@base, layers, found);
    }

    // The merge requests below the top: the local branches on its first-parent
    // line above --base that have a pushed version. A backup of a branch the
    // rebase only added to is on that line too, but was never pushed.
    static List<Layer> Discover(Git git, RefInfo top, RefInfo? topPushed, RefInfo @base)
    {
        var line = git.Run("rev-list", "--first-parent", top.Sha, "--not", @base.Sha).Out
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (line.Length == 0)
            throw new UserError(
                $"{top.Label} is already in {@base.Label}, so there is no stack between them.",
                null,
                "Name the branch the bottom merge request targets: `--base <ref>`.");
        var height = line.Select((sha, i) => (sha, i)).ToDictionary(x => x.sha, x => line.Length - x.i);
        var below = new List<Layer>();
        foreach (var record in git.Run("for-each-ref", "--format=%(objectname) %(refname:lstrip=2)", "refs/heads/").Out
                     .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var fields = record.Split(' ', 2);
            var (sha, branch) = (fields[0], fields[1]);
            if (sha == top.Sha || !height.ContainsKey(sha)) continue;
            if (FindPushed(git, branch) is { } pushed)
                below.Add(new Layer(new RefInfo(branch, sha, Branch: branch), pushed));
        }
        if (below.GroupBy(l => l.Local.Sha).FirstOrDefault(g => g.Count() > 1) is { } twins)
            throw new UserError(
                $"{string.Join(" and ", twins.Select(l => l.Local.Label))} are the same commit, {Ui.Short(twins.Key)}, so it is unclear which merge request is which.",
                null,
                $"Name the stack's branches, bottom first: `{Cli.Name} <bottom> … {top.Label}`.");
        return [.. below.OrderBy(l => height[l.Local.Sha]), new Layer(top, topPushed)];
    }

    // A branch of the stack: the bottom one forks from --base, as a branch
    // alone does; every other one is a merge request on the branch below it.
    static Analysis AnalyzeLayer(Git git, StackInfo stack, int i, Settings s, Dictionary<RefInfo, RemoteCheck>? asked, Action<string> status)
    {
        var (local, remote) = (stack.Layers[i].Local, stack.Layers[i].Remote!);
        Analysis a;
        if (i == 0)
        {
            a = new Analysis { Git = git, Local = local, Remote = remote, Onto = stack.Base };
            a.OldBase = MergeBase(git, remote, stack.Base, null);
            a.NewBase = MergeBase(git, local, stack.Base, null);
        }
        else
        {
            var below = stack.Layers[i - 1];
            a = new Analysis { Git = git, Local = local, Remote = remote, Onto = below.Local with { Why = "the merge request below" }, Stacked = true };
            a.NewBase = below.Local.Sha;
            a.OldBase = ForkPoint(git, below, remote) ?? throw new UserError(
                $"Could not tell which version of {below.Local.Label} the pushed {local.Label} was built on.",
                (below.Remote is null
                    ? $"{below.Local.Label}'s reflog does not have it"
                    : $"Neither {below.Remote.Label}'s reflog nor {below.Local.Label}'s has it")
                    + " -- as in a fresh clone, or once the reflog expired.",
                $"Check {local.Label} alone, from that version: `{Cli.Name} {local.Label} --old-base <commit> --new-base {below.Local.Label}`, "
                    + $"with a backup of the old {below.Local.Label}, or its id from the merge request's history.");
        }
        if (asked is not null) a.RemoteCheck = asked[remote];
        Compare(git, a, s, status);
        return a;
    }

    // The version of the branch below that the pushed one was built on: the
    // newest one the pushed one contains, as the reflogs of that branch and of
    // its remote-tracking ref remember them -- so it is found even once that
    // branch was rebased, and force-pushed.
    static string? ForkPoint(Git git, Layer below, RefInfo pushed)
    {
        string[] refs = below.Remote is null
            ? [$"refs/heads/{below.Local.Branch}"]
            : [$"refs/remotes/{below.Remote.Label}", $"refs/heads/{below.Local.Branch}"];
        var points = refs
            .Select(r => git.Try("merge-base", "--fork-point", r, pushed.Sha))
            .Where(r => r.ExitCode == 0)
            .Select(r => r.Out.Trim())
            .Distinct()
            .ToList();
        return points.Count < 2 ? points.FirstOrDefault()
            : git.IsAncestor(points[0], points[1]) ? points[1] : points[0];
    }

    // Where the remote has these branches now, asked once per remote.
    static Dictionary<RefInfo, RemoteCheck> AskRemote(Git git, IEnumerable<RefInfo> pushed, Action<string> status)
    {
        var checks = new Dictionary<RefInfo, RemoteCheck>();
        foreach (var group in pushed.GroupBy(r => r.RemoteName!))
        {
            var branches = group.Select(r => r.RemoteBranch!).Distinct().ToList();
            var which = branches.Count == 1 ? $"{branches[0]} is" : $"{branches.Count} branches are";
            status($"Asking {group.Key} where {which}…");
            var answer = git.Try(["ls-remote", group.Key, .. branches.Select(b => $"refs/heads/{b}")], TimeSpan.FromSeconds(30));
            if (answer.ExitCode != 0)
                throw new UserError(
                    $"Could not ask {group.Key} where {which}.",
                    answer.Err,
                    "Check the network, VPN and credentials, or leave `--check-remote` out to verify against your last fetch.");
            var heads = answer.Out.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                .Select(l => l.Split('\t'))
                .Where(f => f.Length == 2)
                .DistinctBy(f => f[1].Trim())
                .ToDictionary(f => f[1].Trim(), f => f[0].Trim());
            foreach (var r in group) checks[r] = new RemoteCheck(heads.GetValueOrDefault($"refs/heads/{r.RemoteBranch}"));
        }
        return checks;
    }

    // The tree the rebase would make with no hand on it: the pushed changes,
    // old fork point to pushed tip, merged onto the new fork point.
    static string Replay(Git git, Analysis a)
    {
        if (a.OldBase == a.NewBase) return a.Remote.Sha;
        var result = git.Try("merge-tree", "--write-tree", "-z", "--name-only", "--no-messages", $"--merge-base={a.OldBase}", a.NewBase, a.Remote.Sha);
        if (result.ExitCode > 1) throw new GitError(result);
        var fields = result.Out.Split('\0');
        foreach (var path in fields.Skip(1).TakeWhile(f => f.Length > 0)) a.Conflicts.Add(path);
        return fields[0].Trim();
    }

    static IEnumerable<string> DiffTree(int context, string from, string to) =>
        ["diff-tree", "-r", "-p", "-M", $"-U{context}", "--full-index", "--no-textconv", "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/", from, to];

    static Dictionary<string, FilePatch> CommitPatches(Git git, Commit? commit, IReadOnlyCollection<string> paths, int context)
    {
        if (commit is null) return [];
        // Renames need both of their paths in the pathspec to stay renames.
        var all = commit.Files.Where(f => f.Paths.Any(paths.Contains)).SelectMany(f => f.Paths).Concat(paths);
        IEnumerable<string> args = ["diff-tree", "--root", "--no-commit-id", "-p", "-M", $"-U{context}", "--full-index", "--no-textconv", "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/", commit.Sha, "--", .. Git.Pathspecs(all)];
        return PatchParser.Parse(git.Run(args).Out).GroupBy(f => f.Path).ToDictionary(g => g.Key, g => g.First());
    }

    // A patch as range-diff compares it: no line numbers, and no index line
    // but for a binary file, where the blobs are all there is to compare.
    static IReadOnlyList<string> Normalize(FilePatch? patch) =>
        patch is null ? [] : patch.Raw
            .Where(l => !(l.StartsWith("index ") && !patch.Binary) && !l.StartsWith("similarity index ") && !l.StartsWith("dissimilarity index "))
            .Select(l => l.StartsWith("@@ ") && l.IndexOf(" @@", 3, StringComparison.Ordinal) is var end and > 0 ? "@@" + l[(end + 3)..] : l)
            .ToList();

    static void RejectRebaseInProgress(Git git)
    {
        foreach (var name in new[] { "rebase-merge", "rebase-apply" })
        {
            var path = git.Run("rev-parse", "--path-format=relative", "--git-path", name).Out.Trim();
            if (Directory.Exists(Path.Combine(git.Dir, path)))
                throw new UserError(
                    name == "rebase-merge"
                        ? "A rebase is still in progress here, so HEAD is not the rebased branch yet."
                        : "A rebase or `git am` is still in progress here, so HEAD is not the rebased branch yet.",
                    null,
                    "Finish it with `git rebase --continue` (or undo it with `git rebase --abort`), then run this again.");
        }
    }

    static string Require(Git git, string rev, string what, params string[] hints) =>
        git.Commit(rev) ?? throw new UserError(
            $"{what} '{rev}' names no commit in this repository.",
            null,
            hints.Length > 0 ? hints : ["Check the spelling: `git branch -a` lists the branches, `git log --oneline` the commits."]);

    static RefInfo ResolveLocal(Git git, string spec)
    {
        var sha = Require(git, spec, "<local>");
        if (spec == "HEAD")
        {
            var head = git.Try("symbolic-ref", "--quiet", "--short", "HEAD");
            return head.ExitCode == 0
                ? new RefInfo(head.Out.Trim(), sha, "checked out", Branch: head.Out.Trim())
                : new RefInfo("HEAD", sha, "detached");
        }
        var name = spec.StartsWith("refs/heads/") ? spec["refs/heads/".Length..] : spec;
        return git.Try("show-ref", "--verify", "--quiet", $"refs/heads/{name}").ExitCode == 0
            ? new RefInfo(name, sha, Branch: name)
            : new RefInfo(spec, sha);
    }

    static RefInfo ResolveRemote(Git git, string? spec, RefInfo local)
    {
        if (spec is not null)
        {
            var sha = Require(git, spec, "--remote",
                "Fetch it first (`git fetch <remote>`), or check the name: `git branch -r` lists the remote-tracking branches.");
            return Tracking(git, spec, sha, "--remote");
        }
        if (local.Branch is null)
            throw new UserError(
                local.Label == "HEAD"
                    ? "HEAD is detached, so there is no branch whose pushed version could be looked up."
                    : $"{local.Label} is not a local branch, so there is no pushed version to look up.",
                null,
                $"Name the branch: `{Cli.Name} <branch>`,",
                "or the pushed version itself: `--remote origin/<branch>`.");

        var branch = local.Branch;
        return FindPushed(git, branch) ?? throw new UserError(
            $"Found no pushed version of {branch}: it has no push destination or upstream, and there is no origin/{branch}.",
            null,
            "Pushed under another name? Pass it: `--remote <remote>/<branch>`.",
            "Pushed, but not fetched here? `git fetch`, then run this again.",
            "Never pushed? Then nothing would be overwritten: a plain `git push` publishes it.");
    }

    // The pushed version of a branch: where `git push` sends it, else origin's
    // branch of its name, else its upstream if that has its name; null if none.
    static RefInfo? FindPushed(Git git, string branch)
    {
        foreach (var (rev, why) in new[]
        {
            ($"{branch}@{{push}}", $"where `git push` sends {branch}"),
            ($"refs/remotes/origin/{branch}", $"origin's {branch}"),
            ($"{branch}@{{upstream}}", $"upstream of {branch}"),
        })
        {
            var full = git.Try("rev-parse", "--symbolic-full-name", rev);
            var name = full.ExitCode == 0 ? full.Out.Trim() : "";
            if (!name.StartsWith("refs/remotes/") || git.Commit(name) is not { } sha) continue;
            var info = Tracking(git, name, sha, why);
            // An upstream of another name is the branch it started from, not its pushed version.
            if (rev.EndsWith("@{upstream}") && info.RemoteBranch != branch) continue;
            return info;
        }
        return null;
    }

    // The ref with its remote and branch, when it is a remote-tracking one.
    static RefInfo Tracking(Git git, string rev, string sha, string why)
    {
        var full = git.Try("rev-parse", "--symbolic-full-name", rev).Out.Trim();
        var label = full.StartsWith("refs/remotes/") ? full["refs/remotes/".Length..] : rev;
        var remote = full.StartsWith("refs/remotes/")
            ? git.Run("remote").Out.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(r => full.StartsWith($"refs/remotes/{r}/")).MaxBy(r => r.Length)
            : null;
        return remote is null
            ? new RefInfo(label, sha, why)
            : new RefInfo(label, sha, why, RemoteName: remote, RemoteBranch: full[$"refs/remotes/{remote}/".Length..]);
    }

    // --base, else the remote's default branch, other than the pushed branch itself.
    static RefInfo ResolveBase(Git git, string? spec, string? remoteName, string? pushed)
    {
        if (spec is not null)
            return new RefInfo(spec, Require(git, spec, "--base",
                "Name the branch you rebased onto, e.g. `--base origin/main`; `git branch -a` lists them."), "--base");

        var name = remoteName ?? "origin";
        var head = git.Try("symbolic-ref", "--quiet", "--short", $"refs/remotes/{name}/HEAD");
        var candidates = new List<(string Rev, string Why)>();
        if (head.ExitCode == 0) candidates.Add((head.Out.Trim(), $"{name}'s default branch"));
        candidates.AddRange([($"{name}/main", "found by name"), ($"{name}/master", "found by name"), ("main", "found by name"), ("master", "found by name")]);
        foreach (var (rev, why) in candidates)
            if (rev != pushed && git.Commit(rev) is { } sha)
                return new RefInfo(rev, sha, why);
        throw new UserError(
            $"Could not tell which branch this was rebased onto: there is no {name}/HEAD, {name}/main or {name}/master.",
            null,
            "Name it: `--base <ref>`, e.g. `--base origin/develop`.",
            $"Or have git record {name}'s default branch: `git remote set-head {name} --auto`.");
    }

    // The option is the one that could name the fork point instead; none in a stack.
    static string MergeBase(Git git, RefInfo tip, RefInfo @base, string? option)
    {
        var result = git.Try("merge-base", tip.Sha, @base.Sha);
        return result.ExitCode == 0
            ? result.Out.Trim()
            : throw new UserError(
                $"{tip.Label} and {@base.Label} share no history, so there is no fork point to compare from.",
                null,
                option is null
                    ? "Name the branch the bottom merge request targets: `--base <ref>`."
                    : $"Pass the commit it starts from with `{option} <commit>`, or another branch with `--base <ref>`.");
    }
}

// ─── report ──────────────────────────────────────────────────────────────────

static class Report
{
    public static int Render(Analysis a, Settings s)
    {
        var c = Ui.Out;
        c.WriteLine();
        c.Write(new Rule("[bold deepskyblue1]verify rebase[/]").LeftJustified().RuleStyle(new Style(Color.Grey)));
        var outcome = Body(c, a, s);
        if (outcome.PushPrefix is { } prefix && PushCommand(a) is { } push)
            Offer(c, prefix, "the version checked here", [push]);
        return outcome.ExitCode;
    }

    // A branch's refs, commits, content and diffs, and the verdict on them.
    static Outcome Body(IAnsiConsole c, Analysis a, Settings s)
    {
        Refs(c, a, s);
        if (!a.RemoteMoved && a.Relation is Relation.Behind or Relation.Diverged)
        {
            Commits(c, a);
            Content(c, a);
            if (s.Diff) Diffs(c, a, s.Context);
        }
        var outcome = Judge(a, s);
        Box(c, outcome);
        return outcome;
    }

    static void Refs(IAnsiConsole c, Analysis a, Settings s)
    {
        var grid = new Grid();
        grid.AddColumn(new GridColumn().NoWrap().PadLeft(1).PadRight(2));
        grid.AddColumn(new GridColumn());
        void Row(string label, string value) => grid.AddRow(new Markup($"[grey]{label}[/]"), new Markup(value));

        Row("rebased", Ref(a.Local));
        Row("pushed", Ref(a.Remote));
        Row("onto", Ref(a.Onto));
        Row("fork point", a.OldBase == a.NewBase
            ? $"[deepskyblue1]{Ui.Short(a.OldBase)}[/]  [grey]unchanged[/]"
            : $"[deepskyblue1]{Ui.Short(a.OldBase)}[/] → [deepskyblue1]{Ui.Short(a.NewBase)}[/]  [grey]{Moved(a)}[/]");
        if (a.Relation is Relation.Behind or Relation.Diverged)
        {
            var merges = a.OldMerges + a.NewMerges > 0
                ? $"  [yellow]merge commits are left out: {a.OldMerges} pushed, {a.NewMerges} rebased[/]"
                : "";
            Row("commits", $"{a.OldCommits.Count} pushed → {a.NewCommits.Count} rebased{merges}");
        }
        if (a.RemoteCheck is { } check)
            Row("on the remote", check.Sha == a.Remote.Sha
                ? $"[green]✔ {Ui.E(a.Remote.RemoteBranch!)} is still at {Ui.Short(check.Sha)}: the lease is current[/]"
                : check.Sha is null
                    ? $"[red]✘ {Ui.E(a.Remote.RemoteName!)} has no {Ui.E(a.Remote.RemoteBranch!)} any more[/]"
                    : $"[red]✘ {Ui.E(a.Remote.RemoteBranch!)} moved to {Ui.Short(check.Sha)} since your last fetch[/]");
        if (s.Verbose) Row("git", $"{Ui.E(a.Git.Exe)} {a.Git.Version}");
        c.Write(new Padder(grid, new Padding(0, 1, 0, 1)));
    }

    static string Ref(RefInfo r) =>
        $"[bold]{Ui.E(r.Label)}[/]  [deepskyblue1]{Ui.Short(r.Sha)}[/]{(r.Why is null ? "" : $"  [grey]{Ui.Code(r.Why)}[/]")}";

    static string Moved(Analysis a) =>
        (a.UpstreamAhead, a.UpstreamBehind) switch
        {
            (var ahead, 0) => $"{Plural(ahead, "new commit")} from {Ui.E(a.Onto.Label)} underneath",
            (0, var behind) => $"moved back {Plural(behind, "commit")} on {Ui.E(a.Onto.Label)}",
            var (ahead, behind) when a.Stacked => $"{Ui.E(a.Onto.Label)} was rewritten underneath: {ahead} commits gained, {behind} lost",
            var (ahead, behind) => $"{ahead} commits gained and {behind} lost underneath -- onto another line of history",
        };

    static void Commits(IAnsiConsole c, Analysis a)
    {
        c.Write(new Rule("[bold]commits[/]").LeftJustified().RuleStyle(new Style(Color.Grey)));
        if (a.Rows.Count == 0)
        {
            c.MarkupLine(" [grey]Neither version has commits of its own.[/]");
            c.WriteLine();
            return;
        }
        var table = new Table().Border(TableBorder.Rounded).BorderColor(Color.Grey);
        table.AddColumn(new TableColumn("[grey]pushed[/]").NoWrap());
        table.AddColumn(new TableColumn("[grey]rebased[/]").NoWrap());
        table.AddColumn(new TableColumn("[grey]subject[/]"));
        table.AddColumn(new TableColumn("[grey]result[/]").NoWrap());
        foreach (var row in a.Rows)
            table.AddRow(
                new Markup(row.Old is null ? "[grey]—[/]" : $"[grey]{row.OldIndex + 1,2}[/] [deepskyblue1]{Ui.Short(row.Old.Sha)}[/]"),
                new Markup(row.New is null ? "[grey]—[/]" : $"[grey]{row.NewIndex + 1,2}[/] [deepskyblue1]{Ui.Short(row.New.Sha)}[/]"),
                new Markup(Ui.E((row.New ?? row.Old)!.Subject)).Overflow(Overflow.Ellipsis),
                new Markup(Result(row)));
        c.Write(table);

        var differing = a.Rows.Where(r => r.Files.Count > 0 && r.Status is RowStatus.Changed or RowStatus.Dropped or RowStatus.Added).ToList();
        if (differing.Count > 0)
        {
            var tree = new Tree("[bold]files whose changes differ[/]") { Guide = TreeGuide.Line, Style = new Style(Color.Grey) };
            foreach (var row in differing)
            {
                var commit = (row.New ?? row.Old)!;
                var node = tree.AddNode($"{Glyph(row)} [deepskyblue1]{Ui.Short(commit.Sha)}[/] {Ui.E(commit.Subject)}");
                foreach (var file in row.Files)
                    node.AddNode(file.Kind switch
                    {
                        _ when row.Status == RowStatus.Dropped => $"[red]−[/] {Ui.E(file.Path)}",
                        _ when row.Status == RowStatus.Added => $"[yellow]+[/] {Ui.E(file.Path)}",
                        DeltaKind.Differs => $"[yellow]~[/] {Ui.E(file.Path)}  [grey]changed differently[/]",
                        DeltaKind.OnlyOld => $"[red]−[/] {Ui.E(file.Path)}  [grey]no longer changed by this commit[/]",
                        _ => $"[yellow]+[/] {Ui.E(file.Path)}  [grey]now also changed by this commit[/]",
                    });
            }
            c.Write(new Padder(tree, new Padding(1, 1, 0, 0)));
        }
        c.WriteLine();
    }

    static string Glyph(CommitRow row) => row.Status switch
    {
        RowStatus.Changed => "[red]✘[/]",
        RowStatus.Dropped => "[red]−[/]",
        _ => "[yellow]+[/]",
    };

    static string Result(CommitRow row)
    {
        var text = row.Status switch
        {
            RowStatus.Same => "[green]✔ same[/]",
            RowStatus.Reworded => "[deepskyblue1]✎ reworded[/]",
            RowStatus.Changed => $"[red]✘ changed[/] [grey]{Plural(row.Files.Count, "file")}[/]",
            RowStatus.Squashed => $"[yellow]↓ squashed[/] [grey]into {Ui.Short(row.Into!.New!.Sha)}[/]",
            RowStatus.Upstream => $"[green]✔ upstream[/] [grey]as {Ui.Short(row.Upstream!.Sha)}[/]",
            RowStatus.Dropped => $"[red]− dropped[/] [grey]{Plural(row.Files.Count, "file")}[/]",
            _ => $"[yellow]+ added[/] [grey]{Plural(row.Files.Count, "file")}[/]",
        };
        if (row.Moved) text += " [yellow]↕ moved[/]";
        if (row.AuthorChanged) text += " [yellow]author changed[/]";
        return text;
    }

    static void Content(IAnsiConsole c, Analysis a)
    {
        c.Write(new Rule("[bold]content[/]").LeftJustified().RuleStyle(new Style(Color.Grey)));
        var replay = a.OldBase == a.NewBase
            ? $"{Ui.E(a.Remote.Label)}"
            : $"{Ui.E(a.Remote.Label)}'s changes replayed onto {Ui.Short(a.NewBase)}";
        if (a.ContentSame)
        {
            c.MarkupLine($" [green]✔[/] Every file of {Ui.E(a.Local.Label)} is as in {replay}.");
            c.WriteLine();
            return;
        }
        c.MarkupLine($" [red]✘[/] {Plural(a.Content.Count, "file")} of {Ui.E(a.Local.Label)} {(a.Content.Count == 1 ? "differs" : "differ")} from {replay}:");
        var table = new Table().Border(TableBorder.Rounded).BorderColor(Color.Grey);
        table.AddColumn(new TableColumn("").NoWrap());
        table.AddColumn(new TableColumn("[grey]file[/]"));
        table.AddColumn(new TableColumn("[grey]lines[/]").RightAligned().NoWrap());
        table.AddColumn(new TableColumn("[grey]why, as far as known[/]"));
        foreach (var file in a.Content)
        {
            var p = file.Patch;
            var (glyph, kind) = p.Kind switch
            {
                'A' => ("[yellow]+[/]", "only in the rebased branch"),
                'D' => ("[red]−[/]", "missing from the rebased branch"),
                'R' => ("[yellow]→[/]", $"renamed from {p.OldPath}"),
                _ => ("[yellow]~[/]", ""),
            };
            var notes = new List<string>();
            if (kind.Length > 0) notes.Add($"[grey]{Ui.E(kind)}[/]");
            if (p.HasConflictMarkers) notes.Add("[red bold]conflict markers were committed[/]");
            if (file.Conflict) notes.Add("[yellow]the rebase had a conflict here: check how it was resolved[/]");
            if (file.AddedBy is { } added) notes.Add($"[grey]changed by the added commit {Ui.Short(added.New!.Sha)}[/]");
            if (file.DroppedBy is { } dropped) notes.Add($"[grey]changed by the dropped commit {Ui.Short(dropped.Old!.Sha)}[/]");
            if (notes.Count == 0) notes.Add("[red]a clean replay gives other content[/]");
            table.AddRow(
                new Markup(glyph),
                new Markup(Ui.E(p.Path)),
                new Markup(p.Binary ? "[grey]binary[/]" : $"[green]+{p.Added}[/] [red]−{p.Removed}[/]"),
                new Markup(string.Join("[grey];[/] ", notes)));
        }
        c.Write(table);
        c.WriteLine();
    }

    static void Diffs(IAnsiConsole c, Analysis a, int context)
    {
        if (a.ContentDiffs.Count == 0 && a.CommitDiffs.Count == 0) return;
        c.Write(new Rule("[bold]diffs[/]").LeftJustified().RuleStyle(new Style(Color.Grey)));
        foreach (var patch in a.ContentDiffs)
        {
            c.MarkupLine($"[bold]{Ui.E(patch.Path)}[/]  [grey]− a clean replay, + {Ui.E(a.Local.Label)}[/]");
            Patch(c, patch.Raw.Where(l => !l.StartsWith("index ")));
            c.WriteLine();
        }
        foreach (var diff in a.CommitDiffs)
        {
            var row = diff.Row;
            var commit = (row.New ?? row.Old)!;
            var (old, @new) = (row.Old is null ? "nothing" : Ui.Short(row.Old.Sha), row.New is null ? "nothing" : Ui.Short(row.New.Sha));
            c.MarkupLine($"[bold]{Ui.E(diff.Path)}[/] [grey]in[/] {Ui.E(commit.Subject)}  [grey]outer − the patch in {old}, outer + the patch in {@new}[/]");
            Interdiff(c, diff.Old, diff.New, context);
            c.WriteLine();
        }
    }

    // A unified diff, colored by line kind; a CR at a line's end shows as ␍.
    static void Patch(IAnsiConsole c, IEnumerable<string> lines)
    {
        var inHeader = true;
        foreach (var line in lines)
        {
            if (line.StartsWith("diff --git ")) inHeader = true;
            if (line.StartsWith("@@")) inHeader = false;
            var style = inHeader ? "grey"
                : line.StartsWith("@@") ? "deepskyblue1"
                : line.StartsWith('+') ? "green"
                : line.StartsWith('-') ? "red"
                : line.StartsWith('\\') ? "grey italic"
                : "default";
            c.MarkupLine($"[{style}]{Visible(line)}[/]");
        }
    }

    // The old patch against the new one, as range-diff shows it: the outer
    // column says which side a line is from, the inner one what the patch does.
    static void Interdiff(IAnsiConsole c, IReadOnlyList<string> old, IReadOnlyList<string> @new, int context)
    {
        if (old.Count + @new.Count > 20_000)
        {
            c.MarkupLine("[grey]  These patches are too long to compare here; `git range-diff` shows them.[/]");
            return;
        }
        var ops = LineDiff.Compute(old, @new);
        if (ops.All(o => o.Op == ' '))
        {
            c.MarkupLine("[grey]  The patches differ only in line numbers or context; `git range-diff` shows them whole.[/]");
            return;
        }
        var show = new bool[ops.Count];
        for (var i = 0; i < ops.Count; i++)
            if (ops[i].Op != ' ')
                for (var k = Math.Max(0, i - context); k <= Math.Min(ops.Count - 1, i + context); k++) show[k] = true;
        var gap = false;
        for (var i = 0; i < ops.Count; i++)
        {
            if (!show[i])
            {
                gap = true;
                continue;
            }
            if (gap) c.MarkupLine("[grey]  ⋯[/]");
            gap = false;
            var (op, line) = ops[i];
            var inner = line.StartsWith("@@") ? "deepskyblue1" : line.StartsWith('+') ? "green" : line.StartsWith('-') ? "red" : "default";
            c.MarkupLine(op switch
            {
                '-' => $"[red bold]-[/][red]{Visible(line)}[/]",
                '+' => $"[green bold]+[/][green]{Visible(line)}[/]",
                _ => $" [{inner} dim]{Visible(line)}[/]",
            });
        }
    }

    // The line for markup, with control characters -- a CR, or a binary file
    // git took for text -- drawn as their symbols instead of sent to the terminal.
    static string Visible(string line)
    {
        var text = new StringBuilder();
        var plain = new StringBuilder();
        foreach (var ch in line)
        {
            if (ch == '\t' || (ch >= ' ' && ch != '\x7f'))
            {
                plain.Append(ch);
                continue;
            }
            text.Append(Ui.E(plain.ToString())).Append("[grey]").Append(ch == '\x7f' ? '\u2421' : (char)('\u2400' + ch)).Append("[/]");
            plain.Clear();
        }
        return text.Append(Ui.E(plain.ToString())).ToString();
    }

    static Outcome Judge(Analysis a, Settings s)
    {
        if (a.RemoteMoved)
            return new(Color.Red, "✘ the remote moved", ExitCodes.Differs,
            [
                a.RemoteCheck!.Sha is null
                    ? $"{a.Remote.RemoteName} no longer has {a.Remote.RemoteBranch}; this check was against your last fetch."
                    : $"Someone pushed {a.Remote.RemoteBranch} since your last fetch, so this check was against an old version, and --force-with-lease would be rejected.",
                $"`git fetch {a.Remote.RemoteName}`, bring the new commits into {a.Local.Label}, and verify again.",
            ]);
        if (a.Relation == Relation.Same)
            return new(Color.Green, "✔ nothing to force-push", ExitCodes.Same,
                [$"{a.Local.Label} and {a.Remote.Label} are the same commit: the rebase changed nothing, and there is nothing to push."]);
        if (a.Relation == Relation.Ahead)
            return new(Color.Green, "✔ nothing was rewritten", ExitCodes.Same,
            [
                $"{a.Local.Label} contains {a.Remote.Label} and adds {Plural(a.Distance, "commit")} to it, so no history was rewritten.",
                "No force needed: a plain `git push` publishes them.",
            ]);

        var rangeDiff = $"`git range-diff {Ui.Short(a.OldBase)}..{a.Remote.Label} {Ui.Short(a.NewBase)}..{a.Local.Label}` compares them commit by commit.";
        var seeDiff = s.Diff ? rangeDiff : "Run again with `--diff` to see what differs; " + rangeDiff;
        var conflictsOnly = a.Content.Count > 0 && a.Content.All(f => f.Conflict && !f.Patch.HasConflictMarkers);
        var behind = a.Relation == Relation.Behind
            ? [$"{a.Local.Label} is {Plural(a.Distance, "commit")} behind {a.Remote.Label}, and a force-push would remove {(a.Distance == 1 ? "it" : "them")} from the remote."]
            : Array.Empty<string>();

        if (!a.ContentSame && conflictsOnly)
            return new(Color.Yellow, "⚠ review the conflict resolutions", ExitCodes.Differs,
                [.. behind,
                $"Only {Plural(a.Content.Count, "file")} where the rebase had conflicts differ{(a.Content.Count == 1 ? "s" : "")} from a clean replay. "
                    + "Make sure each resolution keeps both sides' intent.",
                seeDiff],
                "Once they are right, ");
        if (!a.ContentSame)
            return new(Color.Red, a.Relation == Relation.Behind ? "✘ a force-push would drop commits" : "✘ the rebase changed the content", ExitCodes.Differs,
                [.. behind,
                $"{Plural(a.Content.Count, "file")} of {a.Local.Label} differ{(a.Content.Count == 1 ? "s" : "")} from what replaying {a.Remote.Label} onto the new base gives.",
                seeDiff],
                "Only if every difference is intended, ");
        if (!a.CommitsSame)
            return new(s.Strict ? Color.Red : Color.Yellow,
                s.Strict ? "✘ the commits differ" : "⚠ same content, other commits",
                s.Strict ? ExitCodes.Differs : ExitCodes.Same,
                [$"Every file is as before, but the commits were {Reshaped(a)}.",
                "Fine if that was the point of the rebase (squash, split, reorder); otherwise " + (s.Diff ? rangeDiff : "see `--diff`.")],
                "If so, ");
        return new(Color.Green, "✔ safe to force-push", ExitCodes.Same,
            [a.OldBase == a.NewBase
                ? "Same content, same commits: the rebase changed nothing but the commit ids."
                : $"Same content, same commits: the rebase only moved {a.Local.Label} onto {Ui.Short(a.NewBase)}.",
            .. a.Rows.Any(r => r.Status == RowStatus.Reworded) ? ["Some commit messages were reworded."] : Array.Empty<string>()],
            "");
    }

    static string Reshaped(Analysis a)
    {
        var parts = new List<string>();
        void Add(RowStatus status, string what)
        {
            var n = a.Rows.Count(r => r.Status == status);
            if (n > 0) parts.Add($"{n} {what}");
        }
        Add(RowStatus.Changed, "changed");
        Add(RowStatus.Squashed, "squashed");
        Add(RowStatus.Dropped, "dropped");
        Add(RowStatus.Added, "added");
        var moved = a.Rows.Count(r => r.Moved);
        if (moved > 0) parts.Add($"{moved} moved");
        return parts.Count == 0 ? "reshaped" : $"reshaped: {string.Join(", ", parts)}";
    }

    // The push that overwrites exactly the verified version, and nothing newer.
    static string? PushCommand(Analysis a)
    {
        if (a.Local.Branch is null || a.Remote.RemoteName is null) return null;
        var target = a.Local.Branch == a.Remote.RemoteBranch ? a.Local.Branch : $"{a.Local.Branch}:{a.Remote.RemoteBranch}";
        return $"git push --force-with-lease={a.Remote.RemoteBranch}:{a.Remote.Sha} {a.Remote.RemoteName} {target}";
    }

    // The pushes, below the verdict rather than in its box, so that each copies whole.
    static void Offer(IAnsiConsole c, string prefix, string what, IReadOnlyList<string> pushes)
    {
        var verb = pushes.Count == 1 ? "this push overwrites" : "these pushes overwrite";
        var lead = prefix.Length == 0 ? char.ToUpperInvariant(verb[0]) + verb[1..] : prefix + verb;
        c.MarkupLine($" {Ui.Code($"{lead} exactly {what}, and nothing pushed since:")}");
        foreach (var push in pushes) Ui.Command(c, push);
    }

    static void Box(IAnsiConsole c, Outcome outcome) =>
        c.Write(Ui.Box(outcome.Title, outcome.Color, outcome.Lines.Select(l => new Markup(Ui.Code(l)))));

    // ─── stacks

    public static void Intro(StackInfo stack)
    {
        var c = Ui.Out;
        var n = stack.Layers.Count;
        c.WriteLine();
        c.Write(new Rule($"[bold deepskyblue1]verify rebase[/] [grey]·[/] [bold]a stack of {n} branch{(n == 1 ? "" : "es")}[/]")
            .LeftJustified().RuleStyle(new Style(Color.Grey)));
        var grid = new Grid();
        grid.AddColumn(new GridColumn().NoWrap().PadLeft(1).PadRight(2));
        grid.AddColumn(new GridColumn());
        grid.AddRow(new Markup("[grey]onto[/]"), new Markup(Ref(stack.Base)));
        for (var i = 0; i < n; i++)
        {
            var layer = stack.Layers[i];
            grid.AddRow(new Markup($"[grey]{i + 1}[/]"),
                new Markup(Ref(layer.Local with { Why = layer.Remote is null ? "never pushed" : $"pushed as {layer.Remote.Label}" })));
        }
        c.Write(new Padder(grid, new Padding(0, 1, 0, 1)));
        if (stack.Found)
            c.MarkupLine($"[grey] Found as the branches with a pushed version on the first-parent line from {Ui.E(stack.Base.Label)} "
                + $"to {Ui.E(stack.Layers[^1].Local.Label)}; name the branches, bottom first, to check others.[/]");
    }

    // One branch of the stack, under a header that says which.
    public static Outcome RenderLayer(StackInfo stack, int i, Settings s)
    {
        var c = Ui.Out;
        var layer = stack.Layers[i];
        c.WriteLine();
        c.Write(new Rule($"[bold deepskyblue1]{i + 1}/{stack.Layers.Count}[/] [bold]{Ui.E(layer.Local.Label)}[/]")
            .LeftJustified().RuleStyle(new Style(Color.Grey)));
        if (layer.Analysis is { } a) return Body(c, a, s);
        c.WriteLine();
        if (layer.Error is { } error)
        {
            c.Write(Ui.ErrorBox(error));
            return new(Color.Red, "✘ cannot verify", ExitCodes.Error, [error.Message]);
        }
        var below = i == 0 ? stack.Base : stack.Layers[i - 1].Local;
        var outcome = new Outcome(Color.Grey, "○ never pushed", ExitCodes.Same,
        [
            $"{layer.Local.Label} has no pushed version, so there is nothing to compare, and a push overwrites nothing.",
            $"Review it as its merge request shows it: `git diff {below.Label}...{layer.Local.Label}`.",
        ]);
        Box(c, outcome);
        return outcome;
    }

    // The stack at a glance, the verdict on all of it, and one push for all of it.
    public static int Summary(StackInfo stack, Settings s)
    {
        var c = Ui.Out;
        c.WriteLine();
        c.Write(new Rule("[bold]the stack[/]").LeftJustified().RuleStyle(new Style(Color.Grey)));
        var table = new Table().Border(TableBorder.Rounded).BorderColor(Color.Grey);
        table.AddColumn(new TableColumn("[grey]#[/]").RightAligned().NoWrap());
        table.AddColumn(new TableColumn("[grey]branch[/]"));
        table.AddColumn(new TableColumn("[grey]commits[/]").NoWrap());
        table.AddColumn(new TableColumn("[grey]files[/]").NoWrap());
        table.AddColumn(new TableColumn("[grey]verdict[/]"));
        for (var i = 0; i < stack.Layers.Count; i++)
        {
            var layer = stack.Layers[i];
            table.AddRow(
                new Markup($"[grey]{i + 1}[/]"),
                new Markup($"[bold]{Ui.E(layer.Local.Label)}[/]"),
                new Markup(CommitCell(layer.Analysis)),
                new Markup(FileCell(layer.Analysis)),
                new Markup($"[{layer.Outcome!.Color.ToMarkup()}]{Ui.E(layer.Outcome.Title)}[/]"));
        }
        c.Write(table);
        c.WriteLine();

        var verdict = StackVerdict(stack, s);
        Box(c, verdict);
        if (verdict.PushPrefix is { } prefix && StackPushes(stack) is { Count: > 0 } pushes)
        {
            Offer(c, prefix, "the versions checked here, all or none", pushes);
            var fresh = stack.Layers.Where(l => l.Remote is null).Select(l => l.Local.Label).ToList();
            if (fresh.Count > 0)
                c.MarkupLine($"[grey] {(pushes.Count == 1 ? "It" : "They")} also publish{(pushes.Count == 1 ? "es" : "")} {Ui.E(string.Join(", ", fresh))}, "
                    + $"never pushed so far; leave {(fresh.Count == 1 ? "it" : "them")} out to keep {(fresh.Count == 1 ? "it" : "them")} local.[/]");
        }
        return verdict.ExitCode;
    }

    static string CommitCell(Analysis? a) => a switch
    {
        null => "[grey]—[/]",
        { Relation: Relation.Same } => "[grey]the same[/]",
        { Relation: Relation.Ahead } => $"[grey]{a.Distance} added[/]",
        _ => $"{a.OldCommits.Count} → {a.NewCommits.Count}",
    };

    static string FileCell(Analysis? a)
    {
        if (a is null || a.Relation is Relation.Same or Relation.Ahead) return "[grey]—[/]";
        if (a.ContentSame) return "[green]all the same[/]";
        var conflicts = a.Content.Count(f => f.Conflict);
        return $"[red]{a.Content.Count} differ{(a.Content.Count == 1 ? "s" : "")}[/]"
            + (conflicts > 0 ? $"[grey],[/] [yellow]{conflicts} after a conflict[/]" : "");
    }

    static Outcome StackVerdict(StackInfo stack, Settings s)
    {
        var layers = stack.Layers;
        var n = layers.Count;
        static string Names(IEnumerable<Layer> which) => string.Join(", ", which.Select(l => l.Local.Label));
        static string Their(int count, string what) => count == 1 ? $"its section says {what}" : $"their sections say {what}";

        var failed = layers.Where(l => l.Outcome!.ExitCode == ExitCodes.Error).ToList();
        if (failed.Count > 0)
            return new(Color.Red, $"✘ could not check {failed.Count} of {n}", ExitCodes.Error,
                [$"{Names(failed)}: {Their(failed.Count, "why")}, above.", "Fix that, and run this again before you push any of them."]);

        var differ = layers.Where(l => l.Outcome!.ExitCode == ExitCodes.Differs).ToList();
        if (differ.Count > 0)
        {
            var red = differ.Any(l => l.Outcome!.Color == Color.Red);
            var moved = differ.Where(l => l.Analysis?.RemoteMoved == true).ToList();
            var changed = differ.Except(moved).ToList();
            return new(red ? Color.Red : Color.Yellow,
                moved.Count == differ.Count ? $"✘ the remote moved for {moved.Count} of {n}"
                    : red ? $"✘ {differ.Count} of {n} branches differ"
                    : $"⚠ review the conflict resolutions in {differ.Count} of {n}",
                ExitCodes.Differs,
                [.. changed.Count > 0 ? [$"{Names(changed)}: {Their(changed.Count, "what differs")}, above{(s.Diff ? "" : "; `--diff` shows it line by line")}."] : Array.Empty<string>(),
                .. moved.Count > 0 ? [$"The remote moved for {Names(moved)} since your last fetch: fetch, and verify again before you push."] : Array.Empty<string>()],
                moved.Count > 0 ? null : red ? "Only if every difference is intended, " : "Once they are right, ");
        }

        var reshaped = layers.Where(l => l.Outcome!.Color == Color.Yellow).ToList();
        if (reshaped.Count > 0)
            return new(Color.Yellow, "⚠ same content, other commits", ExitCodes.Same,
                [$"Every file is as before, but {Names(reshaped)} {(reshaped.Count == 1 ? "has" : "have")} other commits: fine if that was the point of the rebase."],
                "If so, ");
        if (layers.All(l => l.Analysis is { Relation: Relation.Same }))
            return new(Color.Green, "✔ nothing to force-push", ExitCodes.Same, ["Every branch is where it was pushed."]);
        return new(Color.Green, "✔ safe to force-push", ExitCodes.Same, ["The rebase altered no merge request's changes."], "");
    }

    // One push per remote, atomic: each branch leased to the version checked,
    // and one never pushed to there being none yet.
    static List<string> StackPushes(StackInfo stack)
    {
        var fallback = stack.Layers.LastOrDefault(l => l.Remote?.RemoteName is not null)?.Remote!.RemoteName ?? "origin";
        var refs = new List<(string Remote, string Lease, string Target)>();
        foreach (var layer in stack.Layers)
            if (layer.Analysis is { Relation: not Relation.Same } a && a.Local.Branch is { } branch && a.Remote.RemoteName is { } remote)
                refs.Add((remote, $"--force-with-lease={a.Remote.RemoteBranch}:{a.Remote.Sha}",
                    branch == a.Remote.RemoteBranch ? branch : $"{branch}:{a.Remote.RemoteBranch}"));
            else if (layer.Remote is null && layer.Error is null)
                refs.Add((fallback, $"--force-with-lease={layer.Local.Branch}:", layer.Local.Branch!));
        return refs.GroupBy(r => r.Remote)
            .Select(g => $"git push{(g.Count() > 1 ? " --atomic" : "")} {string.Join(' ', g.Select(r => r.Lease))} {g.Key} {string.Join(' ', g.Select(r => r.Target))}")
            .ToList();
    }

    static string Plural(int n, string noun) => n == 1 ? $"1 {noun}" : $"{n} {noun}s";
}

// ─── line diff ───────────────────────────────────────────────────────────────

static class LineDiff
{
    // Myers' shortest edit script, as (' ' | '-' | '+', line) in order.
    public static List<(char Op, string Line)> Compute(IReadOnlyList<string> a, IReadOnlyList<string> b)
    {
        int n = a.Count, m = b.Count, max = n + m, offset = max + 1;
        var v = new int[2 * max + 3];
        var trace = new List<int[]>();
        for (var d = 0; d <= max; d++)
        {
            trace.Add((int[])v.Clone());
            for (var k = -d; k <= d; k += 2)
            {
                var x = k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) ? v[offset + k + 1] : v[offset + k - 1] + 1;
                var y = x - k;
                while (x < n && y < m && a[x] == b[y]) (x, y) = (x + 1, y + 1);
                v[offset + k] = x;
                if (x >= n && y >= m) return Backtrack(a, b, trace, offset);
            }
        }
        return Backtrack(a, b, trace, offset);
    }

    static List<(char, string)> Backtrack(IReadOnlyList<string> a, IReadOnlyList<string> b, List<int[]> trace, int offset)
    {
        var ops = new List<(char, string)>();
        int x = a.Count, y = b.Count;
        for (var d = trace.Count - 1; d >= 0; d--)
        {
            var v = trace[d];
            var k = x - y;
            var previousK = k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) ? k + 1 : k - 1;
            var previousX = v[offset + previousK];
            var previousY = previousX - previousK;
            while (x > previousX && y > previousY)
            {
                (x, y) = (x - 1, y - 1);
                ops.Add((' ', a[x]));
            }
            if (d > 0)
            {
                if (x == previousX) ops.Add(('+', b[--y]));
                else ops.Add(('-', a[--x]));
            }
            (x, y) = (previousX, previousY);
        }
        ops.Reverse();
        return ops;
    }
}
