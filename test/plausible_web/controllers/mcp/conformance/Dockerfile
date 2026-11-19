FROM node:24.22.1-alpine3.23@sha256:0468540aa58203ff9e40c2aab3907c52644ab818af6176b1c70a026137dc92a2

WORKDIR /app
RUN npm install --ignore-scripts --no-audit --no-fund --before=2026-11-01 \
  @modelcontextprotocol/conformance@0.2.0-alpha.12 \
  @modelcontextprotocol/sdk@1.32.2 \
  @modelcontextprotocol/client@2.4.0 \
  ajv@8.20.0
COPY client.mjs expected-failures.yml ./

USER node
ENV PATH=/app/node_modules/.bin:$PATH
