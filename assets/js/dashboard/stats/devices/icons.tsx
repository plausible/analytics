import React, { ReactNode } from 'react'

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

export const BrowserIcon = ({ dimensionValue }: { dimensionValue: string }) => {
  const filename = BROWSER_ICONS[dimensionValue] ?? 'fallback.svg'
  return (
    <img
      alt=""
      src={`/images/icon/browser/${filename}`}
      className="inline-block w-4 h-4 mr-2"
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

export const OsIcon = ({ dimensionValue }: { dimensionValue: string }) => {
  const filename = OS_ICONS[dimensionValue] ?? 'fallback.svg'
  return (
    <img
      alt=""
      src={`/images/icon/os/${filename}`}
      className="inline-block w-4 h-4 mr-2"
    />
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
  className: '-mt-px feather inline-block'
} as const

export const MobileScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
    <line x1="12" y1="18" x2="12" y2="18" />
  </svg>
)

export const TabletScreenIconSvg = () => (
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

export const LaptopScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
    <line x1="2" y1="20" x2="22" y2="20" />
  </svg>
)

export const DesktopScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
    <line x1="8" y1="21" x2="16" y2="21" />
    <line x1="12" y1="17" x2="12" y2="21" />
  </svg>
)

export const UltraWideScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <rect x="1" y="4" width="22" height="12" rx="2" ry="2" />
    <line x1="6" y1="20" x2="18" y2="20" />
    <line x1="12" y1="16" x2="12" y2="20" />
  </svg>
)

export const NotSetScreenIconSvg = () => (
  <svg {...SHARED_SCREEN_SIZE_SVG_PROPS}>
    <circle cx="12" cy="12" r="10" />
    <circle cx="12" cy="17.25" r="1.25" />
    <path d="M9.244 8.369c.422-1.608 1.733-2.44 3.201-2.364 1.45.075 2.799.872 2.737 2.722-.089 2.63-2.884 2.273-3.197 4.773h.011" />
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
