import React from 'react'
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { AppNavigationLink } from '../../navigation/use-app-navigate'

export default function WithImportedSwitch({ tooltipMessage, disabled }) {
  const { query } = useQueryContext()
  const importsSwitchedOn = query.with_imported

  const iconClass = classNames('mt-0.5', {
    'dark:text-gray-300 text-gray-700': importsSwitchedOn,
    'dark:text-gray-500 text-gray-400': !importsSwitchedOn
  })

  return (
    <div tooltip={tooltipMessage} className="w-4 h-4 mx-2">
      <AppNavigationLink
        search={
          disabled
            ? (search) => search
            : (search) => ({ ...search, with_imported: !importsSwitchedOn })
        }
      >
        <BarsArrowUpIcon className={iconClass} />
      </AppNavigationLink>
    </div>
  )
}
