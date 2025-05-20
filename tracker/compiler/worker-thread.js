import { compileFile } from './index.js'
import { expose } from "threads/worker"

expose({ compileFile })
