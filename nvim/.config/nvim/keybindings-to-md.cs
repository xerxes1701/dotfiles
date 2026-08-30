#!/usr/bin/env dotnet
//
// keybindings-to-md.cs
//
// Single-file (.NET 10 file-based app) that converts `keybindings.yaml` into a
// `keybindings.md` reference document with a table of contents and four views:
//
//   1. Grouped by file
//   2. Grouped by plugin (only bindings that come from files configuring a plugin)
//   3. Grouped logically (by the `group` field)
//   4. Ungrouped, just sorted
//
// Implicitly-defined keybindings (those a plugin sets by default, marked
// `source: default` in the YAML) are flagged with a 🔸 marker everywhere.
//
// Usage:
//   dotnet run keybindings-to-md.cs -- [input.yaml] [output.md] [options]
//   (defaults: keybindings.yaml -> keybindings.md, relative to the CWD)
//
// Options:
//   -w, --desc-width N     max width of the Description column (default 80)
//   -a, --action-width N   max width of the Action column      (default 40)
// Columns are padded to their width in the source and values longer than the
// width are truncated with an ellipsis.

#:package YamlDotNet@16.3.0

using System.Text;
using YamlDotNet.Serialization;

// Parse args: positional [input] [output], plus optional column-width flags:
//   --desc-width/-w N     max width of the Description column (default 80)
//   --action-width/-a N   max width of the Action column      (default 40)
string input = "keybindings.yaml";
string output = "keybindings.md";
int descWidth = 80;
int actionWidth = 40;
var positional = new List<string>();
for (int i = 0; i < args.Length; i++)
{
    string a = args[i];
    if (TryWidthFlag(a, "--desc-width", "-w", args, ref i, ref descWidth, out bool descErr))
    {
        if (descErr) return 1;
    }
    else if (TryWidthFlag(a, "--action-width", "-a", args, ref i, ref actionWidth, out bool actErr))
    {
        if (actErr) return 1;
    }
    else positional.Add(a);
}
if (descWidth < 10) descWidth = 10;
if (actionWidth < 10) actionWidth = 10;
if (positional.Count > 0) input = positional[0];
if (positional.Count > 1) output = positional[1];

// Returns true if `arg` matches the flag (long/short, space- or =-separated),
// consuming the value; sets `error` when the value is missing/invalid.
static bool TryWidthFlag(string arg, string longName, string shortName,
    string[] args, ref int i, ref int target, out bool error)
{
    error = false;
    if (arg == longName || arg == shortName)
    {
        if (i + 1 >= args.Length || !int.TryParse(args[++i], out target))
        {
            Console.Error.WriteLine($"error: {longName}/{shortName} requires an integer value");
            error = true;
        }
        return true;
    }
    if (arg.StartsWith(longName + "="))
    {
        if (!int.TryParse(arg[(longName.Length + 1)..], out target))
        {
            Console.Error.WriteLine($"error: invalid {longName} value");
            error = true;
        }
        return true;
    }
    return false;
}

if (!File.Exists(input))
{
    Console.Error.WriteLine($"error: input file not found: {input}");
    return 1;
}

var deserializer = new DeserializerBuilder().IgnoreUnmatchedProperties().Build();
Root root;
try
{
    root = deserializer.Deserialize<Root>(File.ReadAllText(input)) ?? new Root();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"error: failed to parse YAML: {ex.Message}");
    return 1;
}

var all = new List<Binding>();
all.AddRange(root.Keybindings ?? new());
all.AddRange(root.DefaultBindings ?? new());
all.AddRange(root.BuiltinBindings ?? new());
foreach (var b in all) b.Normalize();

if (all.Count == 0)
{
    Console.Error.WriteLine("error: no keybindings found in input.");
    return 1;
}

var md = new MarkdownBuilder(root, all, descWidth, actionWidth);
File.WriteAllText(output, md.Build());

int defaults = all.Count(b => b.IsDefault);
int builtins = all.Count(b => b.IsBuiltin);
int explicits = all.Count - defaults - builtins;
Console.WriteLine($"Wrote {output}: {all.Count} keybindings ({explicits} explicit, {defaults} implicit defaults, {builtins} built-ins).");
return 0;


// --------------------------------------------------------------------------
// Model
// --------------------------------------------------------------------------

class Root
{
    [YamlMember(Alias = "meta")]
    public Dictionary<string, string>? Meta { get; set; }

    [YamlMember(Alias = "keybindings")]
    public List<Binding>? Keybindings { get; set; }

    [YamlMember(Alias = "default_bindings")]
    public List<Binding>? DefaultBindings { get; set; }

    [YamlMember(Alias = "builtin_bindings")]
    public List<Binding>? BuiltinBindings { get; set; }
}

class Binding
{
    [YamlMember(Alias = "key")] public string Key { get; set; } = "";
    [YamlMember(Alias = "mode")] public string Mode { get; set; } = "";
    [YamlMember(Alias = "action")] public string Action { get; set; } = "";
    [YamlMember(Alias = "description")] public string Description { get; set; } = "";
    [YamlMember(Alias = "file")] public string File { get; set; } = "";
    [YamlMember(Alias = "plugin")] public string Plugin { get; set; } = "";
    [YamlMember(Alias = "group")] public string Group { get; set; } = "";
    [YamlMember(Alias = "source")] public string Source { get; set; } = "explicit";

    public bool IsDefault => string.Equals(Source, "default", StringComparison.OrdinalIgnoreCase);
    public bool IsBuiltin => string.Equals(Source, "builtin", StringComparison.OrdinalIgnoreCase);

    public void Normalize()
    {
        Key = (Key ?? "").Trim();
        Mode = (Mode ?? "").Trim();
        Action = (Action ?? "").Trim();
        Description = (Description ?? "").Trim();
        File = (File ?? "").Trim();
        Plugin = (Plugin ?? "").Trim();
        Group = string.IsNullOrWhiteSpace(Group) ? "Uncategorized" : Group.Trim();
        Source = string.IsNullOrWhiteSpace(Source) ? "explicit" : Source.Trim();
    }
}

// --------------------------------------------------------------------------
// Markdown generation
// --------------------------------------------------------------------------

class MarkdownBuilder
{
    private const string DefaultMarker = "🔸";
    private const string BuiltinMarker = "🔹";

    private readonly Root _root;
    private readonly List<Binding> _all;
    private readonly int _descWidth;
    private readonly int _actionWidth;
    private readonly StringBuilder _sb = new();

    // Stable anchor ids. Both the TOC and the headings resolve to the same
    // string for the same input, so links never drift.
    private const string IdByFile = "sec-by-file";
    private const string IdByPlugin = "sec-by-plugin";
    private const string IdLogical = "sec-logical";
    private const string IdAll = "sec-all";
    private static string IdForFile(string f) => "file-" + Slug(f);
    private static string IdForPlugin(string p) => "plugin-" + Slug(p);
    private static string IdForGroup(string g) => "group-" + Slug(g);

    public MarkdownBuilder(Root root, List<Binding> all, int descWidth, int actionWidth)
    {
        _root = root;
        _all = all;
        _descWidth = descWidth;
        _actionWidth = actionWidth;
    }

    public string Build()
    {
        _sb.Clear();

        WriteHeader();
        WriteToc();
        WriteByFile();
        WriteByPlugin();
        WriteByLogicalGroup();
        WriteUngrouped();

        return _sb.ToString();
    }

    // ---- sections ------------------------------------------------------- #

    private void WriteHeader()
    {
        Line("# Neovim Keybindings");
        Line();
        Line("_Generated from `keybindings.yaml` by `keybindings-to-md.cs`._");
        Line();

        if (_root.Meta is { Count: > 0 })
        {
            Line("| Setting | Value |");
            Line("| --- | --- |");
            foreach (var kv in _root.Meta)
                Line($"| {Cell(kv.Key)} | {Code(kv.Value)} |");
            Line();
        }

        int defaultCount = _all.Count(b => b.IsDefault);
        int builtinCount = _all.Count(b => b.IsBuiltin);
        int explicitCount = _all.Count - defaultCount - builtinCount;

        Line("> **Legend**");
        Line($"> {DefaultMarker} marks an **implicitly-defined** keybinding — one a plugin sets by");
        Line("> default (out-of-the-box), not something written in this configuration.");
        Line(">");
        Line($"> {BuiltinMarker} marks a **Neovim built-in** default — a core editor command that is");
        Line("> not defined via a keymap (it never appears in `:map`/`nvim_get_keymap`).");
        Line(">");
        Line($"> Totals: **{_all.Count}** keybindings — **{explicitCount}** explicit, **{defaultCount}** implicit defaults ({DefaultMarker}), **{builtinCount}** built-ins ({BuiltinMarker}).");
        Line();
    }

    private void WriteToc()
    {
        Line("## Table of Contents");
        Line();

        // Section 1
        Line($"1. [Grouped by File](#{IdByFile})");
        foreach (var file in FilesInOrder())
            Line($"   - [{Escape(file)}](#{IdForFile(file)})");

        // Section 2
        Line($"2. [Grouped by Plugin](#{IdByPlugin})");
        foreach (var plugin in PluginsInOrder())
            Line($"   - [{Escape(plugin)}](#{IdForPlugin(plugin)})");

        // Section 3
        Line($"3. [Grouped Logically](#{IdLogical})");
        foreach (var group in GroupsInOrder())
            Line($"   - [{Escape(group)}](#{IdForGroup(group)})");

        // Section 4
        Line($"4. [All Keybindings (sorted)](#{IdAll})");
        Line();
    }

    private void WriteByFile()
    {
        Heading2("Grouped by File", IdByFile);
        Line("Every keybinding explicitly defined in the configuration, grouped by the");
        Line("file it lives in. (Implicit plugin defaults have no source file and appear");
        Line("in the plugin and logical views instead.)");
        Line();

        foreach (var file in FilesInOrder())
        {
            var rows = _all.Where(b => b.File == file)
                           .OrderBy(b => b.Key, StringComparer.OrdinalIgnoreCase)
                           .ToList();
            var plugins = rows.Select(r => r.Plugin)
                              .Where(p => !string.IsNullOrEmpty(p))
                              .Distinct().ToList();
            string subtitle = plugins.Count > 0
                ? $"Configures: {string.Join(", ", plugins.Select(Code))}"
                : "Core configuration (no plugin)";

            Heading3(file, IdForFile(file));
            Line(subtitle);
            Line();
            Table(rows, includePlugin: false);
        }
    }

    private void WriteByPlugin()
    {
        Heading2("Grouped by Plugin", IdByPlugin);
        Line("Keybindings associated with a plugin — both those defined in the plugin's");
        Line($"config file and the plugin's implicit defaults ({DefaultMarker}). Core-config");
        Line("keybindings that belong to no plugin are omitted here.");
        Line();

        foreach (var plugin in PluginsInOrder())
        {
            var rows = _all.Where(b => b.Plugin == plugin)
                           .OrderBy(b => b.IsDefault)
                           .ThenBy(b => b.Key, StringComparer.OrdinalIgnoreCase)
                           .ToList();

            int def = rows.Count(r => r.IsDefault);
            var files = rows.Select(r => r.File).Where(f => !string.IsNullOrEmpty(f)).Distinct().ToList();

            Heading3(plugin, IdForPlugin(plugin));
            var parts = new List<string>();
            if (files.Count > 0)
                parts.Add($"Defined in: {string.Join(", ", files.Select(Code))}");
            if (def > 0)
                parts.Add($"includes {def} implicit default(s) {DefaultMarker}");
            if (parts.Count > 0)
            {
                Line(string.Join("; ", parts));
                Line();
            }
            Table(rows, includePlugin: false);
        }
    }

    private void WriteByLogicalGroup()
    {
        Heading2("Grouped Logically", IdLogical);
        Line("All keybindings organized by their logical purpose, regardless of file or");
        Line("plugin.");
        Line();

        foreach (var group in GroupsInOrder())
        {
            var rows = _all.Where(b => b.Group == group)
                           .OrderBy(b => b.Key, StringComparer.OrdinalIgnoreCase)
                           .ThenBy(b => b.Mode, StringComparer.OrdinalIgnoreCase)
                           .ToList();

            Heading3(group, IdForGroup(group));
            Table(rows, includePlugin: true);
        }
    }

    private void WriteUngrouped()
    {
        Heading2("All Keybindings (sorted)", IdAll);
        Line("Every keybinding in one flat table, sorted by key then mode.");
        Line();

        var rows = _all.OrderBy(b => b.Key, StringComparer.OrdinalIgnoreCase)
                       .ThenBy(b => b.Mode, StringComparer.OrdinalIgnoreCase)
                       .ToList();
        Table(rows, includePlugin: true);
    }

    // ---- ordering helpers ----------------------------------------------- #

    private IEnumerable<string> FilesInOrder() =>
        _all.Where(b => !string.IsNullOrEmpty(b.File))
            .Select(b => b.File).Distinct()
            .OrderBy(f => f, StringComparer.OrdinalIgnoreCase);

    private IEnumerable<string> PluginsInOrder() =>
        _all.Where(b => !string.IsNullOrEmpty(b.Plugin))
            .Select(b => b.Plugin).Distinct()
            .OrderBy(p => p, StringComparer.OrdinalIgnoreCase);

    private IEnumerable<string> GroupsInOrder() =>
        _all.Select(b => b.Group).Distinct()
            .OrderBy(g => g, StringComparer.OrdinalIgnoreCase);

    // ---- table rendering ------------------------------------------------ #

    private void Table(List<Binding> rows, bool includePlugin)
    {
        if (rows.Count == 0)
        {
            Line("_No keybindings._");
            Line();
            return;
        }

        // Header labels padded so the source column is at least as wide as the
        // configured max, giving the rendered table a wider Description/Action.
        string descHead = Pad("Description", _descWidth);
        string descRule = new string('-', Math.Max(3, _descWidth));
        string actHead = Pad("Action", _actionWidth);
        string actRule = new string('-', Math.Max(3, _actionWidth));

        if (includePlugin)
        {
            Line($"| Key | Mode | {descHead} | {actHead} | Plugin | Implicit |");
            Line($"| --- | --- | {descRule} | {actRule} | --- | --- |");
            foreach (var r in rows)
                Line($"| {Code(r.Key)} | {Cell(r.Mode)} | {DescCell(r.Description)} | {CodeCell(r.Action, _actionWidth)} | {PluginCell(r)} | {ImplicitCell(r)} |");
        }
        else
        {
            Line($"| Key | Mode | {descHead} | {actHead} | Implicit |");
            Line($"| --- | --- | {descRule} | {actRule} | --- |");
            foreach (var r in rows)
                Line($"| {Code(r.Key)} | {Cell(r.Mode)} | {DescCell(r.Description)} | {CodeCell(r.Action, _actionWidth)} | {ImplicitCell(r)} |");
        }
        Line();
    }

    private static string PluginCell(Binding b) =>
        string.IsNullOrEmpty(b.Plugin) ? "_core_" : Code(b.Plugin);

    // Implicit column marker: plugin defaults and Neovim built-ins each get
    // their own marker; explicit config rows are blank.
    private static string ImplicitCell(Binding b) =>
        b.IsDefault ? DefaultMarker : b.IsBuiltin ? BuiltinMarker : "";

    // Description cell: truncate to the max width, then pad to that width so
    // the source column lines up. Empty descriptions still pad to width.
    private string DescCell(string? text)
    {
        string t = Truncate(text ?? "", _descWidth);
        return Pad(Escape(t).Replace("|", "\\|"), _descWidth);
    }

    // ---- low-level emit ------------------------------------------------- #

    private void Heading2(string text, string id)
    {
        Line($"## {Escape(text)} <a id=\"{id}\"></a>");
        Line();
    }

    private void Heading3(string text, string id)
    {
        Line($"### {Escape(text)} <a id=\"{id}\"></a>");
        Line();
    }

    private void Line(string text = "") => _sb.Append(text).Append('\n');

    // ---- text helpers --------------------------------------------------- #

    // Escape text destined for a plain markdown table cell.
    private static string Cell(string? text)
    {
        if (string.IsNullOrEmpty(text)) return "";
        return Escape(text).Replace("|", "\\|");
    }

    // Wrap in a code span, escaping pipes and backticks so tables stay intact.
    private static string Code(string? text)
    {
        if (string.IsNullOrEmpty(text)) return "";
        string t = text.Replace("|", "\\|").Replace("`", "'");
        return $"`{t}`";
    }

    // Like Code, but truncates the value to `width` and pads the whole cell
    // (backticks included) to `width` so the source column aligns.
    private static string CodeCell(string? text, int width)
    {
        string cell = Code(Truncate(text ?? "", width));
        return Pad(cell, width);
    }

    // Truncate to `max` characters, appending an ellipsis when shortened.
    private static string Truncate(string text, int max)
    {
        if (text.Length <= max) return text;
        if (max <= 1) return text[..max];
        return text[..(max - 1)] + "…";
    }

    // Right-pad with spaces to a minimum width (never truncates).
    private static string Pad(string text, int width) =>
        text.Length >= width ? text : text + new string(' ', width - text.Length);

    private static string Escape(string text) =>
        text.Replace("<", "&lt;").Replace(">", "&gt;");

    // GitHub-style anchor slug: deterministic, no counter. Callers add a
    // section prefix (file-/plugin-/group-) so the ids are globally unique.
    private static string Slug(string text)
    {
        var sb = new StringBuilder();
        foreach (char c in text.ToLowerInvariant())
        {
            if (char.IsLetterOrDigit(c)) sb.Append(c);
            else if (c == ' ' || c == '-' || c == '_') sb.Append('-');
            // drop everything else (dots, parens, slashes, etc.)
        }
        return sb.ToString().Trim('-');
    }
}
