// Compiled by Windows PowerShell 5.1 in Start-Portal.ps1, not by an application host.
// The job's sole handle belongs to the launcher. Windows closes it even on TerminateProcess.
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace MealPlanning.LocalDevelopment
{
    public sealed class OwnedProcess : IDisposable
    {
        private IntPtr job;
        private IntPtr process;

        public int ProcessId { get; private set; }

        public bool HasExited
        {
            get { return WaitForSingleObject(process, 0) == 0; }
        }

        public int ExitCode
        {
            get
            {
                uint code;
                if (!GetExitCodeProcess(process, out code)) throw new Win32Exception();
                return unchecked((int)code);
            }
        }

        public static OwnedProcess Start(string executable, string[] arguments, string workingDirectory)
        {
            var owner = new OwnedProcess();
            var information = new ProcessInformation();
            IntPtr input = IntPtr.Zero, output = IntPtr.Zero, error = IntPtr.Zero;
            try
            {
                owner.job = CreateJobObject(IntPtr.Zero, null);
                if (owner.job == IntPtr.Zero) throw new Win32Exception();
                var limits = new ExtendedLimitInformation();
                limits.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
                if (!SetInformationJobObject(owner.job, 9, ref limits, (uint)Marshal.SizeOf(limits)))
                    throw new Win32Exception();

                input = DuplicateStandardHandle(-10);
                output = DuplicateStandardHandle(-11);
                error = DuplicateStandardHandle(-12);
                var startup = new StartupInformation();
                startup.Size = Marshal.SizeOf(startup);
                startup.Flags = 0x100; // STARTF_USESTDHANDLES
                startup.StandardInput = input;
                startup.StandardOutput = output;
                startup.StandardError = error;

                var command = new StringBuilder(Quote(executable));
                foreach (var argument in arguments) command.Append(' ').Append(Quote(argument));

                // Suspend BEFORE any Node code runs: no child can escape between spawn and assignment.
                if (!CreateProcess(executable, command, IntPtr.Zero, IntPtr.Zero, true,
                    0x00000004 | 0x08000000, IntPtr.Zero, workingDirectory, ref startup, out information))
                    throw new Win32Exception();
                owner.process = information.Process;
                owner.ProcessId = information.ProcessId;
                if (!AssignProcessToJobObject(owner.job, owner.process)) throw new Win32Exception();
                if (ResumeThread(information.Thread) == uint.MaxValue) throw new Win32Exception();
                return owner;
            }
            catch
            {
                if (information.Process != IntPtr.Zero) TerminateProcess(information.Process, 1);
                owner.Dispose();
                throw;
            }
            finally
            {
                if (information.Thread != IntPtr.Zero) CloseHandle(information.Thread);
                CloseValidHandle(input);
                CloseValidHandle(output);
                CloseValidHandle(error);
            }
        }

        public void Dispose()
        {
            if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
            if (process != IntPtr.Zero) { CloseHandle(process); process = IntPtr.Zero; }
        }

        private static IntPtr DuplicateStandardHandle(int kind)
        {
            var source = GetStdHandle(kind);
            if (source == IntPtr.Zero || source == new IntPtr(-1)) return IntPtr.Zero;
            IntPtr copy;
            var current = GetCurrentProcess();
            if (!DuplicateHandle(current, source, current, out copy, 0, true, 2)) throw new Win32Exception();
            return copy;
        }

        private static void CloseValidHandle(IntPtr handle)
        {
            if (handle != IntPtr.Zero && handle != new IntPtr(-1)) CloseHandle(handle);
        }

        private static string Quote(string argument)
        {
            var result = new StringBuilder("\"");
            var backslashes = 0;
            foreach (var character in argument)
            {
                if (character == '\\') { backslashes++; continue; }
                if (character == '"') result.Append('\\', backslashes * 2 + 1).Append('"');
                else result.Append('\\', backslashes).Append(character);
                backslashes = 0;
            }
            return result.Append('\\', backslashes * 2).Append('"').ToString();
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct BasicLimitInformation
        {
            public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass, SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct IoCounters
        {
            public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount;
            public ulong ReadTransferCount, WriteTransferCount, OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ExtendedLimitInformation
        {
            public BasicLimitInformation BasicLimitInformation;
            public IoCounters IoInfo;
            public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct StartupInformation
        {
            public int Size;
            public string Reserved, Desktop, Title;
            public int X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags;
            public short ShowWindow, ReservedSize;
            public IntPtr ReservedPointer, StandardInput, StandardOutput, StandardError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ProcessInformation
        {
            public IntPtr Process, Thread;
            public int ProcessId, ThreadId;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(IntPtr job, int kind, ref ExtendedLimitInformation limits, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcess(string application, StringBuilder command, IntPtr processAttributes,
            IntPtr threadAttributes, bool inheritHandles, uint flags, IntPtr environment, string directory,
            ref StartupInformation startup, out ProcessInformation information);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint ResumeThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll")]
        private static extern IntPtr GetStdHandle(int kind);
        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool DuplicateHandle(IntPtr sourceProcess, IntPtr source, IntPtr targetProcess,
            out IntPtr target, uint access, bool inherit, uint options);
    }
}
