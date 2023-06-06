import { PROPS } from "."
import { featureSetupNotice } from "../../components/notice"

export default function Props(props) {
  if (props.hasProps) {
		// TODO
		return null
	} else {
		const opts = {
      title: 'I\'m behind the "props" feature flag',
			info: 'I currently exist only for UI testing. Please update this text to something meaningful :)',
			docsLink: 'TODO - the correct docs link',
      hideNotice: 'Hide the "Custom Properties" tab from your dashboard by clicking the icon on the top right. You can make custom properties visible again in your site settings later'
    }
  
    return featureSetupNotice(props.site, PROPS, opts)
	}
}