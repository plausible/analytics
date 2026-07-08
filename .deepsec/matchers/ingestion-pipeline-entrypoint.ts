import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Public tracker event ingestion pipeline.
 *
 * `/api/event` accepts unauthenticated browser input and passes it through
 * request parsing, enrichment, shield checks, tracker script configuration, and
 * ClickHouse/session buffers. Generic Phoenix coverage sees the controller but
 * not the downstream ingestion pipeline as a single security boundary.
 */
export const ingestionPipelineEntrypoint: MatcherPlugin = {
  slug: "plausible-ingestion-pipeline-entrypoint",
  description:
    "Tracker event ingestion request parsing, enrichment, tracker-script config, and buffering",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/controllers/api/external_controller.ex",
    "lib/plausible_web/plugs/tracker_plug.ex",
    "lib/plausible_web/tracker.ex",
    "lib/plausible/ingestion/**/*.ex",
    "extra/lib/plausible/ingestion/**/*.ex",
    "lib/plausible/event/write_buffer.ex",
    "lib/plausible/session/write_buffer.ex",
    "lib/plausible/session/balancer*.ex",
  ],
  examples: [
    "  def event(conn, _params) do\n    Ingestion.Request.build(conn)",
    "  def build(%Plug.Conn{} = conn, now \\\\ NaiveDateTime.utc_now()) do",
    "  def build_and_buffer(%Request{domains: domains} = request, context \\\\ []) do",
    '  defp put_props(changeset, %{} = request_body) do\n    request_body["props"]',
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-ingestion-pipeline-entrypoint",
      [
        {
          regex: /^\s*def\s+event\s*\(\s*conn\s*,/m,
          label: "Public tracker event controller action",
        },
        {
          regex: /\bIngestion\.Request\.build\s*\(\s*conn\s*\)/,
          label: "Controller hands Plug.Conn to ingestion request builder",
        },
        {
          regex: /^\s*def\s+build\s*\(\s*%Plug\.Conn\{\}\s*=\s*conn\b/m,
          label: "Ingestion request builder consumes Plug.Conn",
        },
        {
          regex: /\b(?:Plug\.Conn\.read_body|conn\.body_params|conn\.params|Plug\.Conn\.get_req_header)\b/,
          label: "Ingestion reads browser-controlled body, params, or headers",
        },
        {
          regex: /\brequest_body\s*\[\s*"(?:n|name|u|url|d|domain|r|referrer|m|meta|p|props|sd|e|hashMode)"\s*\]/,
          label: "Ingestion maps tracker payload fields",
        },
        {
          regex: /^\s*def\s+build_and_buffer\s*\(\s*%Request\{/m,
          label: "Builds and buffers tracker events",
        },
        {
          regex: /^\s*defp?\s+(?:pipeline|process_unless_dropped|execute_step|drop_|put_|register_session|validate_clickhouse_event)\b/m,
          label: "Event enrichment/drop/persistence pipeline step",
        },
        {
          regex: /\b(?:ClickhouseEventV2|ClickhouseRepo|Ch\.(?:query|query!|stream)|WriteBuffer\.(?:insert|flush))\b/,
          label: "Ingestion writes to ClickHouse or write buffers",
        },
        {
          regex: /^\s*def\s+(?:get_plausible_main_script|build_script|update_script_configuration|get_or_create_tracker_script_configuration)\s*\(/m,
          label: "Tracker script configuration boundary",
        },
      ],
      content,
    );
  },
};
