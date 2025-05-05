import http from "k6/http";

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
    wave1: {
      executor: "constant-vus",
      startTime: "0s",
      vus: 20000,
      duration: "60s",
    },
    wave2: {
      executor: "constant-vus",
      startTime: "60s",
      vus: 20000,
      duration: "60s",
    },
    wave3: {
      executor: "constant-vus",
      startTime: "120s",
      vus: 20000,
      duration: "60s",
    },
    wave4: {
      executor: "constant-vus",
      startTime: "180s",
      vus: 20000,
      duration: "60s",
    },
  },
};

export default function () {
  http.post("http://localhost:8000/api/event", PAYLOAD, newParams());
}
