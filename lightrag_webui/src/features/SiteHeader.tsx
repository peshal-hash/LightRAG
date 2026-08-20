import Button from '@/components/ui/Button'
import { SiteInfo, webuiPrefix } from '@/lib/constants'
import AppSettings from '@/components/AppSettings'
import { TabsList, TabsTrigger } from '@/components/ui/Tabs'
import { useSettingsStore } from '@/stores/settings'
import { useAuthStore } from '@/stores/state'
import { cn } from '@/lib/utils'
import { useTranslation } from 'react-i18next'
import { navigationService } from '@/services/navigation'
import { ZapIcon, GithubIcon, LogOutIcon } from 'lucide-react'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/Tooltip'

interface NavigationTabProps {
  value: string
  currentTab: string
  children: React.ReactNode
}

function NavigationTab({ value, currentTab, children }: NavigationTabProps) {
  return (
    <TabsTrigger
      value={value}
      className={cn(
        'cursor-pointer px-2 py-1 transition-all',
        currentTab === value
          ? '!bg-primary !text-primary-foreground'
          : 'hover:bg-accent/60'
      )}
    >
      {children}
    </TabsTrigger>
  )
}

function TabsNavigation() {
  const currentTab = useSettingsStore.use.currentTab()
  const { t } = useTranslation()

  return (
    // The tab labels are translated, so their combined width is not knowable
    // up front. Allow horizontal scrolling instead of letting them overflow the
    // header on a phone; the scrollbar is hidden so it reads as a plain row.
    <div className="flex h-8 max-w-full self-center overflow-x-auto [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      <TabsList className="h-full w-max gap-1 sm:gap-2">
        <NavigationTab value="documents" currentTab={currentTab}>
          {t('header.documents')}
        </NavigationTab>
        <NavigationTab value="knowledge-graph" currentTab={currentTab}>
          {t('header.knowledgeGraph')}
        </NavigationTab>
        <NavigationTab value="retrieval" currentTab={currentTab}>
          {t('header.retrieval')}
        </NavigationTab>
      </TabsList>
    </div>
  )
}

export default function SiteHeader() {
  const { t } = useTranslation()
  const { isGuestMode, coreVersion, apiVersion, username, webuiTitle, webuiDescription } = useAuthStore()

  const versionDisplay = (coreVersion && apiVersion)
    ? `${coreVersion}/${apiVersion}`
    : null;

  // Check if frontend needs rebuild (apiVersion ends with warning symbol)
  const hasWarning = apiVersion?.endsWith('⚠️');
  const versionTooltip = hasWarning
    ? t('header.frontendNeedsRebuild')
    : versionDisplay ? `v${versionDisplay}` : '';

  const handleLogout = () => {
    navigationService.navigateToLogin();
  }

  return (
    <header className="border-border/40 bg-background/95 supports-[backdrop-filter]:bg-background/60 sticky top-0 z-50 flex h-10 w-full border-b px-2 backdrop-blur sm:px-4">
      {/* Both side rails are currently empty and exist only to keep the tabs
          optically centred. Two fixed 200px rails ate 400px of a 375px phone
          and pushed the tabs off screen, so they only reserve space once there
          is room for it. */}
      <div className="hidden sm:block sm:min-w-[200px]" />

      <div className="flex h-10 min-w-0 flex-1 items-center justify-center">
        <TabsNavigation />
      </div>

      <nav className="hidden items-center justify-end sm:flex sm:w-[200px]">
        <div className="flex items-center gap-2">
        </div>
      </nav>
    </header>
  )
}
