# Load testing

This folder contains a [`k6`](https://grafana.com/docs/k6) load testing script.

## Running the load test

Open the script, set input constants (environment under test, site domains), then run it:

```sh
$ docker run --name k6-test -i --rm grafana/k6 run -e AUTH_COOKIE="_plausible_staging=..." -e STATS_API_TOKEN="..." - < ./script.js
```

To get a machine readable JSON summary, run it using the command:

```sh
$ docker run --name k6-test -i grafana/k6 run -e AUTH_COOKIE="_plausible_staging=..." -e STATS_API_TOKEN="..." -e JSON_SUMMARY=true - < ./script.js; docker cp k6-test:/tmp/summary.json ./summary.json; docker rm k6-test
```

## Changing the load profile

To reconfigure the load profile, edit the exported `options` constant.

## Example output

The output looks like this:

```
  █ THRESHOLDS

    http_req_duration{endpoint: "/api/event", domain: "dummy.site/heavy"}
    ✗ 'p(95)<1500' p(95)=7.38s

    http_req_duration{endpoint: "/api/event", domain: "dummy.site/light"}
    ✗ 'p(95)<1500' p(95)=7.56s

    http_req_duration{endpoint: "/api/health"}
    ✓ 'p(95)<300' p(95)=0s

    http_req_duration{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy"}
    ✗ 'p(95)<3000' p(95)=5.53s

    http_req_duration{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light"}
    ✗ 'p(95)<1500' p(95)=1.61s

    http_req_duration{endpoint: "/api/system/health/ready"}
    ✓ 'p(95)<500' p(95)=226.96ms

    http_req_duration{endpoint: "/api/v2/query", domain: "dummy.site/heavy"}
    ✗ 'p(95)<5000' p(95)=7.2s

    http_req_duration{endpoint: "/api/v2/query", domain: "dummy.site/light"}
    ✓ 'p(95)<2500' p(95)=1.58s

    http_req_failed{endpoint: "/api/event", domain: "dummy.site/heavy"}
    ✗ 'rate<0.01' rate=21.95%

    http_req_failed{endpoint: "/api/event", domain: "dummy.site/light"}
    ✗ 'rate<0.01' rate=19.60%

    http_req_failed{endpoint: "/api/health"}
    ✗ 'rate<0.01' rate=100.00%

    http_req_failed{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy"}
    ✗ 'rate<0.01' rate=14.28%

    http_req_failed{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light"}
    ✗ 'rate<0.01' rate=16.66%

    http_req_failed{endpoint: "/api/system/health/ready"}
    ✓ 'rate<0.01' rate=0.00%

    http_req_failed{endpoint: "/api/v2/query", domain: "dummy.site/heavy"}
    ✗ 'rate<0.01' rate=33.33%

    http_req_failed{endpoint: "/api/v2/query", domain: "dummy.site/light"}
    ✓ 'rate<0.01' rate=0.00%


  █ TOTAL RESULTS

    checks_total.......: 1132   36.498981/s
    checks_succeeded...: 86.92% 984 out of 1132
    checks_failed......: 13.07% 148 out of 1132

    ✗ request is successful
      ↳  81% — ✓ 13 / ✗ 3
    ✗ is accepted
      ↳  78% — ✓ 432 / ✗ 120
    ✗ is buffered
      ↳  96% — ✓ 534 / ✗ 18
    ✗ request is successful (200)
      ↳  83% — ✓ 5 / ✗ 1
    ✗ request is rate limited (429)
      ↳  0% — ✓ 0 / ✗ 6

    HTTP
    http_req_duration........................................................: avg=1.38s    min=0s       med=1.06s    max=7.78s    p(90)=1.88s    p(95)=7.38s
      { endpoint: "/api/event", domain: "dummy.site/heavy" }.................: avg=1.37s    min=0s       med=1.05s    max=7.77s    p(90)=1.86s    p(95)=7.38s
      { endpoint: "/api/event", domain: "dummy.site/light" }.................: avg=1.54s    min=0s       med=1.41s    max=7.78s    p(90)=1.91s    p(95)=7.56s
      { endpoint: "/api/health" }............................................: avg=0s       min=0s       med=0s       max=0s       p(90)=0s       p(95)=0s
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy" }...: avg=1.71s    min=279.43ms med=912.92ms max=7.07s    p(90)=3.99s    p(95)=5.53s
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light" }...: avg=738.31ms min=282.4ms  med=437.64ms max=1.77s    p(90)=1.45s    p(95)=1.61s
      { endpoint: "/api/system/health/ready" }...............................: avg=209.82ms min=190.77ms med=209.82ms max=228.87ms p(90)=225.06ms p(95)=226.96ms
      { endpoint: "/api/v2/query", domain: "dummy.site/heavy" }..............: avg=3.86s    min=1.8s     med=1.99s    max=7.78s    p(90)=6.62s    p(95)=7.2s
      { endpoint: "/api/v2/query", domain: "dummy.site/light" }..............: avg=1s       min=371ms    med=989.72ms max=1.65s    p(90)=1.52s    p(95)=1.58s
      { expected_response:true }.............................................: avg=1.12s    min=111.27ms med=1.19s    max=2.15s    p(90)=1.8s     p(95)=1.86s
    http_req_failed..........................................................: 21.60%  124 out of 574
      { endpoint: "/api/event", domain: "dummy.site/heavy" }.................: 21.95%  110 out of 501
      { endpoint: "/api/event", domain: "dummy.site/light" }.................: 19.60%  10 out of 51
      { endpoint: "/api/health" }............................................: 100.00% 1 out of 1
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy" }...: 14.28%  1 out of 7
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light" }...: 16.66%  1 out of 6
      { endpoint: "/api/system/health/ready" }...............................: 0.00%   0 out of 2
      { endpoint: "/api/v2/query", domain: "dummy.site/heavy" }..............: 33.33%  1 out of 3
      { endpoint: "/api/v2/query", domain: "dummy.site/light" }..............: 0.00%   0 out of 3
    http_reqs................................................................: 574     18.507434/s

    EXECUTION
    iteration_duration.......................................................: avg=6.67s    min=332.62ms med=1.92s    max=30.01s   p(90)=30s      p(95)=30s
    iterations...............................................................: 574     18.507434/s
    vus......................................................................: 48      min=0          max=420
    vus_max..................................................................: 8000    min=6005       max=8000

    NETWORK
    data_received............................................................: 1.7 MB  54 kB/s
    data_sent................................................................: 1.0 MB  33 kB/s
```
