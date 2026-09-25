import React from 'react'

export const GlobeIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M22 12H2M12 22c5.714-5.442 5.714-14.558 0-20M12 22C6.286 16.558 6.286 7.442 12 2"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z"
    />
  </svg>
)

export const FilterIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
      d="M6 12h12M2 5h20M10 19h4"
    />
  </svg>
)

export const RefreshIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 18 18"
    fill="none"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M5.25 9.5L3 7.25L0.75 9.5"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M13.495 13.345C12.3587 14.5226 10.7641 15.25 9 15.25C5.548 15.25 2.75 12.45 2.75 9C2.75 8.4 2.834 7.83003 2.99 7.28003"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M12.75 8.5L15 10.75L17.25 8.5"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M4.50629 4.65564C5.64249 3.48544 7.23658 2.75 8.99998 2.75C12.452 2.75 15.25 5.55 15.25 9C15.25 9.58 15.171 10.14 15.024 10.67"
    />
  </svg>
)

export const PencilIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 18 18"
    fill="none"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="m10.547 4.422 3.031 3.031M2.75 15.25s3.599-.568 4.546-1.515l7.327-7.327a2.142 2.142 0 1 0-3.03-3.03l-7.327 7.327c-.947.947-1.515 4.546-1.515 4.546h0Z"
    />
  </svg>
)

export const TrashIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="m4.75 6.5.905 12.89a2 2 0 0 0 1.995 1.86h8.7a2 2 0 0 0 1.995-1.86L19.25 6.5M3.25 5.75h17.5M8.523 5.583a3.5 3.5 0 0 1 6.951 0"
    />
  </svg>
)

export const QuestionMarkCircleIcon = ({
  className
}: {
  className?: string
}) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeMiterlimit="10"
      strokeWidth="1.5"
      d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeMiterlimit="10"
      strokeWidth="1.5"
      d="M9 10a3 3 0 1 1 6 0c0 1.31-.839 2.11-2.008 2.389-.538.128-.992.559-.992 1.111"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeWidth="2.5"
      d="M12 17.01V17"
    />
  </svg>
)

export const CursorIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="m4.63 3.711 15.23 5.565c.641.235.623 1.148-.028 1.358l-6.97 2.23-2.232 6.971c-.208.65-1.122.67-1.357.028L3.71 4.631a.717.717 0 0 1 .92-.92"
    />
  </svg>
)

export const DocumentIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    className={className}
  >
    <g
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
    >
      <path d="M20.216 8.333h-4.547a1.334 1.334 0 0 1-1.333-1.334V2.47" />
      <path d="M3.668 18.999v-14a2.666 2.666 0 0 1 2.667-2.667h7.448c.353 0 .693.14.942.39l5.219 5.22c.25.25.39.589.39.942v10.115a2.666 2.666 0 0 1-2.666 2.666H6.335A2.666 2.666 0 0 1 3.668 19" />
    </g>
  </svg>
)

export const FolderIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeMiterlimit="10"
      strokeWidth="1.5"
      d="M2 5v13a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7l-3-3H4a2 2 0 0 0-2 2"
    />
  </svg>
)

export const DiamondIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M2.734 9h18.531M3.023 8.164l3.205-3.408c.255-.27.61-.424.984-.424h9.57c.374 0 .73.153.985.424l3.205 3.408c.44.468.48 1.18.093 1.693l-7.99 10.608a1.352 1.352 0 0 1-2.155 0L2.93 9.857a1.31 1.31 0 0 1 .093-1.693"
    />
  </svg>
)

export const TagIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      fill="currentColor"
      d="M8.7 10.2a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M4.8 3.602h6.206a2.4 2.4 0 0 1 1.697.703l6.643 6.643a3.597 3.597 0 0 1 0 5.092l-3.308 3.308a3.6 3.6 0 0 1-5.092 0l-6.643-6.643a2.4 2.4 0 0 1-.703-1.697V4.802a1.2 1.2 0 0 1 1.2-1.2"
    />
  </svg>
)

export const RouteIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M7 4.333h10.166a3.166 3.166 0 1 1 0 6.334H6.833a3.166 3.166 0 1 0 0 6.333h4.833M17.667 19.667a2.667 2.667 0 1 0 0-5.334 2.667 2.667 0 0 0 0 5.334"
    />
  </svg>
)

export const TargetArrowIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="m12 12 4.333-4.333M16.334 7.667l-1-3 3.333-3.334 1 3 3 1-3.333 3.334zM11.677 6.342a5.668 5.668 0 1 0 5.981 5.982"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M12.085 2.334h-.084c-5.339 0-9.667 4.328-9.667 9.666 0 5.339 4.328 9.667 9.667 9.667s9.666-4.328 9.666-9.667v-.085"
    />
  </svg>
)

export const DesktopIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <g
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
    >
      <rect x="2" y="3" width="20" height="14" rx="2" />
      <path d="M8 21h8M12 17v4" />
    </g>
  </svg>
)

export const BrowserWindowIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M4.76 20.64H19.24A2.76 2.76 0 0 0 22 17.883V6.16A2.76 2.76 0 0 0 19.241 3.4H4.76A2.76 2.76 0 0 0 2.001 6.16v11.723a2.76 2.76 0 0 0 2.758 2.759"
    />
    <path
      fill="currentColor"
      d="M5.449 7.883a1.034 1.034 0 1 0 0-2.07 1.034 1.034 0 0 0 0 2.07M8.896 7.883a1.034 1.034 0 1 0 0-2.07 1.034 1.034 0 0 0 0 2.07"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M2 10.296h20"
    />
  </svg>
)

export const ServerIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M4 20.818h16a2 2 0 0 0 2-2v-4.73q0-.18-.032-.355l-2.38-9.087A2 2 0 0 0 17.617 3H6.382a2 2 0 0 0-1.968 1.646l-2.381 9.087a2 2 0 0 0-.032.355v4.73a2 2 0 0 0 2 2M22 13.91H2"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeWidth="2.5"
      d="M6.092 17.328v-.01M10.182 17.328v-.01"
    />
  </svg>
)

export const Spinner = ({ className }: { className?: string }) => (
  <svg
    className={className}
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
  >
    <circle
      className="opacity-25"
      cx="12"
      cy="12"
      r="10"
      stroke="currentColor"
      strokeWidth="4"
    />
    <path
      className="opacity-75"
      fill="currentColor"
      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
    />
  </svg>
)
