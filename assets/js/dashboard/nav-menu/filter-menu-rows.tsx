import { ComponentType, SVGProps } from 'react'
import {
  CheckCircleIcon,
  LinkIcon,
  MapPinIcon,
  StarIcon
} from '@heroicons/react/24/outline'
import {
  BrowserWindowIcon,
  DesktopIcon,
  GlobeIcon,
  RouteIcon,
  ServerIcon,
  TagIcon,
  TargetArrowIcon
} from '../components/icons'
import { FILTER_GROUP_TO_DIMENSIONS, formattedFilters } from '../util/filters'
import { PlausibleSite } from '../site-context'

type IconComponent = ComponentType<SVGProps<SVGSVGElement>>

export type FilterGroupKey = keyof typeof FILTER_GROUP_TO_DIMENSIONS

export type FilterDimension = keyof typeof formattedFilters

export type FilterMenuRow =
  | { kind: 'segments'; key: 'segment'; label: string; Icon: IconComponent }
  | {
      kind: 'item'
      key: FilterGroupKey
      label: string
      dimension: FilterDimension
      Icon: IconComponent
    }
  | {
      kind: 'submenu'
      key: FilterGroupKey
      label: string
      dimensions: FilterDimension[]
      Icon: IconComponent
    }

export type FilterSubmenuRow = Exclude<FilterMenuRow, { kind: 'item' }>

const GROUPS: Record<FilterGroupKey, { label: string; Icon: IconComponent }> = {
  segment: { label: 'Segment', Icon: StarIcon },
  page: { label: 'Page', Icon: LinkIcon },
  hostname: { label: 'Hostname', Icon: GlobeIcon },
  source: { label: 'Source', Icon: RouteIcon },
  utm: { label: 'UTM tags', Icon: TargetArrowIcon },
  location: { label: 'Location', Icon: MapPinIcon },
  screen: { label: 'Screen size', Icon: DesktopIcon },
  browser: { label: 'Browser', Icon: BrowserWindowIcon },
  os: { label: 'Operating system', Icon: ServerIcon },
  goal: { label: 'Goal', Icon: CheckCircleIcon },
  props: { label: 'Property', Icon: TagIcon }
}

export const SEGMENTS_ROW: Extract<FilterMenuRow, { kind: 'segments' }> = {
  kind: 'segments',
  key: 'segment',
  ...GROUPS.segment
}

export function getFilterMenuRows({
  propsAvailable
}: Pick<PlausibleSite, 'propsAvailable'>): FilterMenuRow[] {
  const keys = Object.keys(FILTER_GROUP_TO_DIMENSIONS) as FilterGroupKey[]

  return keys
    .filter(
      (key) => key !== SEGMENTS_ROW.key && (key !== 'props' || propsAvailable)
    )
    .map((key) => {
      const dimensions = FILTER_GROUP_TO_DIMENSIONS[key] as FilterDimension[]

      return dimensions.length > 1
        ? { kind: 'submenu', key, dimensions, ...GROUPS[key] }
        : { kind: 'item', key, dimension: dimensions[0], ...GROUPS[key] }
    })
}
