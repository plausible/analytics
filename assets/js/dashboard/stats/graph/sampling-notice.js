import React from "react"

export default function SamplingNotice({topStatData}) {
  const samplePercent = topStatData?.samplePercent
  
  if (samplePercent && samplePercent < 100) {
    return (
      <div tooltip={`Stats based on a ${samplePercent}% sample of all visitors`} className="cursor-pointer w-4 h-4 mx-2">
        <svg className="absolute w-4 h-4 dark:text-gray-300 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
    )
  } else {
    return null
  }
}