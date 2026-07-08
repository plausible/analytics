import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Installation and domain verification entry points.
 *
 * These flows take customer-controlled domains/URLs, run DNS and HTTP checks,
 * and in EE call Browserless/Puppeteer against the target URL. The default
 * matchers catch some generic SSRF or JS patterns but miss the subsystem as a
 * review unit.
 *
 * Tier: normal — every matched boundary should be reviewed for SSRF, redirect,
 * DNS rebinding, rate limiting, and diagnostic leakage.
 */
export const verificationEntrypoint: MatcherPlugin = {
  slug: "plausible-verification-entrypoint",
  description: "Site and SSO domain verification flows that fetch or browse user-controlled URLs",
  noiseTier: "normal",
  filePatterns: [
    "extra/lib/plausible/installation_support/**/*.ex",
    "extra/lib/plausible/auth/sso/domain/verification.ex",
    "extra/lib/plausible/auth/sso/domain/verification/**/*.ex",
    "extra/lib/plausible_web/live/verification.ex",
    "priv/tracker/installation_support/**/*.js",
    "tracker/installation_support/**/*.js",
  ],
  examples: [
    '  def handle_event("verify-custom-url", %{"custom_url" => custom_url}, socket) do',
    "  def run(url, data_domain, installation_type, opts \\\\ []) do",
    "  def perform(%State{url: url} = state, _opts) do",
    "      const response = await page.goto(url)",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs|js|ts|tsx)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-verification-entrypoint",
      [
        {
          regex: /^\s*def\s+handle_event\s*\(\s*"verify-custom-url"/,
          label: "LiveView custom URL verification input",
        },
        {
          regex: /^\s*def\s+run\s*\(\s*(?:url|sso_domain)\b/,
          label: "Verification check runner accepts URL/domain input",
        },
        {
          regex: /^\s*def\s+perform\s*\(\s*%State\{url:\s*url\}/,
          label: "Verification check consumes state.url",
        },
        {
          regex: /\bpage\.goto\s*\(\s*url\s*\)/,
          label: "Browserless/Puppeteer navigation to supplied URL",
        },
        {
          regex: /\bReq\.post\s*\(\s*BrowserlessConfig\.browserless_function_api_endpoint\(\)/,
          label: "Browserless function API call",
        },
        {
          regex: /\brun_request\s*\(\s*(?:url_override|\S*url)/,
          label: "Verification HTTP request to supplied domain/URL",
        },
        {
          regex: /\b(?:dns_lookup|:inet_res\.lookup)\s*\(/,
          label: "Verification DNS lookup",
        },
        {
          regex: /\bwindow\.fetch\s*=\s*function\s*\(\s*url\b/,
          label: "Verifier intercepts page fetch calls",
        },
      ],
      content,
    );
  },
};
