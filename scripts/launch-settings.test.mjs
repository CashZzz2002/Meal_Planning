import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { launchDefinitions, synchronizeLaunchSettings } from "./sync-launch-settings.mjs";
import { portals } from "./public-config.mjs";

const settings = {
  stage: "dev",
  swaggerEnabled: true,
  services: {
    Admin: { apiUrl: "http://localhost:6101", portalUrl: "http://localhost:4001" },
    User: { apiUrl: "http://localhost:6201", portalUrl: "http://localhost:4002" },
  },
};

test("sync updates all four native URLs, preserves user launch options, and is idempotent", (t) => {
  const root = mkdtempSync(path.join(os.tmpdir(), "mealplanning-launch-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const original = JSON.stringify({ profiles: { http: { commandName: "Project", environmentVariables: { CustomFlag: "kept" } }, other: { commandName: "Project" } } });
  for (const portal of portals) {
    const file = path.join(root, portal.apiDirectory, "Properties/launchSettings.json");
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, original);
  }

  assert.equal(synchronizeLaunchSettings({ root, settings, check: true }).length, 4);
  assert.equal(readFileSync(path.join(root, portals[0].apiDirectory, "Properties/launchSettings.json"), "utf8"), original);
  assert.equal(synchronizeLaunchSettings({ root, settings }).length, 4);
  assert.deepEqual(synchronizeLaunchSettings({ root, settings, check: true }), []);
  assert.deepEqual(synchronizeLaunchSettings({ root, settings }), []);

  for (const portal of portals) {
    const api = JSON.parse(readFileSync(path.join(root, portal.apiDirectory, "Properties/launchSettings.json"), "utf8"));
    assert.equal(api.profiles.http.applicationUrl, settings.services[portal.name].apiUrl);
    assert.equal(api.profiles.http.launchUrl, "swagger");
    assert.equal(api.profiles.http.launchBrowser, true);
    assert.equal(api.profiles.http.environmentVariables.CustomFlag, "kept");
    assert.deepEqual(api.profiles.other, { commandName: "Project" });
    const web = JSON.parse(readFileSync(path.join(root, portal.directory, ".vscode/launch.json"), "utf8"));
    assert.equal(web.configurations[0].url, settings.services[portal.name].portalUrl);
  }
});

test("local launch rejects duplicate ports and remote URLs before writing files", () => {
  const duplicate = structuredClone(settings);
  duplicate.services.User.portalUrl = duplicate.services.Admin.portalUrl;
  assert.throws(() => launchDefinitions(duplicate), /different ports/);
  const remote = structuredClone(settings);
  remote.services.Admin.apiUrl = "https://api.example.invalid";
  assert.throws(() => launchDefinitions(remote), /Local launch URLs/);
});
