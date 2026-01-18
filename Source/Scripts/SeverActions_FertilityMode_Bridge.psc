Scriptname SeverActions_FertilityMode_Bridge extends Quest
; Bridges Fertility Mode Reloaded data to SkyrimNet via registered decorators
; Requires: Fertility Mode Reloaded source files (_JSW_BB_Storage.psc, _JSW_BB_Utility.psc) to compile

Actor Property PlayerRef Auto
Bool Property Enabled = True Auto
Float Property UpdateInterval = 3.0 Auto

; Cached references
_JSW_BB_Storage FertStorage
_JSW_BB_Utility FertUtil
Bool bInitialized = True

Event OnInit()
    Maintenance()
EndEvent

Event OnPlayerLoadGame()
    Maintenance()
EndEvent

Event OnUpdate()
    if Enabled && bInitialized
        UpdateNearbyActors()
    endif
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Function Maintenance()
    PlayerRef = Game.GetPlayer()
    
    ; Check if Fertility Mode is installed
    if Game.GetModByName("Fertility Mode.esm") == 255
        Debug.Trace("[SeverActions_FM] Fertility Mode not found")
        return
    endif
    
    ; Get the handler quest from Fertility Mode Reloaded
    ; FormID 0x0D62 is _JSW_BB_HandlerQuest which has BOTH Storage and Utility scripts
    Quest handlerQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !handlerQuest
        Debug.Trace("[SeverActions_FM] Could not find FM handler quest at 0x0D62")
        return
    endif
    
    ; Cast to BOTH script types from the same quest
    FertStorage = handlerQuest as _JSW_BB_Storage
    FertUtil = handlerQuest as _JSW_BB_Utility
    
    if !FertStorage
        Debug.Trace("[SeverActions_FM] Could not cast to _JSW_BB_Storage")
        return
    endif
    
    bInitialized = True
    Debug.Trace("[SeverActions_FM] Initialized successfully")
    
    ; Register for FM events
    RegisterForModEvent("FertilityModeAddSperm", "OnFertilityModeAddSperm")
    RegisterForModEvent("FertilityModeConception", "OnFertilityModeConception")
    
    ; Start the update loop
    RegisterForSingleUpdate(UpdateInterval)
    Debug.Trace("[SeverActions_FM] Update loop started with interval: " + UpdateInterval)
EndFunction

; ============================================================================
; MOD EVENTS
; ============================================================================

Event OnFertilityModeAddSperm(Form akTarget, String fatherName, Form father)
    if !Enabled
        return
    endif
    
    Actor targetActor = akTarget as Actor
    Actor fatherActor = father as Actor
    
    if !targetActor
        return
    endif
    
    String targetName = targetActor.GetDisplayName()
    String actualFatherName = fatherName
    if fatherActor
        actualFatherName = fatherActor.GetDisplayName()
    endif
    
    ; Store insemination data in StorageUtil for prompt access
    StorageUtil.SetStringValue(targetActor, "SkyrimNet_FM_InsemFather", actualFatherName)
    StorageUtil.SetFloatValue(targetActor, "SkyrimNet_FM_InsemTime", Utility.GetCurrentGameTime())
    
    ; Send narration
    String content = "*" + actualFatherName + " releases inside " + targetName + ".*"
    SkyrimNetApi.DirectNarration(content, targetActor, fatherActor)
    
    Debug.Trace("[SeverActions_FM] Insemination: " + actualFatherName + " -> " + targetName)
EndEvent

Event OnFertilityModeConception(String eventName, Form akSender, String motherName, String fatherName, Int trackingIndex)
    if !Enabled
        return
    endif
    
    Actor mother = akSender as Actor
    if mother
        String content = "*" + motherName + " has conceived " + fatherName + "'s child.*"
        SkyrimNetApi.DirectNarration(content, mother, None)
        Debug.Trace("[SeverActions_FM] Conception: " + motherName + " by " + fatherName)
    endif
EndEvent

; ============================================================================
; STORAGEUTIL UPDATE FUNCTIONS - Makes data accessible to prompts
; ============================================================================

Function UpdateActorFertilityData(Actor akActor)
    if !akActor || !bInitialized
        return
    endif
    
    ; Get and store the fertility state
    String fertState = SeverActions_FertilityMode_Bridge.GetFertilityState(akActor)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_State", fertState)
    
    ; Store father name if pregnant
    String fertFather = SeverActions_FertilityMode_Bridge.GetFertilityFather(akActor)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_Father", fertFather)
    
    ; Store pregnant days (now returns String)
    String pregDaysStr = SeverActions_FertilityMode_Bridge.GetPregnantDays(akActor)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_PregnantDays", pregDaysStr)
    
    ; Store cycle day (now returns String)
    String fertCycleDayStr = SeverActions_FertilityMode_Bridge.GetCycleDay(akActor)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_CycleDay", fertCycleDayStr)
    
    ; Store has baby flag (now returns String "true"/"false")
    String hasBabyStr = SeverActions_FertilityMode_Bridge.GetHasBaby(akActor)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_HasBaby", hasBabyStr)
    
    ; Mark as tracked
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_IsTracked", 1)
EndFunction

Function UpdateNearbyActors()
    if !bInitialized || !Enabled
        return
    endif
    
    ; Update player if female
    if PlayerRef.GetActorBase().GetSex() == 1
        UpdateActorFertilityData(PlayerRef)
    endif
    
    ; Update nearby female NPCs using cell scan
    Cell currentCell = PlayerRef.GetParentCell()
    if currentCell
        int numRefs = currentCell.GetNumRefs(43) ; 43 = kActorCharacter
        int i = 0
        while i < numRefs
            Actor npc = currentCell.GetNthRef(i, 43) as Actor
            if npc && npc != PlayerRef && npc.GetActorBase().GetSex() == 1
                if npc.Is3DLoaded()
                    UpdateActorFertilityData(npc)
                endif
            endif
            i += 1
        endwhile
    endif
EndFunction

; ============================================================================
; DECORATOR FUNCTIONS - Called by SkyrimNet prompts
; ============================================================================

String Function GetFertilityState(Actor akActor) Global
    if !akActor
        return "normal"
    endif
    
    ; Only check female actors
    if akActor.GetActorBase().GetSex() != 1
        return "normal"
    endif
    
    ; Check if Fertility Mode is installed
    if Game.GetModByName("Fertility Mode.esm") == 255
        return "normal"
    endif
    
    ; Get storage quest
    Quest storageQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !storageQuest
        return "normal"
    endif
    
    _JSW_BB_Storage storage = storageQuest as _JSW_BB_Storage
    if !storage
        return "normal"
    endif
    
    ; Find actor in tracked array
    int actorIndex = storage.TrackedActors.Find(akActor)
    if actorIndex == -1
        return "normal"
    endif
    
    ; Get current game time for calculations
    float now = Utility.GetCurrentGameTime()
    
    ; Check pregnancy first
    if actorIndex < storage.LastConception.Length && storage.LastConception[actorIndex] > 0.0
        float pregnantDays = now - storage.LastConception[actorIndex]
        float pregnancyDuration = 30.0 ; Default
        
        ; Try to get actual duration from global (FormID 0x000D66)
        GlobalVariable durationGlobal = Game.GetFormFromFile(0x000D66, "Fertility Mode.esm") as GlobalVariable
        if durationGlobal
            pregnancyDuration = durationGlobal.GetValue()
        endif
        
        float progress = (pregnantDays / pregnancyDuration) * 100.0
        
        if progress >= 66.0
            return "third_trimester"
        elseif progress >= 33.0
            return "second_trimester"
        else
            return "first_trimester"
        endif
    endif
    
    ; Check recovery
    if actorIndex < storage.LastBirth.Length && storage.LastBirth[actorIndex] > 0.0
        float daysSinceBirth = now - storage.LastBirth[actorIndex]
        float recoveryDuration = 10.0 ; Default
        
        GlobalVariable recoveryGlobal = Game.GetFormFromFile(0x0058D1, "Fertility Mode.esm") as GlobalVariable
        if recoveryGlobal
            recoveryDuration = recoveryGlobal.GetValue()
        endif
        
        if daysSinceBirth < recoveryDuration
            return "recovery"
        endif
    endif
    
    ; Get cycle day and phase
    int cycleDuration = 28
    int menstruationBegin = 0
    int menstruationEnd = 7
    int ovulationBegin = 8
    int ovulationEnd = 16
    
    ; Try to get actual values from globals (FM Reloaded FormIDs)
    GlobalVariable cycleGlobal = Game.GetFormFromFile(0x000D67, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable mensBeginGlobal = Game.GetFormFromFile(0x000D68, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable mensEndGlobal = Game.GetFormFromFile(0x000D69, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable ovulBeginGlobal = Game.GetFormFromFile(0x000D6A, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable ovulEndGlobal = Game.GetFormFromFile(0x000D6B, "Fertility Mode.esm") as GlobalVariable
    
    if cycleGlobal
        cycleDuration = cycleGlobal.GetValueInt()
    endif
    if mensBeginGlobal
        menstruationBegin = mensBeginGlobal.GetValueInt()
    endif
    if mensEndGlobal
        menstruationEnd = mensEndGlobal.GetValueInt()
    endif
    if ovulBeginGlobal
        ovulationBegin = ovulBeginGlobal.GetValueInt()
    endif
    if ovulEndGlobal
        ovulationEnd = ovulEndGlobal.GetValueInt()
    endif
    
    ; Calculate cycle day
    float lastGameHours = 0.0
    int lastGameHoursDelta = 0
    
    if actorIndex < storage.LastGameHours.Length
        lastGameHours = storage.LastGameHours[actorIndex]
    endif
    if actorIndex < storage.LastGameHoursDelta.Length
        lastGameHoursDelta = storage.LastGameHoursDelta[actorIndex]
    endif
    
    int cycleDay = (Math.Ceiling(lastGameHours + lastGameHoursDelta) as int) % (cycleDuration + 1)
    
    ; Check for ovulation (egg present)
    bool hasEgg = false
    if actorIndex < storage.LastOvulation.Length && storage.LastOvulation[actorIndex] > 0.0
        hasEgg = true
    endif
    
    ; Determine phase
    if cycleDay >= menstruationBegin && cycleDay <= menstruationEnd
        return "menstruating"
    elseif hasEgg || (cycleDay >= ovulationBegin && cycleDay <= ovulationEnd)
        return "ovulating"
    elseif cycleDay > ovulationEnd
        return "pms"
    else
        return "fertile"
    endif
EndFunction

String Function GetFertilityFather(Actor akActor) Global
    if !akActor
        return ""
    endif
    
    if akActor.GetActorBase().GetSex() != 1
        return ""
    endif
    
    if Game.GetModByName("Fertility Mode.esm") == 255
        return ""
    endif
    
    Quest storageQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !storageQuest
        return ""
    endif
    
    _JSW_BB_Storage storage = storageQuest as _JSW_BB_Storage
    if !storage
        return ""
    endif
    
    int actorIndex = storage.TrackedActors.Find(akActor)
    if actorIndex == -1
        return ""
    endif
    
    ; Only return father if pregnant
    if actorIndex < storage.LastConception.Length && storage.LastConception[actorIndex] > 0.0
        if actorIndex < storage.CurrentFather.Length
            return storage.CurrentFather[actorIndex]
        endif
    endif
    
    return ""
EndFunction

String Function GetCycleDay(Actor akActor) Global
    if !akActor
        return "-1"
    endif
    
    if akActor.GetActorBase().GetSex() != 1
        return "-1"
    endif
    
    if Game.GetModByName("Fertility Mode.esm") == 255
        return "-1"
    endif
    
    Quest storageQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !storageQuest
        return "-1"
    endif
    
    _JSW_BB_Storage storage = storageQuest as _JSW_BB_Storage
    if !storage
        return "-1"
    endif
    
    int actorIndex = storage.TrackedActors.Find(akActor)
    if actorIndex == -1
        return "-1"
    endif
    
    int cycleDuration = 28
    GlobalVariable cycleGlobal = Game.GetFormFromFile(0x000D67, "Fertility Mode.esm") as GlobalVariable
    if cycleGlobal
        cycleDuration = cycleGlobal.GetValueInt()
    endif
    
    float lastGameHours = 0.0
    int lastGameHoursDelta = 0
    
    if actorIndex < storage.LastGameHours.Length
        lastGameHours = storage.LastGameHours[actorIndex]
    endif
    if actorIndex < storage.LastGameHoursDelta.Length
        lastGameHoursDelta = storage.LastGameHoursDelta[actorIndex]
    endif
    
    int cycleDay = (Math.Ceiling(lastGameHours + lastGameHoursDelta) as int) % (cycleDuration + 1)
    return cycleDay as String
EndFunction

String Function GetPregnantDays(Actor akActor) Global
    if !akActor
        return "0"
    endif
    
    if akActor.GetActorBase().GetSex() != 1
        return "0"
    endif
    
    if Game.GetModByName("Fertility Mode.esm") == 255
        return "0"
    endif
    
    Quest storageQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !storageQuest
        return "0"
    endif
    
    _JSW_BB_Storage storage = storageQuest as _JSW_BB_Storage
    if !storage
        return "0"
    endif
    
    int actorIndex = storage.TrackedActors.Find(akActor)
    if actorIndex == -1
        return "0"
    endif
    
    if actorIndex < storage.LastConception.Length && storage.LastConception[actorIndex] > 0.0
        float now = Utility.GetCurrentGameTime()
        int days = (now - storage.LastConception[actorIndex]) as int
        return days as String
    endif
    
    return "0"
EndFunction

String Function GetHasBaby(Actor akActor) Global
    if !akActor
        return "false"
    endif
    
    if akActor.GetActorBase().GetSex() != 1
        return "false"
    endif
    
    if Game.GetModByName("Fertility Mode.esm") == 255
        return "false"
    endif
    
    Quest storageQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !storageQuest
        return "false"
    endif
    
    _JSW_BB_Storage storage = storageQuest as _JSW_BB_Storage
    if !storage
        return "false"
    endif
    
    int actorIndex = storage.TrackedActors.Find(akActor)
    if actorIndex == -1
        return "false"
    endif
    
    if actorIndex < storage.BabyAdded.Length && storage.BabyAdded[actorIndex] > 0.0
        float now = Utility.GetCurrentGameTime()
        float daysSinceBaby = now - storage.BabyAdded[actorIndex]
        
        float babyDuration = 7.0
        GlobalVariable babyGlobal = Game.GetFormFromFile(0x00EAA6, "Fertility Mode.esm") as GlobalVariable
        if babyGlobal
            babyDuration = babyGlobal.GetValue()
        endif
        
        if daysSinceBaby < babyDuration
            return "true"
        endif
    endif
    
    return "false"
EndFunction