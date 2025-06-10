import express from 'express'
import path from 'node:path'
import { fileURLToPath } from 'url'
import { compileFile } from '../../compiler/index.js'
import variantsFile from '../../compiler/variants.json' with { type: 'json' }

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const isMainModule = fileURLToPath(import.meta.url) === process.argv[1];

const app = express();
const LOCAL_SERVER_PORT = 3000
const FIXTURES_PATH = path.join(__dirname, '/../fixtures')
const VARIANTS = variantsFile.legacyVariants.concat(variantsFile.manualVariants)

export const LOCAL_SERVER_ADDR = `http://localhost:${LOCAL_SERVER_PORT}`

export function runLocalFileServer() {
  app.use(express.static(FIXTURES_PATH));

  app.get('/tracker/js/*', async (req, res) => {
    const name = req.params[0]
    const variant = VARIANTS.find((variant) => variant.name === name)

    let code = await compileFile(variant, { returnCode: true })

    if (name === 'plausible-web.js') {
      code = code.replace('"<%= @config_js %>"', req.query.script_config)
    }

    res.type('application/javascript').send(code)
  });

  // A test utility - serve an image with an artificial delay
  app.get('/img/slow-image', (_req, res) => {
    setTimeout(() => {
      res.sendFile(path.join(FIXTURES_PATH, '/img/black3x3000.png'));
    }, 100);
  });

  app.listen(LOCAL_SERVER_PORT, function () {
    console.log(`Local server listening on ${LOCAL_SERVER_ADDR}`)
  });
}

if (isMainModule) {
  runLocalFileServer()
}
