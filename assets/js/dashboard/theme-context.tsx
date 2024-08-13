/* @format */
import React, {
  createContext,
  ReactNode,
  useContext,
  useLayoutEffect,
  useRef,
  useState
} from 'react'

export enum UIMode {
  light = 'light',
  dark = 'dark'
}

const defaultValue = { mode: UIMode.light }

const ThemeContext = createContext(defaultValue)

function parseUIMode(element: Element | null): UIMode {
  return element?.classList.contains('dark') ? UIMode.dark : UIMode.light
}

export default function ThemeContextProvider({
  children
}: {
  children: ReactNode
}) {
  const observerRef = useRef<MutationObserver | null>(null)
  const [mode, setMode] = useState<UIMode>(
    parseUIMode(document.querySelector('html'))
  )
  useLayoutEffect(() => {
    const htmlElement = document.querySelector('html')
    const currentObserver = observerRef.current
    if (htmlElement && !currentObserver) {
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (
            mutation.type === 'attributes' &&
            mutation.attributeName === 'class'
          ) {
            return setMode(parseUIMode(mutation.target as Element))
          }
        })
      })
      observerRef.current = observer
      observer.observe(htmlElement, {
        attributes: true,
        attributeFilter: ['class']
      })
    }
    return () => currentObserver?.disconnect()
  }, [])
  return (
    <ThemeContext.Provider value={{ mode }}>{children}</ThemeContext.Provider>
  )
}

export function useTheme() {
  return useContext(ThemeContext)
}
