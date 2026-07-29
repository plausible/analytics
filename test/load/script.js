import http from "k6/http";
import { check } from "k6";

/** INPUTS */
/** Base URL of the environment under test (env) */
const baseURL = "http://localhost:8000";
/** Domain of a site registered in the env */
const domainHeavy = "dummy.site/heavy";
/** Domain of a site registered in the env */
const domainLight = "dummy.site/light";

const endpoints = {
  track: {
    method: "POST",
    name: "/api/event",
    getUrl: () => `${baseURL}/api/event`,
    getBody: ({ domain }) => {
      const { n, d } = {
        n: "pageview",
        d: domain,
      };
      const payload = {
        d,
        n,
        u: `https://${domain}/page/${Math.floor(Math.random() * 100) + 1}`,
      };
      return JSON.stringify(payload);
    },
    getParams: () => {
      const n = () => Math.floor(Math.random() * 255);
      const ip = [n() + 1, n(), n(), n()].join(".");
      return {
        headers: {
          "Content-Type": "application/json",
          "X-Forwarded-For": ip,
          "User-Agent": `${Math.random() > 0.5 ? "Mozilla/5.0" : "Mozilla/4.0"} (${Math.random() > 0.5 ? "Macintosh" : "Windows"}; ${Math.random() > 0.5 ? "Intel Mac OS X 10_15_6" : "Windows NT 10.0"}) AppleWebKit/${Math.floor(Math.random() * 1000) + 500}.36 (KHTML, like Gecko) Chrome/${Math.floor(Math.random() * 100) + 50}.0.${Math.floor(Math.random() * 5000) + 1000}.${Math.floor(Math.random() * 500)} Safari/${Math.floor(Math.random() * 1000) + 500}.${Math.floor(Math.random() * 100)} OPR/${Math.floor(Math.random() * 100)}.0.${Math.floor(Math.random() * 5000) + 1000}.${Math.floor(Math.random() * 500)}`,
        },
      };
    },
    checks: {
      "is accepted": (res) => res.body === "ok",
      "is buffered": (res) => res.headers["X-Plausible-Dropped"] != 1,
    },
  },
  internalApiPages: {
    method: "GET",
    name: "/api/stats/:domain/pages",
    getUrl: ({ domain }) =>
      `${baseURL}/api/stats/${encodeURIComponent(domain)}/pages?period=all&date=${new Date().toISOString().split("T")[0]}&filters=%5B%5D`,
    getParams: () => ({ headers: { Cookie: __ENV.AUTH_COOKIE } }),
    checks: {
      "request is successful": (res) => res.status === 200,
    },
  },
  externalApiQuery: {
    method: "POST",
    name: "/api/v2/query",
    getUrl: () => `${baseURL}/api/v2/query`,
    getBody: ({ domain }) => {
      const { site_id, metrics, date_range, ...rest } = {
        site_id: domain,
        // increase complexity / load with harder queries
        metrics: ["visitors", "percentage"],
        filters: [
          [
            "or",
            [
              ["contains", "event:page", ["1"]],
              ["not", ["contains", "event:page", ["5", "6", "7", "8", "9"]]],
            ],
          ],
        ],
        date_range: "all",
      };

      return JSON.stringify({ site_id, metrics, date_range, ...rest });
    },
    getParams: () => ({
      headers: {
        Authorization: `Bearer ${__ENV.STATS_API_TOKEN}`,
        "Content-Type": "application/json",
      },
    }),
    checks: {
      "request is successful (200)": (res) => res.status === 200,
      "request is rate limited (429)": (res) => res.status === 429,
    },
  },
  healthReadiness: {
    method: "GET",
    name: "/api/system/health/ready",
    getUrl: () => `${baseURL}/api/system/health/ready`,
    getParams: () => ({}),
    checks: {
      "request is successful": (res) => res.status === 200,
    },
  },
  healthLiveness: {
    method: "GET",
    name: "/api/health",
    getUrl: () => `${baseURL}/api/health`,
    getParams: () => ({}),
    checks: {
      "request is successful": (res) => res.status === 200,
    },
  },
};

function makeRequest(endpoint, opts = {}) {
  const { domain } = opts;
  const res = http.request(
    endpoint.method,
    endpoint.getUrl({ domain }),
    endpoint.getBody ? endpoint.getBody({ domain }) : null,
    {
      tags: { endpoint: endpoint.name, ...(domain && { domain }) },
      ...endpoint.getParams({ domain }),
    },
  );

  check(res, endpoint.checks);
}

export const trackHeavy = () =>
  makeRequest(endpoints.track, { domain: domainHeavy });
export const trackLight = () =>
  makeRequest(endpoints.track, { domain: domainLight });

export const readinessCheck = () => makeRequest(endpoints.healthReadiness);
export const livenessCheck = () => makeRequest(endpoints.healthLiveness);

export const pagesHeavy = () =>
  makeRequest(endpoints.internalApiPages, { domain: domainHeavy });
export const pagesLight = () =>
  makeRequest(endpoints.internalApiPages, { domain: domainLight });

export const queryHeavy = () =>
  makeRequest(endpoints.externalApiQuery, { domain: domainHeavy });
export const queryLight = () =>
  makeRequest(endpoints.externalApiQuery, { domain: domainLight });

const scenarioOptions = {
  executor: "constant-arrival-rate",
  timeUnit: "1s",
  duration: "120s",
};

// configuring thresholds changes what stats are shown in the summary at the end
const selectors = [
  [
    `endpoint: "${endpoints.healthLiveness.name}"`,
    [
      ["http_req_duration", ["p(95)<300"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.healthReadiness.name}"`,
    [
      ["http_req_duration", ["p(95)<500"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.track.name}", domain: "${domainHeavy}"`,
    [
      ["http_req_duration", ["p(95)<1500"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.track.name}", domain: "${domainLight}"`,
    [
      ["http_req_duration", ["p(95)<1500"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.internalApiPages.name}", domain: "${domainHeavy}"`,
    [
      ["http_req_duration", ["p(95)<3000"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.internalApiPages.name}", domain: "${domainLight}"`,
    [
      ["http_req_duration", ["p(95)<1500"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.externalApiQuery.name}", domain: "${domainHeavy}"`,
    [
      ["http_req_duration", ["p(95)<5000"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
  [
    `endpoint: "${endpoints.externalApiQuery.name}", domain: "${domainLight}"`,
    [
      ["http_req_duration", ["p(95)<2500"]],
      ["http_req_failed", ["rate<0.01"]],
    ],
  ],
];

export const options = {
  // to disable specific requests, comment out those scenarios
  scenarios: {
    [livenessCheck.name]: {
      ...scenarioOptions,
      rate: 1,
      preAllocatedVUs: 100,
      exec: livenessCheck.name,
    },
    [readinessCheck.name]: {
      ...scenarioOptions,
      rate: 1,
      preAllocatedVUs: 100,
      exec: readinessCheck.name,
    },
    [trackHeavy.name]: {
      ...scenarioOptions,
      rate: 500,
      preAllocatedVUs: 6000,
      exec: trackHeavy.name,
    },
    [trackLight.name]: {
      ...scenarioOptions,
      rate: 50,
      preAllocatedVUs: 600,
      exec: trackLight.name,
    },
    [pagesHeavy.name]: {
      ...scenarioOptions,
      rate: 6,
      preAllocatedVUs: 400,
      exec: pagesHeavy.name,
    },
    [pagesLight.name]: {
      ...scenarioOptions,
      rate: 6,
      preAllocatedVUs: 400,
      exec: pagesLight.name,
    },
    [queryHeavy.name]: {
      ...scenarioOptions,
      rate: 3,
      preAllocatedVUs: 200,
      exec: queryHeavy.name,
    },
    [queryLight.name]: {
      ...scenarioOptions,
      rate: 3,
      preAllocatedVUs: 200,
      exec: queryLight.name,
    },
  },
  thresholds: {
    ...Object.fromEntries(
      selectors.flatMap(([selector, thresholds]) =>
        thresholds.map(([metricName, thresholdValues]) => [
          `${metricName}{${selector}}`,
          thresholdValues,
        ]),
      ),
    ),
  },
};

export function handleSummary(data) {
  if (__ENV.JSON_SUMMARY) {
    return {
      "/tmp/summary.json": JSON.stringify(data),
    };
  }
  return undefined; // built-in text summary
}
