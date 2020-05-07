# Plausible Insights




## Envionment Variables
Plausible relies on the several services for operating, the expected environment variables are explaiend below.  

### Server
Following are the variables that can be used to configure the availability of the server.

- HOST (*String*)
    - The hosting address of the server. For running on local system, this can be set to **localhost**. In production systems, this can be your ingress host.
- PORT (*Number*)
    - The port on which the server is available. 
- SECRET_KEY_BASE (*String*)
    - An internal secret key used by [Phoenix Framework](https://www.phoenixframework.org/). Follow the [instructions](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Secret.html#content) to generate one. 

### Database
PLausible uses postgresql as database for storing all the data. Use the following the variables to configure it.

- DATABASE_URL (*String*)
    - The repo Url as dictated [here](https://hexdocs.pm/ecto/Ecto.Repo.html#module-urls)
- DATABASE_POOL_SIZE (*Number*)
    -  A default pool size for connecting to the database, defaults to *10*, a higher number is recommended for a production system.
- DATABASE_TLS_ENABLED (*Boolean String*)
    - A flag that says whether to connect to the database via TLS, read [here](https://www.postgresql.org/docs/10/ssl-tcp.html)

### External Services

- [Google Client](https://developers.google.com/api-client-library)
    - GOOGLE_CLIENT_ID
    - GOOGLE_CLIENT_SECRET
- [Sentry](https://sentry.io/) 
    - SENTRY_DSN
- [Paddle](https://paddle.com/)
    - PADDLE_VENDOR_AUTH_CODE
- [PostMark](https://postmarkapp.com/)
    - POSTMARK_API_KEY

Apart from these, there are also the following integrations 

- [Twitter](https://developer.twitter.com/en/docs)
    - TWITTER_CONSUMER_KEY
    - TWITTER_CONSUMER_SECRET
    - TWITTER_ACCESS_TOKEN
    - TWITTER_ACCESS_TOKEN_SECRET
- [Slack](https://api.slack.com/messaging/webhooks) 
    - SLACK_WEBHOOK
