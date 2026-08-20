import { useEffect, useState, useCallback, useMemo, useRef, Component, ErrorInfo, ReactNode } from 'react'
// import { MiniMap } from '@react-sigma/minimap'
import { SigmaContainer, useRegisterEvents, useSigma } from '@react-sigma/core'
import { Settings as SigmaSettings } from 'sigma/settings'
import { GraphSearchOption, OptionItem } from '@react-sigma/graph-search'
import { EdgeArrowProgram, NodePointProgram, NodeCircleProgram } from 'sigma/rendering'
import { NodeBorderProgram } from '@sigma/node-border'
import { EdgeCurvedArrowProgram, createEdgeCurveProgram } from '@sigma/edge-curve'

import FocusOnNode from '@/components/graph/FocusOnNode'
import LayoutsControl from '@/components/graph/LayoutsControl'
import GraphControl from '@/components/graph/GraphControl'
// import ThemeToggle from '@/components/ThemeToggle'
import ZoomControl from '@/components/graph/ZoomControl'
import FullScreenControl from '@/components/graph/FullScreenControl'
import Settings from '@/components/graph/Settings'
import GraphSearch from '@/components/graph/GraphSearch'
import GraphLabels from '@/components/graph/GraphLabels'
import PropertiesView from '@/components/graph/PropertiesView'
import SettingsDisplay from '@/components/graph/SettingsDisplay'
import Legend from '@/components/graph/Legend'
import LegendButton from '@/components/graph/LegendButton'

import { useSettingsStore } from '@/stores/settings'
import { useGraphStore } from '@/stores/graph'
import { labelColorDarkTheme, labelColorLightTheme } from '@/lib/constants'

import '@react-sigma/core/lib/style.css'
import '@react-sigma/graph-search/lib/style.css'

// Check whether the browser can create a WebGL rendering context
const canUseWebGL = (): boolean => {
  try {
    const canvas = document.createElement('canvas')
    return !!(
      window.WebGLRenderingContext &&
      (canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
    )
  } catch {
    return false
  }
}

// Error boundary to catch any remaining WebGL runtime errors inside SigmaContainer
class SigmaErrorBoundary extends Component<
  { children: ReactNode; fallback: ReactNode },
  { hasError: boolean }
> {
  state: { hasError: boolean } = { hasError: false }

  static getDerivedStateFromError(): { hasError: boolean } {
    return { hasError: true }
  }
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('SigmaContainer render error:', error, info)
  }
  render() {
    if (this.state.hasError) return this.props.fallback
    return this.props.children
  }
}

// Function to create sigma settings based on theme
const createSigmaSettings = (isDarkTheme: boolean): Partial<SigmaSettings> => ({
  defaultNodeType: 'default',
  defaultEdgeType: 'curvedNoArrow',
  renderEdgeLabels: false,
  edgeProgramClasses: {
    arrow: EdgeArrowProgram,
    curvedArrow: EdgeCurvedArrowProgram,
    curvedNoArrow: createEdgeCurveProgram()
  },
  nodeProgramClasses: {
    default: NodeBorderProgram,
    circel: NodeCircleProgram,
    point: NodePointProgram
  },
  labelGridCellSize: 60,
  labelRenderedSizeThreshold: 12,
  enableEdgeEvents: true,
  labelColor: {
    color: isDarkTheme ? labelColorDarkTheme : labelColorLightTheme,
    attribute: 'labelColor'
  },
  edgeLabelColor: {
    color: isDarkTheme ? labelColorDarkTheme : labelColorLightTheme,
    attribute: 'labelColor'
  },
  edgeLabelSize: 8,
  labelSize: 12
  // minEdgeThickness: 2
  // labelFont: 'Lato, sans-serif'
})

const GraphEvents = () => {
  const registerEvents = useRegisterEvents()
  const sigma = useSigma()
  const [draggedNode, setDraggedNode] = useState<string | null>(null)

  useEffect(() => {
    // Register the events
    registerEvents({
      downNode: (e) => {
        setDraggedNode(e.node)
        sigma.getGraph().setNodeAttribute(e.node, 'highlighted', true)
      },
      // On mouse move, if the drag mode is enabled, we change the position of the draggedNode
      mousemovebody: (e) => {
        if (!draggedNode) return
        // Get new position of node
        const pos = sigma.viewportToGraph(e)
        sigma.getGraph().setNodeAttribute(draggedNode, 'x', pos.x)
        sigma.getGraph().setNodeAttribute(draggedNode, 'y', pos.y)

        // Prevent sigma to move camera:
        e.preventSigmaDefault()
        e.original.preventDefault()
        e.original.stopPropagation()
      },
      // On mouse up, we reset the autoscale and the dragging mode
      mouseup: () => {
        if (draggedNode) {
          setDraggedNode(null)
          sigma.getGraph().removeNodeAttribute(draggedNode, 'highlighted')
        }
      },
      // Disable the autoscale at the first down interaction
      mousedown: (e) => {
        // Only set custom BBox if it's a drag operation (mouse button is pressed)
        const mouseEvent = e.original as MouseEvent;
        if (mouseEvent.buttons !== 0 && !sigma.getCustomBBox()) {
          sigma.setCustomBBox(sigma.getBBox())
        }
      }
    })
  }, [registerEvents, sigma, draggedNode])

  return null
}

const GraphViewer = () => {
  const [isThemeSwitching, setIsThemeSwitching] = useState(false)
  const [webGLSupported] = useState(() => canUseWebGL())
  const sigmaRef = useRef<any>(null)
  const prevTheme = useRef<string>('')

  const selectedNode = useGraphStore.use.selectedNode()
  const focusedNode = useGraphStore.use.focusedNode()
  const moveToSelectedNode = useGraphStore.use.moveToSelectedNode()
  const isFetching = useGraphStore.use.isFetching()

  const showPropertyPanel = useSettingsStore.use.showPropertyPanel()
  const showNodeSearchBar = useSettingsStore.use.showNodeSearchBar()
  const enableNodeDrag = useSettingsStore.use.enableNodeDrag()
  const showLegend = useSettingsStore.use.showLegend()
  const theme = useSettingsStore.use.theme()

  // Memoize sigma settings to prevent unnecessary re-creation
  // Handle 'system' theme by reading the OS preference at memo time
  const memoizedSigmaSettings = useMemo(() => {
    const isDarkTheme =
      theme === 'dark' ||
      (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    return createSigmaSettings(isDarkTheme)
  }, [theme])

  // Initialize sigma settings based on theme with theme switching protection
  useEffect(() => {
    // Detect theme change
    const isThemeChange = prevTheme.current && prevTheme.current !== theme
    if (isThemeChange) {
      setIsThemeSwitching(true)
      console.log('Theme switching detected:', prevTheme.current, '->', theme)

      // Reset theme switching state after a short delay
      const timer = setTimeout(() => {
        setIsThemeSwitching(false)
        console.log('Theme switching completed')
      }, 150)

      return () => clearTimeout(timer)
    }
    prevTheme.current = theme
    console.log('Initialized sigma settings for theme:', theme)
  }, [theme])

  // Clean up sigma instance when component unmounts
  useEffect(() => {
    return () => {
      // TAB is mount twice in vite dev mode, this is a workaround

      const sigma = useGraphStore.getState().sigmaInstance;
      if (sigma) {
        try {
          // Destroy sigma，and clear WebGL context
          sigma.kill();
          useGraphStore.getState().setSigmaInstance(null);
          console.log('Cleared sigma instance on Graphviewer unmount');
        } catch (error) {
          console.error('Error cleaning up sigma instance:', error);
        }
      }
    };
  }, []);

  // Note: There was a useLayoutEffect hook here to set up the sigma instance and graph data,
  // but testing showed it wasn't executing or having any effect, while the backup mechanism
  // in GraphControl was sufficient. This code was removed to simplify implementation

  const onSearchFocus = useCallback((value: GraphSearchOption | null) => {
    if (value === null) useGraphStore.getState().setFocusedNode(null)
    else if (value.type === 'nodes') useGraphStore.getState().setFocusedNode(value.id)
  }, [])

  const onSearchSelect = useCallback((value: GraphSearchOption | null) => {
    if (value === null) {
      useGraphStore.getState().setSelectedNode(null)
    } else if (value.type === 'nodes') {
      useGraphStore.getState().setSelectedNode(value.id, true)
    }
  }, [])

  const autoFocusedNode = useMemo(() => focusedNode ?? selectedNode, [focusedNode, selectedNode])
  const searchInitSelectedNode = useMemo(
    (): OptionItem | null => (selectedNode ? { type: 'nodes', id: selectedNode } : null),
    [selectedNode]
  )

  const webGLFallback = (
    <div className="flex h-full w-full items-center justify-center bg-background text-center p-4">
      <div>
        <p className="font-semibold text-lg mb-2">Graph visualization unavailable</p>
        <p className="text-sm text-muted-foreground">
          WebGL is not supported or has been blocked by your browser or an extension.<br />
          Try disabling privacy extensions (e.g. Privacy Badger, uBlock Origin canvas blocking) or use a different browser.
        </p>
      </div>
    </div>
  )

  if (!webGLSupported) return webGLFallback

  // Always render SigmaContainer but control its visibility with CSS
  return (
    <div className="relative h-full w-full overflow-hidden">
      <SigmaErrorBoundary fallback={webGLFallback}>
      <SigmaContainer
        settings={memoizedSigmaSettings}
        className="!bg-background !size-full overflow-hidden"
        ref={sigmaRef}
      >
        <GraphControl />

        {enableNodeDrag && <GraphEvents />}

        <FocusOnNode node={autoFocusedNode} move={moveToSelectedNode} />

        {/* Stacks the label picker above the search box on a phone (they do
            not fit side by side) and is width-bounded so it cannot run under
            the properties panel pinned to the top right. */}
        <div className="absolute top-2 left-2 right-2 z-10 flex max-w-full flex-col items-stretch gap-2 sm:right-auto sm:max-w-[calc(100%-1rem)] sm:flex-row sm:items-start">
          <GraphLabels />
          {showNodeSearchBar && !isThemeSwitching && (
            <GraphSearch
              value={searchInitSelectedNode}
              onFocus={onSearchFocus}
              onChange={onSearchSelect}
            />
          )}
        </div>

        <div className="bg-background/60 absolute bottom-2 left-2 flex flex-col rounded-xl border-2 backdrop-blur-lg">
          <LayoutsControl />
          <ZoomControl />
          <FullScreenControl />
          <LegendButton />
          <Settings />
          {/* <ThemeToggle /> */}
        </div>

        {/* On a phone the controls above occupy the top strip, so the panel is
            docked to the bottom (clear of the zoom/layout column on the left)
            and capped in height so it never swallows the whole canvas. */}
        {showPropertyPanel && (
          <div className="absolute right-2 bottom-2 left-14 z-10 max-h-[45%] overflow-auto sm:top-2 sm:bottom-auto sm:left-auto sm:max-h-[calc(100%-1rem)]">
            <PropertiesView />
          </div>
        )}

        {/* Hidden on phones: it would sit on top of the properties panel, and
            the canvas is the thing worth seeing at that size. */}
        {showLegend && (
          <div className="absolute bottom-10 right-2 z-0 hidden sm:block">
            <Legend className="bg-background/60 backdrop-blur-lg" />
          </div>
        )}

        {/* <div className="absolute bottom-2 right-2 flex flex-col rounded-xl border-2">
          <MiniMap width="100px" height="100px" />
        </div> */}

        <SettingsDisplay />
      </SigmaContainer>
      </SigmaErrorBoundary>

      {/* Loading overlay - shown when data is loading or theme is switching */}
      {(isFetching || isThemeSwitching) && (
        <div className="absolute inset-0 flex items-center justify-center bg-background/80 z-10">
          <div className="text-center">
            <div className="mb-2 h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto"></div>
            <p>{isThemeSwitching ? 'Switching Theme...' : 'Loading Graph Data...'}</p>
          </div>
        </div>
      )}
    </div>
  )
}

export default GraphViewer
