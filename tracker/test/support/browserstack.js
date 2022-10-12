const BrowserStackLocal = require('browserstack-local');

exports.bsLocal = new BrowserStackLocal.Local();
exports.BS_LOCAL_ARGS = {
  key: process.env.BROWSERSTACK_ACCESS_KEY
};

exports.ensureCredentials = function() {
  if (!process.env.BROWSERSTACK_ACCESS_KEY) {
    throw 'Please configure process.env.BROWSERSTACK_ACCESS_KEY'
  }

  if (!process.env.BROWSERSTACK_USERNAME) {
    throw 'Please configure process.env.BROWSERSTACK_USERNAME'
  }
}
