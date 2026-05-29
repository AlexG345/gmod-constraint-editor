-- This addon, at its core, uses the same functions as the duplicator to create constraints.
-- The duplicator uses functions from the global constraint table to create constraints, at least in most cases (constraints from addons might be different)
-- Thus there are two methods of "easily" creating constraints, the second one is untested and unused in this addon:
--	duplicator.ConstraintType[constrType](unpack(constrData))
--	constraint[constrType](unpack(constrData))
-- Note: constrData is a constraint data that uses numerical keys. Check constraint_editor/sv_constr_data.lua file for more information on constraint data.

-- A complete list of constraint factory functions and their arguments can be found here: https://wiki.facepunch.com/gmod/constraint
-- 	e.g. constraint.Weld (https://wiki.facepunch.com/gmod/constraint.Weld)


local NT = ConstraintEditor.netTags


----------------------
--  Simple helpers  --
----------------------


local function setEntMotion( ent, b )
	local phys = isentity( ent ) and ent:IsValid() and ent:GetPhysicsObject()
	if IsValid( phys ) then
		local reset = phys:IsMoveable()
		phys:EnableMotion( b )
		return phys, reset
	end
end


local function disableEntsMotion( entities )
	local motionRestores = {}
	for ent1, ent2 in pairs( entities ) do
		for _, ent in ipairs( { ent1, ent2 } ) do
			local phys, b = setEntMotion( ent, false )
			if phys then motionRestores[phys] = b end
		end
	end
	return motionRestores
end


local function restoreEntsMotion( motionRestores )
	for phys, b in pairs( motionRestores ) do
		phys:EnableMotion( b )
	end
end


-- Save position, angles, motion state of an entity and/or physics object, with options
--
-- Arguments:
--	ent (Entity): The entity whose info we want to save
--	phys (PhysObj): The physics object whose info we want to save (can replace ent (arg))
--	saveTransform: Only if true will save ent's or phys' (args) position and angles
--	saveMotion: Only if true will try to save phys' (arg) motion state (whether it's frozen or not)
--
-- Returns:
--	(table): Table containing the wanted information (check the arguments)
--	(Entity | PhysObj | boolean): ent (arg) if it's valid or phys (arg) if it's valid or false
--	phys (PhysObj): phys (arg) if it's valid or false
local function saveObjectInfo( ent, phys, saveTransform, saveMotion, localObject )

	local entValid, physValid = IsValid( ent ), IsValid( phys )

	local objectInfo = {}

	if saveTransform then

		local object = ( entValid and ent ) or ( physValid and phys )

		if object then
			local pos, ang = object:GetPos(), object:GetAngles()

			if IsValid( localObject ) then
				-- Make position and angles local
				pos, ang				= WorldToLocal( pos, ang, localObject:GetPos(), localObject:GetAngles() )
				objectInfo.localObject	= localObject
			end

			objectInfo.object	= object
			objectInfo.pos		= pos
			objectInfo.ang		= ang

		end
	end

	if saveMotion and physValid then
		objectInfo.phys		= phys
		objectInfo.motion	= phys:IsMotionEnabled()
	end

	return objectInfo, objectInfo.object, objectInfo.phys

end


-- Restore position, angles, motion state according to what's found in the given object information
--
-- Arguments:
--	objectInfo (table): table obtained using the saveObjectInfo function
local function applyObjectInfo( objectInfo )

	local object, phys = objectInfo.object, objectInfo.phys

	if object then
		local pos, ang		= objectInfo.pos, objectInfo.ang
		local localObject	= objectInfo.localObject

		if IsValid( localObject ) then
			-- Make position and angles non-local
			pos, ang = LocalToWorld( pos, ang, localObject:GetPos(), localObject:GetAngles() )
		end

		object:SetPos( pos )
		object:SetAngles( ang )
	end

	if phys and objectInfo.motion ~= nil then
		phys:EnableMotion( objectInfo.motion )
	end

end


-- Restore position, angles, motion state for multiple objects (entities or PhysObj)
--
-- Arguments:
--	objectsInfo (table): table whose values are tables obtained using the saveObjectInfo function
local function applyObjectsInfo( objectsInfo )
	for _, objectInfo in pairs( objectsInfo ) do
		applyObjectInfo( objectInfo )
	end
end


-------------------------------------------
--  Constraint Data Position Transforms  --
-------------------------------------------


-- Converts all found occurences of local positions to world positions
--
-- Arguments:
--	constrData (table): Constraint data that must use string keys
--	overwrite (boolean): If true, constrData (arg) is directly modified, otherwise a new table is created.
--
-- Returns:
--	worldConstrData (table): World-relative converted constraint data
--	entities (table): Sequential table containing first entity and second entity from constrData (arg) before any modifications
local function LocalToWorldConstrData( constrData, overwrite )

	local entKeys, _, posKeys = ConstraintEditor.GetConstrEntBonePosKeys( constrData )
	local worldConstrData = overwrite and constrData or table.Copy( constrData )
	local entities = {}
	local world = game.GetWorld()

	print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

	for i, entKey in pairs( entKeys ) do

		local ent = constrData[entKey]
		table.insert( entities, ent )

		print("made to world: ", ent, "->", world)

		if ent:IsWorld() then continue end

		worldConstrData[entKey] = world

		for _, posKey in pairs( posKeys[i] ) do

			local localPos = constrData[posKey]
			worldConstrData[posKey] = ent:LocalToWorld( localPos )

		end
	end

	return worldConstrData, entities

end


-- Converts all found occurences of world positions to local positions
--
-- Arguments:
--	worldConstrData (table): Constraint data that must use string keys, and whose entities should be the world
--	entities (table): Sequential table containing first entity and second entity for the positions to be relative to
--	overwrite (boolean): If true, worldConstrData (arg) is directly modified, otherwise a new table is created.
--
-- Returns:
--	constrData (table): entities (arg) -relative converted constraint data
local function WorldToLocalConstrData( worldConstrData, entities, overwrite )

	local entKeys, _, posKeys = ConstraintEditor.GetConstrEntBonePosKeys( worldConstrData )
	local constrData = overwrite and worldConstrData or table.Copy( worldConstrData )

	for i, entKey in pairs( entKeys ) do

		local ent = entities[entKey] or entities[i]
		if ent:IsWorld() then continue end

		for _, posKey in pairs( posKeys[i] ) do
			local worldPos = constrData[posKey]
			constrData[posKey] = ent:WorldToLocal( worldPos )
		end
		constrData[entKey] = ent

	end

	return constrData

end




--------------------------------
--    BuildDupeInfo Helpers   --
--------------------------------


-- Overwrites a BuildDupeInfo table positions and angles using the given entities current state
-- TODO: the. bones. are. not. considered. WHY??
local function overwriteInfoFromConstrCreationTime( BuildDupeInfo, entKeys, entities )

	if not BuildDupeInfo then return end

	local firstPos

	for entIndex, ent in ipairs( entities ) do
		-- The world entity gets skipped, this is intended
		if not IsValid( ent ) then continue end

		local entKey = entKeys[entIndex]

		BuildDupeInfo[entKey .. "Ang"] = ent:GetAngles()

		if entIndex == 1 then
			firstPos = ent:GetPos()
			BuildDupeInfo[entKey .. "Pos"] = firstPos
		elseif firstPos then
			BuildDupeInfo.EntityPos = firstPos - ent:GetPos()
		end

	end
end


-- Creates a deep copy of a BuildDupeInfo table, considering that it can contain vectors and angles
local function copyInfoFromConstrCreationTime( BuildDupeInfo )
	if not BuildDupeInfo then return end
	local newBuildDupeInfo = {}
	for k, v in pairs( BuildDupeInfo ) do
		if isvector( v ) then newBuildDupeInfo[k] = Vector( v )
		elseif isangle( v ) then newBuildDupeInfo[k] = Angle( v ) end
	end
	return newBuildDupeInfo
end


-- Credits: Originally from Advanced Duplicator 2
-- Puts entities back to the position and angles they were in relative to each other upon constraint creation
-- You can choose to force an entity to stay static (its pos and angles will not change). If so, BuildDupeInfo will be modified.
-- TODO: check why when world is involved, it doesn't always work as intended, and if it can be fixed.
local function applyInfoFromConstrCreationTime( BuildDupeInfo, constrData, entKeys, staticEntIndex, objectsInfo )

	local objectsInfo = objectsInfo or {}

	if not BuildDupeInfo then return objectsInfo end

	entKeys = entKeys or ConstraintEditor.GetConstrEntBonePosKeys( constrData )

	local entities = {
		constrData[entKeys[1]],
		constrData[entKeys[2]] or game.GetWorld()
	}

	local bonePhysObjs = {}

	local followedEnt, followerEnt = entities[1], entities[2]
	--TODO: verify this line is useful
	if followedEnt == followerEnt then return objectsInfo end

	for entIndex, ent in ipairs( entities ) do

		if not IsValid( ent ) then continue end

		-- Preserve current position, angles and motion state of the entity
		local objectInfo, object, phys	= saveObjectInfo( ent, ent:GetPhysicsObject(), true, true )
		if not phys then continue end
		objectsInfo[object] = objectInfo
		phys:EnableMotion( false )

		-- Apply at-constraint-creation transforms to the entity
		local entKey = entKeys[entIndex]
		local ang = BuildDupeInfo[entKey .. "Ang"]
		if ang then object:SetAngles( ang ) end

		local pos

		-- Advdupe2 doesn't save the second entity's pos (pos2),
		-- it only saves the pos1 - pos2 vector, and only if both entities are valid (this includes not being the world)
		-- This means you get pos2 that way: pos2 = pos1 - posDiff
		-- What if ent1 is the world? Then neither ent1 nor ent2 are moved.
		-- What if ent2 is the world? Then ent1 is moved but not ent2. Weird.
		if entIndex == 2 then
			local firstEnt = entities[1]
			local posDiff = IsValid( firstEnt ) and BuildDupeInfo.EntityPos
			if not posDiff then break end
			pos = firstEnt:GetPos()
			pos:Sub( posDiff )
		else
			pos = BuildDupeInfo[entKey .. "Pos"]
		end

		if pos then object:SetPos( pos ) end


		local bone = BuildDupeInfo["Bone" .. entIndex]
		if not bone then continue end

		-- Preserve current position, angles and motion state of the bone's physics object
		objectInfo, object, phys = saveObjectInfo( nil, ent:GetPhysicsObjectNum( bone ), true, true )
		if not phys then continue end
		objectsInfo[object] = objectInfo
		phys:EnableMotion( false )

		bonePhysObjs[entIndex] = phys

		-- Apply at-constraint-creation transforms to the bone's physics object
		pos = ent:GetPos()
		local boneKey = "Bone" .. entIndex
		object:SetPos( ent:GetPos() + BuildDupeInfo[boneKey .. "Pos"] )
		object:SetAngles( BuildDupeInfo[boneKey .. "Angle"] )

	end

	-- TODO: remove this if it's indeed redundant
	-- if second.object then
	-- 	local ang = BuildDupeInfo.Ent2Ang or BuildDupeInfo.Ent4Ang
	-- 	if ang then second.object:SetAngles( ang ) end
	-- end

	-- This is a dirty hack.
	-- If needed, resets one of the entities (called "staticEnt") back to its state at the start of the function,
	-- while making the other entity act like its parented to it (its staticEnt-local angles and position should not change, or only due to floating point error)
	-- In the end it's as if "staticEnt" never moved, BUT relative positions between the two entities are preserved
	-- TODO: check if using the bone is actually useful or not
	if staticEntIndex then

		local staticObject = bonePhysObjs[staticEntIndex] or entities[staticEntIndex]

		local nonStaticEntIndex = 1 + staticEntIndex % 2
		local nonStaticObjects = { bonePhysObjs[nonStaticEntIndex], entities[nonStaticEntIndex] }
		local localObjectsInfo = {}

		for _, nonStaticObject in pairs( nonStaticObjects ) do
			-- Save local positions and angles (local here means relative to the static object)
			localObjectsInfo[nonStaticObject] = saveObjectInfo( nonStaticObject, nil, true, false, staticObject )
		end

		local staticObjectInfo = objectsInfo[staticObject]
		if staticObjectInfo then
			applyObjectInfo( objectsInfo[staticObject] )
		end

		for _, localObjectInfo in pairs( localObjectsInfo ) do
			applyObjectInfo( localObjectInfo )
		end

		-- TODO: Check if this can be removed. It's probably unused.
		-- overwriteInfoFromConstrCreationTime( BuildDupeInfo, entKeys, entities )

		-- You might think that since we already applied the static object's object info, we can discard it.
		-- However, it's not a good idea because some functions use that info elsewhere after applying other transforms
		-- objectsInfo[staticObject] = nil

	end

	return objectsInfo

end




---------------------------
--  Entity change (WIP)  --
---------------------------


-- TODO: allow for custom coordinates space

-- The aim is for a constraint created using the updated tables to look and behave the same in global coordinates as a constraint created using the non-updated tables.
-- Returns false if we're sure that the tables haven't been updated
-- TODO: find out if it's possible to restore world attached advanced ballsockets properly
-- Arguments:
--	constrData (table): literal keys constraint data (contains the new entity)
local function restoreConstrWorldBehaviorAfterEntChange( constrData, BuildDupeInfo, replacedEnt, replacedEntIndex, entKeys, boneKeys )

	local replacedEntKey	= entKeys[replacedEntIndex]
	local newEnt			= constrData[replacedEntKey]

	if not ( isentity( replacedEnt ) and isentity( newEnt ) ) or replacedEnt == newEnt then return false end

	constrData[replacedEntKey] = replacedEnt

	-- previously in applyAndConvertInfoFromConstrCreationTime
	local objectsInfo = {}

	local otherEntIndex = 1 + replacedEntIndex % 2
	local otherEnt = constrData[entKeys[otherEntIndex]] or game.GetWorld()
	local entities = { [replacedEntIndex] = newEnt, [otherEntIndex] = otherEnt }

	-- when newEnt == otherEnt things break
	if BuildDupeInfo and not ( newEnt == otherEnt or replacedEnt:IsWorld() and otherEnt:IsWorld() ) then

		local moveNew			= not ( newEnt:IsWorld() or replacedEnt:IsWorld() )
		local newBone			= constrData[boneKeys[replacedEntIndex]] or 0
		local newPhys			= newEnt:GetPhysicsObjectNum( newBone )
		local moveNewPhys		= newBone ~= 0
		local localObjectsInfo	= {}

		if moveNew then
			-- Save the new entity info so that it can be restored later
			-- Save local position and angles to follow the replaced entity a few lines below
			objectsInfo[newEnt]			= saveObjectInfo( newEnt, newPhys, true, true ) -- TODO: check if this should save motion or not
			localObjectsInfo[newEnt]	= saveObjectInfo( newEnt, nil, true, false, replacedEnt )
			if moveNewPhys then
				objectsInfo[newPhys]		= saveObjectInfo( nil, newPhys, true )
				localObjectsInfo[newPhys]	= saveObjectInfo( nil, newPhys, true, false, replacedEnt )
			end

			print("------------ NEW BONE (verify this the inputted one!!): ", newBone)
		end
		print(otherEnt, replacedEnt, "--->", newEnt, "moving newEnt: ", moveNew, "moving its bone:", moveNewPhys)

		-- World will not be moved/rotated by applyInfoFromConstrCreationTime, so if present we use it as the static entity
		-- TODO: is checking for replacedEnt necessary ?
		local staticEntIndex = ( not moveNew and replacedEntIndex ) or ( otherEnt:IsWorld() and otherEntIndex )
		applyInfoFromConstrCreationTime( BuildDupeInfo, constrData, entKeys, staticEntIndex, objectsInfo )

		-- Make the new entity follow the replaced entity (whose info we just restored) as if parented to it
		applyObjectsInfo( localObjectsInfo )

		-- Update BuildDupeInfo with the new entity
		overwriteInfoFromConstrCreationTime( BuildDupeInfo, entKeys, entities )
	end
	-- end of previously in applyAndConvertInfoFromConstrCreationTime

	LocalToWorldConstrData( constrData, true )
	constrData[replacedEntKey] = newEnt
	WorldToLocalConstrData( constrData, entities, true )

	applyObjectsInfo( objectsInfo )

	return true

end


-- Alternative to the "restoreConstrWorldBehaviorAfterEntChange" function.
-- The aim is for a constraint created using the updated tables to behave the same in newEnt coordinates space
-- as a constraint created using the non-updated tables would in replacedEnt coordinates space
local function restoreConstrLocalBehaviorAfterEntChange( constrData, BuildDupeInfo, replacedEnt, replacedEntIndex, entKeys, boneKeys )

	local replacedEntKey = entKeys[replacedEntIndex]
	local newEnt = constrData[replacedEntKey] or constrData[replacedEntIndex]

	if not ( isentity( replacedEnt ) and isentity( newEnt ) ) or replacedEnt == newEnt then return false end

	print("keep going: ", replacedEnt, "->", newEnt)

	constrData[replacedEntKey] = replacedEnt

	local otherEntIndex = 1 + replacedEntIndex % 2
	local otherEnt		= constrData[entKeys[otherEntIndex]] or game.GetWorld()

	local objectsInfo	= applyInfoFromConstrCreationTime( BuildDupeInfo, constrData, entKeys, otherEntIndex )

	local localObjectsInfo = {}

	if not newEnt:IsWorld() then
		if not otherEnt:IsWorld() then
			localObjectsInfo[otherEnt] = saveObjectInfo( otherEnt, nil, true, false, newEnt )
		end

		objectsInfo[newEnt]	= saveObjectInfo( newEnt, newEnt:GetPhysicsObject(), true, true )
		newEnt:SetPos( replacedEnt:GetPos() )
		newEnt:SetAngles( replacedEnt:GetAngles() )
	end

	-- Attach the constraint positions to newEnt
	LocalToWorldConstrData( constrData, true )

	print("restoreConstrLocalBehaviorAfterEntChange debug [S]")
	PrintTable(constrData)
	print("restoreConstrLocalBehaviorAfterEntChange debug [E]")

	WorldToLocalConstrData( constrData, { newEnt, newEnt }, true )

	if not ( otherEnt:IsWorld() or BuildDupeInfo ) then
		objectsInfo[otherEnt] = saveObjectInfo( otherEnt, otherEnt:GetPhysicsObject(), true, true ) -- TODO: check if this should save motion or not
	end

	applyObjectsInfo( localObjectsInfo )

	local entities = { [replacedEntIndex] = newEnt, [otherEntIndex] = otherEnt }

	overwriteInfoFromConstrCreationTime( BuildDupeInfo, entKeys, entities )

	LocalToWorldConstrData( constrData, true )
	WorldToLocalConstrData( constrData, entities, true )

	applyObjectsInfo( objectsInfo )

	return true

end


-- Attempts to modify data so that a new constraint created using constrData preserves a certain behavior despite having changed entities:
--	with transferMode set to 1: Behavior preservation in World coordinates
--	with transferMode set to 2: Behavior preservation from replacedEnt to newEnt Local coordinates
-- The original entities must be given in replacedEnts, replacedEnts should have a constrData structure (both str and numerical keys work)
-- All of the entities must exist.
-- This function might not freeze the entities hence it's unsafe when used alone (TODO: check if this line is still true?)
-- Does not work with ragdolls.
local function restoreConstrBehaviorAfterEntsChange( replacedEnts, constrData, BuildDupeInfo, transferMode )

	if not ( replacedEnts and constrData ) then return end

	local entKeys, boneKeys = ConstraintEditor.GetConstrEntBonePosKeys( constrData )
	local update = false

	-- TODO: try to make the two functions be a single one??
	local transferFunc = transferMode == 1 and restoreConstrWorldBehaviorAfterEntChange or transferMode == 2 and restoreConstrLocalBehaviorAfterEntChange
	if not transferFunc then return end

	for entIndex, entKey in pairs( entKeys ) do

		local replacedEnt = replacedEnts[entKey] or replacedEnts[entIndex]
		print( "replacedEnt = ", replacedEnt )
		update = transferFunc( constrData, BuildDupeInfo, replacedEnt, entIndex, entKeys, boneKeys ) or update

	end

	print("restoreConstrBehaviorAfterEntsChange DEBUG (S)")
	PrintTable( constrData )
	print("restoreConstrBehaviorAfterEntsChange DEBUG (E)")

end


-- Similar to above but changes entities of constr
-- Returns updated constrData, can recreate constr
local function changeConstrEnts( entChange, constr, ply, delete )

	local constrData = ConstraintEditor.GetConstrData( constr )
	local entKeys = ConstraintEditor.GetConstrEntBonePosKeys( constrData )
	local update = false

	for i, entKey in pairs( entKeys ) do

		local ent		= constrData[entKey]
		local newEnt	= ent and entChange[ent] or entChange[i]
		print("changeConstrEnts DEBUG", ent, "->", newEnt)
		if newEnt then
			update = ( newEnt ~= ent ) or update
			constrData[entKey] = newEnt
		end

	end

	if update then ConstraintEditor.CreateConstrsFromConstrs( { constr }, constrData, ply, true, true, delete ) end

	PrintTable( constrData )

	return constrData

end


-- Lets you replace the entities of multiple constraints while trying to preserve the constraints' behaviors (if they break by doing so, does nothing)
-- TODO: Check if this can actually be used alone safely, write the answer to that HERE...
--
-- Arguments:
-- entChange (table): Table whose keys are the replaced entities / constraint data entities' indexes and values the replacement (=new) entities:
--	If the key is an entity, any occurence of that entity in the constraints data will be targetted
--	If the key is 1 (resp. 2), the first (resp. second) entity in the constraints data will be targetted (with lower priority than entity key)
function ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, delete )

	for _, newEnt in pairs( entChange ) do
		if not ( isentity( newEnt ) and ( newEnt:IsValid() or newEnt:IsWorld() ) ) then return false end
	end

	local motionRestores = disableEntsMotion( entChange )

	for _, constr in pairs( constrs ) do

		if istable( constr ) then constr = constr.Constraint end
		if constr then changeConstrEnts( entChange, constr, ply, delete ) end

	end

	restoreEntsMotion( motionRestores )

end



----------------------------------
--  Actual Constraint Creation  --
----------------------------------


-- Create a constraint like the duplicator does
--
-- Arguments:
--	factory (function): The function to be called to create the constraint
--	constrData (table): Constraint data that uses only numerical keys, to be used as arguments for factory (arg)
--	ply (Player): The player who caused this function call
--	constrType (string): The (very optional) constraint type
--
-- Returns:
--	constr (Entity): The created constraint.
--	rope (Entity (keyframe_rope) | nil): The visual part of the constraint, a keyframe_rope
--
-- TODO: check if it's necessary to return more (e.g. for hydraulic constraint there can be 4 return values: phys_spring, keyframe_rope, gmod_winch_controller, phys_slideconstraint)
local function createConstrBlindly( factory, constrData, ply, constrType )
	local ok, constr, rope = pcall( factory, unpack( constrData, 1, #constrData ) )
	-- print( ok, constr, rope, "error:", ply and not (ok and constr), "type:", constrType)
	if ply and not ( ok and constr ) then
		ply:ChatPrint( "Constraint Editor - ERROR: Failed to create " .. constrType or "unknown type" .. " constraint properly!" )
	end
	return constr, rope
end


-- Credits: based on Advanced Duplicator 2 (https://github.com/wiremod/advdupe2) CreateConstraintFromTable function
-- Recreate a constraint based on more complete data than just what's stored in constraint data. Assumes that no entity were changed.
--
-- Arguments:
--	constrType (string): The (very optional) constraint type
--	constrData (table): Constraint data that must use string keys
--	BuildDupeInfo (table | nil): Table (created by Advanced Duplicator 2) to restore relative positions and angles
--	duplicatorFunc (function): The function to be called to create the constraint
--	ply (Player): The player who caused this function call
--
-- Returns:
--	constr (Entity): The created constraint.
--	rope (Entity (keyframe_rope) | nil): The visual part of the constraint, a keyframe_rope
--
-- TODO: Check if 'redundant ent motion disabling' can be solved (won't have much impact)
local function createConstrAccurate( constrType, constrData, BuildDupeInfo, duplicatorFunc, ply )

	local objectsInfo = applyInfoFromConstrCreationTime( BuildDupeInfo, constrData )

	ConstraintEditor.TransformConstrDataKeys( constrData, nil, true ) -- use numerical keys
	local constr, rope = createConstrBlindly( duplicatorFunc, constrData, ply, constrType )

	if constr and BuildDupeInfo then constr.BuildDupeInfo = table.Copy( BuildDupeInfo ) end

	applyObjectsInfo( objectsInfo )

	return constr, rope
end


-- Tries to create a new constraint, assuming no entity change must be handled.
-- Handles cleanup, undo, sandbox limits, wire hydraulics stuff, BuildDupeInfo, ...
-- Does not check at all if constrData is "safe".
--
-- Arguments:
--	constrData (table): Constraint data that must use string keys
--	BuildDupeInfo (table | nil): Table (created by advanced duplicator 2) to restore relative positions and angles
--	duplicatorFunc (function): The function to be called to create the constraint
--	ply (Player): The player who supposedly owns the created constraint
--	enforceLimits (boolean): Only if true, sandbox limits are checked, which can result in the deletion of the constraint and rope.
--	addUndo (boolean): Only if true, an entry is added to the undo menu for ply (arg).
--
-- Returns:
--	constr (Entity | nil): The created constraint.
--	rope (Entity (keyframe_rope) | nil): The visual part of the constraint, a keyframe_rope
function ConstraintEditor.CreateConstr( constrData, BuildDupeInfo, duplicatorFunc, ply, enforceLimits, addUndo )

	local constrType = constrData.Type

	if not duplicatorFunc then
		local desc = ConstraintEditor.GetConstrDescriptor( constrData )
		duplicatorFunc = desc.Func
	end


	---------- WIRE HYDRAULICS (S) ----------
	-- Prevent the usage of a possibly nonexistent hydraulic controller.
	local wireController
	if constrType == "WireHydraulic" then
		wireController = constrData.MyCrtl and Entity( constrData.MyCrtl )
		constrData.MyCrtl = nil
	end
	---------- WIRE HYDRAULICS (E) ----------


	local newConstr, rope = createConstrAccurate( constrType, constrData, BuildDupeInfo, duplicatorFunc, ply )

	-- TODO: check how this interacts with wire controller stuff
	local limitSafe = ConstraintEditor.DoLimitsUndoCleanup( ply, newConstr, rope, enforceLimits, addUndo )
	if not limitSafe then return end


	---------- WIRE HYDRAULICS (S) ----------
	-- We now need to link the newly created wire hydraulic to the hydraulic controller if it exists.
	if IsValid( wireController ) and wireController:GetClass() == "gmod_wire_hydraulic" then

		-- Unlink the old constraints and the hydraulic controller
		for _, ent in ipairs( { wireController.constraint, wireController.rope } ) do
			if isentity( ent ) then
				ent.MyCrtl = -1 -- if set to nil it's uneditable afterwards
				ent:DontDeleteOnRemove( wireController )
				wireController:DontDeleteOnRemove( ent )
			end
		end

		-- Link the new constraints to the hydraulic controller
		wireController:SetConstraint( newConstr, rope )
		for _, ent in ipairs( { newConstr, rope } ) do
			if isentity( ent ) then wireController:DeleteOnRemove( ent ) end -- check if entity exists since rope does not exist if constr width is 0
		end
		newConstr.MyCrtl = wireController:EntIndex()
	end
	---------- WIRE HYDRAULICS (E) ----------


	return newConstr, rope

end


-- Creates a new constraint by using an existing constraint and some given constraint data
-- What if the existing constraint had been created using different values? That's part of what this function tries to do.
-- Does safety checks for the given constraint data, can optionally delete the old constraint, update players menu...

-- Arguments:
--	constr (table | Entity): The existing constraint the new one will be based on
--	newConstrData (table): Constraint data for the new constraint
--	ply (Player): The player who's trying to create the new constraint
--	restoreBehavior (boolean): Only if true, tries to restore the constraint behavior despite any linked entity/entities change(s).
--	sanitize (boolean): Only if true, checks if entities inside newConstrData (arg) can be accessed by ply (arg)
--	delete (boolean): Only if true, deletes the old constraint in case of successful creation of the new constraint
--	setEdited (boolean): Only if true, makes ply (arg) edit the new constraint in case of its successful creation
function ConstraintEditor.CreateConstrsFromConstrs( constrs, newConstrData, ply, restoreBehavior, sanitize, delete, setEdited )

	if next( constrs ) == nil then return end

	-- If the constraint was transferred between entities, try to preserve its behavior in some way.
	local transferMode = 1
	if ply then
		local tool = ConstraintEditor.GetTool( ply )
		transferMode = tool and tool:GetClientNumber( "transfer_mode", 1 ) or 1
	end

	local constrsReplacements = {}

	if sanitize then ConstraintEditor.SanitizeConstrData( newConstrData, ply ) end

	for _, constr in pairs( constrs ) do

		local constrData, desc = ConstraintEditor.GetConstrData( constr )
		local newConstrDataCopy = {}
		for k, v in pairs( newConstrData ) do
			newConstrDataCopy[k] = v
		end

		-- Safety measures for constrData.
		ConstraintEditor.TransformConstrDataKeys( newConstrDataCopy, desc, false, true ) -- Make sure we use str keys
		local isChanged = ConstraintEditor.CompleteConstrData( constrData, newConstrDataCopy, desc, ply )

		print("[debug] CreateConstrsFromConstrs (S)")
		PrintTable( newConstrDataCopy )
		print("[debug] CreateConstrsFromConstrs (E)")

		if delete and not isChanged then continue end

		local BuildDupeInfo = copyInfoFromConstrCreationTime( constr.BuildDupeInfo )

		if restoreBehavior and isChanged then restoreConstrBehaviorAfterEntsChange( constrData, newConstrDataCopy, BuildDupeInfo, transferMode ) end

		print("[debug] CreateConstrsFromConstrs (S)")
		PrintTable( newConstrDataCopy )
		print("[debug] CreateConstrsFromConstrs (E)")

		constrsReplacements[constr] = ConstraintEditor.CreateConstr( newConstrDataCopy, BuildDupeInfo, desc.Func, ply, not delete, not delete )

	end

	-- Menu stuff and deletion
	ConstraintEditor.ReplaceConstrs( constrsReplacements, ply, delete, setEdited )

end


-- Replace (in the access system etc) an existing constraint with another existing one.
--
-- Arguments
--	constrsReplacements (table): Table whose keys are the constraints to be replaced and values the new ones
--	ply (Player | nil): The player who supposedly owns newConstr (arg)
--	delete (boolean): Only if true, deletes the old constraint, and only if the replacement one is valid.
--	setEdited (boolean): Only if true, sets the new constraint as the currently edited one in the menu of ply (arg), and only if newConstr (arg) is valid.
function ConstraintEditor.ReplaceConstrs( constrsReplacements, ply, delete, setEdited )

	if next( constrsReplacements ) == nil then return end

	local surfaceConstrsData = ConstraintEditor.GetSurfaceConstrsData( constrsReplacements )

	if ConstraintEditor.NetStartWrite( NT.REGISTER_CONSTRS, ply ) then
		net.WriteTable( surfaceConstrsData )
		net.Send( ply )
	end

	local newConstrs, deletedConstrs = {}, {}

	for constr, newConstr in pairs( constrsReplacements ) do

		if not ( isentity( newConstr ) and newConstr:IsValid() ) or constr == newConstr then continue end

		local newConstrID = ConstraintEditor.RegisterConstr( newConstr )

		if setEdited then
			newConstrs[newConstrID] = true
		end


		if delete then
			local constrID = constr:GetCreationID()
			deletedConstrs[constrID] = true
			ConstraintEditor.constrs[constrID] = nil
			SafeRemoveEntity( constr )
		end

	end

	if setEdited then

		local constrType = next( constrsReplacements ).Type

		if ConstraintEditor.NetStartWrite( NT.SELECT_CONSTRS, ply ) then
			ConstraintEditor.NetWriteConstrIDs( newConstrs )
			net.WriteString( constrType )
			-- TODO: check if deselecting the constraints that are about to be deleted is truly needed
			ConstraintEditor.NetWriteConstrIDs( deletedConstrs )
			net.Send( ply )
		end

	end

end