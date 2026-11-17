import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { localEndpoint, portals, readPublicSettings, repositoryRoot } from "./public-config.mjs";

export function launchDefinitions(settings) {
  const definitions = portals.map((portal) => ({
    ...portal,
    api: localEndpoint(settings.services[portal.name].apiUrl),
    web: localEndpoint(settings.services[portal.name].portalUrl),
  }));
  const ports = definitions.flatMap(({ api, web }) => [api.port, web.port]);
  if (new Set(ports).size !== ports.length) {
    throw new Error("All four local services must use different ports.");
  }
  return definitions;
}

export function synchronizeLaunchSettings({ root = repositoryRoot, settings = readPublicSettings(), check = false } = {}) {
  const changed = [];
  for (const portal of launchDefinitions(settings)) {
    const apiPath = path.join(root, portal.apiDirectory, "Properties/launchSettings.json");
    const api = JSON.parse(readFileSync(apiPath, "utf8").replace(/^\uFEFF/, ""));
    const profile = api.profiles.http;
    const desiredProfile = {
      ...profile,
      launchBrowser: settings.swaggerEnabled,
      launchUrl: "swagger",
      applicationUrl: portal.api.url,
    };
    if (JSON.stringify(profile) !== JSON.stringify(desiredProfile)) {
      changed.push(path.relative(root, apiPath));
      if (!check) {
        api.profiles.http = desiredProfile;
        writeFileSync(apiPath, `${JSON.stringify(api, null, 2)}\n`);
      }
    }

    const webPath = path.join(root, portal.directory, ".vscode/launch.json");
    let web;
    try {
      web = JSON.parse(readFileSync(webPath, "utf8").replace(/^\uFEFF/, ""));
    } catch (error) {
      if (error.code !== "ENOENT") throw new Error(`Invalid launch.json for ${portal.name}.`);
      web = { version: "0.2.0", configurations: [] };
    }
    const name = `Launch ${portal.name} portal`;
    const existing = web.configurations.find((configuration) => configuration.name === name);
    const desired = {
      ...(existing ?? { name, type: "edge", request: "launch", webRoot: "${workspaceFolder}" }),
      url: portal.web.url,
      timeout: 120000,
    };
    if (JSON.stringify(existing) !== JSON.stringify(desired)) {
      changed.push(path.relative(root, webPath));
      if (!check) {
        if (existing) Object.assign(existing, desired);
        else web.configurations.push(desired);
        mkdirSync(path.dirname(webPath), { recursive: true });
        writeFileSync(webPath, `${JSON.stringify(web, null, 2)}\n`);
      }
    }
  }
  return changed;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const settings = readPublicSettings();
    if (process.argv.includes("--print")) {
      console.log(JSON.stringify({ stage: settings.stage, services: launchDefinitions(settings) }));
    } else {
      const check = process.argv.includes("--check");
      const changed = synchronizeLaunchSettings({ settings, check });
      if (check && changed.length) {
        throw new Error(`Launch settings differ from Stage=${settings.stage}: ${changed.join(", ")}. Run npm run config:sync, then reload the solution.`);
      }
      console.log(`Stage=${settings.stage}: Visual Studio launch settings ${check ? "verified" : "synchronized"} (${changed.length} files).`);
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
