import http from "k6/http";
import { check } from "k6";

const PAYLOAD = JSON.stringify({
  n: "pageview",
  u: "http://dummy.site/some-page",
  d: "dummy.site",
  r: null,
  w: 1666,
});

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

export const options = {
  scenarios: {
    constant_rps: {
      executor: "constant-arrival-rate",
      rate: 6000,
      timeUnit: "1s",
      duration: "1m",
      preAllocatedVUs: 10000,
      maxVUs: 30000,
    },
  },
};

export default function () {
  const res = http.post(
    "http://localhost:8000/api/event",
    PAYLOAD,
    newParams(),
  );

  check(res, {
    "is accepted": (r) => r.body === "ok",
    "is buffered": (r) => r.headers["X-Plausible-Dropped"] !== "1",
  });
}
