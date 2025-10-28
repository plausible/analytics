import React from 'react'
import classNames from 'classnames'

interface SourceFaviconProps {
  name: string
  className?: string
}

export const SourceFavicon = ({ name, className }: SourceFaviconProps) => {
  const sourceName = name.toLowerCase()
  const needsWhiteBg =
    sourceName.includes('github') || sourceName.includes('chatgpt.com')

  return (
    <img
      alt=""
      src={`/favicon/sources/${encodeURIComponent(name)}`}
      referrerPolicy="no-referrer"
      className={classNames(
        className,
        needsWhiteBg &&
          'dark:bg-white dark:border dark:border-white dark:rounded-full'
      )}
    />
  )
}
