import * as Sentry from "@sentry/react";
import { Integrations } from "@sentry/tracing";

const container = document.getElementById('stats-react-container')

Sentry.init({
  dsn: container.dataset.sentryDsn,
  environment: container.dataset.environment,
  integrations: [new Integrations.BrowserTracing()],
  release: container.dataset.sentryRelease || "unknown",
  initialScope: {
    tags: {
      'app_version': container.dataset.sentryRelease,
      'origin': 'dashboard'
    },
  },
  tracesSampleRate: 0.5,
});
