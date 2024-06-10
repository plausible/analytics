import http from "k6/http";
import { check, sleep } from "k6";

const PAYLOAD = JSON.stringify({
  n: "pageview",
  u: "http://loadtest.site/some-page",
  d: "loadtest.site",
  r: null,
  w: 1666,
});

function rand_uniform(from, to) {
  return Math.floor(Math.random() * from) + to;
}

function newParams() {
  return {
    headers: {
      "Content-Type": "application/json",
      "X-Forwarded-For": `${rand_uniform(1, 255)}.${rand_uniform(
        1,
        255
      )}.${rand_uniform(1, 255)}.${rand_uniform(1, 255)}`,
      // original header: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284'
      // now it's 300*30*3000 = 27_000_000 combinations
      // 'User-Agent': `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/${rand_uniform(300, 600)}.${rand_uniform(20, 50)} (KHTML, like Gecko) Chrome/85.0.${rand_uniform(2000, 5000)}.121 Safari/537.36 OPR/71.0.3770.284`
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284",
    },
  };
}

export const options = {
  noConnectionReuse: false,
  stages: [
    { target: 100, duration: "10s" },
    { target: 200, duration: "30s" },
    { target: 400, duration: "30s" },
    { target: 100, duration: "30s" },
    { target: 0, duration: "10s" },
  ],
};

export default function () {
  let resp = http.post("http://localhost:8000/api/event", PAYLOAD, newParams());
  check(resp, {
    "is status 200": (r) => r.status === 200,
    "text verification": (r) => r.body === "ok",
  });
  // sleep(0.1);
}
