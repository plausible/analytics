import React, { ReactNode } from 'react'
import classNames from 'classnames'
import {
  Annotation,
  getAnnotationAttribution,
  getAttributionDateLabel
} from './annotations'

export const AnnotationsListContainer = ({
  children
}: {
  children: ReactNode
}) => (
  <div className="text-sm font-normal text-gray-100 flex flex-col gap-2">
    {children}
  </div>
)

const VerticalBar = () => (
  <div className="rounded-xs w-[3px] bg-green-500 shrink-0" />
)

export const AnnotationItemRow = ({ children }: { children: ReactNode }) => (
  <div className="group flex flex-row gap-x-2">
    <VerticalBar />
    {children}
  </div>
)

export const AnnotationAttributionLine = ({
  annotation
}: {
  annotation: Annotation
}) => (
  <div className="flex items-baseline text-xs text-gray-300 pr-8">
    <span className="truncate min-w-0">
      {getAnnotationAttribution(annotation)}
    </span>
    <span className="whitespace-nowrap shrink-0">
      {` • ${getAttributionDateLabel(annotation)}`}
    </span>
  </div>
)

export const AnnotationNote = ({
  note,
  clamp
}: {
  note: string
  clamp?: boolean
}) => (
  <div
    className={classNames(
      'text-left whitespace-pre-wrap [overflow-wrap:anywhere] [word-break:normal]',
      { 'line-clamp-2': clamp }
    )}
  >
    {note}
  </div>
)
