import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { readPortalSettings, readPublicSettings } from "./public-config.mjs";

function fixture(t) {
  const configDirectory = mkdtempSync(path.join(os.tmpdir(), "mealplanning-config-"));
  t.after(() => rmSync(configDirectory, { recursive: true, force: true }));
  const write = (name, settings) => writeFileSync(path.join(configDirectory, name), JSON.stringify(settings));
  write("appsettings.json", { Stage: "dev", BusinessTimeZone: "Asia/Yangon", Swagger: { Enabled: false } });
  write("custom-setting-dev.json", {
    Services: {
      Admin: { ApiUrl: "http://localhost:5101", PortalUrl: "http://localhost:3001" },
      User: { ApiUrl: "http://localhost:5201", PortalUrl: "http://localhost:3002" },
    },
    ConnectionStrings: { MealPlanner: "private-test-value" },
    Jwt: { Key: "never-export-this" },
  });
  return { configDirectory, write };
}

test("public projection includes only approved fields, never server configuration", (t) => {
  const { configDirectory } = fixture(t);
  const settings = readPublicSettings({ configDirectory, environment: {} });
  assert.equal(settings.stage, "dev");
  assert.equal(settings.services.Admin.apiUrl, "http://localhost:5101");
  assert.equal(settings.services.User.apiUrl, "http://localhost:5201");
  assert.deepEqual(Object.keys(settings), ["stage", "businessTimeZone", "swaggerEnabled", "services"]);
  assert.doesNotMatch(JSON.stringify(settings), /ConnectionStrings|private-test-value|Jwt|never-export-this/);
});

test("environment selects the required stage and overrides its public URLs case-insensitively", (t) => {
  const { configDirectory, write } = fixture(t);
  write("custom-setting-uat.json", {
    Services: {
      Admin: { ApiUrl: "https://admin-api.example.invalid", PortalUrl: "https://admin.example.invalid" },
      User: { ApiUrl: "https://user-api.example.invalid", PortalUrl: "https://user.example.invalid" },
    },
  });
  const settings = readPublicSettings({
    configDirectory,
    environment: { STAGE: " UAT ", Services__Admin__ApiUrl: "https://override.example.invalid" },
  });
  assert.equal(settings.stage, "uat");
  assert.equal(settings.services.Admin.apiUrl, "https://override.example.invalid");
  assert.equal(settings.services.User.apiUrl, "https://user-api.example.invalid");
});

test("per-portal NEXT_PUBLIC_API_URL override wins without exposing other environment values", (t) => {
  const { configDirectory } = fixture(t);
  const settings = readPortalSettings("User", {
    configDirectory,
    environment: { NEXT_PUBLIC_API_URL: "https://api.example.invalid", DATABASE_URL: "private-test-value" },
  });
  assert.equal(settings.apiUrl, "https://api.example.invalid");
  assert.equal(settings.portalUrl, "http://localhost:3002");
  assert.doesNotMatch(JSON.stringify(settings), /DATABASE_URL|private-test-value/);
});

test("unsupported, empty, and missing stages fail instead of using dev fixtures", (t) => {
  const { configDirectory } = fixture(t);
  for (const Stage of ["", "staging", "../prod"]) {
    assert.throws(() => readPublicSettings({ configDirectory, environment: { Stage } }), /Stage is required/);
  }
  assert.throws(() => readPublicSettings({ configDirectory, environment: { Stage: "prod" } }), /custom-setting-prod.json/);
});

test("rejects stage redirection and secret-bearing public URLs with redacted errors", (t) => {
  const { configDirectory, write } = fixture(t);
  assert.throws(() => readPortalSettings("Admin", {
    configDirectory,
    environment: { NEXT_PUBLIC_API_URL: "https://user:do-not-log@example.invalid" },
  }), (error) => /without credentials/.test(error.message) && !error.message.includes("do-not-log"));
  write("custom-setting-dev.json", { Stage: "prod" });
  assert.throws(() => readPublicSettings({ configDirectory, environment: {} }), /not inside a stage file/);
});
