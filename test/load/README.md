# Load testing

This folder contains a [`k6s`](https://grafana.com/docs/k6) load testing script.
Open the script, set input constants (environment under test, site domains, auth cookie, API token), then run the script using 

```sh
$ docker run --rm -i grafana/k6 run - <script.js
```

To reconfigure the load profile, edit the exported `options` constant. 

The output looks like this:
```
  █ THRESHOLDS 

    http_req_duration{endpoint: "/api/event", domain: "dummy.site/heavy"}
    ✗ 'p(95)<500' p(95)=5.32s

    http_req_duration{endpoint: "/api/event", domain: "dummy.site/light"}
    ✗ 'p(95)<500' p(95)=5.32s

    http_req_duration{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy"}
    ✗ 'p(95)<500' p(95)=5.55s

    http_req_duration{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light"}
    ✗ 'p(95)<500' p(95)=4.96s

    http_req_duration{endpoint: "/api/system/health/ready"}
    ✗ 'p(95)<500' p(95)=3.99s

    http_req_duration{endpoint: "/api/v2/query", domain: "dummy.site/heavy"}
    ✗ 'p(95)<500' p(95)=5.66s

    http_req_duration{endpoint: "/api/v2/query", domain: "dummy.site/light"}
    ✗ 'p(95)<500' p(95)=5.98s

    http_req_failed{endpoint: "/api/event", domain: "dummy.site/heavy"}
    ✓ 'rate<0.01' rate=0.00%

    http_req_failed{endpoint: "/api/event", domain: "dummy.site/light"}
    ✓ 'rate<0.01' rate=0.00%

    http_req_failed{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy"}
    ✓ 'rate<0.01' rate=0.00%

    http_req_failed{endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light"}
    ✓ 'rate<0.01' rate=0.00%

    http_req_failed{endpoint: "/api/system/health/ready"}
    ✓ 'rate<0.01' rate=0.00%

    http_req_failed{endpoint: "/api/v2/query", domain: "dummy.site/heavy"}
    ✗ 'rate<0.01' rate=3.27%

    http_req_failed{endpoint: "/api/v2/query", domain: "dummy.site/light"}
    ✗ 'rate<0.01' rate=3.27%


  █ TOTAL RESULTS 

    checks_total.......: 9069   430.116267/s
    checks_succeeded...: 98.47% 8931 out of 9069
    checks_failed......: 1.52%  138 out of 9069

    ✗ request is successful
      ↳  98% — ✓ 261 / ✗ 4
    ✓ is accepted
    ✗ is buffered
      ↳  96% — ✓ 4268 / ✗ 134

    HTTP
    http_req_duration...............................................................: avg=1.27s    min=45.76ms  med=332.65ms max=13.95s p(90)=4.49s p(95)=5.32s
      { endpoint: "/api/event", domain: "dummy.site/heavy" }.................: avg=1.25s    min=45.76ms  med=330.37ms max=9.8s   p(90)=4.48s p(95)=5.32s
      { endpoint: "/api/event", domain: "dummy.site/light" }.................: avg=1.23s    min=54.57ms  med=327.16ms max=9.44s  p(90)=4.16s p(95)=5.32s
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy" }...: avg=1.78s    min=235.45ms med=494.39ms max=13.95s p(90)=5.36s p(95)=5.55s
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light" }...: avg=1.47s    min=199.07ms med=464.42ms max=7.86s  p(90)=4.25s p(95)=4.96s
      { endpoint: "/api/system/health/ready" }......................................: avg=819.57ms min=86.45ms  med=146.18ms max=4.61s  p(90)=3.21s p(95)=3.99s
      { endpoint: "/api/v2/query", domain: "dummy.site/heavy" }..............: avg=1.84s    min=114.13ms med=579.62ms max=11.42s p(90)=5.04s p(95)=5.66s
      { endpoint: "/api/v2/query", domain: "dummy.site/light" }..............: avg=1.89s    min=99.36ms  med=581.55ms max=10.53s p(90)=5.4s  p(95)=5.98s
      { expected_response:true }....................................................: avg=1.28s    min=45.76ms  med=332.76ms max=13.95s p(90)=4.49s p(95)=5.32s
    http_req_failed.................................................................: 0.08%  4 out of 4667
      { endpoint: "/api/event", domain: "dummy.site/heavy" }.................: 0.00%  0 out of 4001
      { endpoint: "/api/event", domain: "dummy.site/light" }.................: 0.00%  0 out of 401
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/heavy" }...: 0.00%  0 out of 61
      { endpoint: "/api/stats/:domain/pages", domain: "dummy.site/light" }...: 0.00%  0 out of 61
      { endpoint: "/api/system/health/ready" }......................................: 0.00%  0 out of 21
      { endpoint: "/api/v2/query", domain: "dummy.site/heavy" }..............: 3.27%  2 out of 61
      { endpoint: "/api/v2/query", domain: "dummy.site/light" }..............: 3.27%  2 out of 61
    http_reqs.......................................................................: 4667   221.342223/s

    EXECUTION
    iteration_duration..............................................................: avg=1.3s     min=46.2ms   med=361.51ms max=14.04s p(90)=4.52s p(95)=5.4s 
    iterations......................................................................: 4667   221.342223/s
    vus.............................................................................: 144    min=139       max=362 
    vus_max.........................................................................: 1310   min=1310      max=1310

    NETWORK
    data_received...................................................................: 5.5 MB 262 kB/s
    data_sent.......................................................................: 3.6 MB 172 kB/s
```