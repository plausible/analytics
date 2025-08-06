import http from "k6/http";
import { check } from "k6";

function payload(pages) {
  return JSON.stringify({
    n: "pageview",
    u: pages[Math.floor(Math.random() * pages.length)],
    d: "dummy2.site",
    r: null,
    w: 1666,
  });
}

function newParams() {
  const ip =
    Math.floor(Math.random() * 255) +
    1 +
    "." +
    Math.floor(Math.random() * 255) +
    "." +
    Math.floor(Math.random() * 255) +
    "." +
    Math.floor(Math.random() * 255);

  return {
    headers: {
      "Content-Type": "application/json",
      "X-Forwarded-For": ip,
      "User-Agent": `${Math.random() > 0.5 ? "Mozilla/5.0" : "Mozilla/4.0"} (${Math.random() > 0.5 ? "Macintosh" : "Windows"}; ${Math.random() > 0.5 ? "Intel Mac OS X 10_15_6" : "Windows NT 10.0"}) AppleWebKit/${Math.floor(Math.random() * 1000) + 500}.36 (KHTML, like Gecko) Chrome/${Math.floor(Math.random() * 100) + 50}.0.${Math.floor(Math.random() * 5000) + 1000}.${Math.floor(Math.random() * 500)} Safari/${Math.floor(Math.random() * 1000) + 500}.${Math.floor(Math.random() * 100)} OPR/${Math.floor(Math.random() * 100)}.0.${Math.floor(Math.random() * 5000) + 1000}.${Math.floor(Math.random() * 500)}`,
    },
  };
}

function getClient(clients) {
  return clients[Math.floor(Math.random() * clients.length)];
}

function getClientSliding(clients, start, runtime, windowSize) {
  const now = Date.now();
  const delta = windowSize + Math.floor((now - start) / 1000);
  const timeline = runtime + 2 * windowSize;

  const lowerBound = Math.max(delta - windowSize, 0);
  const upperBound = Math.min(lowerBound + 2 * windowSize, timeline);

  const lowerIndex = Math.floor((lowerBound / timeline) * clients.length);
  const upperIndex = Math.floor((upperBound / timeline) * clients.length);
  const indexWindow = upperIndex - lowerIndex;

  return clients[lowerIndex + Math.floor(Math.random() * indexWindow)];
}

export function setup() {
  const start = Date.now();

  const clients = Array(2000)
    .fill(0)
    .map((_) => newParams());

  const pages = Array(100)
    .fill(0)
    .map((_, i) => `http://dummy.site/some-page-${i}`);

  return { clients: clients, pages: pages, start: start };
}

export const options = {
  scenarios: {
    constant_rps: {
      executor: "constant-arrival-rate",
      rate: 50,
      timeUnit: "1s",
      duration: "10m",
      preAllocatedVUs: 0,
      maxVUs: 30000,
    },
  },
};

export default function (data) {
  // const client = getClient(data.clients);
  const client = getClientSliding(data.clients, data.start, 600, 60);

  const res = http.post(
    "http://localhost:4000/api/event",
    payload(data.pages),
    client,
  );

  check(res, {
    "is accepted": (r) => r.body === "ok",
    "is buffered": (r) => r.headers["X-Plausible-Dropped"] !== "1",
  });
}
