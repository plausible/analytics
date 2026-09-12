import React, { ReactElement } from 'react'

const ICON_CLASS = 'shrink-0 inline-block size-4 mr-2'

const SVG_ICON_COLOR_CLASS = 'text-gray-600 dark:text-gray-300'

// The icons that are not brand logos are inlined so that they follow the
// current text color, supporting light and dark mode.
const SHARED_SVG_PROPS = {
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
  <svg {...SHARED_SVG_PROPS}>
    <path d="M12 22c2.21 0 4-4.477 4-10S14.21 2 12 2 8 6.477 8 12s1.79 10 4 10Z" />
    <path d="M2 12h20" />
    <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z" />
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
  <svg {...SHARED_SVG_PROPS}>
    <path d="M4 20.818h16a2 2 0 0 0 2-2v-4.73q0-.18-.032-.355l-2.38-9.087A2 2 0 0 0 17.617 3H6.382a2 2 0 0 0-1.968 1.646l-2.381 9.087a2 2 0 0 0-.032.355v4.73a2 2 0 0 0 2 2M22 13.91H2" />
    <path strokeWidth={3} d="M6.092 17.328v-.01M10.182 17.328v-.01" />
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

const MobileScreenIconSvg = () => (
  <svg {...SHARED_SVG_PROPS}>
    <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
    <line x1="12" y1="18" x2="12" y2="18" />
  </svg>
)

const TabletScreenIconSvg = () => (
  <svg {...SHARED_SVG_PROPS}>
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
  <svg {...SHARED_SVG_PROPS}>
    <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
    <line x1="2" y1="20" x2="22" y2="20" />
  </svg>
)

const DesktopScreenIconSvg = () => (
  <svg {...SHARED_SVG_PROPS}>
    <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
    <line x1="8" y1="21" x2="16" y2="21" />
    <line x1="12" y1="17" x2="12" y2="21" />
  </svg>
)

const UltraWideScreenIconSvg = () => (
  <svg {...SHARED_SVG_PROPS}>
    <rect x="1" y="4" width="22" height="12" rx="2" ry="2" />
    <line x1="6" y1="20" x2="18" y2="20" />
    <line x1="12" y1="16" x2="12" y2="20" />
  </svg>
)

const NotSetScreenIconSvg = () => (
  <svg {...SHARED_SVG_PROPS}>
    <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z" />
    <path d="M9 10a3 3 0 1 1 6 0c0 1.31-.839 2.11-2.008 2.389-.538.128-.992.559-.992 1.111" />
    <path strokeWidth={3} d="M12 17.01V17" />
  </svg>
)

const SCREEN_SIZE_SVGS: Record<string, ReactElement> = {
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
}) => SCREEN_SIZE_SVGS[dimensionValue] ?? null
