import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * LiveView mount/3 and event handlers — real HTTP+WebSocket entry points.
 *
 * LiveViews mount twice per page load: once for the HTTP server-render and once
 * on WebSocket connect. Auth must be re-checked in mount/3 (or via an on_mount
 * hook); the plug pipeline is NOT called on WebSocket reconnect.
 *
 * Confirmed pattern: team_setup.ex performed a DB write (team rename) in mount
 * with no role gate, while the equivalent HTTP controller action had
 * `plug AuthorizeTeamAccess, [:owner, :admin]`.
 *
 * Tier: noisy — every LiveView that defines mount/3 is a legitimate review target.
 */
export const liveViewMount: MatcherPlugin = {
  slug: "plausible-liveview-mount",
  description: "LiveView mount/3 and event handlers — HTTP+WebSocket entry points",
  noiseTier: "noisy",
  filePatterns: [
    "lib/plausible_web/live/**/*.ex",
    "extra/lib/plausible_web/live/**/*.ex",
  ],
  examples: [
    "  def mount(_params, session, socket) do\n    {:ok, socket}\n  end",
    '  def handle_event("save", params, socket) do',
    "  def handle_params(params, _uri, socket) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    return regexMatcher(
      "plausible-liveview-mount",
      [
        { regex: /^\s*def\s+mount\s*\(/m, label: "def mount — LiveView HTTP/WS entry point" },
        { regex: /^\s*def\s+handle_event\s*\(\s*"/m, label: "def handle_event — WebSocket state mutation" },
        { regex: /^\s*def\s+handle_params\s*\(/m, label: "def handle_params — URL-param driven state change" },
      ],
      content,
    );
  },
};
