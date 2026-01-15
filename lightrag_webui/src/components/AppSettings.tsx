import { useState, useEffect } from 'react'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/Popover'
import Button from '@/components/ui/Button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/Select'
import { useSettingsStore } from '@/stores/settings'
import { PaletteIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { cn } from '@/lib/utils'

interface AppSettingsProps {
  className?: string
}

export default function AppSettings({ className }: AppSettingsProps) {
  const [opened, setOpened] = useState<boolean>(false)
  const { t } = useTranslation()

  // We still import the setters to force the state
  const setLanguage = useSettingsStore.use.setLanguage()
  const setTheme = useSettingsStore.use.setTheme()

  // FORCE English and Light mode on mount
  useEffect(() => {
    setLanguage('en')
    setTheme('light')
  }, [setLanguage, setTheme])

  return (
    <Popover open={opened} onOpenChange={setOpened}>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className={cn('h-9 w-9', className)}>
          <PaletteIcon className="h-5 w-5" />
        </Button>
      </PopoverTrigger>
      <PopoverContent side="bottom" align="end" className="w-56">
        <div className="flex flex-col gap-4">
          
          {/* Language Section - Locked to English */}
          <div className="flex flex-col gap-2">
            <label className="text-sm font-medium">{t('settings.language')}</label>
            <Select value="en" disabled>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="en">English</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Theme Section - Locked to Light */}
          <div className="flex flex-col gap-2">
            <label className="text-sm font-medium">{t('settings.theme')}</label>
            <Select value="light" disabled>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="light">{t('settings.light')}</SelectItem>
              </SelectContent>
            </Select>
          </div>

        </div>
      </PopoverContent>
    </Popover>
  )
}