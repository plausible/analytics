import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Third-party callback, webhook, and OAuth handoff boundary.
 *
 * These flows accept data from Paddle, HelpScout, Google OAuth/API, and support
 * iframes. They tend to need signature validation, nonce/state binding, replay
 * handling, rate limits, and careful error/log handling. SSO/SAML has a more
 * specific matcher already, so this matcher focuses on the non-SAML integrations.
 */
export const thirdPartyCallbackEntrypoint: MatcherPlugin = {
  slug: "plausible-third-party-callback-entrypoint",
  description:
    "Paddle webhook, Google OAuth/API, and HelpScout callback/signature/token handoff boundaries",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/controllers/api/paddle_controller.ex",
    "lib/plausible/billing/billing.ex",
    "lib/plausible/billing/paddle_api.ex",
    "lib/plausible/billing/subscription/status.ex",
    "lib/plausible_web/controllers/auth_controller.ex",
    "lib/plausible/google/**/*.ex",
    "extra/lib/plausible_web/controllers/help_scout_controller.ex",
    "extra/lib/plausible/help_scout.ex",
  ],
  examples: [
    '  def webhook(conn, %{"alert_name" => "subscription_created"} = params) do',
    '  def google_auth_callback(conn, %{"code" => code, "state" => state} = params) do',
    "  def validate_signature(conn) do",
    '  signature = Base.decode64!(conn.params["p_signature"])',
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-third-party-callback-entrypoint",
      [
        {
          regex: /^\s*defp?\s+(?:webhook|callback|google_auth_callback|verify_signature|validate_signature)\s*\(/m,
          label: "Webhook, callback, OAuth, or signature validation handler",
        },
        {
          regex:
            /\b(?:Plug\.Conn\.read_body|conn\.body_params|conn\.query_string|conn\.params\s*\[\s*"(?:p_signature|customer-id|conversation-id|customer_id|conversation_id|term|token|state|code|error)"\s*\])/,
          label: "Third-party request params/body consumed",
        },
        {
          regex: /\b(?:Base\.decode64!?|Jason\.decode!?|PhpSerializer\.serialize|:public_key\.verify|Plug\.Crypto\.secure_compare)\s*\(/,
          label: "Callback payload decoding or signature comparison",
        },
        {
          regex: /\b(?:Phoenix\.Token\.(?:sign|verify)|sign_oauth_state|verify_oauth_state|fetch_access_token!|fetch_access_token)\s*\(/,
          label: "OAuth state or callback token lifecycle",
        },
        {
          regex:
            /\b(?:Plausible\.Billing\.subscription_\w+\s*\(|Plausible\.Billing\.PaddleApi\.\w+\s*\(|HelpScout\.(?:validate_signature|get_details_for_customer|get_details_for_emails|search_users)\s*\(|Plausible\.HelpScout\.\w+\s*\(|Google\.API\.(?:verify_oauth_state|fetch_access_token!?|fetch_verified_properties|fetch_stats|list_properties|get_property|get_analytics_(?:start|end)_date|maybe_refresh_token)\s*\(|Google\.HTTP\.\w+\s*\()/,
          label: "Third-party integration handoff",
        },
        {
          regex: /\b(?:Sentry\.capture_message|Logger\.(?:error|warning|debug))\s*\([^)]*(?:params|reason|error|details|body)/is,
          label: "Callback error/log path includes third-party data",
        },
      ],
      content,
    );
  },
};
