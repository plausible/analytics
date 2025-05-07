import React from 'react'
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { Tooltip } from '../../util/tooltip'

export default function WithImportedSwitch({
  tooltipMessage,
  disabled
}: {
  tooltipMessage: string
  disabled?: boolean
}) {
  const { query } = useQueryContext()
  const importsSwitchedOn = query.with_imported

  const iconClass = classNames({
    'dark:text-gray-300 text-gray-700': importsSwitchedOn,
    'dark:text-gray-500 text-gray-400': !importsSwitchedOn
  })

  return (
    <Tooltip
      info={<div className="font-normal truncate">{tooltipMessage}</div>}
      className="w-4 h-4"
    >
      <AppNavigationLink
        search={
          disabled
            ? (search) => search
            : (search) => ({ ...search, with_imported: !importsSwitchedOn })
        }
      >
        <BarsArrowUpIcon className={iconClass} />
      </AppNavigationLink>
    </Tooltip>
  )
}
