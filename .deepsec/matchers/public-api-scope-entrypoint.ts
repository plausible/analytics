import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Public API authz and query parsing surface.
 *
 * Built-in Phoenix coverage catches controllers, and the existing plugin catches
 * Plugins API controllers. The service modules that validate API scopes, parse
 * stats queries, paginate plugin resources, and apply segment filters need their
 * own review path because they are where tenant scoping and request-to-query
 * mistakes usually appear.
 */
export const publicApiScopeEntrypoint: MatcherPlugin = {
  slug: "plausible-public-api-scope-entrypoint",
  description:
    "Public API scope checks, OpenAPI body params, stats query parsing, plugin API services, and segment filters",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/plugs/authorize_public_api.ex",
    "lib/plausible_web/plugs/authorize_plugins_api.ex",
    "lib/plausible_web/controllers/api/**/*_controller.ex",
    "lib/plausible_web/plugins/api/controllers/**/*.ex",
    "extra/lib/plausible_web/plugins/api/controllers/**/*.ex",
    "lib/plausible/plugins/api/**/*.ex",
    "extra/lib/plausible/plugins/api/**/*.ex",
    "lib/plausible/stats/api_query_parser.ex",
    "lib/plausible/stats/dashboard/query_parser.ex",
    "lib/plausible/stats/query*.ex",
    "lib/plausible/stats/filters/**/*.ex",
    "lib/plausible/segments/**/*.ex",
  ],
  examples: [
    '  defp verify_by_scope(conn, api_key, "stats:read:" <> _ = scope) do',
    "  def parse(params, opts \\\\ []) when is_map(params) do",
    "  {:ok, paginate(query, params, cursor_fields: [{:id, :desc}])}",
    "  %{private: %{open_api_spex: %{body_params: body_params}}} = conn",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-public-api-scope-entrypoint",
      [
        {
          regex: /\b(?:api_scope|check_scope|verify_by_scope|get_bearer_token|authorization)\b/,
          label: "API key scope or bearer-token authorization",
        },
        {
          regex: /\b(?:conn\.params|conn\.query_params|body_params|open_api_spex|OpenApiSpex)\b/,
          label: "Public API params or OpenAPI-validated body",
        },
        {
          regex:
            /^\s*def\s+(?:query|aggregate|breakdown|timeseries|realtime_visitors|create_site|update_site|delete_site|create|update|delete|delete_bulk|enable|disable|index|get)\s*\(/m,
          label: "Public API or plugin API action/service function",
        },
        {
          regex: /\b(?:JSONSchema\.validate|parse\s*\(\s*params|parse_(?:filters|order_by|pagination|metrics|dimensions|include)|Map\.fetch!\s*\(\s*params)\b/,
          label: "Stats/query API parameter parsing",
        },
        {
          regex: /\bpaginate\s*\(\s*query\s*,\s*params\b/,
          label: "API pagination from query params",
        },
        {
          regex: /\b(?:segment_id|site_id|team_id|authorized_site|current_team|current_user)\b/,
          label: "Tenant, team, site, or segment scoping value",
        },
        {
          regex: /\b(?:Clickhouse|ClickhouseRepo|Ch\.(?:query|query!|stream)|QueryRunner|QueryBuilder)\b/,
          label: "Stats API request reaches query execution/building",
        },
      ],
      content,
    );
  },
};
