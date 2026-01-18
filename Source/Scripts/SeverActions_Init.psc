Scriptname SeverActions_Init extends ReferenceAlias
{Initializer script for SeverActions - attach to Player alias on your quest}

; =============================================================================
; PROPERTIES - Set these in CK
; =============================================================================

SeverActions_FertilityMode_Bridge Property FertilityBridge Auto
{Optional - Link to the FM bridge script if using Fertility Mode}

SeverActions_Travel Property TravelSystem Auto
{Optional - Link to the Travel system quest script}

SeverActions_Hotkeys Property HotkeySystem Auto
{Optional - Link to the Hotkeys system for keyboard shortcuts}

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions] OnInit - First time initialization")
    ; Small delay to ensure all quest scripts have run their OnInit first
    Utility.Wait(0.5)
    Initialize(true)
EndEvent

Event OnPlayerLoadGame()
    Debug.Trace("[SeverActions] OnPlayerLoadGame - Save game loaded")
    Initialize(false)
EndEvent

Function Initialize(Bool isFirstInit)
    Debug.Trace("[SeverActions] Initializing SeverActions...")
    
    RegisterDecorators()
    InitializeBridge()
    InitializeTravelSystem(isFirstInit)
    InitializeHotkeySystem()
    SyncMCMSettings()
    
    Debug.Trace("[SeverActions] Initialization complete!")
    Debug.Notification("SeverActions loaded")
EndFunction

; =============================================================================
; HOTKEY SYSTEM INITIALIZATION
; =============================================================================

Function InitializeHotkeySystem()
    Debug.Trace("[SeverActions] Initializing Hotkey System...")
    
    if HotkeySystem
        ; Re-register keys on game load
        HotkeySystem.RegisterKeys()
        Debug.Trace("[SeverActions] Hotkey System initialized successfully")
    else
        ; Try to find it on the owning quest
        Quest myQuest = GetOwningQuest()
        if myQuest
            SeverActions_Hotkeys hotkeys = myQuest as SeverActions_Hotkeys
            if hotkeys
                Debug.Trace("[SeverActions] Found Hotkey System via quest cast")
                hotkeys.RegisterKeys()
            else
                Debug.Trace("[SeverActions] Hotkey System not found (optional)")
            endif
        endif
    endif
EndFunction

; =============================================================================
; TRAVEL SYSTEM INITIALIZATION
; =============================================================================

Function InitializeTravelSystem(Bool isFirstInit)
    Debug.Trace("[SeverActions] Initializing Travel System...")
    
    SeverActions_Travel travel = GetTravelSystem()
    
    If travel
        ; The travel script now handles its own initialization in OnInit/OnPlayerLoadGame
        ; We just need to ensure the database is loaded (safe to call multiple times)
        travel.ForceReloadDatabase()
        
        ; Show status for debugging
        If travel.EnableDebugMessages
            travel.ShowStatus()
        EndIf
        
        Debug.Trace("[SeverActions] Travel System initialized successfully")
    Else
        Debug.Trace("[SeverActions] WARNING: Travel System not found!")
    EndIf
EndFunction

; Helper to get travel system reference
SeverActions_Travel Function GetTravelSystem()
    If TravelSystem
        Return TravelSystem
    EndIf
    
    ; Try to find it on the owning quest
    Quest myQuest = GetOwningQuest()
    If myQuest
        SeverActions_Travel travel = myQuest as SeverActions_Travel
        If travel
            Debug.Trace("[SeverActions] Found Travel System via quest cast")
            Return travel
        EndIf
    EndIf
    
    Return None
EndFunction

; =============================================================================
; BRIDGE INITIALIZATION
; =============================================================================

Function InitializeBridge()
    ; Initialize Fertility Mode bridge if available
    If FertilityBridge
        Debug.Trace("[SeverActions] Calling FertilityBridge.Maintenance()...")
        FertilityBridge.Maintenance()
    Else
        ; Try to find it via GetFormFromFile if property not set
        If Game.GetModByName("Fertility Mode.esm") != 255
            Debug.Trace("[SeverActions] FertilityBridge property not set, trying to find quest...")
            ; The bridge script is on the same quest as this script - get it via self
            Quest myQuest = GetOwningQuest()
            If myQuest
                SeverActions_FertilityMode_Bridge bridge = myQuest as SeverActions_FertilityMode_Bridge
                If bridge
                    Debug.Trace("[SeverActions] Found bridge on quest, initializing...")
                    bridge.Maintenance()
                Else
                    Debug.Trace("[SeverActions] WARNING: Could not cast quest to FertilityBridge")
                EndIf
            EndIf
        EndIf
    EndIf
EndFunction

; =============================================================================
; DECORATOR REGISTRATION
; =============================================================================

Function RegisterDecorators()
    Debug.Trace("[SeverActions] Registering decorators...")
    
    Int result
    
    ; -------------------------------------------------------------------------
    ; AROUSAL DECORATORS
    ; -------------------------------------------------------------------------
    
    ; OSLAroused (if using OSLAroused.esp with native SKSE plugin)
    If Game.GetModByName("OSLAroused.esp") != 255
        result = SkyrimNetApi.RegisterDecorator("get_arousal_state", "SeverActions_Arousal", "GetArousalState")
        Debug.Trace("[SeverActions] get_arousal_state (OSLAroused): " + (result == 0) as String)
    EndIf
    
    ; SLO Aroused NG / OAroused (if using SexLabAroused.esm)
    If Game.GetModByName("SexLabAroused.esm") != 255
        ; Full JSON state
        result = SkyrimNetApi.RegisterDecorator("get_slo_arousal_state", "SeverActions_SLOArousal", "GetSLOArousalState")
        Debug.Trace("[SeverActions] get_slo_arousal_state: " + (result == 0) as String)
        
        ; Simple arousal value (just the number as string)
        result = SkyrimNetApi.RegisterDecorator("get_slo_arousal", "SeverActions_SLOArousal", "GetSLOArousal")
        Debug.Trace("[SeverActions] get_slo_arousal: " + (result == 0) as String)
        
        ; Simple arousal description (just the text)
        result = SkyrimNetApi.RegisterDecorator("get_slo_arousal_desc", "SeverActions_SLOArousal", "GetSLOArousalDesc")
        Debug.Trace("[SeverActions] get_slo_arousal_desc: " + (result == 0) as String)
        
        ; Nakedness check (returns "true" or "false")
        result = SkyrimNetApi.RegisterDecorator("get_slo_is_naked", "SeverActions_SLOArousal", "GetSLOIsNaked")
        Debug.Trace("[SeverActions] get_slo_is_naked: " + (result == 0) as String)
    EndIf
    
    ; -------------------------------------------------------------------------
    ; FERTILITY MODE DECORATORS
    ; -------------------------------------------------------------------------
    
    ; Fertility Mode Reloaded - always register, the functions handle missing FM gracefully
    result = SkyrimNetApi.RegisterDecorator("fertility_state", "SeverActions_FertilityMode_Bridge", "GetFertilityState")
    Debug.Trace("[SeverActions] fertility_state: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_father", "SeverActions_FertilityMode_Bridge", "GetFertilityFather")
    Debug.Trace("[SeverActions] fertility_father: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_cycle_day", "SeverActions_FertilityMode_Bridge", "GetCycleDay")
    Debug.Trace("[SeverActions] fertility_cycle_day: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_pregnant_days", "SeverActions_FertilityMode_Bridge", "GetPregnantDays")
    Debug.Trace("[SeverActions] fertility_pregnant_days: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_has_baby", "SeverActions_FertilityMode_Bridge", "GetHasBaby")
    Debug.Trace("[SeverActions] fertility_has_baby: " + (result == 0) as String)
    Debug.Trace("[SeverActions] Fertility Mode decorators registered")
    
    ; -------------------------------------------------------------------------
    ; OTHER DECORATORS
    ; -------------------------------------------------------------------------
    
    ; Environmental awareness - uses WorldCache for VR performance
    ;result = SkyrimNetApi.RegisterDecorator("get_nearby_objects", "SeverActions_WorldCache", "GetNearbyObjects")
    ;Debug.Trace("[SeverActions] get_nearby_objects: " + (result == 0) as String)
    
    ; Travel System decorators - NOT NEEDED!
    ; The travel system stores state via StorageUtil, which can be read directly
    ; using the native papyrus_util decorator in prompt templates:
    ;   {{ papyrus_util("GetStringValue", actorUUID, "SeverTravel_State", "") }}
    ;   {{ papyrus_util("GetStringValue", actorUUID, "SeverTravel_Destination", "") }}
    ;   {{ papyrus_util("GetFloatValue", actorUUID, "SeverTravel_WaitUntil", 0) }}
    ; Or use the new query functions:
    ;   travel.IsNPCTraveling(actor)
    ;   travel.GetNPCTravelState(actor)  ; returns "", "traveling", or "waiting"
    Debug.Trace("[SeverActions] Travel system uses native papyrus_util decorator")
    
    ; Spell Cast
    ;SkyrimNetApi.RegisterDecorator("get_known_spells", "SeverActions_Magic", "GetKnownSpells")
    
    Debug.Trace("[SeverActions] Decorator registration complete")
EndFunction

; =============================================================================
; MCM SETTINGS SYNC
; =============================================================================

Function SyncMCMSettings()
    Debug.Trace("[SeverActions] Syncing MCM settings...")
    
    SeverActions_MCM mcm = SeverActions_MCM.GetInstance()
    If mcm
        mcm.SyncAllSettings()
        Debug.Trace("[SeverActions] MCM settings synced")
    Else
        Debug.Trace("[SeverActions] MCM not found - using defaults")
    EndIf
EndFunction