// Fixture for verify.sh. Exercises the C# path: roslyn attach, treesitter
// parse, inlay hints, code lens.

internal static class Program
{
    private static void Main()
    {
        var msg = Greet("world");
        Console.WriteLine(msg);
    }

    internal static string Greet(string who) => $"hello, {who}";
}
