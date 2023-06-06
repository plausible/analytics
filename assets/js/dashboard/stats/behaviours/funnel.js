import { featureSetupNotice } from "../../components/notice"
import { FUNNELS } from "."

export default function Funnel(props) {
	if (props.funnelName) {
		// TODO
		return null
	} else {
		const opts = {
			title: 'I\'m behind the "funnels" feature flag',
			info: 'I currently exist only for UI testing. Please update me to something meaningful.',
			docsLink: 'TODO - the correct docs link',
			hideNotice: 'Hide the "Funnels" tab from your dashboard by clicking the icon on the top right. You can make funnels visible again in your site settings later'
		}
		
		return featureSetupNotice(props.site, FUNNELS, opts)
	}
}