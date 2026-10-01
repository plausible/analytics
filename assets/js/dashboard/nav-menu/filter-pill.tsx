import React, {
  ReactNode,
  useCallback,
  useEffect,
  useRef,
  useState
} from 'react'
import { createPortal } from 'react-dom'
import { Popover, Transition } from '@headlessui/react'
import { usePopper } from 'react-popper'
import { XMarkIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'
import { BlurMenuButtonOnEscape, popover } from '../components/popover'
import { Filter, FilterClauseLabels, FilterOperator } from '../dashboard-state'
import {
  EVENT_PROPS_PREFIX,
  getPropertyKeyFromFilterKey,
  getSupportedOperations
} from '../util/filters'
import { getFilterTextParts, plainFilterText } from '../util/filter-text'
import {
  useFilterEditorContext,
  FilterEditorPart
} from '../filtering/filter-editor-context'
import { FilterPillPopover } from './filter-pill-popover'
import { FilterOperatorList } from './filter-operator-list'
import { FilterValuePicker } from './filter-value-picker'

type RenderMenu = (closeMenu: () => void) => ReactNode

export type FilterPillAction =
  | { type: 'edit' }
  | { type: 'menu'; renderMenu: RenderMenu }

export type FilterPillProps = {
  position: number
  filter: Filter
  labels: FilterClauseLabels
  action?: FilterPillAction
  error?: string
  onRemoveClick?: () => void
}

const partClassName = 'flex items-center h-full px-2 whitespace-nowrap'

const buttonPartClassName = classNames(
  partClassName,
  'cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-750 aria-expanded:bg-gray-100 dark:aria-expanded:bg-gray-750'
)

const PillValues = ({
  values,
  error
}: {
  values: string[]
  error?: string
}) => (
  <span
    className={classNames(
      'inline-block max-w-2xs md:max-w-xs truncate',
      !!error && 'text-red-600 dark:text-red-400'
    )}
  >
    {values.length ? (
      values.map((value, index) => (
        <React.Fragment key={index}>
          {index > 0 && (
            <span className="text-gray-500 dark:text-gray-400"> or </span>
          )}
          {value}
        </React.Fragment>
      ))
    ) : (
      <span className="text-gray-500 dark:text-gray-400">Select...</span>
    )}
  </span>
)

const PillMenuPanel = ({
  open,
  buttonElement,
  children
}: {
  open: boolean
  buttonElement: HTMLButtonElement | null
  children: ReactNode
}) => {
  const [panelElement, setPanelElement] = useState<HTMLDivElement | null>(null)

  const { styles, attributes, update } = usePopper(
    buttonElement,
    panelElement,
    {
      placement: 'bottom-start',
      modifiers: [
        { name: 'offset', options: { offset: [-1, 8] } },
        { name: 'preventOverflow', options: { padding: 8 } }
      ]
    }
  )

  // the pill can move while the menu is closed, e.g. when the top bar changes
  useEffect(() => {
    if (open) {
      update?.()
    }
  }, [open, update])

  return createPortal(
    <div
      ref={setPanelElement}
      style={styles.popper}
      {...attributes.popper}
      className="z-20"
    >
      <Transition
        as="div"
        {...popover.transition.props}
        className="origin-top-left"
      >
        <Popover.Panel
          className={classNames(
            popover.panel.classNames.roundedSheet,
            'w-72 max-w-[calc(100vw-1rem)]'
          )}
        >
          {children}
        </Popover.Panel>
      </Transition>
    </div>,
    document.body
  )
}

const PillMenu = ({
  className,
  label,
  renderMenu,
  children
}: {
  className: string
  label: string
  renderMenu: RenderMenu
  children: ReactNode
}) => {
  const buttonRef = useRef<HTMLButtonElement | null>(null)
  const [buttonElement, setButtonElement] = useState<HTMLButtonElement | null>(
    null
  )
  const setButton = useCallback((element: HTMLButtonElement | null) => {
    buttonRef.current = element
    setButtonElement(element)
  }, [])

  return (
    <Popover className="flex h-full">
      {({ open, close }) => (
        <>
          {open && <div className="fixed top-0 left-0 w-full h-full"></div>}
          <BlurMenuButtonOnEscape targetRef={buttonRef} />
          <Popover.Button
            ref={setButton}
            className={classNames(className, 'relative')}
            aria-label={label}
          >
            {children}
          </Popover.Button>
          <PillMenuPanel open={open} buttonElement={buttonElement}>
            {renderMenu(close)}
          </PillMenuPanel>
        </>
      )}
    </Popover>
  )
}

export function FilterPill({
  position,
  filter,
  labels,
  action,
  error,
  onRemoveClick
}: FilterPillProps) {
  const editor = useFilterEditorContext()
  const [containerElement, setContainerElement] =
    useState<HTMLDivElement | null>(null)
  const [operatorButton, setOperatorButton] =
    useState<HTMLButtonElement | null>(null)
  const [valuesButton, setValuesButton] = useState<HTMLButtonElement | null>(
    null
  )

  const { dimension, operation, values } = getFilterTextParts(
    { labels },
    filter
  )
  const plainText = plainFilterText({ labels }, filter)
  const dimensionLabel = filter[1].startsWith(EVENT_PROPS_PREFIX)
    ? getPropertyKeyFromFilterKey(filter[1])
    : dimension
  const canChangeOperation =
    action?.type === 'edit' && getSupportedOperations(filter[1]).length > 1
  const openPart = editor.openPosition === position ? editor.openPart : null

  const toggle = (part: FilterEditorPart) =>
    openPart === part ? editor.close() : editor.open(position, part)

  const closeEditor = useCallback(
    ({ refocus }: { refocus: boolean }) => {
      const anchor =
        editor.openPart === 'operator' ? operatorButton : valuesButton
      editor.close()
      if (refocus) {
        anchor?.focus()
      }
    },
    [editor, operatorButton, valuesButton]
  )

  const onOperationSelect = (newOperation: FilterOperator) => {
    const [_operation, filterKey, clauses] = filter
    editor.update([newOperation, filterKey, clauses])
    if (clauses.length) {
      editor.close()
      operatorButton?.focus()
    } else {
      editor.open(position, 'values')
    }
  }

  const roundedRight = !onRemoveClick && 'rounded-r-md'

  return (
    <div
      ref={setContainerElement}
      role="group"
      aria-label={plainText}
      className="flex h-8 shrink-0 items-center rounded-md bg-white border border-gray-200 dark:border-gray-700 dark:bg-gray-800 text-gray-800 dark:text-gray-100 text-sm divide-x divide-gray-200 dark:divide-gray-700"
    >
      <span className={classNames(partClassName, 'rounded-l-md')}>
        {dimensionLabel}
      </span>
      {canChangeOperation ? (
        <button
          ref={setOperatorButton}
          type="button"
          className={buttonPartClassName}
          aria-label={`Change operator: ${plainText}`}
          aria-expanded={openPart === 'operator'}
          onClick={() => toggle('operator')}
        >
          {operation}
        </button>
      ) : (
        <span className={partClassName}>{operation}</span>
      )}
      {action?.type === 'edit' ? (
        <button
          ref={setValuesButton}
          type="button"
          className={classNames(buttonPartClassName, roundedRight)}
          title={plainText}
          aria-label={`Edit filter: ${plainText}`}
          aria-expanded={openPart === 'values'}
          onClick={() => toggle('values')}
        >
          <PillValues values={values} />
        </button>
      ) : action?.type === 'menu' ? (
        <PillMenu
          className={classNames(buttonPartClassName, roundedRight)}
          label={`Open menu: ${plainText}${error ? ` (${error})` : ''}`}
          renderMenu={action.renderMenu}
        >
          <PillValues values={values} error={error} />
        </PillMenu>
      ) : (
        <span
          className={classNames(partClassName, roundedRight)}
          title={plainText}
        >
          <PillValues values={values} />
        </span>
      )}
      {!!onRemoveClick && (
        <button
          type="button"
          title={`Remove filter: ${plainText}`}
          className="w-7.5 flex items-center justify-center h-full rounded-r-md cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-750"
          onClick={onRemoveClick}
        >
          <XMarkIcon className="size-4" />
        </button>
      )}
      {openPart === 'operator' && (
        <FilterPillPopover
          anchorElement={operatorButton}
          containerElement={containerElement}
          onClose={closeEditor}
          className="w-44"
        >
          <FilterOperatorList filter={filter} onSelect={onOperationSelect} />
        </FilterPillPopover>
      )}
      {openPart === 'values' && (
        <FilterPillPopover
          anchorElement={valuesButton}
          containerElement={containerElement}
          onClose={closeEditor}
          className="w-80 max-w-[calc(100vw-1rem)]"
        >
          <FilterValuePicker
            filter={filter}
            labels={labels}
            onChange={editor.update}
          />
        </FilterPillPopover>
      )}
    </div>
  )
}
