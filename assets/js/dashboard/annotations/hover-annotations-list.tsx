import React from 'react'
import {
  Annotation,
  allAnnotationsAreFromThisExactDatetime
} from './annotations'
import {
  AnnotationAuthorshipLine,
  AnnotationItemRow,
  AnnotationNote,
  AnnotationsListContainer
} from './annotation-list-items'

const MAX_PREVIEW = 2

export const HoverAnnotationsList = ({
  annotationDatetime,
  annotations
}: {
  annotationDatetime: string
  annotations: Annotation[]
}) => {
  const preview = annotations.slice(0, MAX_PREVIEW)
  const extra = annotations.length - MAX_PREVIEW
  const showDateLabel = !allAnnotationsAreFromThisExactDatetime(
    preview,
    annotationDatetime
  )

  return (
    <>
      <AnnotationsListContainer>
        {preview.map((annotation) => (
          <AnnotationItemRow key={annotation.id}>
            <div className="flex flex-col gap-y-px w-full max-w-64">
              <AnnotationAuthorshipLine
                annotation={annotation}
                showDateLabel={showDateLabel}
              />
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
