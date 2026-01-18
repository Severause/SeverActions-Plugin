Scriptname SeverActions_MCM extends SKI_ConfigBase
{MCM Configuration menu for SeverActions - includes hotkey configuration}

; =============================================================================
; SCRIPT REFERENCES - Set in CK or use GetInstance functions
; =============================================================================

SeverActions_Currency Property CurrencyScript Auto
SeverActions_Travel Property TravelScript Auto
SeverActions_Hotkeys Property HotkeyScript Auto
SeverActions_Combat Property CombatScript Auto
SeverActions_Outfit Property OutfitScript Auto

; =============================================================================
; SETTINGS - These mirror the properties in other scripts
; =============================================================================

; Currency Settings
bool Property AllowConjuredGold = true Auto

; Hotkey Settings (stored here, applied to HotkeyScript)
int Property FollowToggleKey = -1 Auto Hidden
int Property DismissAllKey = -1 Auto Hidden
int Property StandUpKey = -1 Auto Hidden
int Property FullCleanupKey = -1 Auto Hidden
int Property UndressKey = -1 Auto Hidden
int Property DressKey = -1 Auto Hidden
int Property TargetMode = 0 Auto Hidden
float Property NearestNPCRadius = 500.0 Auto Hidden

; =============================================================================
; MCM STATE - Option IDs
; =============================================================================

; General page
int OID_Version

; Currency page
int OID_AllowConjuredGold

; Travel page
int OID_ResetTravelSlots
int OID_TravelSlot0
int OID_TravelSlot1
int OID_TravelSlot2
int OID_TravelSlot3
int OID_TravelSlot4
int OID_ActiveSlotCount

; Hotkeys page
int OID_FollowToggleKey
int OID_DismissAllKey
int OID_StandUpKey
int OID_FullCleanupKey
int OID_UndressKey
int OID_DressKey
int OID_TargetMode
int OID_NearestNPCRadius

; Page names
string PAGE_GENERAL = "General"
string PAGE_HOTKEYS = "Hotkeys"
string PAGE_CURRENCY = "Currency"
string PAGE_TRAVEL = "Travel"

; Target mode options
string[] TargetModeOptions

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnConfigInit()
    ModName = "SeverActions"
    
    ; Set current version - increment this when you make MCM changes
    ; Format: major * 100 + minor (e.g., 106 = version 1.06)
    CurrentVersion = 106
    
    Pages = new string[4]
    Pages[0] = PAGE_GENERAL
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_CURRENCY
    Pages[3] = PAGE_TRAVEL
    
    ; Initialize target mode dropdown options
    TargetModeOptions = new string[3]
    TargetModeOptions[0] = "Crosshair Target"
    TargetModeOptions[1] = "Nearest NPC"
    TargetModeOptions[2] = "Last Talked To"
EndEvent

Event OnVersionUpdate(int newVersion)
    ; Called when CurrentVersion is higher than saved version
    Debug.Trace("[SeverActions_MCM] Updating from version " + CurrentVersion + " to " + newVersion)
    
    ; Force page rebuild on any version change
    Pages = new string[4]
    Pages[0] = PAGE_GENERAL
    Pages[1] = PAGE_HOTKEYS
    Pages[2] = PAGE_CURRENCY
    Pages[3] = PAGE_TRAVEL
    
    ; Re-initialize dropdown options
    TargetModeOptions = new string[3]
    TargetModeOptions[0] = "Crosshair Target"
    TargetModeOptions[1] = "Nearest NPC"
    TargetModeOptions[2] = "Last Talked To"
EndEvent

; Force MCM to rebuild - call this on game load
Function ForceMenuRebuild()
    OnConfigInit()
    Debug.Trace("[SeverActions_MCM] Forced menu rebuild")
EndFunction

; Get singleton instance
SeverActions_MCM Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_MCM
EndFunction

; =============================================================================
; PAGE LAYOUT
; =============================================================================

Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    if page == "" || page == PAGE_GENERAL
        DrawGeneralPage()
    elseif page == PAGE_HOTKEYS
        DrawHotkeysPage()
    elseif page == PAGE_CURRENCY
        DrawCurrencyPage()
    elseif page == PAGE_TRAVEL
        DrawTravelPage()
    endif
EndEvent

Function DrawGeneralPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("SeverActions Configuration")
    AddEmptyOption()
    OID_Version = AddTextOption("Version", "1.06")
    AddTextOption("Author", "Severause")
    AddEmptyOption()
    AddTextOption("", "Configure SeverActions modules")
    AddTextOption("", "using the pages on the left.")
    AddEmptyOption()
    AddHeaderOption("Quick Reference")
    AddTextOption("", "Hotkeys - Keyboard shortcuts")
    AddTextOption("", "Currency - Gold/payment settings")
    AddTextOption("", "Travel - NPC travel system")
EndFunction

Function DrawHotkeysPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("Follow System Hotkeys")
    OID_FollowToggleKey = AddKeyMapOption("Toggle Follow", FollowToggleKey)
    OID_DismissAllKey = AddKeyMapOption("Dismiss All Followers", DismissAllKey)
    
    AddEmptyOption()
    AddHeaderOption("Furniture Hotkeys")
    OID_StandUpKey = AddKeyMapOption("Make NPC Stand Up", StandUpKey)
    
    AddEmptyOption()
    AddHeaderOption("Combat Hotkeys")
    OID_FullCleanupKey = AddKeyMapOption("Full Cleanup (Reset NPC)", FullCleanupKey)
    
    AddEmptyOption()
    AddHeaderOption("Outfit Hotkeys")
    OID_UndressKey = AddKeyMapOption("Undress NPC", UndressKey)
    OID_DressKey = AddKeyMapOption("Dress NPC", DressKey)
    
    AddEmptyOption()
    AddHeaderOption("Target Selection")
    OID_TargetMode = AddMenuOption("Target Mode", TargetModeOptions[TargetMode])
    
    ; Only show radius option if using Nearest NPC mode
    if TargetMode == 1
        OID_NearestNPCRadius = AddSliderOption("Search Radius", NearestNPCRadius, "{0} units")
    else
        OID_NearestNPCRadius = AddTextOption("Search Radius", "N/A (using " + TargetModeOptions[TargetMode] + ")")
    endif
    
    ; Show hotkey script status
    AddEmptyOption()
    AddHeaderOption("Status")
    if HotkeyScript
        if HotkeyScript.IsRegistered
            AddTextOption("Hotkey System", "Active", OPTION_FLAG_DISABLED)
        else
            AddTextOption("Hotkey System", "Not Registered", OPTION_FLAG_DISABLED)
        endif
    else
        AddTextOption("Hotkey System", "ERROR: Script not linked!", OPTION_FLAG_DISABLED)
    endif
EndFunction

Function DrawCurrencyPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("Gold Settings")
    OID_AllowConjuredGold = AddToggleOption("Allow Conjured Gold", AllowConjuredGold)
    AddTextOption("", "When enabled, NPCs can give gold")
    AddTextOption("", "even if they don't have any.")
    AddEmptyOption()
    AddTextOption("", "Disable for more realistic economy")
    AddTextOption("", "where NPCs need actual gold to give.")
EndFunction

Function DrawTravelPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    
    AddHeaderOption("Travel Slot Status")
    
    If TravelScript
        Int activeCount = TravelScript.GetActiveTravelCount()
        OID_ActiveSlotCount = AddTextOption("Active Slots", activeCount + " / 5")
        AddEmptyOption()
        
        ; Show each slot's status - clickable to clear if active
        OID_TravelSlot0 = AddTextOption("Slot 0", TravelScript.GetSlotStatusText(0))
        OID_TravelSlot1 = AddTextOption("Slot 1", TravelScript.GetSlotStatusText(1))
        OID_TravelSlot2 = AddTextOption("Slot 2", TravelScript.GetSlotStatusText(2))
        OID_TravelSlot3 = AddTextOption("Slot 3", TravelScript.GetSlotStatusText(3))
        OID_TravelSlot4 = AddTextOption("Slot 4", TravelScript.GetSlotStatusText(4))
        
        AddEmptyOption()
        AddTextOption("", "Click a slot to clear it.")
        
        AddEmptyOption()
        AddHeaderOption("Maintenance")
        OID_ResetTravelSlots = AddTextOption("Reset All Travel Slots", "CLICK")
        AddTextOption("", "Use if slots are stuck or broken.")
    Else
        AddTextOption("", "Travel script not connected!")
        AddTextOption("", "Set TravelScript property in CK.")
    EndIf
EndFunction

; =============================================================================
; OPTION SELECTION
; =============================================================================

Event OnOptionSelect(int option)
    if option == OID_AllowConjuredGold
        AllowConjuredGold = !AllowConjuredGold
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        ApplyCurrencySettings()
        
    elseif option == OID_ResetTravelSlots
        bool confirm = ShowMessage("This will cancel ALL active NPC travel, restore follower status, and reset all slots. Continue?", true, "Yes", "No")
        if confirm && TravelScript
            TravelScript.ForceResetAllSlots(true)
            ForcePageReset()
        endif
        
    elseif option == OID_TravelSlot0
        ClearTravelSlotWithConfirm(0)
    elseif option == OID_TravelSlot1
        ClearTravelSlotWithConfirm(1)
    elseif option == OID_TravelSlot2
        ClearTravelSlotWithConfirm(2)
    elseif option == OID_TravelSlot3
        ClearTravelSlotWithConfirm(3)
    elseif option == OID_TravelSlot4
        ClearTravelSlotWithConfirm(4)
    endif
EndEvent

Function ClearTravelSlotWithConfirm(Int slotIndex)
    {Clear a travel slot with user confirmation}
    Int slotState
    String statusText
    String confirmMsg
    Bool doConfirm
    
    If !TravelScript
        Return
    EndIf
    
    ; Check if slot is active
    slotState = TravelScript.GetSlotState(slotIndex)
    If slotState == 0
        ShowMessage("This slot is already empty.", false)
        Return
    EndIf
    
    statusText = TravelScript.GetSlotStatusText(slotIndex)
    confirmMsg = "Clear slot " + slotIndex + "? " + statusText + " This will cancel travel and restore follower status if applicable."
    doConfirm = ShowMessage(confirmMsg, true, "Yes", "No")
    
    If doConfirm
        TravelScript.ClearSlotFromMCM(slotIndex, true)
        ForcePageReset()
    EndIf
EndFunction

; =============================================================================
; KEYMAP HANDLING
; =============================================================================

Event OnOptionKeyMapChange(int option, int keyCode, string conflictControl, string conflictName)
    ; Handle conflict checking
    if conflictControl != ""
        string msg = "This key is already mapped to:\n" + conflictControl
        if conflictName != ""
            msg += " (" + conflictName + ")"
        endif
        msg += "\n\nAre you sure you want to use this key?"
        
        if !ShowMessage(msg, true, "Yes", "No")
            return
        endif
    endif
    
    if option == OID_FollowToggleKey
        FollowToggleKey = keyCode
        SetKeyMapOptionValue(OID_FollowToggleKey, keyCode)
        ApplyHotkeySettings()
        
    elseif option == OID_DismissAllKey
        DismissAllKey = keyCode
        SetKeyMapOptionValue(OID_DismissAllKey, keyCode)
        ApplyHotkeySettings()
        
    elseif option == OID_StandUpKey
        StandUpKey = keyCode
        SetKeyMapOptionValue(OID_StandUpKey, keyCode)
        ApplyHotkeySettings()
        
    elseif option == OID_FullCleanupKey
        FullCleanupKey = keyCode
        SetKeyMapOptionValue(OID_FullCleanupKey, keyCode)
        ApplyHotkeySettings()
        
    elseif option == OID_UndressKey
        UndressKey = keyCode
        SetKeyMapOptionValue(OID_UndressKey, keyCode)
        ApplyHotkeySettings()
        
    elseif option == OID_DressKey
        DressKey = keyCode
        SetKeyMapOptionValue(OID_DressKey, keyCode)
        ApplyHotkeySettings()
    endif
EndEvent

; =============================================================================
; MENU HANDLING (Target Mode dropdown)
; =============================================================================

Event OnOptionMenuOpen(int option)
    if option == OID_TargetMode
        SetMenuDialogStartIndex(TargetMode)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(TargetModeOptions)
    endif
EndEvent

Event OnOptionMenuAccept(int option, int index)
    if option == OID_TargetMode
        TargetMode = index
        SetMenuOptionValue(OID_TargetMode, TargetModeOptions[TargetMode])
        ApplyHotkeySettings()
        ; Force page refresh to show/hide radius slider
        ForcePageReset()
    endif
EndEvent

; =============================================================================
; SLIDER HANDLING
; =============================================================================

Event OnOptionSliderOpen(int option)
    if option == OID_NearestNPCRadius
        SetSliderDialogStartValue(NearestNPCRadius)
        SetSliderDialogDefaultValue(500.0)
        SetSliderDialogRange(100.0, 2000.0)
        SetSliderDialogInterval(50.0)
    endif
EndEvent

Event OnOptionSliderAccept(int option, float value)
    if option == OID_NearestNPCRadius
        NearestNPCRadius = value
        SetSliderOptionValue(OID_NearestNPCRadius, NearestNPCRadius, "{0} units")
        ApplyHotkeySettings()
    endif
EndEvent

; =============================================================================
; OPTION HIGHLIGHTING (Tooltips)
; =============================================================================

Event OnOptionHighlight(int option)
    if option == OID_AllowConjuredGold
        SetInfoText("Allow NPCs to give gold they don't actually have. Useful for rewards and quest payments. Disable for hardcore economy.")
        
    elseif option == OID_ResetTravelSlots
        SetInfoText("Emergency reset: Clears all travel slots and cancels any active NPC travel. Use if travel slots appear stuck or show incorrect status.")
        
    elseif option == OID_TravelSlot0 || option == OID_TravelSlot1 || option == OID_TravelSlot2 || option == OID_TravelSlot3 || option == OID_TravelSlot4
        SetInfoText("Click to clear this travel slot. This will cancel travel for the NPC and restore their follower status if applicable.")
        
    elseif option == OID_FollowToggleKey
        SetInfoText("Hotkey to toggle NPC following. Look at an NPC and press this key to make them follow you or stop following. Also resumes following if they were waiting.")
        
    elseif option == OID_DismissAllKey
        SetInfoText("Hotkey to dismiss ALL followers at once. Useful for quickly clearing all NPCs following you.")
        
    elseif option == OID_StandUpKey
        SetInfoText("Hotkey to make an NPC stand up from furniture. Look at the NPC and press this key to make them get up from chairs, beds, workstations, etc.")
        
    elseif option == OID_FullCleanupKey
        SetInfoText("Hotkey to fully reset an NPC's combat state. Clears surrender status, restores aggression/confidence to normal, and removes all combat flags. Use on stuck NPCs.")
        
    elseif option == OID_UndressKey
        SetInfoText("Hotkey to remove all armor/clothing from an NPC. Items are stored and can be re-equipped with the Dress hotkey.")
        
    elseif option == OID_DressKey
        SetInfoText("Hotkey to re-equip all stored armor/clothing on an NPC. Only works if the NPC was previously undressed with the Undress hotkey.")
        
    elseif option == OID_TargetMode
        SetInfoText("How to select which NPC the hotkey affects:\n- Crosshair: NPC you're looking at\n- Nearest NPC: Closest NPC to you\n- Last Talked To: Last NPC you had dialogue with")
        
    elseif option == OID_NearestNPCRadius
        SetInfoText("Maximum distance (in game units) to search for the nearest NPC. Only used when Target Mode is set to 'Nearest NPC'. Default: 500 units.")
    endif
EndEvent

; =============================================================================
; DEFAULT VALUES
; =============================================================================

Event OnOptionDefault(int option)
    if option == OID_AllowConjuredGold
        AllowConjuredGold = true
        SetToggleOptionValue(OID_AllowConjuredGold, AllowConjuredGold)
        ApplyCurrencySettings()
        
    elseif option == OID_FollowToggleKey
        FollowToggleKey = -1
        SetKeyMapOptionValue(OID_FollowToggleKey, FollowToggleKey)
        ApplyHotkeySettings()
        
    elseif option == OID_DismissAllKey
        DismissAllKey = -1
        SetKeyMapOptionValue(OID_DismissAllKey, DismissAllKey)
        ApplyHotkeySettings()
        
    elseif option == OID_StandUpKey
        StandUpKey = -1
        SetKeyMapOptionValue(OID_StandUpKey, StandUpKey)
        ApplyHotkeySettings()
        
    elseif option == OID_FullCleanupKey
        FullCleanupKey = -1
        SetKeyMapOptionValue(OID_FullCleanupKey, FullCleanupKey)
        ApplyHotkeySettings()
        
    elseif option == OID_UndressKey
        UndressKey = -1
        SetKeyMapOptionValue(OID_UndressKey, UndressKey)
        ApplyHotkeySettings()
        
    elseif option == OID_DressKey
        DressKey = -1
        SetKeyMapOptionValue(OID_DressKey, DressKey)
        ApplyHotkeySettings()
        
    elseif option == OID_TargetMode
        TargetMode = 0
        SetMenuOptionValue(OID_TargetMode, TargetModeOptions[0])
        ApplyHotkeySettings()
        ForcePageReset()
        
    elseif option == OID_NearestNPCRadius
        NearestNPCRadius = 500.0
        SetSliderOptionValue(OID_NearestNPCRadius, 500.0, "{0} units")
        ApplyHotkeySettings()
    endif
EndEvent

; =============================================================================
; APPLY SETTINGS TO SCRIPTS
; =============================================================================

Function ApplyCurrencySettings()
    if CurrencyScript
        CurrencyScript.AllowConjuredGold = AllowConjuredGold
        Debug.Trace("[SeverActions_MCM] Applied currency settings - Conjured Gold: " + AllowConjuredGold)
    else
        Debug.Trace("[SeverActions_MCM] WARNING: CurrencyScript not set!")
    endif
EndFunction

Function ApplyHotkeySettings()
    if HotkeyScript
        ; Update individual keys (handles re-registration)
        HotkeyScript.UpdateFollowToggleKey(FollowToggleKey)
        HotkeyScript.UpdateDismissAllKey(DismissAllKey)
        HotkeyScript.UpdateStandUpKey(StandUpKey)
        HotkeyScript.UpdateFullCleanupKey(FullCleanupKey)
        HotkeyScript.UpdateUndressKey(UndressKey)
        HotkeyScript.UpdateDressKey(DressKey)
        
        ; Update other settings directly
        HotkeyScript.TargetMode = TargetMode
        HotkeyScript.NearestNPCRadius = NearestNPCRadius
        
        Debug.Trace("[SeverActions_MCM] Applied hotkey settings")
        Debug.Trace("[SeverActions_MCM]   FollowToggleKey: " + FollowToggleKey)
        Debug.Trace("[SeverActions_MCM]   DismissAllKey: " + DismissAllKey)
        Debug.Trace("[SeverActions_MCM]   StandUpKey: " + StandUpKey)
        Debug.Trace("[SeverActions_MCM]   FullCleanupKey: " + FullCleanupKey)
        Debug.Trace("[SeverActions_MCM]   UndressKey: " + UndressKey)
        Debug.Trace("[SeverActions_MCM]   DressKey: " + DressKey)
        Debug.Trace("[SeverActions_MCM]   TargetMode: " + TargetMode)
        Debug.Trace("[SeverActions_MCM]   NearestNPCRadius: " + NearestNPCRadius)
    else
        Debug.Trace("[SeverActions_MCM] WARNING: HotkeyScript not set!")
    endif
EndFunction

; Called on game load to sync settings
Function SyncAllSettings()
    ; Force MCM to rebuild pages (fixes version/page issues)
    OnConfigInit()
    
    ApplyCurrencySettings()
    ApplyHotkeySettings()
    Debug.Trace("[SeverActions_MCM] All settings synced and menu rebuilt")
EndFunction