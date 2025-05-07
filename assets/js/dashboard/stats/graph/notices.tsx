import React from 'react'
import { Tooltip } from '../../util/tooltip'

export const NoticesIcon = ({ notices }: { notices: string[] }) => {
  if (!notices.length) {
    return null
  }
  return (
    <Tooltip
      info={
        <div className="w-[200px] font-normal flex flex-col gap-y-2">
          {notices.map((notice, id) => (
            <p key={id}>{notice}</p>
          ))}
        </div>
      }
      className="cursor-pointer w-4 h-4"
    >
      <svg
        className="absolute w-4 h-4 dark:text-gray-300 text-gray-700"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="2"
          d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
    </Tooltip>
  )
}

export function getSamplingNotice(topStatData: { samplePercent?: number }) {
  const samplePercent = topStatData?.samplePercent

  if (samplePercent && samplePercent < 100) {
    return `Stats based on a ${samplePercent}% sample of all visitors`
  }

  return null
}
