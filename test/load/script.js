import http from "k6/http";
import { check } from "k6";

/** INPUTS */
/** Base URL of the environment under test (env) */
const baseURL = "http://localhost:8000";
/** Domain of a site registered in the env */
const domainHeavy = "dummy.site/heavy";
/** Domain of a site registered in the env */
const domainLight = "dummy.site/light";
/** Valid auth cookie of a user with access to the domains above in the env */
const internalApiCookie = "_plausible_dev=...";
/** Valid Stats API token of a user with access to the domains above in the env */
const externalApiToken = "...";

const endpoints = {
  track: {
    method: "POST",
    name: "/api/event",
    getUrl: () => `${baseURL}/api/event`,
    getBody: (options) => {
      const { name, domain, url, ...rest } = {
        name: "pageview",
        ...options,
      };
      const payload = {
        n: name,
        u: url ?? `https://${domain}/page`,
        d: domain,
        ...rest,
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
  internalApi: {
    method: "GET",
    name: "/api/stats/:domain/pages",
    getUrl: ({ domain }) =>
      `${baseURL}/api/stats/${encodeURIComponent(domain)}/pages?period=all&date=${new Date().toISOString().split("T")[0]}&filters=%5B%5D`,
    getParams: () => ({ headers: { Cookie: internalApiCookie } }),
    checks: {
      "request is successful": (res) => res.status === 200,
    },
  },
  externalApi: {
    method: "POST",
    name: "/api/v2/query",
    getUrl: () => `${baseURL}/api/v2/query`,
    getBody: ({ domain }) => {
      const { site_id, metrics, date_range, ...rest } = {
        site_id: domain,
        metrics: ["visitors"],
        date_range: "all",
      };

      return JSON.stringify({ site_id, metrics, date_range, ...rest });
    },
    getParams: () => ({
      headers: {
        Authorization: `Bearer ${externalApiToken}`,
        "Content-Type": "application/json",
      },
    }),
    checks: {
      "request is successful": (res) => res.status === 200,
    },
  },
  health: {
    method: "GET",
    name: "/api/system/health/ready",
    getUrl: () => `${baseURL}/api/system/health/ready`,
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
export const healthCheck = () => makeRequest(endpoints.health);
export const pagesHeavy = () =>
  makeRequest(endpoints.internalApi, { domain: domainHeavy });
export const pagesLight = () =>
  makeRequest(endpoints.internalApi, { domain: domainLight });
export const queryHeavy = () =>
  makeRequest(endpoints.externalApi, { domain: domainHeavy });
export const queryLight = () =>
  makeRequest(endpoints.externalApi, { domain: domainLight });

const sharedScenarioOptions = {
  executor: "constant-arrival-rate",
  timeUnit: "1s",
  duration: "20s",
};

const selectors = [
  `{endpoint: "${endpoints.health.name}"}`,
  `{endpoint: "${endpoints.track.name}", domain: "${domainHeavy}"}`,
  `{endpoint: "${endpoints.track.name}", domain: "${domainLight}"}`,
  `{endpoint: "${endpoints.internalApi.name}", domain: "${domainHeavy}"}`,
  `{endpoint: "${endpoints.internalApi.name}", domain: "${domainLight}"}`,
  `{endpoint: "${endpoints.externalApi.name}", domain: "${domainHeavy}"}`,
  `{endpoint: "${endpoints.externalApi.name}", domain: "${domainLight}"}`,
];

export const options = {
  scenarios: {
    [trackHeavy.name]: {
      ...sharedScenarioOptions,
      rate: 200,
      preAllocatedVUs: 1000,
      exec: trackHeavy.name,
    },
    [trackLight.name]: {
      ...sharedScenarioOptions,
      rate: 20,
      preAllocatedVUs: 100,
      exec: trackLight.name,
    },
    [healthCheck.name]: {
      ...sharedScenarioOptions,
      rate: 1,
      preAllocatedVUs: 10,
      exec: healthCheck.name,
    },
    [pagesHeavy.name]: {
      ...sharedScenarioOptions,
      rate: 3,
      preAllocatedVUs: 50,
      exec: pagesHeavy.name,
    },
    [pagesLight.name]: {
      ...sharedScenarioOptions,
      rate: 3,
      preAllocatedVUs: 50,
      exec: pagesLight.name,
    },
    [queryHeavy.name]: {
      ...sharedScenarioOptions,
      rate: 3,
      preAllocatedVUs: 50,
      exec: queryHeavy.name,
    },
    [queryLight.name]: {
      ...sharedScenarioOptions,
      rate: 3,
      preAllocatedVUs: 50,
      exec: queryLight.name,
    },
  },
  thresholds: {
    ...Object.fromEntries(
      selectors.map((selector) => [
        `http_req_duration${selector}`,
        ["p(95)<500"],
      ]),
    ),
    ...Object.fromEntries(
      selectors.map((selector) => [
        `http_req_failed${selector}`,
        ["rate<0.01"],
      ]),
    ),
  },
};
