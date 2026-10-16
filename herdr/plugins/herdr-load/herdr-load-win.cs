// herdr-load-win: the Windows half of herdr-load. It lists Windows processes
// for herdr-load in WSL, which cannot see them: a newline on stdin asks for
// one snapshot, answered as
//
//   now <filetime>
//   <pid> <parent pid> <created, filetime> <working set, bytes> <user+kernel time, 100 ns> <name>
//   ...
//   (an empty line)
//
// One NtQuerySystemInformation call per snapshot returns every process with
// these fields, so no process is opened and no WMI is asked. It exits when its
// stdin closes, so it never outlives the reporter that started it.
#:property PublishAot=true
#:property InvariantGlobalization=true
#:property OptimizationPreference=Size

using System.Runtime.InteropServices;
using System.Text;

const int SystemProcessInformation = 5;
const int StatusInfoLengthMismatch = unchecked((int)0xC0000004);

var input = new StreamReader(Console.OpenStandardInput());
var output = new StreamWriter(Console.OpenStandardOutput(), new UTF8Encoding(false)) { NewLine = "\n" };
var size = 1 << 20;
var buf = Marshal.AllocHGlobal(size);
while (input.ReadLine() is not null)
{
    int status;
    while ((status = NtQuerySystemInformation(SystemProcessInformation, buf, size, out var needed)) == StatusInfoLengthMismatch)
    {
        Marshal.FreeHGlobal(buf);
        size = Math.Max(size * 2, needed + (64 << 10));
        buf = Marshal.AllocHGlobal(size);
    }
    if (status == 0)
    {
        GetSystemTimeAsFileTime(out var now);
        output.WriteLine($"now {now}");
        // SYSTEM_PROCESS_INFORMATION on x64, one entry per process, chained by
        // NextEntryOffset.
        for (var e = buf; ; )
        {
            var pid = Marshal.ReadInt64(e, 0x50);
            if (pid != 0)
            {
                var nameLength = (ushort)Marshal.ReadInt16(e, 0x38);
                var name = Marshal.PtrToStringUni(Marshal.ReadIntPtr(e, 0x40), nameLength / 2);
                var cpu = Marshal.ReadInt64(e, 0x28) + Marshal.ReadInt64(e, 0x30);
                output.WriteLine($"{pid} {Marshal.ReadInt64(e, 0x58)} {Marshal.ReadInt64(e, 0x20)} {Marshal.ReadInt64(e, 0x90)} {cpu} {name}");
            }
            var next = Marshal.ReadInt32(e, 0);
            if (next == 0)
                break;
            e += next;
        }
    }
    output.WriteLine();
    output.Flush();
}

[DllImport("ntdll.dll")]
static extern int NtQuerySystemInformation(int infoClass, IntPtr info, int length, out int returnLength);

[DllImport("kernel32.dll")]
static extern void GetSystemTimeAsFileTime(out long fileTime);
