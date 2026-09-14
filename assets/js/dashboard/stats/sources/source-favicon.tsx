import React from 'react'
import classNames from 'classnames'
import { useTheme } from '../../theme-context'

interface SourceFaviconProps {
  name: string
  className?: string
}

export const SourceFavicon = ({ name, className }: SourceFaviconProps) => {
  const { mode } = useTheme()
  const sourceName = name.toLowerCase()
  const needsWhiteBg =
    sourceName.includes('github') || sourceName.includes('chatgpt.com')

  return (
    <img
      alt=""
      src={`/favicon/sources/${encodeURIComponent(name)}?ui-mode=${mode}`}
      referrerPolicy="no-referrer"
      className={classNames(
        className,
        needsWhiteBg &&
          'dark:bg-white dark:border dark:border-white dark:rounded-full'
      )}
    />
  )
}
