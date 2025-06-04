import { Page } from "@playwright/test";
import { ScriptConfig } from "./types";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const TEMPLATE = readFileSync(
  path.resolve(__dirname, "./dynamic-page-template.html")
).toString();

interface DynamicPageOptions {
  scriptConfig: ScriptConfig;
  /** vanilla HTML string, which can contain JS, will be set in the body of the page */
  bodyContent: string;
  testId: string;
}

interface DynamicPageInfo {
  /** the url where the page is served */
  url: string;
}

export async function initializePageDynamically(
  page: Page,
  { testId, scriptConfig, bodyContent }: DynamicPageOptions
): Promise<DynamicPageInfo> {
  const url = `/dynamic/${testId}`;
  await page.route(url, async (route) => {
    await route.fulfill({
      body: TEMPLATE.replace(
        "<%= plausible_script_url %>",
        `/tracker/js/plausible-web.js?script_config=${encodeURIComponent(
          JSON.stringify(scriptConfig)
        )}`
      ).replace("<body></body>", `<body>${bodyContent}</body>`),
      contentType: "text/html",
    });
  });
  return { url };
}
