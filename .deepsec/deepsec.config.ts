import { type DeepsecPlugin, defineConfig } from "deepsec/config";
import { phoenixPlugModule } from "./matchers/phoenix-plug-module.js";
import { liveViewMount } from "./matchers/liveview-mount.js";
import { onEeWithoutElse } from "./matchers/on-ee-without-else.js";
import { authorizeSiteAccessAllRoles } from "./matchers/authorize-site-access-all-roles.js";
import { pluginsApiController } from "./matchers/plugins-api-controller.js";
import { obanWorker } from "./matchers/oban-worker.js";
import { mixTaskEntrypoint } from "./matchers/mix-task-entrypoint.js";
import { ssoEntrypoint } from "./matchers/sso-entrypoint.js";
import { verificationEntrypoint } from "./matchers/verification-entrypoint.js";
import { liveComponentEvent } from "./matchers/livecomponent-event.js";
import { liveViewSocketBoundary } from "./matchers/liveview-socket-boundary.js";
import { authFlowEntrypoint } from "./matchers/auth-flow-entrypoint.js";
import { ingestionPipelineEntrypoint } from "./matchers/ingestion-pipeline-entrypoint.js";
import { publicApiScopeEntrypoint } from "./matchers/public-api-scope-entrypoint.js";
import { csvImportUploadEntrypoint } from "./matchers/csv-import-upload-entrypoint.js";
import { thirdPartyCallbackEntrypoint } from "./matchers/third-party-callback-entrypoint.js";

const plausiblePlugin: DeepsecPlugin = {
  name: "plausible-analytics",
  matchers: [
    phoenixPlugModule,
    liveViewMount,
    onEeWithoutElse,
    authorizeSiteAccessAllRoles,
    pluginsApiController,
    obanWorker,
    mixTaskEntrypoint,
    ssoEntrypoint,
    verificationEntrypoint,
    liveComponentEvent,
    liveViewSocketBoundary,
    authFlowEntrypoint,
    ingestionPipelineEntrypoint,
    publicApiScopeEntrypoint,
    csvImportUploadEntrypoint,
    thirdPartyCallbackEntrypoint,
  ],
};

export default defineConfig({
  projects: [
    {
      id: "analytics",
      root: "..",
      // <deepsec:projects-insert-above>
      githubUrl: "https://github.com/plausible/analytics/blob/master",
      priorityPaths: [
        "extra/lib/plausible_web/",
        "extra/lib/plausible/",
        "lib/plausible_web/plugs/",
        "lib/plausible/auth/",
        "lib/plausible_web/router.ex",
        "lib/plausible_web/controllers/",
        "lib/plausible_web/live/",
      ],
      promptAppend:
        "This is an Elixir/Phoenix SaaS analytics app. " +
        "Auth is plug-based (AuthPlug, RequireAccountPlug, AuthorizeSiteAccess, AuthorizePublicAPI) not decorator-based. " +
        "LiveViews are full HTTP+WebSocket entry points — treat mount/3 and handle_event/3 as controller actions. " +
        "The `on_ee do ... else ... end` macro compiles two code paths; check both branches. " +
        "An absent `else` clause means the CE build silently omits the entire block. " +
        "`plug AuthorizeSiteAccess` with no args admits :public role (unauthenticated). " +
        '`conn.params["__team"]` is user-supplied; downstream current_team trust is a known risk. ' +
        "SSO/SAML, domain verification, Browserless custom-url checks, and LiveComponent phx-target events are high-risk entry points. " +
        "The `extra/` directory is EE-only; the CRITICAL finding came from there.",
    },
  ],
  plugins: [plausiblePlugin],
});
