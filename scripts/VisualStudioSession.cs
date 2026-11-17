// Compiled by Windows PowerShell 5.1. Uses the IDE's automation interface without
// requiring a particular Visual Studio installation path or interop package.
using System;
using System.Diagnostics;
using System.Globalization;
using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace MealPlanning.LocalDevelopment
{
    public sealed class VisualStudioSession : IDisposable
    {
        private Process process;
        private object dte, debugger, solution, build;
        private bool debuggingStarted;
        private readonly Stopwatch idle = Stopwatch.StartNew();

        public string State { get; private set; }

        public static VisualStudioSession Connect(int processId, string solutionPath)
        {
            var session = new VisualStudioSession();
            try
            {
                session.process = Process.GetProcessById(processId);
                var handle = session.process.Handle; // Retain the exact process identity.
                session.dte = FindAutomationObject(processId);
                if (session.dte == null) throw new InvalidOperationException("The owning Visual Studio instance is unavailable.");
                session.solution = Get(session.dte, "Solution");
                if (!string.Equals(Convert.ToString(Get(session.solution, "FullName"), CultureInfo.InvariantCulture),
                    solutionPath, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The owning Visual Studio instance has a different solution open.");
                session.debugger = Get(session.dte, "Debugger");
                session.build = Get(session.solution, "SolutionBuild");
                return session;
            }
            catch
            {
                session.Dispose();
                throw;
            }
        }

        public void BeginLaunchWait()
        {
            // Connection and the Docker/Neon preflight happen before the portal
            // process starts. Do not charge that work against debugger startup.
            idle.Restart();
            State = "Waiting for debugger";
        }

        public bool HasEnded
        {
            get
            {
                if (process.HasExited) { State = "IDE exited"; return true; }
                try
                {
                    var mode = Convert.ToInt32(Get(debugger, "CurrentMode"), CultureInfo.InvariantCulture);
                    if (mode == 2 || mode == 3) // Break mode and run mode both own the portal.
                    {
                        debuggingStarted = true;
                        State = mode == 2 ? "Debugger paused" : "Debugger running";
                        return false;
                    }
                    if (debuggingStarted) { State = "Debugger stopped"; return true; }

                    // JSPS starts the server during local Deploy, before Debug.Start.
                    // Allow that transition, but also clean up a cancelled/failed launch.
                    if (Convert.ToInt32(Get(build, "BuildState"), CultureInfo.InvariantCulture) == 1)
                    {
                        idle.Restart();
                        State = "Local build/deploy in progress";
                        return false;
                    }
                    var failed = Convert.ToInt32(Get(build, "LastBuildInfo"), CultureInfo.InvariantCulture) != 0;
                    // Docker image deployment for a four-project startup can be
                    // serialized and legitimately take longer than 30 seconds.
                    // Match the browser launch timeout before treating the start
                    // as abandoned; explicit build failures still stop at once.
                    var timedOut = idle.Elapsed > TimeSpan.FromSeconds(120);
                    State = failed ? "Local build/deploy failed" : timedOut ? "Debugger startup timed out" : "Waiting for debugger";
                    return failed || timedOut;
                }
                catch (COMException exception)
                {
                    return HandleAutomationFailure(exception);
                }
                catch (TargetInvocationException exception)
                {
                    var automationFailure = exception.InnerException as COMException;
                    if (automationFailure == null) throw;
                    return HandleAutomationFailure(automationFailure);
                }
            }
        }

        public void Dispose()
        {
            Release(build); build = null;
            Release(solution); solution = null;
            Release(debugger); debugger = null;
            Release(dte); dte = null;
            if (process != null) { process.Dispose(); process = null; }
        }

        private static object Get(object value, string name)
        {
            return value.GetType().InvokeMember(name, BindingFlags.GetProperty, null, value, null,
                CultureInfo.InvariantCulture);
        }

        private bool HandleAutomationFailure(COMException exception)
        {
            // The UI can reject a call while starting/stopping. Retry on the next tick.
            if (exception.ErrorCode == unchecked((int)0x80010001) ||
                exception.ErrorCode == unchecked((int)0x8001010A)) { State = "IDE busy"; return false; }
            // The IDE closed or its automation server disconnected.
            if (exception.ErrorCode == unchecked((int)0x80010108) ||
                exception.ErrorCode == unchecked((int)0x800706BA) ||
                exception.ErrorCode == unchecked((int)0x800401FD)) { State = "IDE disconnected"; return true; }
            ExceptionDispatchInfo.Capture(exception).Throw();
            return true;
        }

        private static object FindAutomationObject(int processId)
        {
            IRunningObjectTable table = null;
            IBindCtx context = null;
            IEnumMoniker iterator = null;
            try
            {
                Marshal.ThrowExceptionForHR(GetRunningObjectTable(0, out table));
                Marshal.ThrowExceptionForHR(CreateBindCtx(0, out context));
                table.EnumRunning(out iterator);
                var monikers = new IMoniker[1];
                while (iterator.Next(1, monikers, IntPtr.Zero) == 0)
                {
                    try
                    {
                        string name;
                        monikers[0].GetDisplayName(context, null, out name);
                        if (name.StartsWith("!VisualStudio.DTE.", StringComparison.Ordinal) &&
                            name.EndsWith(":" + processId.ToString(CultureInfo.InvariantCulture), StringComparison.Ordinal))
                        {
                            object result;
                            table.GetObject(monikers[0], out result);
                            return result;
                        }
                    }
                    finally { Release(monikers[0]); }
                }
                return null;
            }
            finally { Release(iterator); Release(context); Release(table); }
        }

        private static void Release(object value)
        {
            if (value != null && Marshal.IsComObject(value)) Marshal.ReleaseComObject(value);
        }

        [DllImport("ole32.dll")]
        private static extern int GetRunningObjectTable(int reserved, out IRunningObjectTable table);
        [DllImport("ole32.dll")]
        private static extern int CreateBindCtx(int reserved, out IBindCtx context);
    }
}
