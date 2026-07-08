import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * LiveComponent websocket event handlers outside lib/plausible_web/live.
 *
 * The existing LiveView matcher intentionally scans live/**.ex. Components can
 * also receive phx events over the LiveView websocket when rendered with
 * phx-target={@myself}, and this repo has component directories outside live/.
 *
 * Tier: normal — path globs are limited to components, and handle_event/3 is a
 * real browser-controlled websocket boundary.
 */
export const liveComponentEvent: MatcherPlugin = {
  slug: "plausible-livecomponent-event",
  description: "LiveComponent handle_event/3 websocket entry points outside live/ directories",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/components/**/*.ex",
    "extra/lib/plausible_web/components/**/*.ex",
  ],
  examples: [
    "  use PlausibleWeb, :live_component\n\n  def handle_event(\"toggle\", _params, socket) do",
    "  use Phoenix.LiveComponent\n\n  def handle_event(\"save\", params, socket) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-livecomponent-event",
      [
        {
          regex: /\buse\s+PlausibleWeb\s*,\s*:live_component\b/,
          label: "Plausible LiveComponent module",
        },
        {
          regex: /\buse\s+Phoenix\.LiveComponent\b/,
          label: "Phoenix LiveComponent module",
        },
        {
          regex: /^\s*def\s+handle_event\s*\(\s*"/,
          label: "LiveComponent websocket event handler",
        },
      ],
      content,
    );
  },
};
