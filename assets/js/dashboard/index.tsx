import React, { useMemo, useState } from 'react'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations'
import Devices from './stats/devices'
import { TopBar } from './nav-menu/top-bar'
import Behaviours from './stats/behaviours'
import { useQueryContext } from './query-context'
import { isRealTimeDashboard } from './util/filters'
import { Layout, Responsive, WidthProvider, ResizeHandle } from 'react-grid-layout'

const ResponsiveGridLayout = WidthProvider(Responsive);

type Layouts = {
  lg: Layout[];
  md: Layout[];
  sm: Layout[];
  xs: Layout[];
  xxs: Layout[];
};

//NOTE: Here can be problem as ResizeHandle is not exported from react-grid-layout by default, create own type or export it from react-grid-layout
//type ResizeHandle = "se" | "sw" | "ne" | "nw" | "e" | "w" | "n" | "s";
const availableResizers: ResizeHandle[] = ["se"];

const breakpointsConfig: { [key in keyof Layouts]: { columns: number; width: number; height: number } } = {
  lg: { columns: 2, width: 15, height: 15 },
  md: { columns: 2, width: 8, height: 15 },
  sm: { columns: 1, width: 16, height: 15 },
  xs: { columns: 1, width: 12, height: 15 },
  xxs: { columns: 1, width: 8, height: 15 },
};

interface ItemConfig {
  id: string;
  minW?: number;
  minH?: number;
}

const items: ItemConfig[] = [
  { id: "sources", minW: 5, minH: 12 },
  { id: "pages", minW: 5, minH: 12 },
  { id: "locations", minW: 5, minH: 12 },
  { id: "devices", minW: 5, minH: 12 },
];

const generateLayouts = (): Layouts => {
  const layouts = {} as Layouts;

  for (const bp in breakpointsConfig) {
    const config = breakpointsConfig[bp as keyof Layouts];
    layouts[bp as keyof Layouts] = items.map((item, index) => {
      // For single-column layouts, x is always 0, and y increases by the height of each item.
      // For multi-column layouts, x depends on the column position and y on the row.
      const x = config.columns === 1 ? 0 : (index % config.columns) * config.width;
      const y = config.columns === 1 ? index * config.height : Math.floor(index / config.columns) * config.height;
      return {
        i: item.id,
        x,
        y,
        w: config.width,
        h: config.height,
        minW: item.minW,
        minH: item.minH,
        resizeHandles: availableResizers,
      };
    });
  }
  return layouts;
};

function DashboardStats({
  importedDataInView,
  updateImportedDataInView
}: {
  importedDataInView?: boolean
  updateImportedDataInView?: (v: boolean) => void
}) {
  const [layouts, setLayouts] = useState<Layouts>(generateLayouts());
  const onLayoutChange = (_currentLayout: Layout[], allLayouts: Layouts) => {
    setLayouts(allLayouts);
    if (typeof updateImportedDataInView === 'function') {
      updateImportedDataInView(true);
    }
  };

  const statsBoxClass =
    'relative p-4 flex flex-col bg-white dark:bg-gray-825 shadow-xl rounded'

  const dragHandleClass =
    'drag-handle absolute top-0 left-0 right-0 h-5 rounded-t'

  return (
    <>
      <VisitorGraph updateImportedDataInView={updateImportedDataInView} />
      <ResponsiveGridLayout
        className="styles.react-grid-layout layout relative"
        layouts={layouts}
        breakpoints={{ lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 }}
        cols={{ lg: 30, md: 16, sm: 16, xs: 12, xxs: 8 }}
        rowHeight={20}
        onLayoutChange={onLayoutChange}
        isDraggable={true}
        isResizable={true}
        draggableHandle='.drag-handle'
        margin={[15, 15]}
        containerPadding={[0, 25]}
      >
        <div key="sources" className={statsBoxClass}>
          <div className={dragHandleClass}></div>
          <Sources />
        </div>
        <div key="pages" className={statsBoxClass}>
          <div className={dragHandleClass}></div>
          <Pages />
        </div>
        <div key="locations" className={statsBoxClass}>
          <div className={dragHandleClass}></div>
          <Locations />
        </div>
        <div key="devices" className={statsBoxClass}>
          <div className={dragHandleClass}></div>
          <Devices />
        </div>
      </ResponsiveGridLayout>
      <Behaviours importedDataInView={importedDataInView} />
    </>
  )
}

function useIsRealtimeDashboard() {
  const {
    query: { period }
  } = useQueryContext()
  return useMemo(() => isRealTimeDashboard({ period }), [period])
}

function Dashboard() {
  const isRealTimeDashboard = useIsRealtimeDashboard()
  const [importedDataInView, setImportedDataInView] = useState(false)

  return (
    <div className="mb-12">
      <TopBar showCurrentVisitors={!isRealTimeDashboard} />
      <DashboardStats
        importedDataInView={
          isRealTimeDashboard ? undefined : importedDataInView
        }
        updateImportedDataInView={
          isRealTimeDashboard ? undefined : setImportedDataInView
        }
      />
    </div>
  )
}

export default Dashboard;
