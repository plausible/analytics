import http from "k6/http";

const PAYLOAD = JSON.stringify({
  "n":"pageview",
  "u":"http://loadtest.site/some-page",
  "d":"loadtest.site",
  "r":null,
  "w":1666
});

function newParams() {
  const ip = (Math.floor(Math.random() * 255) + 1)+"."+(Math.floor(Math.random() * 255))+"."+(Math.floor(Math.random() * 255))+"."+(Math.floor(Math.random() * 255));

  return {
    headers: {
      'Content-Type': 'application/json',
      'X-Forwarded-For': ip,
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284'
    }
  }
}

export const options = {
  scenarios: {
    wave1: {
      executor: 'constant-vus',
      startTime: '0s',
      vus: 200,
      duration: '60s'
    },
    wave2: {
      executor: 'constant-vus',
      startTime: '60s',
      vus: 200,
      duration: '60s'
    },
    wave3: {
      executor: 'constant-vus',
      startTime: '120s',
      vus: 200,
      duration: '60s'
    },
    wave4: {
      executor: 'constant-vus',
      startTime: '180s',
      vus: 200,
      duration: '60s'
    },
  },
};

export default function() {
  http.post("http://localhost:8000/api/event", PAYLOAD, newParams());
};
