var pref = document.currentScript.dataset.pref;

function reapplyTheme() {
	var userPref = pref || "system";
	var mediaPref = window.matchMedia('(prefers-color-scheme: dark)').matches;
	var htmlRef = document.querySelector('html');

	htmlRef.classList.remove('dark');

	switch (userPref) {
		case "dark":
			htmlRef.classList.add('dark');
			break;
		case "system":
			if (mediaPref)
				htmlRef.classList.add('dark');
	}
}

reapplyTheme();
window.matchMedia('(prefers-color-scheme: dark)').addListener(reapplyTheme);
