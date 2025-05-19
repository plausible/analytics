import { useCallback, useEffect, useRef, useState } from 'react'

export function useSearchableItems<TItem>({
  data,
  maxItemsInitially,
  itemMatchesSearchValue
}: {
  data: TItem[]
  maxItemsInitially: number
  itemMatchesSearchValue: (t: TItem, trimmedSearchString: string) => boolean
}): {
  data: TItem[]
  filteredData: TItem[]
  showableData: TItem[]
  searchRef: React.RefObject<HTMLInputElement>
  showSearch: boolean
  searching: boolean
  countOfMoreToShow: number
  handleSearchInput: (v: string) => void
  handleClearSearch: () => void
  handleShowAll: () => void
} {
  const searchRef = useRef<HTMLInputElement>(null)
  const [searchValue, setSearch] = useState<string>()
  const [showAll, setShowAll] = useState(false)
  const trimmedSearch = searchValue?.trim()
  const searching = !!trimmedSearch?.length

  useEffect(() => {
    setShowAll(false)
  }, [searching])

  const filteredData = searching
    ? data.filter((item) => itemMatchesSearchValue(item, trimmedSearch))
    : data

  const showableData = showAll
    ? filteredData
    : filteredData.slice(0, maxItemsInitially)

  const handleClearSearch = useCallback(() => {
    if (searchRef.current) {
      searchRef.current.value = ''
      setSearch(undefined)
    }
  }, [])

  return {
    searchRef,
    data,
    filteredData,
    showableData,
    showSearch: data.length > maxItemsInitially,
    searching,
    countOfMoreToShow: filteredData.length - showableData.length,
    handleSearchInput: setSearch,
    handleClearSearch,
    handleShowAll: () => setShowAll(true)
  }
}
