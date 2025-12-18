import { useCallback, useState } from 'react'
import { AppNavigationLinkProps } from '../navigation/use-app-navigate'

export function useMoreLinkData() {
  const [listData, setListData] = useState<unknown[] | null>(null)
  const [linkProps, setLinkProps] = useState<AppNavigationLinkProps | null>(
    null
  )
  const [listLoading, setListLoading] = useState(true)

  const onListUpdate = useCallback(
    (
      list: unknown[] | null,
      linkProps: AppNavigationLinkProps | undefined,
      loading: boolean
    ) => {
      setListData(list)
      setLinkProps(linkProps ?? null)
      setListLoading(loading)
    },
    []
  )

  const reset = useCallback(() => {
    setListData(null)
    setLinkProps(null)
    setListLoading(true)
  }, [])

  return { onListUpdate, listData, linkProps, listLoading, reset }
}
