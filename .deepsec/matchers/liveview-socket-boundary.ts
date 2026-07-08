import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * LiveView websocket/session boundaries.
 *
 * LiveView reconnects use the socket session and on_mount hooks rather than
 * re-running the full Plug pipeline. This matcher covers the socket definition,
 * live_session hook wiring, and on_mount context modules that gate websocket
 * state.
 *
 * Tier: normal — tight path globs, but the AI must reason about whether each
 * boundary actually re-establishes auth/session/team context safely.
 */
export const liveViewSocketBoundary: MatcherPlugin = {
  slug: "plausible-liveview-socket-boundary",
  description: "LiveView websocket socket config, live_session hooks, and on_mount auth boundaries",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/endpoint.ex",
    "lib/plausible_web/router.ex",
    "lib/plausible_web/live/**/*context.ex",
    "extra/lib/plausible_web/live/**/*context.ex",
  ],
  examples: [
    '  socket("/live", Phoenix.LiveView.Socket, websocket: [check_origin: true])',
    "  live_session :settings, on_mount: PlausibleWeb.Live.SettingsContext do",
    "  def on_mount(:default, _params, session, socket) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-liveview-socket-boundary",
      [
        {
          regex: /\bsocket\s*\(\s*"\/live"\s*,\s*Phoenix\.LiveView\.Socket\b/,
          label: "LiveView websocket endpoint",
        },
        {
          regex: /\bsession:\s*\{__MODULE__,\s*:runtime_session_opts\b/,
          label: "LiveView socket session source",
        },
        {
          regex: /\blive_session\s+[^,\n]+,\s*on_mount:/,
          label: "LiveView live_session on_mount wiring",
        },
        {
          regex: /^\s*def\s+on_mount\s*\(/,
          label: "LiveView on_mount auth/session hook",
        },
      ],
      content,
    );
  },
};
