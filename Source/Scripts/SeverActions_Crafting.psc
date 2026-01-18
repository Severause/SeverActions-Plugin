Scriptname SeverActions_Crafting extends Quest
{Crafting system with JContainers JSON database integration.
Replaces FormLists with a JSON-based item lookup system.}

; =============================================================================
; PROPERTIES - Set in Creation Kit
; =============================================================================

; Packages
Package Property CraftAtForgePackage Auto
{The AI package that makes the NPC use the forge}

Package Property ApproachRecipientPackage Auto
{The AI package that makes the NPC walk to the recipient}

; Aliases for package targeting
ReferenceAlias Property CrafterAlias Auto
{Alias for the NPC doing the crafting - used with forge package}

ReferenceAlias Property ForgeAlias Auto  
{Alias for the target forge}

ReferenceAlias Property CrafterApproachAlias Auto
{Alias for the NPC walking to recipient - used with approach package (separate from CrafterAlias)}

ReferenceAlias Property RecipientAlias Auto
{Alias for who receives the crafted item}

Idle Property IdleGive Auto
{Give item animation}

; Keywords for forge detection
Keyword Property CraftingSmithingForge Auto
{Keyword to identify forge furniture - usually "isBlacksmithForge"}



; =============================================================================
; CONFIGURATION - Tunable via MCM or here
; =============================================================================

float Property CRAFT_TIME = 5.0 Auto
{How long the crafting animation plays}

float Property SEARCH_RADIUS = 2000.0 Auto
{Radius to search for forges (in game units, ~28 meters)}

float Property INTERACTION_DISTANCE = 150.0 Auto
{How close NPC must be to forge to start crafting}

int Property CRAFT_PACKAGE_PRIORITY = 100 Auto
{Priority for craft package - must be higher than dialogue (usually 50-80)}

string Property DATABASE_FOLDER = "Data/SKSE/Plugins/SeverActions/CraftingDB/" Auto
{Folder containing craftable item JSON databases. All .json files in this folder will be loaded and merged.}

; =============================================================================
; INTERNAL VARIABLES
; =============================================================================

int craftableDB = 0          ; JContainers handle to the database
bool isInitialized = false   ; Whether database has been loaded

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    LoadDatabase()
EndEvent

Function LoadDatabase()
    {Load all craftable items databases from the database folder and merge them}
    
    ; Create the master database structure
    craftableDB = JMap.object()
    JMap.setObj(craftableDB, "weapons", JMap.object())
    JMap.setObj(craftableDB, "armor", JMap.object())
    JMap.setObj(craftableDB, "misc", JMap.object())
    
    bool loadedAny = false
    
    ; Try to load from the folder using readFromDirectory
    ; JContainers returns a JMap of {filename: parsed_json_object} pairs
    int fileMap = JValue.readFromDirectory(DATABASE_FOLDER, ".json")
    
    if fileMap != 0 && JValue.isMap(fileMap)
        int fileCount = JMap.count(fileMap)
        Debug.Trace("SeverActions_Crafting: Found " + fileCount + " database files in " + DATABASE_FOLDER)
        
        ; Iterate through the map using nextKey
        string fileName = JMap.nextKey(fileMap)
        while fileName != ""
            Debug.Trace("SeverActions_Crafting: Loading " + fileName)
            
            ; Get the already-parsed JSON object for this file
            int fileDB = JMap.getObj(fileMap, fileName)
            if fileDB != 0
                MergeDatabaseInto(fileDB, craftableDB)
                loadedAny = true
                Debug.Trace("SeverActions_Crafting: Successfully merged " + fileName)
            else
                Debug.Trace("SeverActions_Crafting: Failed to get object for " + fileName)
            endif
            
            fileName = JMap.nextKey(fileMap, fileName)
        endwhile
        
        ; Release the file map (individual file objects are owned by it)
        JValue.release(fileMap)
    else
        Debug.Trace("SeverActions_Crafting: readFromDirectory returned nothing for " + DATABASE_FOLDER)
    endif
    
    ; If folder scan didn't work, try loading known filenames directly
    if !loadedAny
        Debug.Trace("SeverActions_Crafting: Trying direct file paths...")
        
        ; Try common filenames
        string[] tryFiles = new string[6]
        tryFiles[0] = DATABASE_FOLDER + "00_vanilla.json"
        tryFiles[1] = DATABASE_FOLDER + "10_requiem.json"
        tryFiles[2] = DATABASE_FOLDER + "craftable_items.json"
        tryFiles[3] = DATABASE_FOLDER + "vanilla.json"
        tryFiles[4] = "Data/SKSE/Plugins/SeverActions/craftable_items.json"
        tryFiles[5] = "Data/SKSE/Plugins/SeverActions/CraftingDB/00_vanilla.json"
        
        int idx = 0
        while idx < tryFiles.Length
            if tryFiles[idx] != ""
                int fileDB = JValue.readFromFile(tryFiles[idx])
                if fileDB != 0
                    Debug.Trace("SeverActions_Crafting: Successfully loaded " + tryFiles[idx])
                    MergeDatabaseInto(fileDB, craftableDB)
                    JValue.release(fileDB)
                    loadedAny = true
                endif
            endif
            idx += 1
        endwhile
    endif
    
    if !loadedAny
        Debug.Notification("SeverActions: No crafting databases found!")
        Debug.Trace("SeverActions_Crafting: No databases found. Checked folder: " + DATABASE_FOLDER)
        isInitialized = false
        return
    endif
    
    ; Retain the master database so it doesn't get garbage collected
    JValue.retain(craftableDB)
    isInitialized = true
    
    ; Log stats
    int weaponsObj = JMap.getObj(craftableDB, "weapons")
    int armorObj = JMap.getObj(craftableDB, "armor")
    int miscObj = JMap.getObj(craftableDB, "misc")
    
    int weaponCount = JMap.count(weaponsObj)
    int armorCount = JMap.count(armorObj)
    int miscCount = JMap.count(miscObj)
    
    Debug.Trace("SeverActions_Crafting: Database loaded successfully!")
    Debug.Trace("SeverActions_Crafting: " + weaponCount + " weapons, " + armorCount + " armor, " + miscCount + " misc items")
EndFunction

Function MergeDatabaseInto(int sourceDB, int targetDB)
    {Merge a source database into the target database. Later entries override earlier ones.}
    
    ; Merge each category
    MergeCategoryInto(JMap.getObj(sourceDB, "weapons"), JMap.getObj(targetDB, "weapons"))
    MergeCategoryInto(JMap.getObj(sourceDB, "armor"), JMap.getObj(targetDB, "armor"))
    MergeCategoryInto(JMap.getObj(sourceDB, "misc"), JMap.getObj(targetDB, "misc"))
EndFunction

Function MergeCategoryInto(int sourceCategory, int targetCategory)
    {Merge all entries from source category into target category.
    Stores multiple FormIDs per item as an array for fallback support.}
    
    if sourceCategory == 0 || targetCategory == 0
        return
    endif
    
    int keysArray = JMap.allKeys(sourceCategory)
    int keyCount = JArray.count(keysArray)
    
    int idx = 0
    while idx < keyCount
        string keyName = JArray.getStr(keysArray, idx)
        
        ; Skip comment keys (start with underscore)
        if StringUtil.Find(keyName, "_") != 0
            string newValue = JMap.getStr(sourceCategory, keyName)
            
            ; Get or create array for this item
            int formIdArray = JMap.getObj(targetCategory, keyName)
            if formIdArray == 0
                ; First entry for this item - create new array
                formIdArray = JArray.object()
                JMap.setObj(targetCategory, keyName, formIdArray)
            endif
            
            ; Add this FormID to the array (later entries go first for priority)
            JArray.addStr(formIdArray, newValue, 0)
        endif
        
        idx += 1
    endwhile
EndFunction

Function ReloadDatabase()
    {Reload database from disk - useful after editing JSON}
    
    if craftableDB != 0
        JValue.release(craftableDB)
    endif
    
    LoadDatabase()
    Debug.Notification("SeverActions: Crafting database reloaded")
EndFunction

; =============================================================================
; ITEM LOOKUP FUNCTIONS
; =============================================================================

Form Function FindCraftableByName(string itemName)
    {Find a craftable item by name. Searches weapons, armor, then misc.
    Returns None if not found.}
    
    if !isInitialized
        LoadDatabase()
        if !isInitialized
            return None
        endif
    endif
    
    string searchName = StringToLower(itemName)
    
    ; Try exact match first in each category
    Form result = SearchCategory("weapons", searchName)
    if result
        return result
    endif
    
    result = SearchCategory("armor", searchName)
    if result
        return result
    endif
    
    result = SearchCategory("misc", searchName)
    if result
        return result
    endif
    
    ; Try fuzzy search if exact match failed
    result = FuzzySearch(searchName)
    return result
EndFunction

Form Function SearchCategory(string category, string searchName)
    {Search a specific category for an item by name.
    Tries each registered FormID until one succeeds (for mod fallback support).}
    
    int categoryObj = JMap.getObj(craftableDB, category)
    if categoryObj == 0
        return None
    endif
    
    ; Get the array of FormIDs for this item
    int formIdArray = JMap.getObj(categoryObj, searchName)
    if formIdArray == 0
        return None
    endif
    
    ; Try each FormID in order (higher priority mods first)
    int arrayCount = JArray.count(formIdArray)
    int idx = 0
    while idx < arrayCount
        string formIdStr = JArray.getStr(formIdArray, idx)
        Form result = GetFormFromHexString(formIdStr)
        if result
            return result
        endif
        ; Plugin not loaded, try next one
        idx += 1
    endwhile
    
    return None
EndFunction

Form Function FuzzySearch(string searchTerm)
    {Search all categories for partial name matches}
    
    string[] categories = new string[3]
    categories[0] = "weapons"
    categories[1] = "armor"
    categories[2] = "misc"
    
    int idx = 0
    while idx < categories.Length
        Form result = FuzzySearchCategory(categories[idx], searchTerm)
        if result
            return result
        endif
        idx += 1
    endwhile
    
    return None
EndFunction

Form Function FuzzySearchCategory(string category, string searchTerm)
    {Search a category for partial matches. Tries each FormID until one works.}
    
    int categoryObj = JMap.getObj(craftableDB, category)
    if categoryObj == 0
        return None
    endif
    
    ; Get all keys in this category
    int keysArray = JMap.allKeys(categoryObj)
    int keyCount = JArray.count(keysArray)
    
    ; Search for partial match
    int idx = 0
    while idx < keyCount
        string keyName = JArray.getStr(keysArray, idx)
        
        ; Check if search term is contained in the key
        if StringUtil.Find(keyName, searchTerm) >= 0
            ; Get the array of FormIDs for this item
            int formIdArray = JMap.getObj(categoryObj, keyName)
            if formIdArray != 0
                ; Try each FormID until one works
                int formCount = JArray.count(formIdArray)
                int formIdx = 0
                while formIdx < formCount
                    string formIdStr = JArray.getStr(formIdArray, formIdx)
                    Form result = GetFormFromHexString(formIdStr)
                    if result
                        return result
                    endif
                    formIdx += 1
                endwhile
            endif
        endif
        
        idx += 1
    endwhile
    
    return None
EndFunction

Form Function GetFormFromHexString(string hexString)
    {Convert a hex string like "Skyrim.esm|0x00012EB7" to a Form.
    Returns None if the plugin isn't loaded or form doesn't exist.}
    
    ; Expected format: "PluginName.esp|0x00012EB7" or just "0x00012EB7"
    
    int pipeIndex = StringUtil.Find(hexString, "|")
    
    if pipeIndex >= 0
        ; Has plugin specification
        string pluginName = StringUtil.Substring(hexString, 0, pipeIndex)
        string formIdPart = StringUtil.Substring(hexString, pipeIndex + 1)
        
        ; Check if plugin is loaded first
        if !Game.IsPluginInstalled(pluginName)
            return None
        endif
        
        int formId = HexToInt(formIdPart)
        return Game.GetFormFromFile(formId, pluginName)
    else
        ; No plugin - try to parse as raw form ID
        ; This assumes it's a runtime form ID
        int formId = HexToInt(hexString)
        return Game.GetForm(formId)
    endif
EndFunction

int Function HexToInt(string hexStr)
    {Convert hex string (with or without 0x prefix) to integer}
    
    string working = hexStr
    
    ; Remove 0x prefix if present
    if StringUtil.Find(working, "0x") == 0 || StringUtil.Find(working, "0X") == 0
        working = StringUtil.Substring(working, 2)
    endif
    
    ; Convert to lowercase for consistent processing
    working = StringToLower(working)
    
    int result = 0
    int idx = 0
    int len = StringUtil.GetLength(working)
    
    while idx < len
        string charVal = StringUtil.Substring(working, idx, 1)
        int digit = CharToHexDigit(charVal)
        result = result * 16 + digit
        idx += 1
    endwhile
    
    return result
EndFunction

int Function CharToHexDigit(string charVal)
    {Convert a single hex character to its integer value}
    
    if charVal == "0"
        return 0
    elseif charVal == "1"
        return 1
    elseif charVal == "2"
        return 2
    elseif charVal == "3"
        return 3
    elseif charVal == "4"
        return 4
    elseif charVal == "5"
        return 5
    elseif charVal == "6"
        return 6
    elseif charVal == "7"
        return 7
    elseif charVal == "8"
        return 8
    elseif charVal == "9"
        return 9
    elseif charVal == "a"
        return 10
    elseif charVal == "b"
        return 11
    elseif charVal == "c"
        return 12
    elseif charVal == "d"
        return 13
    elseif charVal == "e"
        return 14
    elseif charVal == "f"
        return 15
    endif
    
    return 0
EndFunction

string Function StringToLower(string text)
    {Convert string to lowercase for case-insensitive comparison}
    
    ; Manual lowercase conversion - works without external dependencies
    string result = ""
    int idx = 0
    int len = StringUtil.GetLength(text)
    
    while idx < len
        string c = StringUtil.Substring(text, idx, 1)
        
        if c == "A"
            result += "a"
        elseif c == "B"
            result += "b"
        elseif c == "C"
            result += "c"
        elseif c == "D"
            result += "d"
        elseif c == "E"
            result += "e"
        elseif c == "F"
            result += "f"
        elseif c == "G"
            result += "g"
        elseif c == "H"
            result += "h"
        elseif c == "I"
            result += "i"
        elseif c == "J"
            result += "j"
        elseif c == "K"
            result += "k"
        elseif c == "L"
            result += "l"
        elseif c == "M"
            result += "m"
        elseif c == "N"
            result += "n"
        elseif c == "O"
            result += "o"
        elseif c == "P"
            result += "p"
        elseif c == "Q"
            result += "q"
        elseif c == "R"
            result += "r"
        elseif c == "S"
            result += "s"
        elseif c == "T"
            result += "t"
        elseif c == "U"
            result += "u"
        elseif c == "V"
            result += "v"
        elseif c == "W"
            result += "w"
        elseif c == "X"
            result += "x"
        elseif c == "Y"
            result += "y"
        elseif c == "Z"
            result += "z"
        else
            result += c
        endif
        
        idx += 1
    endwhile
    
    return result
EndFunction

; =============================================================================
; FORGE FINDING
; =============================================================================

ObjectReference Function FindNearbyForge(Actor akActor)
    {Find the nearest forge within search radius}
    
    ; Method 1: Search by keyword
    if CraftingSmithingForge
        ObjectReference forge = Game.FindClosestReferenceOfTypeFromRef(CraftingSmithingForge as Form, akActor, SEARCH_RADIUS)
        if forge
            return forge
        endif
    endif
    
    ; Method 2: Search common forge base objects
    Form[] forgeTypes = new Form[5]
    forgeTypes[0] = Game.GetFormFromFile(0x000BF9E1, "Skyrim.esm")  ; CraftingBlackSmithForgeWR
    forgeTypes[1] = Game.GetFormFromFile(0x000BBCF1, "Skyrim.esm")  ; Skyforge  
    forgeTypes[2] = Game.GetFormFromFile(0x000CAE0B, "Skyrim.esm")  ; CraftingBlackSmithForge
    forgeTypes[3] = Game.GetFormFromFile(0x0200F812, "Dawnguard.esm") ; Dawnguard forge
    forgeTypes[4] = Game.GetFormFromFile(0x0403CF6E, "Dragonborn.esm") ; Dragonborn forge
    
    float closestDist = SEARCH_RADIUS
    ObjectReference closestForge = None
    
    int idx = 0
    while idx < forgeTypes.Length
        if forgeTypes[idx]
            ObjectReference found = Game.FindClosestReferenceOfTypeFromRef(forgeTypes[idx], akActor, SEARCH_RADIUS)
            if found
                float dist = akActor.GetDistance(found)
                if dist < closestDist
                    closestDist = dist
                    closestForge = found
                endif
            endif
        endif
        idx += 1
    endwhile
    
    return closestForge
EndFunction

; =============================================================================
; ELIGIBILITY CHECKS
; =============================================================================

bool Function CraftWeapon_IsEligible(Actor akActor, string weaponName)
    {Check if actor can craft the specified weapon}
    
    ; Check if database is loaded
    if !isInitialized
        return false
    endif
    
    ; Check if item exists in database
    Form item = FindCraftableByName(weaponName)
    if !item
        return false
    endif
    
    ; Check if actor is valid and not busy
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif
    
    ; Check if there's a forge nearby
    ObjectReference forge = FindNearbyForge(akActor)
    if !forge
        return false
    endif
    
    return true
EndFunction

bool Function CraftArmor_IsEligible(Actor akActor, string armorName)
    {Check if actor can craft the specified armor}
    return CraftWeapon_IsEligible(akActor, armorName)
EndFunction

bool Function CraftItem_IsEligible(Actor akActor, string itemName)
    {Check if actor can craft any item by name}
    return CraftWeapon_IsEligible(akActor, itemName)
EndFunction

; =============================================================================
; MAIN CRAFTING FUNCTIONS
; =============================================================================

Function CraftWeapon_Execute(Actor akActor, string weaponName, Actor akRecipient, bool requireMaterials)
    {Execute weapon crafting action}
    CraftItem_Internal(akActor, weaponName, akRecipient, requireMaterials)
EndFunction

Function CraftArmor_Execute(Actor akActor, string armorName, Actor akRecipient, bool requireMaterials)
    {Execute armor crafting action}
    CraftItem_Internal(akActor, armorName, akRecipient, requireMaterials)
EndFunction

Function CraftItem_Execute(Actor akActor, string itemName, Actor akRecipient, bool requireMaterials)
    {Execute generic item crafting action}
    CraftItem_Internal(akActor, itemName, akRecipient, requireMaterials)
EndFunction

Function CraftItem_Internal(Actor akActor, string itemName, Actor akRecipient, bool requireMaterials)
    {Internal crafting implementation - hybrid approach:
     - Uses ActorUtil.AddPackageOverride with interrupt for FORGE phase (to override TalkToPlayer)
     - Uses simple alias assignment for APPROACH phase (like the old working version)}
    
    ; Find the item in database
    Form itemForm = FindCraftableByName(itemName)
    if !itemForm
        Debug.Notification("Cannot craft: " + itemName + " (not in database)")
        return
    endif
    
    ; Find nearby forge
    ObjectReference forge = FindNearbyForge(akActor)
    if !forge
        Debug.Notification("No forge nearby!")
        return
    endif
    
    ; Set recipient (default to player if not specified)
    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif
    
    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()
    
    ; =========================================================================
    ; PHASE 1: Walk to forge and craft
    ; Uses ActorUtil.AddPackageOverride with interrupt to override TalkToPlayer
    ; =========================================================================
    
    Debug.Trace("SeverActions_Crafting: Phase 1 - Walking to forge (with interrupt)")
    
    ; Register persistent event: Started crafting
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins crafting " + itemDisplayName + " at the forge.", akActor, recipient)
    
    ; First, try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")
    
    ; Set up aliases for forge package
    ForgeAlias.ForceRefTo(forge)
    CrafterAlias.ForceRefTo(akActor)
    
    ; Use ActorUtil to add package with HIGH priority and INTERRUPT flag
    ; This is needed to override the TalkToPlayer package
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()
    
    ; Calculate max wait time based on distance
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME
    
    ; Wait for NPC to reach the forge
    WaitForArrival(akActor, forge, maxWait)
    
    ; Wait for crafting animation to play
    Utility.Wait(CRAFT_TIME)
    
    ; =========================================================================
    ; PHASE 2: Exit forge and create item
    ; =========================================================================
    
    Debug.Trace("SeverActions_Crafting: Phase 2 - Exiting forge")
    
    ; Remove the package override we added
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
    
    ; Clear forge alias to exit furniture
    ForgeAlias.Clear()
    akActor.EvaluatePackage()
    
    ; Wait for NPC to fully exit furniture
    Utility.Wait(2.0)
    
    ; Clear crafter alias (done with forge package)
    CrafterAlias.Clear()
    
    ; Add crafted item to the NPC's inventory
    akActor.AddItem(itemForm, 1, true)
    
    ; Register persistent event: Finished crafting
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes crafting " + itemDisplayName + ".", akActor, recipient)
    
    Debug.Trace("SeverActions_Crafting: Item added to NPC inventory")
    
    ; =========================================================================
    ; PHASE 3: Walk to recipient
    ; Uses SIMPLE ALIAS ASSIGNMENT like the old working version
    ; NO ActorUtil.AddPackageOverride - just set aliases and EvaluatePackage
    ; =========================================================================
    
    Debug.Trace("SeverActions_Crafting: Phase 3 - Walking to recipient: " + recipientName)
    
    ; Simple alias assignment - this is how the OLD WORKING VERSION did it
    RecipientAlias.ForceRefTo(recipient)
    CrafterApproachAlias.ForceRefTo(akActor)
    akActor.EvaluatePackage()
    
    ; Wait for NPC to reach the recipient
    WaitForArrival(akActor, recipient as ObjectReference, 20.0)
    
    ; Clear approach aliases
    CrafterApproachAlias.Clear()
    RecipientAlias.Clear()
    akActor.EvaluatePackage()
    
    ; =========================================================================
    ; PHASE 4: Face recipient and do give animation
    ; =========================================================================
    
    Debug.Trace("SeverActions_Crafting: Phase 4 - Giving item")
    
    ; Small pause to let NPC settle
    Utility.Wait(0.3)
    
    ; Face the recipient
    FaceActor(akActor, recipient)
    
    ; Play give animation
    DoGiveAnimation(akActor)
    
    ; =========================================================================
    ; PHASE 5: Transfer item to recipient
    ; =========================================================================
    
    ; Remove from NPC and add to recipient
    akActor.RemoveItem(itemForm, 1, false, recipient)
    
    ; Direct narration: Item handed over (triggers NPC response)
    SkyrimNetApi.DirectNarration(crafterName + " hands " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
    
    ; Notify
    Debug.Notification("Received: " + itemDisplayName)
    
    Debug.Trace("SeverActions_Crafting: Crafting complete")
EndFunction

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

Function WaitForArrival(Actor akActor, ObjectReference akTarget, float maxWaitTime)
    {Wait for actor to reach target location}
    
    float startTime = Utility.GetCurrentRealTime()
    float timeout = startTime + maxWaitTime
    
    while Utility.GetCurrentRealTime() < timeout
        float dist = akActor.GetDistance(akTarget)
        if dist <= INTERACTION_DISTANCE
            return
        endif
        Utility.Wait(0.5)
    endwhile
    
    ; Timeout reached - teleport as fallback
    Debug.Trace("SeverActions_Crafting: Arrival timeout, actor may not have reached target")
EndFunction

Function DoGiveAnimation(Actor akGiver)
    {Play the give item animation}
    
    if IdleGive
        akGiver.PlayIdle(IdleGive)
        Utility.Wait(1.5)
    endif
EndFunction

Function FaceActor(Actor akActor, Actor akTarget)
    {Make actor face the target}
    
    akActor.SetLookAt(akTarget)
    Utility.Wait(0.5)
    akActor.ClearLookAt()
EndFunction

; =============================================================================
; DEBUG / UTILITY
; =============================================================================

Function ListAllCraftableItems()
    {Debug function to list all items in database}
    
    if !isInitialized
        Debug.Notification("Database not loaded!")
        return
    endif
    
    string[] categories = new string[3]
    categories[0] = "weapons"
    categories[1] = "armor"
    categories[2] = "misc"
    
    int catIdx = 0
    while catIdx < categories.Length
        int categoryObj = JMap.getObj(craftableDB, categories[catIdx])
        if categoryObj != 0
            Debug.Trace("=== " + categories[catIdx] + " ===")
            int keysArray = JMap.allKeys(categoryObj)
            int keyCount = JArray.count(keysArray)
            
            int keyIdx = 0
            while keyIdx < keyCount && keyIdx < 20  ; Limit to first 20
                string keyName = JArray.getStr(keysArray, keyIdx)
                int formIdArray = JMap.getObj(categoryObj, keyName)
                int formCount = JArray.count(formIdArray)
                string firstValue = JArray.getStr(formIdArray, 0)
                Debug.Trace("  " + keyName + " -> " + firstValue + " (+" + (formCount - 1) + " fallbacks)")
                keyIdx += 1
            endwhile
            
            if keyCount > 20
                Debug.Trace("  ... and " + (keyCount - 20) + " more")
            endif
        endif
        catIdx += 1
    endwhile
EndFunction

string Function GetDatabaseStats()
    {Get statistics about the loaded database}
    
    if !isInitialized
        return "Database not loaded"
    endif
    
    int weaponsCount = JMap.count(JMap.getObj(craftableDB, "weapons"))
    int armorCount = JMap.count(JMap.getObj(craftableDB, "armor"))
    int miscCount = JMap.count(JMap.getObj(craftableDB, "misc"))
    
    return "Weapons: " + weaponsCount + ", Armor: " + armorCount + ", Misc: " + miscCount
EndFunction