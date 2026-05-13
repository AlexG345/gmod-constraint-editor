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

	local entKeys, posKeys = ConstraintEditor.GetConstrEntPosKeys( constrData )
	local worldConstrData = overwrite and constrData or table.Copy( constrData )
	local entities = {}
	local world = game.GetWorld()

	for i, entKey in pairs( entKeys ) do

		local ent = constrData[entKey]
		table.insert( entities, ent )
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

	local entKeys, posKeys = ConstraintEditor.GetConstrEntPosKeys( worldConstrData )
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


-- Updates a BuildDupeInfo table positions and angles, using data similar to what's returned by applyBuildDupeInfo.
local function saveBuildDupeInfo( BuildDupeInfo, data, entKeys )
	if not BuildDupeInfo then return end
	local first, second = data[1], data[2]
	if first and second then BuildDupeInfo.EntityPos = first.ent:GetPos() - second.ent:GetPos() end
	for i, entData in pairs( data ) do
		BuildDupeInfo[entKeys[i] .. "Pos"] = entData.ent:GetPos()
		BuildDupeInfo[entKeys[i] .. "Ang"] = entData.ent:GetAngles()
	end
end


-- Creates a deep copy of a BuildDupeInfo table, considering that it can contain vectors and angles
local function copyBuildDupeInfo( BuildDupeInfo )
	if not BuildDupeInfo then return end
	local newBuildDupeInfo = {}
	for k, v in pairs( BuildDupeInfo ) do
		if isvector( v ) then newBuildDupeInfo[k] = Vector( v )
		elseif isangle( v ) then newBuildDupeInfo[k] = Angle( v ) end
	end
	return newBuildDupeInfo
end


-- Applies preserved transforms using data returned from applyBuildDupeInfo
-- Basically puts the entities and bones back to their positions and angles before applyBuildDupeInfo was used on them
local function restoreAfterBuildDupeInfo( data )

	if not data then return end
	-- Move the entities back after constraining them. No point in moving the world though.
	for _, entData in pairs( data ) do
		local ent, posR, angR = entData.ent, entData.posReset, entData.angReset
		if posR then ent:SetPos( posR ) end
		if angR then ent:SetAngles( angR ) end

		if entData.boneIndex == 0 then
			local bone, bPosR, bAngR = entData.bone, entData.bonePosReset, entData.boneAngReset
			if bPosR then bone:SetPos( bPosR ) end -- + posR
			if bAngR then bone:SetAngles( bAngR ) end
		end

		if entData.reEnable and IsValid( entData.phys ) then
			entData.phys:EnableMotion( true )
		end

	end

end


-- Credits: Originally from Advanced Duplicator 2
-- Puts entities back to the position and angles they were in upon constraint creation, relative to each other at least.
-- If staticEntIndex is specified, BuildDupeInfo will be modified. Otherwise it should work like in advdupe2.
-- TODO: check why when world is involved, it doesn't always work as intended, and if it can be fixed.
local function applyBuildDupeInfo( BuildDupeInfo, constrData, entKeys, staticEntIndex )

	if not BuildDupeInfo then return end

	entKeys = entKeys or ConstraintEditor.GetConstrEntPosKeys( constrData )

	local firstEnt, secondEnt = constrData[entKeys[1]], constrData[entKeys[2]] or game.GetWorld()
	--TODO: verify this line is useful
	if firstEnt == secondEnt then return end

	local first, second = { ent = firstEnt }, { ent = secondEnt }
	local data = { first, second }

	local followedEnt, followerEnt = firstEnt, secondEnt

	for i = 1, 2 do

		local entData = data[i]

		local ent = entData.ent
		if not IsValid( ent ) then continue end
		entData.valid = true

		entData.phys, entData.reEnable = setEntMotion( ent, false )
		if not IsValid( entData.phys ) then continue end

		local entKey = entKeys[i]
		local entAng = BuildDupeInfo[entKey .. "Ang"]
		local entPos = BuildDupeInfo[entKey .. "Pos"]

		-- entityPos being the initial pos of one entity relative to the other, it is used only if the current entity is the follower entity.
		local entityPos = ( ent == followerEnt and followedEnt and BuildDupeInfo.EntityPos )

		-- Preserve current transforms of the entity
		entData.posReset, entData.angReset = ent:GetPos(), ent:GetAngles()

		-- Apply initial transforms (from when the constraint was created) to the entity
		if entAng then ent:SetAngles( entAng ) end
		if entPos then ent:SetPos( entPos ) end
		if entityPos then
			local pos = followedEnt:GetPos()
			pos[ent == first.ent and "Add" or "Sub"]( pos, entityPos )
			ent:SetPos( pos )
		end

		entData.boneIndex = BuildDupeInfo["Bone" .. i]
		if not entData.boneIndex then continue end

		local bone = ent:GetPhysicsObjectNum( entData.boneIndex )
		entData.bone = bone
		if not IsValid( bone ) then continue end

		entData.bonePosReset, entData.boneAngReset = bone:GetPos(), bone:GetAngles()
		bone:EnableMotion( false )

		bone:SetPos( ent:GetPos() + BuildDupeInfo["Bone" .. i .. "Pos"] )
		bone:SetAngles( BuildDupeInfo["Bone" .. i .. "Angle"] )
	end

	-- Partial redudancy?
	if second.valid then
		local ang = BuildDupeInfo.Ent2Ang or BuildDupeInfo.Ent4Ang
		if ang then second.ent:SetAngles( ang ) end
	end

	-- This is a dirty hack.
	-- If needed, applies to one of the entities (called "static") its preserved transforms,
	-- while keeping the other entity transforms identical in static's coordinates space.
	if staticEntIndex then

		local static = data[staticEntIndex]
		local nonStatic = data[1 + staticEntIndex % 2]

		local localAng = static.ent:WorldToLocalAngles( nonStatic.ent:GetAngles() )
		local localPos = static.ent:WorldToLocal( nonStatic.ent:GetPos() )

		restoreAfterBuildDupeInfo( { static } )

		nonStatic.ent:SetAngles( static.ent:LocalToWorldAngles( localAng ) )
		nonStatic.ent:SetPos( static.ent:LocalToWorld( localPos ) )

		saveBuildDupeInfo( BuildDupeInfo, data, entKeys )

		data.static = nil

	end

	return data

end




---------------------------
--  Entity change (WIP)  --
---------------------------


-- Same as "applyBuildDupeInfo", but also does the work of changing the i-th entity to newEnt
-- You should probably not use this alone: it does not touch constrData and that must be done to "fully convert" a constraint entity to another
local function convertApplyBuildDupeInfo( BuildDupeInfo, constrData, newEnt, i, entKeys )

	local data
	local j = 1 + i % 2
	local replacedEnt, otherEnt = constrData[entKeys[i]], constrData[entKeys[j]]

	-- when newEnt == otherEnt things break
	if BuildDupeInfo and not ( newEnt == otherEnt or replacedEnt:IsWorld() and otherEnt:IsWorld() ) then

		local isFirst = i == 1

		-- Used to transform newEnt later
		local replacedEntAng = replacedEnt:GetAngles()
		local newEntLocalPos = replacedEnt:WorldToLocal( newEnt:GetPos() )

		-- World shouldn't end up transformed, so if present we use it as the static entity
		local staticEntIndex = ( newEnt:IsWorld() and i ) or ( otherEnt:IsWorld() and j )
		data = applyBuildDupeInfo( BuildDupeInfo, constrData, entKeys, staticEntIndex )

		-- Preserve newEnt transforms
		-- TODO: what about bone transforms?
		if data then data.new = {
			ent			= newEnt,
			posReset	= newEnt:GetPos(),
			angReset	= newEnt:GetAngles()
		} end

		-- Partial update of BuildDupeInfo
		if newEnt:IsWorld() then
			BuildDupeInfo.EntityPos = nil
			BuildDupeInfo[entKeys[i] .. "Ang"] = nil
		else
			newEnt:SetPos( replacedEnt:LocalToWorld( newEntLocalPos ) )
			newEnt:SetAngles( newEnt:AlignAngles( replacedEntAng, replacedEnt:GetAngles() ) )

			BuildDupeInfo.EntityPos = otherEnt:GetPos() - newEnt:GetPos()
			BuildDupeInfo[entKeys[i] .. "Ang"] = newEnt:GetAngles()
			if isFirst then BuildDupeInfo.EntityPos:Negate() end
		end
	end

	return data, { [i] = newEnt, [j] = otherEnt }

end


-- Changes newConstrData by assuming that its i-th entity has been changed from replacedEnt to newEnt
-- The objective is that the new constraint (created using constrData) keeps the same behavior, world position and world rotation as the original constraint
-- newConstrData MUST have str keys (such as LPos1, LPos2, etc )
-- Returns true only if some data has been changed
-- TODO: find out if it's possible to restore world attached advanced ballsockets properly
local function restoreConstrBehaviorAfterEntChange( constrData, BuildDupeInfo, replacedEnt, i, entKeys )

	local replacedEntKey = entKeys[i]
	local newEnt = constrData[replacedEntKey] or constrData[i]

	if not ( isentity( replacedEnt ) and isentity( newEnt ) ) or replacedEnt == newEnt then return false end

	constrData[replacedEntKey] = replacedEnt

	local data, newEntities = convertApplyBuildDupeInfo( BuildDupeInfo, constrData, newEnt, i, entKeys )

	LocalToWorldConstrData( constrData, true )
	constrData[replacedEntKey] = newEnt
	WorldToLocalConstrData( constrData, newEntities, true )

	if data then restoreAfterBuildDupeInfo( data ) end

	return true

end


-- Alternative to "restoreConstrBehaviorAfterEntChange" above.
-- Constr behavior in replacedEnt coordinates space is copied over to newEnt coordinates space
local function imitateConstr( constrData, BuildDupeInfo, replacedEnt, i, entKeys )

	local replacedEntKey = entKeys[i]
	local newEnt = constrData[replacedEntKey] or constrData[i]

	if not ( isentity( replacedEnt ) and isentity( newEnt ) ) or replacedEnt == newEnt then return false end

	constrData[replacedEntKey] = replacedEnt

	local j = 1 + i % 2
	local otherEnt = constrData[entKeys[j]]
	local data, entities = applyBuildDupeInfo( BuildDupeInfo, constrData, entKeys, j ), { [i] = newEnt, [j] = otherEnt }
	data = data or {}
	data.new = {
		ent			= newEnt,
		posReset	= newEnt:GetPos(),
		angReset	= newEnt:GetAngles()
	}

	-- Attach the constraint positions to newEnt
	local otherLocalPos = newEnt:WorldToLocal( otherEnt:GetPos() )
	local otherLocalAngles = newEnt:WorldToLocalAngles( otherEnt:GetAngles() )
	if not newEnt:IsWorld() then
		newEnt:SetPos( replacedEnt:GetPos() )
		newEnt:SetAngles( replacedEnt:GetAngles() )
	end

	--debugoverlay.Cross( ent:LocalToWorld(constrData.LPos2), 50, 6, Color( 0, 255, 0 ), false )
	--debugoverlay.Cross( otherEnt:LocalToWorld(constrData.LPos1), 50, 6, Color( 255, 255, 0 ), false )
	LocalToWorldConstrData( constrData, true )
	--debugoverlay.Cross( constrData.LPos1, 50, 6, Color( 255, 0, 0 ), false )
	--debugoverlay.Cross( constrData.LPos2, 50, 6, Color( 50, 100, 255 ), false )
	WorldToLocalConstrData( constrData, { newEnt, newEnt }, true )

	if not otherEnt:IsWorld() then
		otherEnt:SetPos( newEnt:LocalToWorld( otherLocalPos ) )
		otherEnt:SetAngles( newEnt:LocalToWorldAngles( otherLocalAngles ) )
	end

	saveBuildDupeInfo( BuildDupeInfo, { [i] = data.new, [j] = data[j] }, entKeys )
	LocalToWorldConstrData(constrData, true)
	WorldToLocalConstrData(constrData, entities, true)

	restoreAfterBuildDupeInfo( data )

	-- assign new entities

	--saveBuildDupeInfo( BuildDupeInfo, { [i] = data.new, [j] = data[j] }, entKeys )

	--if data then restoreAfterBuildDupeInfo( data ) end

	return true

end


-- The original entities must be given in replacedEnts, replacedEnts should have a constrData structure (both str and numerical keys work)
-- All of the entities must exist.
-- Attempts to modify data so that a new constraint created using constrData has the same behavior despite the entity change:
-- with transferMode set to 1: Behavior preservation in World coordinates
-- with transferMode set to 2: Behavior preservation between replacedEnt and newEnt Local coordinates
-- This function does not freeze the entities hence it's unsafe when used alone
-- Does not work with ragdolls.
local function restoreConstrBehaviorAfterEntsChange( replacedEnts, constrData, BuildDupeInfo, transferMode )

	if not ( replacedEnts and constrData ) then return end

	local entKeys = ConstraintEditor.GetConstrEntPosKeys( constrData )
	local update = false

	-- TODO: try to make the two functions be a single one??
	local transferFunc = transferMode == 1 and restoreConstrBehaviorAfterEntChange or transferMode == 2 and imitateConstr
	if not transferFunc then return end

	for i, entKey in pairs( entKeys ) do

		local replacedEnt = replacedEnts[entKey] or replacedEnts[i]
		update = transferFunc( constrData, BuildDupeInfo, replacedEnt, i, entKeys ) or update

	end

end


-- Similar to above but changes entities of constr
-- Returns updated constrData, can recreate constr
local function changeConstrEnts( entChange, constr, ply, delete )

	local constrData = ConstraintEditor.GetConstrData( constr )
	local entKeys = ConstraintEditor.GetConstrEntPosKeys( constrData )
	local update = false

	for i, entKey in pairs( entKeys ) do

		local ent		= constrData[entKey]
		local newEnt	= ent and entChange[ent] or entChange[i]
		if newEnt then
			update = ( newEnt ~= ent ) or update
			constrData[entKey] = newEnt
		end

	end

	if update then ConstraintEditor.CreateConstrsFromConstrs( { constr }, constrData, ply, true, true, delete ) end

	return constrData

end


-- Lets you transfer constraints between entities (if they break by doing so, does nothing)
-- entChange table can have, as keys, either:
-- 	Entities to specifically target one or multiple entities to be changed
-- 	The numbers 1 and/or 2 to target the first and/or second entity of the constraint(s)
-- Priority is given to entities keys.
-- entChange table values must be the new entities.
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

	local data = applyBuildDupeInfo( BuildDupeInfo, constrData )

	ConstraintEditor.TransformConstrDataKeys( constrData, nil, true ) -- use numerical keys
	local constr, rope = createConstrBlindly( duplicatorFunc, constrData, ply, constrType )

	if constr and BuildDupeInfo then constr.BuildDupeInfo = table.Copy( BuildDupeInfo ) end

	restoreAfterBuildDupeInfo( data )

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

		if delete and not isChanged then continue end

		local BuildDupeInfo = copyBuildDupeInfo( constr.BuildDupeInfo )

		if restoreBehavior and isChanged then restoreConstrBehaviorAfterEntsChange( constrData, newConstrDataCopy, BuildDupeInfo, transferMode ) end

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

	if ply and ConstraintEditor.NetStartWrite( NT.REGISTER_CONSTRS, ply ) then
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
			ConstraintEditor.NetWriteConstrIDs( deletedConstrs )
			net.Send( ply )
		end

	end

end