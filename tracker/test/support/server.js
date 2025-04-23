import express from 'express'
import path from 'node:path'
import { fileURLToPath } from 'url'
import { compileFile } from '../../compiler/index.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const isMainModule = fileURLToPath(import.meta.url) === process.argv[1];

const app = express();
const LOCAL_SERVER_PORT = 3000
const FIXTURES_PATH = path.join(__dirname, '/../fixtures')

export const LOCAL_SERVER_ADDR = `http://localhost:${LOCAL_SERVER_PORT}`

export function runLocalFileServer() {
  app.use(express.static(FIXTURES_PATH));

  app.get('/tracker/js/:name', (req, res) => {
    const name = req.params.name
    const features = name.split('.').filter((feature) => !['js', 'plausible'].includes(feature))

    const code = compileFile({ name, features }, { returnCode: true })
    res.send(code)
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
