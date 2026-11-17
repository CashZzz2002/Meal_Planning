import { spawn } from "node:child_process";
import { createServer } from "node:net";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { localEndpoint, readPortalSettings, repositoryRoot } from "./public-config.mjs";

async function ensurePortAvailable(endpoint) {
  await new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", () => reject(new Error(`Portal port ${endpoint.port} is already in use. Stop its owner before starting another portal.`)));
    server.listen(endpoint.port, endpoint.hostname, () => server.close(resolve));
  });
}

async function waitForApi(settings) {
  console.log(`[${settings.name} portal] Waiting for API /health/ready...`);
  const deadline = Date.now() + 120000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${settings.apiUrl}/health/ready`, { signal: AbortSignal.timeout(2000) });
      if (response.ok && (await response.json()).status === "Healthy") return;
    } catch {
      // An API launched concurrently by Visual Studio may not be listening yet.
    }
    await delay(500);
  }
  throw new Error(`${settings.name} API did not pass /health/ready within 120 seconds. Check the API startup output.`);
}

try {
  const [name = "", command = "", ...requestedArgs] = process.argv.slice(2);
  const args = requestedArgs.filter((argument) => argument !== "--wait-for-api");
  if (!["dev", "build", "start"].includes(command)) {
    throw new Error("Usage: node scripts/portal.mjs <Admin|User> <dev|build|start> [Next.js arguments]");
  }
  const settings = readPortalSettings(name);
  const directory = path.join(repositoryRoot, settings.directory);
  const next = path.join(directory, "node_modules/next/dist/bin/next");
  const nextArgs = [command, ...args];
  if (command === "dev" || command === "start") {
    const endpoint = localEndpoint(settings.portalUrl);
    // Visual Studio's JavaScript Project System can report the configured
    // launch.json port as unavailable when a recent Node runtime binds the
    // dev server only through localhost. A wildcard bind keeps the browser URL
    // authoritative while allowing JSPS to recognize the server it launched.
    const bindHostname = process.platform === "win32" ? "0.0.0.0" : endpoint.hostname;
    // The launch configuration is authoritative; Next must never silently pick another port.
    if (args.some((argument) => /^(--port|--hostname|-p|-H)(=|$)/.test(argument))) {
      throw new Error("Set Services__Admin__PortalUrl / Services__User__PortalUrl (or edit Config) to change a portal's host or port.");
    }
    if (requestedArgs.includes("--wait-for-api")) await waitForApi(settings);
    await ensurePortAvailable({ ...endpoint, hostname: bindHostname });
    nextArgs.push("--hostname", bindHostname, "--port", String(endpoint.port));
  }

  console.log(`[${settings.name} portal] Stage=${settings.stage}; API=${settings.apiUrl}`);
  const child = spawn(process.execPath, [next, ...nextArgs], {
    cwd: directory,
    stdio: "inherit",
    env: {
      ...process.env,
      // Only this approved public value is injected into Next.js, including at build time.
      NEXT_PUBLIC_API_URL: settings.apiUrl,
      TZ: settings.businessTimeZone,
    },
  });
  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => child.kill(signal));
  }
  child.on("error", () => {
    console.error("Unable to start Next.js. Install the portal's dependencies with npm ci.");
    process.exitCode = 1;
  });
  child.on("exit", (code, signal) => {
    process.exitCode = code ?? (signal ? 1 : 0);
  });
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
