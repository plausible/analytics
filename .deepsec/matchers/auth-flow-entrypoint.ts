import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Account lifecycle and membership entry points.
 *
 * The built-in Phoenix matcher reaches the HTTP controller and LiveView edges,
 * but many auth, registration, invitation, 2FA, session, and membership bugs
 * live in service modules beneath those edges. This matcher keeps the glob set
 * to those subsystems and asks the AI to review user-controlled account state
 * transitions for rate limits, token/session binding, tenant scope, and role
 * checks.
 */
export const authFlowEntrypoint: MatcherPlugin = {
  slug: "plausible-auth-flow-entrypoint",
  description:
    "Login, registration, 2FA, password reset, session, invitation, and membership service boundaries",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/controllers/auth_controller.ex",
    "lib/plausible_web/controllers/invitation_controller.ex",
    "lib/plausible_web/live/register_form.ex",
    "lib/plausible_web/live/reset_password_form.ex",
    "lib/plausible_web/user_auth.ex",
    "lib/plausible_web/two_factor/**/*.ex",
    "lib/plausible_web/login_preference.ex",
    "lib/plausible/auth/**/*.ex",
    "lib/plausible/teams/invitations/**/*.ex",
    "lib/plausible/teams/memberships/**/*.ex",
    "lib/plausible/teams/sites/transfer.ex",
    "lib/plausible/teams/site_transfer.ex",
  ],
  examples: [
    '  def handle_event("register", %{"user" => params}, socket) do',
    "  def log_in_user(conn, %Auth.User{} = user, redirect_path) do",
    "  def verify_password_reset(token) do",
    "  def accept(invitation_or_transfer_id, user, team \\\\ nil) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-auth-flow-entrypoint",
      [
        {
          regex:
            /^\s*def\s+(?:login|logout|password_reset(?:_request|_form)?|activate|request_activation_code|verify_2fa(?:_setup|_recovery_code)?|delete_me|google_auth_callback|select_team|switch_team)\s*\(/m,
          label: "Auth controller account lifecycle action",
        },
        {
          regex:
            /^\s*def\s+handle_event\s*\(\s*"(?:register|validate|set|send-metrics-after)"/m,
          label: "Registration/password LiveView event",
        },
        {
          regex: /^\s*def\s+(?:log_in_user|log_out_user|get_user_session|set_logged_in_cookie)\s*\(/m,
          label: "Session/login handoff boundary",
        },
        {
          regex:
            /^\s*def\s+(?:sign|verify)_(?:password_reset|shared_link|oauth_state)\s*\(/m,
          label: "Signed token lifecycle",
        },
        {
          regex: /\bPhoenix\.Token\.(?:sign|verify)\s*\(/,
          label: "Phoenix token signing/verification",
        },
        {
          regex: /^\s*def\s+(?:issue_code|verify_code|create!|remove_by_token)\s*\(/m,
          label: "Email/session verification lifecycle",
        },
        {
          regex:
            /^\s*def\s+(?:accept|accept_transfer_no_members|reject|remove|remove_team_invitation|invite|update_role|leave|transfer|delete|create)\s*\(/m,
          label: "Invitation, membership, or account mutation service",
        },
        {
          regex: /\bRepo\.(?:get_by|one|delete_all|transaction)\s*\([^)]*(?:invitation|transfer|token|email|team|membership)/is,
          label: "Account/team lookup or mutation keyed by user-controlled identifier",
        },
      ],
      content,
    );
  },
};
