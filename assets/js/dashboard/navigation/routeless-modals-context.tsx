import React, {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useState
} from 'react'
import { RoutelessSegmentModal } from '../segments/routeless-segment-modals'

type ActiveModal = null | RoutelessSegmentModal

const routelessModalsContextDefaultValue: {
  /** List of menu IDs that are open, [] if none are */
  openDropmenus: string[]
  registerDropmenuState: (options: { id: string; isOpen: boolean }) => void
  /** Only one modal can be open at a time, this value shows which is */
  modal: ActiveModal
  setModal: (modal: ActiveModal) => void
} = {
  openDropmenus: [],
  modal: null,
  setModal: () => {},
  registerDropmenuState: () => {}
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
  const [openDropmenus, setOpenDropmenus] = useState<string[]>([])

  const registerDropmenuState = useCallback(
    ({ id, isOpen }: { id: string; isOpen: boolean }) => {
      setOpenDropmenus((prevState) => {
        if (!isOpen) {
          return prevState.filter((i) => i !== id)
        }

        return prevState.includes(id) ? prevState : prevState.concat(id)
      })
    },
    []
  )
  const [modal, setModal] = useState<ActiveModal>(
    routelessModalsContextDefaultValue.modal
  )

  return (
    <RoutelessModalsContext.Provider
      value={{
        openDropmenus,
        registerDropmenuState,
        modal,
        setModal
      }}
    >
      {children}
    </RoutelessModalsContext.Provider>
  )
}
