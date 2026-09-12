import React, { ReactNode } from 'react'

const ICON_CLASS = 'inline-block w-4 h-4 mr-2'

const SVG_ICON_COLOR_CLASS = 'text-gray-600 dark:text-gray-300'

// The fallback icons are inlined so that they follow the current text color,
// supporting light and dark mode.
const SHARED_FALLBACK_SVG_PROPS = {
  xmlns: 'http://www.w3.org/2000/svg',
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  className: `${ICON_CLASS} ${SVG_ICON_COLOR_CLASS}`
} as const

// Icons copied from https://github.com/alrra/browser-logos
const BROWSER_ICONS: Record<string, string> = {
  Chrome: 'chrome.svg',
  curl: 'curl.svg',
  Safari: 'safari.png',
  Firefox: 'firefox.svg',
  'Microsoft Edge': 'edge.svg',
  Vivaldi: 'vivaldi.svg',
  Opera: 'opera.svg',
  'Samsung Browser': 'samsung-internet.svg',
  Chromium: 'chromium.svg',
  'UC Browser': 'uc.svg',
  'Yandex Browser': 'yandex.png', // Only PNG available in browser-logos
  // Logos underneath this line are not available in browser-logos. Grabbed from random places on the internets.
  'DuckDuckGo Privacy Browser': 'duckduckgo.svg',
  'MIUI Browser': 'miui.webp',
  'Huawei Browser Mobile': 'huawei.png',
  'QQ Browser': 'qq.png',
  Ecosia: 'ecosia.png',
  'vivo Browser': 'vivo.png'
}

const BrowserFallbackIconSvg = () => (
  <svg {...SHARED_FALLBACK_SVG_PROPS}>
    <path d="M12 23c2.43 0 4.4-4.925 4.4-11S14.43 1 12 1 7.6 5.925 7.6 12 9.57 23 12 23Z" />
    <path d="M1 12h22" />
    <path d="M12 23c6.075 0 11-4.925 11-11S18.075 1 12 1 1 5.925 1 12s4.925 11 11 11Z" />
  </svg>
)

export const BrowserIcon = ({ dimensionValue }: { dimensionValue: string }) => {
  const filename = BROWSER_ICONS[dimensionValue]

  if (!filename) {
    return <BrowserFallbackIconSvg />
  }

  return (
    <img
      alt=""
      src={`/images/icon/browser/${filename}`}
      className={ICON_CLASS}
    />
  )
}

// Icons copied from https://github.com/ngeenx/operating-system-logos
const OS_ICONS: Record<string, string> = {
  iOS: 'ios.png',
  Mac: 'mac.png',
  Windows: 'windows.png',
  'Windows Phone': 'windows.png',
  Android: 'android.png',
  'GNU/Linux': 'gnu_linux.png',
  Ubuntu: 'ubuntu.png',
  'Chrome OS': 'chrome_os.png',
  iPadOS: 'ipad_os.png',
  'Fire OS': 'fire_os.png',
  HarmonyOS: 'harmony_os.png',
  Tizen: 'tizen.png',
  PlayStation: 'playstation.png',
  KaiOS: 'kai_os.png',
  Fedora: 'fedora.png',
  FreeBSD: 'freebsd.png'
}

const OsFallbackIconSvg = () => (
  <svg {...SHARED_FALLBACK_SVG_PROPS}>
    <path d="M3.2 21.8h17.6a2.2 2.2 0 0 0 2.2-2.2v-5.204q0-.195-.035-.39l-2.62-9.996a2.2 2.2 0 0 0-2.164-1.81H5.819a2.2 2.2 0 0 0-2.165 1.81l-2.62 9.997a2 2 0 0 0-.034.39V19.6a2.2 2.2 0 0 0 2.2 2.2M23 14.2H1" />
    <path strokeWidth={3} d="M5.5 17.961v-.011M10 17.961v-.011" />
  </svg>
)

export const OsIcon = ({ dimensionValue }: { dimensionValue: string }) => {
  const filename = OS_ICONS[dimensionValue]

  if (!filename) {
    return <OsFallbackIconSvg />
  }

  return (
    <img alt="" src={`/images/icon/os/${filename}`} className={ICON_CLASS} />
  )
}

const SHARED_SCREEN_SIZE_SVG_PROPS = {
  xmlns: 'http://www.w3.org/2000/svg',
  width: 24,
  height: 24,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  className: `-mt-px feather inline-block ${SVG_ICON_COLOR_CLASS}`
} as const

const MobileScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
    <line x1="12" y1="18" x2="12" y2="18" />
  </svg>
)

const TabletScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect
      x="4"
      y="2"
      width="16"
      height="20"
      rx="2"
      ry="2"
      transform="rotate(180 12 12)"
    />
    <line x1="12" y1="18" x2="12" y2="18" />
  </svg>
)

const LaptopScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
    <line x1="2" y1="20" x2="22" y2="20" />
  </svg>
)

const DesktopScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
    <line x1="8" y1="21" x2="16" y2="21" />
    <line x1="12" y1="17" x2="12" y2="21" />
  </svg>
)

const UltraWideScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="1" y="4" width="22" height="12" rx="2" ry="2" />
    <line x1="6" y1="20" x2="18" y2="20" />
    <line x1="12" y1="16" x2="12" y2="20" />
  </svg>
)

const NotSetScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <path d="M12 23c6.075 0 11-4.925 11-11S18.075 1 12 1 1 5.925 1 12s4.925 11 11 11Z" />
    <path d="M8.7 9.8a3.3 3.3 0 1 1 6.6 0c0 1.44-.923 2.322-2.21 2.628-.59.14-1.09.614-1.09 1.222" />
    <path strokeWidth={3} d="M12 17.511V17.5" />
  </svg>
)

const SCREEN_SIZE_SVGS: Record<string, ReactNode> = {
  Mobile: <MobileScreenIconSvg />,
  Tablet: <TabletScreenIconSvg />,
  Laptop: <LaptopScreenIconSvg />,
  Desktop: <DesktopScreenIconSvg />,
  'Ultra-wide': <UltraWideScreenIconSvg />,
  '(not set)': <NotSetScreenIconSvg />
}

export const ScreenSizeIcon = ({
  dimensionValue
}: {
  dimensionValue: string
}) => <span className="mr-1.5">{SCREEN_SIZE_SVGS[dimensionValue] ?? null}</span>
