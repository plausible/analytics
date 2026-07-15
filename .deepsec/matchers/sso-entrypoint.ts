import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Plausible SSO boundary coverage.
 *
 * SSO spans normal controllers, SAML adapters, LiveView management events,
 * force-SSO plugs, domain ownership verification, and a queue worker. Generic
 * Phoenix matchers see some of these in isolation, but not as one sensitive
 * identity boundary.
 *
 * Tier: normal — the path globs are SSO-specific, and the AI should review the
 * matched boundary for relay-state, cookie, ownership, role, and team scoping.
 */
export const ssoEntrypoint: MatcherPlugin = {
  slug: "plausible-sso-entrypoint",
  description: "SSO/SAML login, policy, domain verification, and force-SSO entry points",
  noiseTier: "normal",
  filePatterns: [
    "extra/lib/plausible/auth/sso/**/*.ex",
    "extra/lib/plausible_web/controllers/sso_controller.ex",
    "extra/lib/plausible_web/live/sso_management.ex",
    "extra/lib/plausible_web/live/customer_support/team/components/sso.ex",
    "extra/lib/plausible_web/plugs/secure_sso.ex",
    "extra/lib/plausible_web/sso/**/*.ex",
    "lib/plausible_web/plugs/sso_team_access.ex",
    "lib/plausible_web/user_auth.ex",
  ],
  examples: [
    "  def saml_consume(conn, params) do\n    saml_adapter().consume(conn, params)\n  end",
    '  def handle_event("toggle-force-sso", _params, socket) do',
    "  def set_force_sso(team, mode) do",
    "  def perform(%{args: %{\"domain\" => domain}}) do",
    "  def log_in_user(conn, %Auth.SSO.Identity{} = identity, redirect_path) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs|js|ts|tsx)$/.test(filePath)) return [];

    const patterns = [
        {
          regex: /^\s*def\s+(?:login|saml_signin|saml_consume|signin|consume)\s*\(/,
          label: "SSO/SAML HTTP login boundary",
        },
        {
          regex:
            /^\s*def\s+handle_event\s*\(\s*"(?:init-sso|update-integration|add-domain|verify-domain(?:-submit)?|cancel-verify-domain|remove-domain|toggle-force-sso|update-policy|remove-sso-[^"]+|deprovision-sso-user)"/,
          label: "SSO LiveView event boundary",
        },
        {
          regex:
            /^\s*def\s+(?:initiate_saml_integration|update_integration|provision_user|deprovision_user!|set_force_sso|check_force_sso|remove_integration|start_verification|cancel_verification|verify|remove)\s*\(/,
          label: "SSO domain/policy service boundary",
        },
        {
          regex: /^\s*def\s+perform\s*\(/,
          label: "SSO background verification worker boundary",
        },
        {
          regex: /\bSimpleSaml\.(?:parse_response|verify_and_validate_response)\b/,
          label: "SAML response parsing/verification",
        },
        {
          regex:
            /^\s*def\s+log_in_user\s*\(\s*conn\s*,\s*%Auth\.SSO\.Identity\{\}\s*=\s*identity\b/,
          label: "SSO identity login handoff",
        },
        {
          regex: /\bAuth\.SSO\.provision_user\s*\(|\bLoginPreference\.set_sso\s*\(/,
          label: "SSO user provisioning/login preference handoff",
        },
      ];

    if (/\/sso\//.test(filePath)) {
      patterns.push({
        regex: /\bPlug\.Conn\.(?:put_resp_cookie|fetch_cookies|delete_resp_cookie)\b/,
        label: "SSO flow cookie handling",
      });
    }

    return regexMatcher("plausible-sso-entrypoint", patterns, content);
  },
};
