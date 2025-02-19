/* @format */
import React, { createContext, ReactNode, useContext, useState } from 'react'
import {
  RoutelessSegmentModal,
  RoutelessSegmentModals
} from '../segments/routeless-segment-modals'

type ActiveModal = null | RoutelessSegmentModal

const routelessModalsContextDefaultValue: {
  modal: ActiveModal
  setModal: (modal: ActiveModal) => void
} = {
  modal: null,
  setModal: () => {}
}

const RoutelessModalsContext = createContext<
  typeof routelessModalsContextDefaultValue
>(routelessModalsContextDefaultValue)

export const useRoutelessModalsContext = () => {
  return useContext(RoutelessModalsContext)
}

export function RoutelessModalsContextProvider({
  children
}: {
  children: ReactNode
}) {
  const [modal, setModal] = useState<ActiveModal>(
    routelessModalsContextDefaultValue.modal
  )

  return (
    <RoutelessModalsContext.Provider
      value={{
        modal,
        setModal
      }}
    >
      <RoutelessSegmentModals />
      {children}
    </RoutelessModalsContext.Provider>
  )
}
