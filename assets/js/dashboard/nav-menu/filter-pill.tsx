import React, {
  ReactNode,
  RefObject,
  useRef,
  useCallback,
  useEffect,
  useMemo,
  useState
} from 'react'
import { createPortal } from 'react-dom'
import { Popover, Transition } from '@headlessui/react'
import { usePopper } from 'react-popper'
import { XMarkIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'
import { popover } from '../components/popover'
import { Filter, FilterClauseLabels, FilterOperator } from '../dashboard-state'
import {
  EVENT_PROPS_PREFIX,
  getPropertyKeyFromFilterKey,
  getSupportedOperations
} from '../util/filters'
import { getFilterTextParts, plainFilterText } from '../util/filter-text'
import {
  useFilterEditorContext,
  FilterEditorPart,
  useMenuButtonRef
} from '../filtering/filter-editor-context'
import { FilterOperatorList } from './filter-operator-list'
import { FilterValuePicker } from './filter-value-picker'

type RenderMenu = (closeMenu: () => void) => ReactNode

export type FilterPillAction =
  | { type: 'edit' }
  | { type: 'menu'; renderMenu: RenderMenu }

export type FilterPillProps = {
  pillKey: string
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
  buttonRef,
  className,
  children
}: {
  open: boolean
  buttonRef: RefObject<HTMLButtonElement>
  className: string
  children: ReactNode
}) => {
  const [panelElement, setPanelElement] = useState<HTMLDivElement | null>(null)
  const anchor = useMemo(
    () => ({
      getBoundingClientRect: () =>
        buttonRef.current?.getBoundingClientRect() ?? new DOMRect()
    }),
    [buttonRef]
  )

  const { styles, attributes, update } = usePopper(anchor, panelElement, {
    placement: 'bottom-start',
    modifiers: [
      { name: 'offset', options: { offset: [-1, 8] } },
      { name: 'preventOverflow', options: { padding: 8 } }
    ]
  })

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
            'max-w-[calc(100vw-1rem)]',
            className
          )}
        >
          {children}
        </Popover.Panel>
      </Transition>
    </div>,
    document.body
  )
}

const OpenState = ({
  open,
  onChange
}: {
  open: boolean
  onChange: (open: boolean) => void
}) => {
  useEffect(() => onChange(open), [open, onChange])
  return null
}

const PillMenu = ({
  className,
  panelClassName,
  label,
  title,
  buttonRef,
  onOpenChange,
  renderMenu,
  children
}: {
  className: string
  panelClassName: string
  label: string
  title?: string
  buttonRef?: RefObject<HTMLButtonElement>
  onOpenChange?: (open: boolean) => void
  renderMenu: RenderMenu
  children: ReactNode
}) => {
  const ownButtonRef = useRef<HTMLButtonElement>(null)
  const ref = buttonRef ?? ownButtonRef

  return (
    <Popover className="flex h-full">
      {({ open, close }) => (
        <>
          {!!onOpenChange && <OpenState open={open} onChange={onOpenChange} />}
          <Popover.Button
            ref={ref}
            className={classNames(className, 'relative')}
            aria-label={label}
            title={title}
            // the dashboard clears all filters on Escape keyup
            onKeyUp={(event: React.KeyboardEvent) => {
              if (event.key === 'Escape') {
                event.stopPropagation()
              }
            }}
          >
            {children}
          </Popover.Button>
          <PillMenuPanel open={open} buttonRef={ref} className={panelClassName}>
            {renderMenu(close)}
          </PillMenuPanel>
        </>
      )}
    </Popover>
  )
}

export function FilterPill({
  pillKey,
  position,
  filter,
  labels,
  action,
  error,
  onRemoveClick
}: FilterPillProps) {
  const editor = useFilterEditorContext()
  const { open: openEditor, close: closeEditor } = editor
  const [openParts, setOpenParts] = useState<FilterEditorPart[]>([])

  const operatorButtonRef = useMenuButtonRef(pillKey, 'operator')
  const valuesButtonRef = useMenuButtonRef(pillKey, 'values')

  const onOpenChange = useCallback(
    (part: FilterEditorPart) => (open: boolean) => {
      if (open) {
        openEditor(position, part)
      }
      setOpenParts((parts) =>
        open ? [...parts, part] : parts.filter((p) => p !== part)
      )
    },
    [openEditor, position]
  )
  const onOperatorOpenChange = useMemo(
    () => onOpenChange('operator'),
    [onOpenChange]
  )
  const onValuesOpenChange = useMemo(
    () => onOpenChange('values'),
    [onOpenChange]
  )

  const isEditing = editor.openPosition === position
  const anyPartOpen = openParts.length > 0

  // deferred, because one part closes before another part of the pill opens
  useEffect(() => {
    if (isEditing && !anyPartOpen) {
      const timeout = setTimeout(closeEditor)
      return () => clearTimeout(timeout)
    }
  }, [isEditing, anyPartOpen, closeEditor])

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

  const onOperationSelect = (
    newOperation: FilterOperator,
    closeMenu: () => void
  ) => {
    const [_operation, filterKey, clauses] = filter
    editor.update([newOperation, filterKey, clauses])
    if (clauses.length) {
      closeMenu()
    } else {
      editor.openMenu(position, 'values')
    }
  }

  const roundedRight = !onRemoveClick && 'rounded-r-md'

  return (
    // focus can move between the menus of a pill without closing them,
    // and opening one menu closes the other
    <Popover.Group
      role="group"
      aria-label={plainText}
      className="flex h-8 shrink-0 items-center rounded-md bg-white border border-gray-200 dark:border-gray-700 dark:bg-gray-800 text-gray-800 dark:text-gray-100 text-sm divide-x divide-gray-200 dark:divide-gray-700"
    >
      <span className={classNames(partClassName, 'rounded-l-md')}>
        {dimensionLabel}
      </span>
      {canChangeOperation ? (
        <PillMenu
          className={buttonPartClassName}
          panelClassName="w-44"
          label={`Change operator: ${plainText}`}
          buttonRef={operatorButtonRef}
          onOpenChange={onOperatorOpenChange}
          renderMenu={(closeMenu) => (
            <FilterOperatorList
              filter={filter}
              onSelect={(newOperation) =>
                onOperationSelect(newOperation, closeMenu)
              }
            />
          )}
        >
          {operation}
        </PillMenu>
      ) : (
        <span className={partClassName}>{operation}</span>
      )}
      {action?.type === 'edit' ? (
        <PillMenu
          className={classNames(buttonPartClassName, roundedRight)}
          panelClassName="w-80"
          label={`Edit filter: ${plainText}`}
          title={plainText}
          buttonRef={valuesButtonRef}
          onOpenChange={onValuesOpenChange}
          renderMenu={(closeMenu) => (
            <FilterValuePicker
              filter={filter}
              labels={labels}
              onChange={editor.update}
              onDone={closeMenu}
            />
          )}
        >
          <PillValues values={values} />
        </PillMenu>
      ) : action?.type === 'menu' ? (
        <PillMenu
          className={classNames(buttonPartClassName, roundedRight)}
          panelClassName="w-72"
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
    </Popover.Group>
  )
}
