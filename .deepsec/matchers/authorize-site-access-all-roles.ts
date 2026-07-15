import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * `plug AuthorizeSiteAccess` with no role restriction.
 *
 * `PlausibleWeb.Plugs.AuthorizeSiteAccess` called with no args (or `:all_roles`)
 * uses @all_roles = [:public, :viewer, :admin, :editor, :super_admin, :owner, :billing]
 * as the allowed set — including :public, meaning unauthenticated visitors pass.
 *
 * Correct for the public stats view; wrong for anything requiring at least :viewer.
 *
 * Confirmed in router.ex:
 *   pipeline :internal_stats_api do
 *     plug PlausibleWeb.Plugs.AuthorizeSiteAccess   ← no args, admits :public
 *
 * Tier: precise — only matches the no-arg / :all_roles form, not
 * `plug ..., [:admin, :owner]` or `plug ..., {[:admin], "site_id"}`.
 */
export const authorizeSiteAccessAllRoles: MatcherPlugin = {
  slug: "plausible-authorize-all-roles",
  description: "AuthorizeSiteAccess with no role restriction — admits :public (unauthenticated) visitors",
  noiseTier: "precise",
  filePatterns: [
    "lib/plausible_web/**/*.ex",
    "extra/lib/plausible_web/**/*.ex",
  ],
  examples: [
    "    plug PlausibleWeb.Plugs.AuthorizeSiteAccess",
    "    plug PlausibleWeb.Plugs.AuthorizeSiteAccess, :all_roles",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    return regexMatcher(
      "plausible-authorize-all-roles",
      [
        {
          // Matches no-arg and :all_roles forms; does NOT match plug ..., [:admin, ...]
          regex: /\bplug\s+PlausibleWeb\.Plugs\.AuthorizeSiteAccess\s*(?:,\s*:all_roles\s*)?(?:#.*)?$/m,
          label: "AuthorizeSiteAccess with no role restriction (admits :public)",
        },
      ],
      content,
    );
  },
};
