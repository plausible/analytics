export default async function({ page, context }) {

	if (context.debug) {
		page.on('console', (msg) => console[msg.type()]('PAGE LOG:', msg.text()));
	}

	await page.setUserAgent(context.userAgent);

	await page.goto(context.url);
	await page.waitForNetworkIdle({ idleTime: 1000 });

	const plausibleInstalled = await page.evaluate(() => {
		window.__plausible = true;
		if (typeof (window.plausible) === "function") {
			window.plausible('verification-agent-test', {
				callback: function(options) {
					window.plausibleCallbackResult = () => options && options.status ? options.status : 1;
				}
			});
			return true;
		} else {
			window.plausibleCallbackResult = () => 0;
			return false;
		}
	});

	await page.waitForFunction('window.plausibleCallbackResult', { timeout: 2000 });
	const callbackStatus = await page.evaluate(() => {
		if (typeof (window.plausibleCallbackResult) === "function") {
			return window.plausibleCallbackResult();
		} else {
			return 0;
		}
	});

	return {
		data: {
			plausibleInstalled, callbackStatus
		},
		type: "application/json"
	};
}
