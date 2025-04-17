import classNames from 'classnames'

const transitionClasses = classNames(
  'transition ease-in-out',
  // Shared closed styles
  'data-[closed]:opacity-0',
  // Entering styles
  'ease-out data-[enter]:duration-100 data-[enter]:data-[closed]:scale-95 data-[enter]:scale-100',
  // Leaving styles
  'ease-in data-[leave]:duration-75 data-[leave]:data-[closed]:scale-95 data-[leave]:scale-100'
)

const transition = {
  props: {},
  classNames: {
    fullwidth: classNames(transitionClasses, 'z-10 absolute left-0 right-0'),
    left: classNames(transitionClasses, 'z-10 absolute left-0'),
    right: classNames(transitionClasses, 'z-10 absolute right-0')
  }
}

const panel = {
  classNames: {
    roundedSheet:
      'focus:outline-none rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200'
  }
}

const toggleButton = {
  classNames: {
    rounded: 'flex items-center rounded text-sm leading-tight h-9',
    shadow:
      'bg-white dark:bg-gray-800 shadow text-gray-800 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900',
    ghost:
      'text-gray-700 dark:text-gray-100 hover:bg-gray-200 dark:hover:bg-gray-900',
    truncatedText: 'truncate block font-medium',
    linkLike:
      'text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600'
  }
}

const items = {
  classNames: {
    navigationLink: classNames(
      'flex items-center justify-between',
      'px-4 py-2 text-sm leading-tight'
    ),
    selectedOption: classNames('data-[selected=true]:font-bold'),
    hoverLink: classNames(
      'hover:bg-gray-100',
      'hover:text-gray-900',
      'dark:hover:bg-gray-900',
      'dark:hover:text-gray-100',

      'focus-within:bg-gray-100',
      'focus-within:text-gray-900',
      'dark:focus-within:bg-gray-900',
      'dark:focus-within:text-gray-100'
    ),
    roundedStartEnd: classNames(
      'first-of-type:rounded-t-md',
      'last-of-type:rounded-b-md'
    ),
    roundedEnd: classNames('last-of-type:rounded-b-md'),
    groupRoundedStartEnd: classNames(
      'group-first-of-type:rounded-t-md',
      'group-last-of-type:rounded-b-md'
    )
  }
}

export const popover = {
  toggleButton,
  panel,
  transition,
  items
}
