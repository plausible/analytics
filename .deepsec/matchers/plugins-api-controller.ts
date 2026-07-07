import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Plausible's Plugins API controllers use `use PlausibleWeb,
 * :plugins_api_controller`, which the built-in Phoenix controller matcher does
 * not currently recognize. These are public JSON API entry points gated by
 * `AuthorizePluginsAPI`, except explicit capability/spec routes.
 *
 * Tier: noisy — every plugin API controller action is an entry point worth
 * review for authz, tenant scoping, schema validation, and mass assignment.
 */
export const pluginsApiController: MatcherPlugin = {
  slug: "plausible-plugins-api-controller",
  description: "Plugins API controllers using PlausibleWeb :plugins_api_controller",
  noiseTier: "noisy",
  filePatterns: [
    "lib/plausible_web/plugins/api/controllers/**/*.ex",
    "extra/lib/plausible_web/plugins/api/controllers/**/*.ex",
  ],
  examples: [
    "  use PlausibleWeb, :plugins_api_controller\n\n  def create(conn, params) do",
    "  def delete(%{private: %{open_api_spex: %{params: %{id: id}}}} = conn, _params) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];

    return regexMatcher(
      "plausible-plugins-api-controller",
      [
        {
          regex: /\buse\s+PlausibleWeb\s*,\s*:plugins_api_controller\b/,
          label: "Plausible Plugins API controller entry point",
        },
        {
          regex:
            /^\s*def\s+(?:index|get|create|update|delete|delete_bulk|enable|disable)\s*\(/m,
          label: "Plugins API action function",
        },
      ],
      content,
    );
  },
};
