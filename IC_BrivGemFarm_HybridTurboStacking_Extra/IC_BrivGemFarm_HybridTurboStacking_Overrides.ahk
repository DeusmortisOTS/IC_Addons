; Overrides IC_BrivGemFarm_Class.TestForSteelBonesStackFarming()
; Overrides IC_BrivGemFarm_Class.ShouldOfflineStack()
; Overrides IC_BrivGemFarm_Class.GetNumStacksFarmed()
; Overrides IC_BrivGemFarm_Class.StackNormal()
class IC_BrivGemFarm_HybridTurboStacking_Class extends IC_BrivGemFarm_Class
{
    static WARDEN_ID := 36
    static MELF_ID := 59
;    BGFHTS_DelayedOffline := false
;    BGFHTS_LastOfflineReset := 0

    ; Stacking offline uses g_BrivUserSettings[ "StackZone" ].
    ; While online uses BGFHTS_MelfMinStackZone.
    TestForSteelBonesStackFarming()
    {
        if (!g_BrivUserSettingsFromAddons[ "BGFHTS_Enabled" ] || this.ShouldOfflineStack())
            return base.TestForSteelBonesStackFarming()
        if (!g_BrivUserSettingsFromAddons[ "BGFHTS_100Melf" ])
            return base.TestForSteelBonesStackFarming()
        ; If no Melf +spawn effect until reset, stack offline.
        range := g_SharedData.BGFHTS_CurrentRunStackRange
        if (range[1] == "" || range[2] == "")
            return base.TestForSteelBonesStackFarming()
        ; Use Melf Min StackZone settings.
        savedStackZone := g_BrivUserSettings[ "StackZone" ]
        g_BrivUserSettings[ "StackZone" ] := g_BrivUserSettingsFromAddons[ "BGFHTS_MelfMinStackZone" ] - 1
        r := base.TestForSteelBonesStackFarming()
        g_BrivUserSettings[ "StackZone" ] := savedStackZone
        return r
    }

    ; Determines if offline stacking is expected with current settings and conditions.
    ShouldOfflineStack()
    {
        if (!g_BrivUserSettingsFromAddons[ "BGFHTS_Enabled" ])
            return base.ShouldOfflineStack()
        ; If no Melf +spawn effect until reset, stack offline.
        range := g_SharedData.BGFHTS_CurrentRunStackRange
        if ((range[1] == "" || range[2] == "") && g_BrivUserSettingsFromAddons[ "BGFHTS_MelfInactiveStrategy" ] == 2)
            return true
        if (!g_BrivUserSettingsFromAddons[ "BGFHTS_MultirunDelayOffline" ])
            return base.ShouldOfflineStack()
        ; Delay offline until last restart for multiple runs.
        shouldOfflineStack := base.ShouldOfflineStack()
        targetStacks := g_BrivUserSettings[ "TargetStacks" ]
        combinedStacks := g_SF.Memory.ReadHasteStacks() + g_SF.Memory.ReadSBStacks()
        if (shouldOfflineStack)
        {
            lastOfflineReset := this.BGFHTS_LastOfflineReset
            resetCount := g_SF.Memory.ReadResetsCount()
            this.BGFHTS_LastOfflineReset := resetCount
            if (!this.BGFHTS_DelayedOffline && combinedStacks >= targetStacks && resetCount != lastOfflineReset)
            {
                this.BGFHTS_DelayedOffline := true
                return false
            }
        }
        if (this.BGFHTS_DelayedOffline && combinedStacks < targetStacks)
        {
            this.BGFHTS_DelayedOffline := false
            return true
        }
        return shouldOfflineStack && !this.BGFHTS_DelayedOffline
    }

    GetNumStacksFarmed(afterReset := false)
    {
        if (!g_BrivUserSettingsFromAddons[ "BGFHTS_Enabled" ])
            return base.GetNumStacksFarmed()
        if (base.ShouldOfflineStack())
            this.ShouldOfflineStack()
        if (afterReset || IC_BrivGemFarm_HybridTurboStacking_Functions.PredictStacksActive)
        {
            stacksAfterReset := IC_BrivGemFarm_HybridTurboStacking_Functions.PredictStacks()
            g_SharedData.BGFHTS_SBStacksPredict := stacksAfterReset
            return stacksAfterReset
        }
        else
            return g_SF.Memory.ReadSBStacks() + 48
    }

    ; Tries to complete the zone before online stacking.
    ; TODO:: Update target stacks if Thellora doesn't have enough stacks for the next run.
    StackNormal(maxOnlineStackTime := 300000)
    {
        if (!g_BrivUserSettingsFromAddons[ "BGFHTS_Enabled" ])
            return base.StackNormal(maxOnlineStackTime)
        ; Melf stacking
        if (g_BrivUserSettingsFromAddons[ "BGFHTS_100Melf" ] && this.BGFHTS_PostponeStacking())
            return 0
        predictStacks := IC_BrivGemFarm_HybridTurboStacking_Functions.PredictStacksActive
        stacks := g_BrivUserSettings[ "AutoCalculateBrivStacks" ] ? g_SF.Memory.ReadSBStacks() : this.GetNumStacksFarmed(predictStacks)
        targetStacks := g_BrivUserSettings[ "AutoCalculateBrivStacks" ] ? (this.TargetStacks - this.LeftoverStacks) : g_BrivUserSettings[ "TargetStacks" ]
        if (this.ShouldAvoidRestack(stacks, targetStacks))
            return
        ; Check if offline stack is needed
        isMelfActive := IC_BrivGemFarm_HybridTurboStacking_Melf.IsCurrentEffectSpawnMore()
        if (this.BGFHTS_DelayedOffline || !isMelfActive && g_BrivUserSettingsFromAddons[ "BGFHTS_MelfInactiveStrategy" ] == 2)
        {
            this.BGFHTS_DelayedOffline := false
            return this.StackRestart()
        }
        if (g_BrivUserSettingsFromAddons[ "BGFHTS_Multirun" ])
            targetStacks := g_BrivUserSettingsFromAddons[ "BGFHTS_MultirunTargetStacks" ]
        g_SF.ToggleAutoProgress( 0, false, true )
        ; Complete the current zone
        completed := g_BrivUserSettingsFromAddons[ "BGFHTS_CompleteOnlineStackZone" ] && this.BGFHTS_WaitForZoneCompleted()
        ; Conditional stack formation
        isMelfActive := IC_BrivGemFarm_HybridTurboStacking_Melf.IsCurrentEffectSpawnMore()
        if (!isMelfActive && g_BrivUserSettingsFromAddons[ "BGFHTS_MelfInactiveStrategy" ] == 1)
        {
            savedFunc := g_SF.Memory.GetFormationByFavorite
            g_SF.Memory["GetFormationByFavorite"] := IC_BrivGemFarm_HybridTurboStacking_Functions.GetFormationByFavoriteRemoveMelf
            modifiedStackFormation := true
        }
        else if (isMelfActive && g_BrivUserSettingsFromAddons[ "BGFHTS_MelfActiveStrategy" ] == 1)
        {
            savedFunc := g_SF.Memory.GetFormationByFavorite
            g_SF.Memory["GetFormationByFavorite"] := IC_BrivGemFarm_HybridTurboStacking_Functions.GetFormationByFavoriteRemoveTatyanaWarden
            modifiedStackFormation := true
        }
        this.StackFarmSetup()
        ; Start online stacking
        StartTime := A_TickCount
        ElapsedTime := 0
        g_SharedData.LoopString := "Stack Normal"
        usedWardenUlt := false
        ; Turn on Briv auto-heal
        autoHeal := g_BrivUserSettingsFromAddons[ "BGFHTS_BrivAutoHeal" ] > 0
        if (autoHeal)
        {
            fncToCallOnTimer := g_SharedData.BGFHTS_TimerFunctionHeal
            SetTimer, %fncToCallOnTimer%, 1000, 0
        }
        ; Haste stacks are taken into account
        if (predictStacks)
        {
            remainder := targetStacks - stacks
            SBStacks := g_SF.Memory.ReadSBStacks()
            while (SBStacks < remainder AND ElapsedTime < maxOnlineStackTime )
            {
                g_SharedData.BGFHTS_Status := "Stacking: " . (stacks + SBStacks ) . "/" . targetStacks
                g_SF.FallBackFromBossZone()
                ; Warden ultimate
                wardenThreshold := g_BrivUserSettingsFromAddons[ "BGFHTS_WardenUltThreshold" ]
                if (!usedWardenUlt && wardenThreshold > 0)
                    usedWardenUlt := this.BGFHTS_TestWardenUltConditions(wardenThreshold)
                Sleep, 30
                ElapsedTime := A_TickCount - StartTime
                SBStacks := g_SF.Memory.ReadSBStacks()
            }
        }
        else
        {
            while ( stacks < targetStacks AND ElapsedTime < maxOnlineStackTime )
            {
                g_SharedData.BGFHTS_Status := "Stacking: " . stacks . "/" . targetStacks
                g_SF.FallBackFromBossZone()
                ; Warden ultimate
                wardenThreshold := g_BrivUserSettingsFromAddons[ "BGFHTS_WardenUltThreshold" ]
                if (!usedWardenUlt && wardenThreshold > 0)
                    usedWardenUlt := this.BGFHTS_TestWardenUltConditions(wardenThreshold)
                Sleep, 30
                ElapsedTime := A_TickCount - StartTime
                stacks := g_BrivUserSettings[ "AutoCalculateBrivStacks" ] ? g_SF.Memory.ReadSBStacks() : this.GetNumStacksFarmed()
            }
        }
        ; Turn off Briv auto-heal
        if (autoHeal)
            SetTimer, %fncToCallOnTimer%, Off
        if ( ElapsedTime >= maxOnlineStackTime)
        {
            if (modifiedStackFormation)
                g_SF.Memory["GetFormationByFavorite"] := savedFunc
            this.RestartAdventure( "Online stacking took too long (> " . (maxOnlineStackTime / 1000) . "s) - z[" . g_SF.Memory.ReadCurrentZone() . "].")
            this.SafetyCheck()
            g_PreviousZoneStartTime := A_TickCount
            return
        }
        ; Update stats
        if (g_BrivUserSettingsFromAddons[ "BGFHTS_100Melf" ])
        {
            g_SharedData.BGFHTS_PreviousStackZone := g_SF.Memory.ReadCurrentZone()
            g_SharedData.BGFHTS_CurrentRunStackRange := ["", ""]
        }
        g_PreviousZoneStartTime := A_TickCount
        ; Go back to z-1 if failed to complete the current zone
        if (g_SF.Memory.ReadQuestRemaining() > 0)
            g_SF.FallBackFromZone()
        g_SF.ToggleAutoProgress( 1, false, true )
        ; StackFarm won't be able to switch back to Q/E from W if the formation on the field isn't the exact
        ; formation saved in the second favorite formationslot.
        g_SF.SetFormation(g_BrivUserSettings)
        if (g_SF.ShouldDashWait())
            g_SF.DoDashWait( Max(g_SF.ModronResetZone - g_BrivUserSettings[ "DashWaitBuffer" ], 0) )
        if (modifiedStackFormation)
            g_SF.Memory["GetFormationByFavorite"] := savedFunc
        ; Update stats
        g_SharedData.BGFHTS_SBStacksPredict := IC_BrivGemFarm_HybridTurboStacking_Functions.PredictStacks()
        g_SharedData.BGFHTS_Status := "Online stacking done"
    }

    BGFHTS_WaitForZoneCompleted(maxTime := 3000)
    {
        g_SF.SetFormation(g_BrivUserSettings)
        highestZone := g_SF.Memory.ReadHighestZone()
        StartTime := A_TickCount
        ElapsedTime := 0
        g_SharedData.BGFHTS_Status := "Stacking: Waiting for transition"
        g_SF.WaitForTransition()
        quest := g_SF.Memory.ReadQuestRemaining()
        while (quest > 0 && ElapsedTime < maxTime)
        {
            quest := g_SF.Memory.ReadQuestRemaining()
            g_SharedData.BGFHTS_Status := "Stacking: Waiting for area completion " . quest
            g_SF.SetFormation(g_BrivUserSettings)
            Sleep, 30
            ElapsedTime := A_TickCount - StartTime
        }
        return ElapsedTime < maxTime
    }

    BGFHTS_TestWardenUltConditions(threshold := 0)
    {
        champID := IC_BrivGemFarm_HybridTurboStacking_Class.WARDEN_ID
        champInWFormation := g_SF.IsChampInFormation(champID, g_SF.Memory.GetFormationByFavorite(2))
        if (champInWFormation && this.BGFHTS_CheckMaxEnemies(threshold))
            return this.BGFHTS_UseWardenUlt()
        return false
    }

    BGFHTS_CheckMaxEnemies(threshold := 0)
    {
        if (threshold == 0 || threshold == "")
            return true
        if (g_SF.Memory.ReadActiveMonstersCount() > threshold)
            return true
        return false
    }

    BGFHTS_UseWardenUlt()
    {
        champID := IC_BrivGemFarm_HybridTurboStacking_Class.WARDEN_ID
        g_SF.DirectedInput(,, "{" . g_SF.GetUltimateButtonByChampID(champID) . "}")
        return true
    }

    BGFHTS_PostponeStacking()
    {
        ; Stack immediately if Briv can't jump anymore.
        if (g_SF.Memory.ReadHasteStacks() < 50)
            return false
        currentZone := g_SF.Memory.ReadCurrentZone()
        ; Stack as soon as possible if not inside range.
        range := g_SharedData.BGFHTS_CurrentRunStackRange
        if (range[1] == "" || range[2] == "")
        {
            ; Offline stack after StackZone has been reached
            if (g_BrivUserSettingsFromAddons[ "BGFHTS_MelfInactiveStrategy" ] == 2)
                return currentZone < g_BrivUserSettings[ "StackZone" ] + 1
            return false
        }
        stackZone := range[1]
        ; Stack immediately to prevent resetting before stacking.
        if (currentZone > IC_BrivGemFarm_HybridTurboStacking_Functions.GetLastSafeStackZone())
            return false
        if (stackZone)
        {
            highestZone := g_SF.Memory.ReadHighestZone()
            mod50Zones := g_BrivUserSettingsFromAddons[ "BGFHTS_PreferredBrivStackZones" ]
            mod50Index := Mod(highestZone, 50) == 0 ? 50 : Mod(highestZone, 50)
            if (mod50Zones[mod50Index] == 0)
                return true
            if (!IC_BrivGemFarm_HybridTurboStacking_Melf.IsCurrentEffectSpawnMore())
                return true
        }
        ; Offline stack after StackZone has been reached
        if (this.BGFHTS_DelayedOffline)
            return currentZone < g_BrivUserSettings[ "StackZone" ] + 1
        return false
    }
}

; Extends IC_SharedData_Class
class IC_BrivGemFarm_HybridTurboStacking_IC_SharedData_Class extends IC_SharedData_Class
{
;    BGFHTS_CurrentRunStackRange := ""
;    BGFHTS_PreviousStackZone := 0
;    BGFHTS_BrivDeaths := 0
;    BGFHTS_BrivHeals := 0
;    BGFHTS_Status := ""
;    BGFHTS_TimerFunction := ""
;    BGFHTS_TimerFunctionHeal := ""
;    BGFHTS_SBStacksPredict := 0
;    BGFHTS_StacksPredictionActive := false

    ; Return true if the class has been updated by the addon.
    ; Returns "" if not properly loaded.
    BGFHTS_Running()
    {
        return g_BrivUserSettingsFromAddons[ "BGFHTS_Enabled" ]
    }

    ; Load settings after "Start Gem Farm" has been clicked.
    BGFHTS_Init()
    {
        this.BGFHTS_BrivDeaths := 0
        this.BGFHTS_BrivHeals := 0
        this.BGFHTS_TimerFunction := ObjBindMethod(this, "BGFHTS_UpdateMelfStackZoneAfterReset")
        this.BGFHTS_TimerFunctionHeal := ObjBindMethod(IC_BrivGemFarm_HybridTurboStacking_Functions, "CheckBrivHealth")
        this.BGFHTS_UpdateSettingsFromFile()
    }

    ; Load settings from the GUI settings file.
    BGFHTS_UpdateSettingsFromFile(fileName := "")
    {
        if (fileName == "")
            fileName := IC_BrivGemFarm_HybridTurboStacking_Functions.SettingsPath
        settings := g_SF.LoadObjectFromJSON(fileName)
        if (!IsObject(settings))
            return false
        g_BrivUserSettingsFromAddons[ "BGFHTS_Enabled" ] := settings.Enabled
        g_BrivUserSettingsFromAddons[ "BGFHTS_CompleteOnlineStackZone" ] := settings.CompleteOnlineStackZone
        g_BrivUserSettingsFromAddons[ "BGFHTS_WardenUltThreshold" ] := settings.WardenUltThreshold
        g_BrivUserSettingsFromAddons[ "BGFHTS_BrivAutoHeal" ] := settings.BrivAutoHeal
        g_BrivUserSettingsFromAddons[ "BGFHTS_Multirun" ] := settings.Multirun
        g_BrivUserSettingsFromAddons[ "BGFHTS_MultirunTargetStacks" ] := settings.MultirunTargetStacks
        g_BrivUserSettingsFromAddons[ "BGFHTS_MultirunDelayOffline" ] := settings.MultirunDelayOffline
        g_BrivUserSettingsFromAddons[ "BGFHTS_100Melf" ] := settings.100Melf
        g_BrivUserSettingsFromAddons[ "BGFHTS_MelfMinStackZone" ] := settings.MelfMinStackZone
        g_BrivUserSettingsFromAddons[ "BGFHTS_MelfMaxStackZone" ] := settings.MelfMaxStackZone
        g_BrivUserSettingsFromAddons[ "BGFHTS_MelfActiveStrategy" ] := settings.MelfActiveStrategy
        g_BrivUserSettingsFromAddons[ "BGFHTS_MelfInactiveStrategy" ] := settings.MelfInactiveStrategy
        mod50Zones := IC_BrivGemFarm_HybridTurboStacking_Functions.GetPreferredBrivStackZones(settings.PreferredBrivStackZones)
        g_BrivUserSettingsFromAddons[ "BGFHTS_PreferredBrivStackZones" ] := mod50Zones
        ; Melf
        fncToCallOnTimer := this.BGFHTS_TimerFunction
        if (settings.Enabled && settings.100Melf)
        {
            SetTimer, %fncToCallOnTimer%, 1000, 0
            this.BGFHTS_UpdateMelfStackZoneAfterReset(true)
        }
        else
            SetTimer, %fncToCallOnTimer%, Off
    }

    BGFHTS_UpdateMelfStackZoneAfterReset(forceUpdate := false)
    {
        static lastResets := 0

        resets := IC_BrivGemFarm_HybridTurboStacking_Functions.ReadResets()
        if (forceUpdate || resets > lastResets || !IsObject(this.BGFHTS_CurrentRunStackRange))
        {
            this.BGFHTS_Status := ""
            this.BGFHTS_CurrentRunStackRange := this.BGFHTS_CheckMelf()
            lastResets := resets
        }
        this.BGFHTS_UpdateStacksPredict()
    }

    BGFHTS_UpdateStacksPredict()
    {
        predictStacks := IC_BrivGemFarm_HybridTurboStacking_Functions.PredictStacksActive
        this.BGFHTS_StacksPredictionActive := predictStacks
        if (predictStacks)
                g_SharedData.BGFHTS_SBStacksPredict := IC_BrivGemFarm_HybridTurboStacking_Functions.PredictStacks()
    }

    BGFHTS_CheckMelf()
    {
        resets := IC_BrivGemFarm_HybridTurboStacking_Functions.ReadResets()
        maxZone := g_SF.Memory.GetModronResetArea() - 1
        currentZone := g_SF.Memory.ReadCurrentZone()
        ; Modron reset happened but currentZone hasn't been reset to 1 yet.
        minZone := (currentZone == -1 || currentZone > maxZone) ? 1 : currentZone
        minZone := Max(minZone, g_BrivUserSettingsFromAddons[ "BGFHTS_MelfMinStackZone" ])
        maxZone := Min(maxZone, g_BrivUserSettingsFromAddons[ "BGFHTS_MelfMaxStackZone" ])
        range := IC_BrivGemFarm_HybridTurboStacking_Melf.GetFirstSpawnMoreEffectRange(, minZone, maxZone)
        this.BGFHTS_CurrentRunStackRange := range ? range : ["", ""]
        return range
    }
}