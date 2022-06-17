const express = require('express');
const app = express();
const path = require('node:path');


const FIXTURES_PATH = path.join(__dirname, '/../fixtures')
const TRACKERS_PATH = path.join(__dirname, '/../../../priv/tracker')

exports.runLocalFileServer = function() {
  app.use(express.static(FIXTURES_PATH));
  app.use('/tracker', express.static(TRACKERS_PATH));

  app.listen(3000, function() {
    console.log('Local server listening on localhost:3000')
  });
}

if (require.main === module) {
  exports.runLocalFileServer()
}
