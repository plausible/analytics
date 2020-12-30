var pref = document.currentScript.dataset.pref;

function reapplyTheme() {
	var userPref = pref || "system";
	var mediaPref = window.matchMedia('(prefers-color-scheme: dark)').matches;
	var htmlRef = document.querySelector('html');
	var hcaptchaRefs = document.getElementsByClassName('h-captcha');

	htmlRef.classList.remove('dark');
	for (let i = 0; i < hcaptchaRefs.length; i++) {
		hcaptchaRefs[i].dataset.theme = "light";
	}

	switch (userPref) {
		case "dark":
			htmlRef.classList.add('dark');
			for (let i = 0; i < hcaptchaRefs.length; i++) {
				hcaptchaRefs[i].dataset.theme = "dark";
			}
			break;
		case "system":
			if (mediaPref) {
				htmlRef.classList.add('dark');
				for (let i = 0; i < hcaptchaRefs.length; i++) {
					hcaptchaRefs[i].dataset.theme = "dark";
				}
			}
			break;
	}
}

reapplyTheme();
window.matchMedia('(prefers-color-scheme: dark)').addListener(reapplyTheme);

window.onload = function() {
	reapplyTheme();
};
