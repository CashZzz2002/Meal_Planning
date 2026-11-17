import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const portals = [
  { name: "Admin", directory: "Admin/admin-web", apiDirectory: "Admin/MealPlanning.Admin.Api" },
  { name: "User", directory: "User/user-web", apiDirectory: "User/MealPlanning.User.Api" },
];

function getValue(source, key) {
  return key.split(":").reduce((value, part) => {
    const match = Object.keys(value ?? {}).find((candidate) => candidate.toLowerCase() === part.toLowerCase());
    return match === undefined ? undefined : value[match];
  }, source);
}

export function environmentValue(environment, key) {
  const match = Object.keys(environment).find(
    (candidate) => candidate.replaceAll("__", ":").toLowerCase() === key.toLowerCase(),
  );
  return match === undefined ? undefined : environment[match];
}

function readJson(file) {
  try {
    return JSON.parse(readFileSync(file, "utf8").replace(/^\uFEFF/, ""));
  } catch {
    // A parser error can include file contents. Report only the expected file name.
    throw new Error(`Required configuration ${path.basename(file)} is missing or is not valid JSON.`);
  }
}

export function validateOrigin(value, key) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${key} must be an absolute HTTP(S) origin.`);
  }
  if (
    typeof value !== "string" ||
    !["http:", "https:"].includes(url.protocol) ||
    url.username || url.password || url.search || url.hash ||
    url.pathname !== "/" || url.hostname.includes("*") || value.endsWith("/")
  ) {
    throw new Error(`${key} must be an HTTP(S) origin without credentials, a path, query, fragment, or trailing slash.`);
  }
  return value;
}

export function readPublicSettings({ environment = process.env, configDirectory } = {}) {
  const directory = path.resolve(repositoryRoot,
    configDirectory ?? environmentValue(environment, "ConfigDirectory") ?? "Config");
  const base = readJson(path.join(directory, "appsettings.json"));
  const stage = String(environmentValue(environment, "Stage") ?? getValue(base, "Stage") ?? "").trim().toLowerCase();
  if (!["dev", "sit", "uat", "preprod", "prod"].includes(stage)) {
    throw new Error("Stage is required and must be one of: dev, sit, uat, preprod, prod.");
  }
  const selected = readJson(path.join(directory, `custom-setting-${stage}.json`));
  if (getValue(selected, "Stage") !== undefined) {
    throw new Error("Set Stage in Config/appsettings.json or the environment, not inside a stage file.");
  }
  const value = (key) => environmentValue(environment, key) ?? getValue(selected, key) ?? getValue(base, key);
  if (value("BusinessTimeZone") !== "Asia/Yangon") {
    throw new Error("BusinessTimeZone must be Asia/Yangon.");
  }

  // Deliberately project only public fields. Never export config objects, API defaults,
  // User Secrets, DATABASE_URL, or other server settings into a portal or launch file.
  return {
    stage,
    businessTimeZone: "Asia/Yangon",
    swaggerEnabled: String(value("Swagger:Enabled")).toLowerCase() === "true",
    services: Object.fromEntries(portals.map(({ name }) => [name, {
      apiUrl: validateOrigin(value(`Services:${name}:ApiUrl`), `Services:${name}:ApiUrl`),
      portalUrl: validateOrigin(value(`Services:${name}:PortalUrl`), `Services:${name}:PortalUrl`),
    }])),
  };
}

export function readPortalSettings(name, options = {}) {
  const portal = portals.find((candidate) => candidate.name.toLowerCase() === name.toLowerCase());
  if (!portal) throw new Error("Portal must be Admin or User.");
  const settings = readPublicSettings(options);
  const apiUrl = environmentValue(options.environment ?? process.env, "NEXT_PUBLIC_API_URL")
    ?? settings.services[portal.name].apiUrl;
  return {
    ...portal,
    stage: settings.stage,
    businessTimeZone: settings.businessTimeZone,
    apiUrl: validateOrigin(apiUrl, "NEXT_PUBLIC_API_URL"),
    portalUrl: settings.services[portal.name].portalUrl,
  };
}

export function localEndpoint(value) {
  const url = new URL(validateOrigin(value, "Local service URL"));
  if (url.protocol !== "http:" || !["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)) {
    throw new Error("Local launch URLs must use HTTP on localhost, 127.0.0.1, or [::1].");
  }
  return {
    url: value,
    port: Number(url.port || 80),
    hostname: url.hostname === "[::1]" ? "::1" : "127.0.0.1",
    probeUrl: `http://${url.hostname === "[::1]" ? "[::1]" : "127.0.0.1"}:${url.port || 80}`,
  };
}
