import React, { ReactNode } from 'react'
import { Annotation, canEditAnnotation } from './annotations'
import {
  AnnotationAuthorshipLine,
  AnnotationItemRow,
  AnnotationNote,
  AnnotationsListContainer
} from './annotation-list-items'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import { useUserContext } from '../user-context'
import { PencilIcon } from '../components/icons'

const ScrollableArea = (props: { children: ReactNode }) => (
  <div className="max-h-25 sm:max-h-40 overflow-y-auto overflow-x-hidden -mr-2.5 pr-2.5 [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.600)_transparent]">
    {props.children}
  </div>
)

export const InteractiveAnnotationsList = ({
  annotations,
  isTouchDevice,
  closeTooltip
}: {
  annotations: Annotation[]
  isTouchDevice: boolean
  closeTooltip: () => void
}) => {
  const { setModal } = useRoutelessModalsContext()
  const user = useUserContext()
  const openEdit = (annotation: Annotation) => {
    closeTooltip()
    setModal({ type: 'update-annotation', annotation })
  }

  return (
    <ScrollableArea>
      <AnnotationsListContainer>
        {annotations.map((annotation) => {
          const editable = canEditAnnotation({ type: annotation.type, user })
          const content = (
            <>
              <AnnotationAuthorshipLine annotation={annotation} />
              <AnnotationNote note={annotation.note} />
              {editable && !isTouchDevice && (
                <button
                  aria-label="Edit note"
                  className="absolute top-px right-0 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity text-gray-300 hover:text-gray-100 focus:outline-none"
                  onClick={() => openEdit(annotation)}
                >
                  <PencilIcon className="size-4" />
                </button>
              )}
            </>
          )
          return (
            <AnnotationItemRow key={annotation.id}>
              {editable && isTouchDevice ? (
                <button
                  className="relative flex flex-col gap-y-px w-full max-w-64 text-left focus:outline-none"
                  onClick={() => openEdit(annotation)}
                >
                  {content}
                </button>
              ) : (
                <div className="relative flex flex-col gap-y-px w-full max-w-64">
                  {content}
                </div>
              )}
            </AnnotationItemRow>
          )
        })}
      </AnnotationsListContainer>
    </ScrollableArea>
  )
}
