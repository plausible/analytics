import React from 'react'
import { Annotation } from './annotations'
import {
  AnnotationAuthorshipLine,
  AnnotationItemRow,
  AnnotationNote,
  AnnotationsListContainer
} from './annotation-list-items'

const MAX_PREVIEW = 2

export const HoverAnnotationsList = ({
  annotations
}: {
  annotations: Annotation[]
}) => {
  const preview = annotations.slice(0, MAX_PREVIEW)
  const extra = annotations.length - MAX_PREVIEW

  return (
    <>
      <AnnotationsListContainer>
        {preview.map((annotation) => (
          <AnnotationItemRow key={annotation.id}>
            <div className="relative flex flex-col gap-y-px w-full max-w-64">
              <AnnotationAuthorshipLine annotation={annotation} />
              <AnnotationNote note={annotation.note} clamp />
            </div>
          </AnnotationItemRow>
        ))}
      </AnnotationsListContainer>
      {extra === 1 && `and 1 more note`}
      {extra > 1 && `and ${extra} more notes`}
    </>
  )
}
