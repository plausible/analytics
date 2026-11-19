import { Client as V1Client } from "@modelcontextprotocol/sdk/client/index.js"
import { StreamableHTTPClientTransport as V1Transport } from "@modelcontextprotocol/sdk/client/streamableHttp.js"
import { Client as V2Client, StreamableHTTPClientTransport as V2Transport } from "@modelcontextprotocol/client"
import Ajv2020 from "ajv/dist/2020.js"

const sdks = {
  v1: [V1Client, V1Transport],
  v2: [V2Client, V2Transport],
}

const [, , sdk, url] = process.argv
const [Client, Transport] = sdks[sdk]

const client = new Client({ name: "plausible-test", version: "0.0.0" })
client.onerror = (error) => {
  console.error(error)
  process.exitCode = 1
}
await client.connect(new Transport(new URL(url)))
const { tools } = await client.listTools()
// MCP recommends JSON Schema 2020-12: https://modelcontextprotocol.io/specification/2026-07-28/basic#schema-dialect
const ajv = new Ajv2020({ strictTypes: false, strictTuples: false, validateFormats: false })
tools.forEach((tool) => ajv.compile(tool.inputSchema))
await client.callTool({ name: "list_sites", arguments: {} })
await client.close()
