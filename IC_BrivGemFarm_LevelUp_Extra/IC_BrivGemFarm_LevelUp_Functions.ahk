#include *i %A_LineFile%\..\..\IC_BrivGemFarm_BrivFeatSwap_Extra\IC_BrivGemFarm_BrivFeatSwap_Functions.ahk

; Functions used by this addon
class IC_BrivGemFarm_LevelUp_Functions
{
    static SettingsPath := A_LineFile . "\..\BrivGemFarm_LevelUp_Settings.json"
    static HeroDefsPath := A_LineFile . "\..\Data\HeroDefines.json"
    static Injected := false

    ; Adds IC_BrivGemFarm_LevelUp_Addon.ahk to the startup of the Briv Gem Farm script.
    InjectAddon()
    {
        if (this.Injected)
            return
        splitStr := StrSplit(A_LineFile, "\")
        addonDirLoc := splitStr[(splitStr.Count()-1)]
        addonLoc := "#include *i %A_LineFile%\..\..\" . addonDirLoc . "\IC_BrivGemFarm_LevelUp_Addon.ahk`n"
        FileAppend, %addonLoc%, %g_BrivFarmModLoc%
        if (this.CheckForBrivFeatSwapAddon()) ; Load Briv Feat Swap after this addon
            IC_BrivGemFarm_BrivFeatSwap_Functions.InjectAddon(true)
        this.Injected := true
    }

    ; Returns true if the BrivGemFarm Briv Feat Swap addon is enabled in Addon Management or in the AddOnsIncluded.ahk file
    CheckForBrivFeatSwapAddon()
    {
        static AddOnsIncludedConfigFile := % A_LineFile . "\..\..\AddOnsIncluded.ahk"
        static AddonName := "BrivGemFarm Briv Feat Swap"

        if (IsObject(AM := AddonManagement)) ; Look for enabled BrivGemFarm Briv Feat Swap addon
            for k, v in AM.EnabledAddons
                if (v.Name == AddonName)
                    return true
        if (FileExist(AddOnsIncludedConfigFile)) ; Try in the AddOnsIncluded file
            Loop, Read, %AddOnsIncludedConfigFile%
                if InStr(A_LoopReadLine, "#include *i %A_LineFile%\..\IC_BrivGemFarm_BrivFeatSwap_Extra\IC_BrivGemFarm_BrivFeatSwap_Component.ahk")
                    return true
        return false
    }

    ; Returns true if the two objects have identical key/value pairs
    AreObjectsEqual(obj1 := "", obj2 := "")
    {
        if (obj1.Count() != obj2.Count())
            return false
        for k, v in obj1
        {
            if (IsObject(v) AND !this.AreObjectsEqual(obj2[k], v) OR !IsObject(v) AND obj2[k] != v AND obj2.HasKey(k))
                return false
        }
        return true
    }

    ; Creates a deep clone of an object
    ObjFullyClone(obj)
    {
        nobj := obj.Clone()
        for k,v in nobj
        {
            if IsObject(v)
                nobj[k] := this.ObjFullyClone(v)
        }
        return nobj
    }

    ; Returns the width of DDL accomodating the longest item in list
    DropDownSize(List, Font:="", FontSize:=10, Padding:=24)
    {
        Loop, Parse, List, |
        {
            if Font
                Gui DropDownSize:Font, s%FontSize%, %Font%
            Gui DropDownSize:Add, Text, R1, %A_LoopField%
            GuiControlGet T, DropDownSize:Pos, Static%A_Index%
            TW > X ? X := TW :
        }
        Gui DropDownSize:Destroy
        return X + Padding
    }

    ; Returns the text with added line wraps if a line is longer than maxLength
    ; TODO: Use text width
    WrapText(text, maxLength := 60)
    {
        if (StrLen(text) <= maxLength)
            return Trim(text)
        str := ""
        lineLength := position := 0
        Loop, Parse, text, " `r`n"
        {
            wordLength := StrLen(A_LoopField)
            position += wordLength + 1
            separator := SubStr(text, position, 1)
            if ((lineLength += wordLength) > maxLength) ; Force new line
            {
                str := RTrim(str) . "`n"
                lineLength := wordLength + (separator == " " ? 1 : 0)
            }
            else if (separator == "`n") ; New line
                lineLength := 0
            else ; Space
                lineLength += 1
            str .= A_LoopField . separator
        }
        return Trim(str)
    }

    ; Returns the index of the active monitor of a given window handle
    ; https://www.autohotkey.com/board/topic/94735-get-active-monitor/
    GetMonitor(hwnd := 0) {
    ; If no hwnd is provided, use the Active Window
        if (hwnd)
            WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
        else
            WinGetActiveStats, winTitle, winW, winH, winX, winY

        SysGet, numDisplays, MonitorCount
        SysGet, idxPrimary, MonitorPrimary

        Loop %numDisplays%
        {	SysGet, mon, MonitorWorkArea, %a_index%
        ; Left may be skewed on Monitors past 1
            if (a_index > 1)
                monLeft -= 10
        ; Right overlaps Left on Monitors past 1
            else if (numDisplays > 1)
                monRight -= 10
        ; Tracked based on X. Cannot properly sense on Windows "between" monitors
            if (winX >= monLeft && winX < monRight)
                return %a_index%
        }
    ; Return Primary Monitor if can't sense
        return idxPrimary
    }
}