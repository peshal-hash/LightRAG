import { SiteInfo } from '@/lib/constants' // Re-added usage or remove if truly not needed
import AppSettings from '@/components/AppSettings'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/Tabs' // Added Tabs Root
import { useSettingsStore } from '@/stores/settings'
import { useAuthStore } from '@/stores/state'
import { cn } from '@/lib/utils'
import { useTranslation } from 'react-i18next'
import { navigationService } from '@/services/navigation'
import { LogOutIcon } from 'lucide-react' // Kept only used icons
import Button from '@/components/ui/Button' // Needed for Logout
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/Tooltip'

// Removed NavigationTab wrapper as it conflicts with standard Radix Tabs behavior 
// unless deeply customized. Standard TabsTrigger is cleaner here.

function TabsNavigation() {
  const currentTab = useSettingsStore.use.currentTab()
  const setCurrentTab = useSettingsStore.use.setCurrentTab() // You need this setter!
  const { t } = useTranslation()

  return (
    <div className="flex h-8 self-center">
      <Tabs value={currentTab} onValueChange={setCurrentTab}>
        <TabsList className="h-full gap-2">
          <TabsTrigger value="documents" className="px-2 py-1">
            {t('header.documents')}
          </TabsTrigger>
          <TabsTrigger value="knowledge-graph" className="px-2 py-1">
            {t('header.knowledgeGraph')}
          </TabsTrigger>
          <TabsTrigger value="retrieval" className="px-2 py-1">
            {t('header.retrieval')}
          </TabsTrigger>
        </TabsList>
      </Tabs>
    </div>
  )
}

export default function SiteHeader() {
  const { t } = useTranslation()
  // Removed unused isGuestMode, username
  const { coreVersion, apiVersion, webuiTitle, webuiDescription } = useAuthStore()

  const versionDisplay = (coreVersion && apiVersion)
    ? `${coreVersion}/${apiVersion}`
    : null;

  const hasWarning = apiVersion?.endsWith('⚠️');
  const versionTooltip = hasWarning
    ? t('header.frontendNeedsRebuild')
    : versionDisplay ? `v${versionDisplay}` : '';

  const handleLogout = () => {
    navigationService.navigateToLogin();
  }

  return (
    <header className="border-border/40 bg-background/95 supports-[backdrop-filter]:bg-background/60 sticky top-0 z-50 flex h-10 w-full border-b px-4 backdrop-blur">
      
      {/* Left Section: Logo/Title */}
      <div className="min-w-[200px] w-auto flex items-center gap-2">
        {/* Restored SiteInfo (Logo) if you have it, otherwise remove this line */}
        <SiteInfo className="h-6 w-6" /> 
        
        {webuiTitle && (
          <div className="flex items-center">
            {/* Only show pipe if SiteInfo is present, otherwise remove it */}
            <span className="mx-1 text-xs text-gray-500 dark:text-gray-400">|</span>
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="font-medium text-sm cursor-default">
                    {webuiTitle}
                  </span>
                </TooltipTrigger>
                {webuiDescription && (
                  <TooltipContent side="bottom">
                    {webuiDescription}
                  </TooltipContent>
                )}
              </Tooltip>
            </TooltipProvider>
          </div>
        )}
      </div>

      {/* Center Section: Navigation */}
      <div className="flex h-10 flex-1 items-center justify-center">
        <TabsNavigation />
      </div>

      <nav className="w-[200px] flex items-center justify-end gap-2">
        <AppSettings />
      </nav>
    </header>
  )
}