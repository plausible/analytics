export default async function({ page, context }) {

	if (context.debug) {
		page.on('console', (msg) => console[msg.type()]('PAGE LOG:', msg.text()));
	}

	await page.setUserAgent(context.userAgent);
	await page.goto(context.url);

	try {
		await page.waitForFunction('window.plausible', { timeout: 5000 });
		await page.evaluate(() => {
			window.__plausible = true;
			window.plausible('verification-agent-test', {
				callback: function(options) {
					window.plausibleCallbackResult = () => options && options.status ? options.status : -1;
				}
			});
		});

		try {
			await page.waitForFunction('window.plausibleCallbackResult', { timeout: 5000 });
			const status = await page.evaluate(() => { return window.plausibleCallbackResult() });
			return { data: { plausibleInstalled: true, callbackStatus: status } };
		} catch ({ err, message }) {
			return { data: { plausibleInstalled: true, callbackStatus: 0, error: message } };
		}
	} catch ({ err, message }) {
		return {
			data: {
				plausibleInstalled: false, callbackStatus: 0, error: message
			}
		};
	}
}

