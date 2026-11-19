/**
 * Tests our `/mcp` server against the official MCP conformance suite
 * (https://github.com/modelcontextprotocol/conformance) and against real
 * clients from the TypeScript SDK v1 and v2.
 *
 * The suite runs once for each protocol version that we support.
 * When you add a version, add it to the list of versions below.
 *
 * We do not support some MCP features, e.g. resources and logging.
 * `expected-failures.yml` lists the scenarios for these features.
 * When you add a feature, remove its scenarios from this file.
 */
import { test, expect, type APIRequestContext } from '@playwright/test'
import { execFile } from 'node:child_process'
import http from 'node:http'
import type { AddressInfo } from 'node:net'
import path from 'node:path'
import { Client as V1Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StreamableHTTPClientTransport as V1Transport } from '@modelcontextprotocol/sdk/client/streamableHttp.js'
import {
  Client as V2Client,
  StreamableHTTPClientTransport as V2Transport
} from '@modelcontextprotocol/client'
import { Ajv2020 } from 'ajv/dist/2020.js'
import { register } from '../fixtures'
import { randomID } from '../test-utils'

const conformanceBin = path.join(
  __dirname,
  '../../node_modules/.bin/conformance'
)
const expectedFailures = path.join(__dirname, 'expected-failures.yml')

test.describe.configure({ timeout: 120_000 })

let token: string

test.beforeEach(async ({ page, request }) => {
  const userID = randomID()
  const user = {
    name: `User ${userID}`,
    email: `email-${userID}@example.com`,
    password: 'VeryStrongVerySecret'
  }

  await register({ page, request, user })
  token = await createOAuthGrant(request, user.email)
})

for (const version of ['2026-07-28', '2025-11-25']) {
  test(`meets the ${version} requirements`, async ({ baseURL }) => {
    // The suite cannot send an access token, so a local proxy adds it.
    const proxy = await startAuthProxy(new URL('/mcp', baseURL), token)

    try {
      const { code, output } = await run(conformanceBin, [
        'server',
        '--url',
        proxy.url,
        '--requirements',
        version,
        '--expected-failures',
        expectedFailures
      ])

      expect(code, output).toBe(0)
    } finally {
      proxy.server.close()
    }
  })
}

test('the TS SDK v1 client connects and calls a tool', async ({ baseURL }) => {
  const client = new V1Client({ name: 'plausible-test', version: '0.0.0' })
  const transport = new V1Transport(new URL('/mcp', baseURL), {
    requestInit: { headers: { authorization: `Bearer ${token}` } }
  })

  const errors: Error[] = []
  client.onerror = (error) => errors.push(error)

  await client.connect(transport)
  const { tools } = await client.listTools()
  expectJsonSchema2020(tools)
  await client.callTool({ name: 'list_sites', arguments: {} })
  await client.close()

  expect(errors).toEqual([])
})

test('the TS SDK v2 client connects and calls a tool', async ({ baseURL }) => {
  const client = new V2Client({ name: 'plausible-test', version: '0.0.0' })
  const transport = new V2Transport(new URL('/mcp', baseURL), {
    requestInit: { headers: { authorization: `Bearer ${token}` } }
  })

  const errors: Error[] = []
  client.onerror = (error) => errors.push(error)

  await client.connect(transport)
  const { tools } = await client.listTools()
  expectJsonSchema2020(tools)
  await client.callTool({ name: 'list_sites', arguments: {} })
  await client.close()

  expect(errors).toEqual([])
})

// MCP recommends JSON Schema 2020-12: https://modelcontextprotocol.io/specification/2026-07-28/basic#schema-dialect
function expectJsonSchema2020(tools: { inputSchema: object }[]) {
  const ajv = new Ajv2020({
    strictTypes: false,
    strictTuples: false,
    validateFormats: false
  })

  tools.forEach((tool) =>
    expect(() => ajv.compile(tool.inputSchema)).not.toThrow()
  )
}

async function createOAuthGrant(request: APIRequestContext, email: string) {
  const response = await request.post('/e2e-tests/oauth-grant', {
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json'
    },
    data: { email }
  })

  expect(response.ok()).toBeTruthy()

  const { access_token } = await response.json()
  return access_token as string
}

async function startAuthProxy(target: URL, token: string) {
  const server = http.createServer((req, res) => {
    const upstream = http.request(
      target,
      {
        method: req.method,
        headers: { ...req.headers, authorization: `Bearer ${token}` }
      },
      (upstreamRes) => {
        res.writeHead(upstreamRes.statusCode!, upstreamRes.headers)
        upstreamRes.pipe(res)
      }
    )

    upstream.on('error', (error) => res.destroy(error))
    req.pipe(upstream)
  })

  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as AddressInfo

  return { server, url: `http://127.0.0.1:${port}/mcp` }
}

function run(
  command: string,
  args: string[]
): Promise<{ code: number; output: string }> {
  return new Promise((resolve) => {
    execFile(
      command,
      args,
      { maxBuffer: 16 * 1024 * 1024 },
      (error, stdout, stderr) => {
        resolve({
          code: error ? ((error.code as number) ?? 1) : 0,
          output: stdout + stderr
        })
      }
    )
  })
}
