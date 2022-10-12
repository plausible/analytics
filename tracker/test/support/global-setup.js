// global-setup.js
const { bsLocal, ensureCredentials, BS_LOCAL_ARGS } = require('./browserstack');
const { promisify } = require('util');
const { runLocalFileServer } = require('./server')

const sleep = promisify(setTimeout);
const redColour = '\x1b[31m';
const whiteColour = '\x1b[0m';

ensureCredentials()

module.exports = async () => {
  console.log('Starting BrowserStackLocal ...');
  runLocalFileServer()
  // Starts the Local instance with the required arguments
  let localResponseReceived = false;
  bsLocal.start(BS_LOCAL_ARGS, (err) => {
    if (err) {
      console.error(
        `${redColour}Error starting BrowserStackLocal${whiteColour}`
      );
    } else {
      console.log('BrowserStackLocal Started');
    }
    localResponseReceived = true;
  });
  while (!localResponseReceived) {
    await sleep(1000);
  }
};
