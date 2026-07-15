import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Phoenix Plug definition modules — the auth/authz layer.
 *
 * The built-in `ex-phoenix-controller` matcher only fires on `use ..., :controller`,
 * route verbs, and `Repo.query`. Plug modules use `import Plug.Conn` instead, making
 * all 19 files in lib/plausible_web/plugs/ and 13 files in lib/plausible/auth/
 * invisible to the existing scanner.
 *
 * Tier: noisy — every plug module in these directories is an authorization boundary
 * and should be AI-reviewed.
 */
export const phoenixPlugModule: MatcherPlugin = {
  slug: "plausible-plug-module",
  description: "Phoenix Plug modules — auth/authz layer invisible to ex-phoenix-controller",
  noiseTier: "noisy",
  filePatterns: [
    "lib/plausible_web/plugs/**/*.ex",
    "lib/plausible/auth/**/*.ex",
    "extra/lib/plausible_web/plugs/**/*.ex",
  ],
  examples: [
    "import Plug.Conn\n  def call(conn, _opts) do",
    "use Plug.Builder\n  plug :check_auth",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    return regexMatcher(
      "plausible-plug-module",
      [
        { regex: /\bimport\s+Plug\.Conn\b/, label: "import Plug.Conn — plug module entry point" },
        { regex: /\buse\s+Plug\.Builder\b/, label: "use Plug.Builder — plug composition" },
      ],
      content,
    );
  },
};
