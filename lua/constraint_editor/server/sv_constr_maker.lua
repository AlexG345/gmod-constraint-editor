-- This addon, at its core, uses the same functions as the duplicator to create constraints.
-- The duplicator uses functions from the global constraint table to create constraints, at least in most cases (constraints from addons might be different)
-- Thus there are two methods of "easily" creating constraints, the second one is untested and unused in this addon:
--	duplicator.ConstraintType[constrType](unpack(constrData))
--	constraint[constrType](unpack(constrData))
-- Note: constrData is a constraint data that uses numerical keys. Check constraint_editor/sv_constr_data.lua file for more information on constraint data.

-- A complete list of constraint factory functions and their arguments can be found here: https://wiki.facepunch.com/gmod/constraint
-- 	e.g. constraint.Weld (https://wiki.facepunch.com/gmod/constraint.Weld)


local NT = ConstraintEditor.netTags


-------------------------------------------
--  Constraint Data Position Transforms  --
-------------------------------------------


-- Change the entities from a constraint data while preserving all found positions in worldspace
--
-- Arguments:
--	constrData (table): Constraint data that must use string keys
--	mats (table): Optional table whose keys are entities found in newEntities (arg) and values matrices representing a translation/rotation.
--		Will be used in place of the respective entities world transform matrices.
--	newEntities (table): Sequential table containing first entity and second entity for the positions to be relative to
--
-- Returns:
--	constrData (table): Constraint data with new entities and appropriately transformed positions
local function LocalToLocalConstrData( constrData, mats, newEntities )

	local entKeys		= ConstraintEditor.GetConstrEntKeys( constrData )
	local posKeys		= ConstraintEditor.GetConstrPosKeys( constrData )

	for i, entKey in pairs( entKeys ) do

		local ent		= constrData[entKey] or constrData[i]
		local newEnt	= newEntities[entKey] or newEntities[i]

		constrData[entKey] = newEnt

		local mat, newMat = ( mats[ent] or ent:GetWorldTransformMatrix() ), ( mats[newEnt] or newEnt:GetWorldTransformMatrix() )

		if mat == newMat then continue end

		local transform = newMat:GetInverseTR()
		transform:Mul( mat )

		for _, posKey in pairs( posKeys[i] ) do

			local localPos = constrData[posKey]
			constrData[posKey] = transform * localPos

		end

	end

end




--------------------------------
--    BuildDupeInfo Helpers   --
--------------------------------


local function overwriteInfoFromConstrCreationTime( BuildDupeInfo, mats, entities, bones )

	if not BuildDupeInfo then return end

	table.Empty( BuildDupeInfo )

	local entCount = #entities
	if not IsValid( entities[1] ) then return end

	if entities[2] and entities[1] == entities[2] then return end

	for i, ent in ipairs( entities ) do

		if i > 2 then break end -- normally should never happen
		if ent:IsWorld() then continue end

		local entMat	= mats[ent] or ent:GetWorldTransformMatrix()
		local entPos	= entMat:GetTranslation()

		BuildDupeInfo["Ent" .. i .. "Ang"] = entMat:GetAngles()

		if entCount > 1 then
			if i == 1 then
				BuildDupeInfo.Ent1Pos	= entPos
			else
				BuildDupeInfo.EntityPos	= BuildDupeInfo.Ent1Pos - entPos
			end
		end

		local bone = bones[i]
		if bone and ent:GetPhysicsObjectCount() > 1 then
			local boneStr	= "Bone" .. i
			local phys		= ent:GetPhysicsObjectNum( bone )
			if IsValid( phys ) then
				local boneMat						= mats[phys] or phys:GetPositionMatrix()
				BuildDupeInfo[boneStr]				= bone
				BuildDupeInfo[boneStr .. "Angle"]	= boneMat:GetAngles()
				BuildDupeInfo[boneStr .. "Pos"]		= boneMat:GetTranslation() - entPos
			end
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


---------------------------
--  Entity change (WIP)  --
---------------------------


-- The replaced entity had specific transforms at constraint creation time, which might be different than its current ones
-- The difference between those transforms must be inherited by either the new entity or the other entity.
local function inheritCorrection( mats, otherEnt, otherBone, newEnt, newBone, replacedEnt, replacedBone )

	local replacedPhys	= replacedBone and ( replacedEnt:GetPhysicsObjectCount() > 1 ) and replacedEnt:GetPhysicsObjectNum( replacedBone )
	replacedPhys		= IsValid( replacedPhys ) or nil
	local from			= replacedPhys and replacedPhys:GetPositionMatrix() or replacedEnt:GetWorldTransformMatrix()
	local to			= replacedPhys and mats[replacedPhys] or mats[replacedEnt]

	if from ~= to then
		-- Find the entity that can move, if any.
		local correctedEnt = ( not newEnt:IsWorld() ) and newEnt or ( not otherEnt:IsWorld() ) and otherEnt or nil
		if not correctedEnt then return end
		local isOther = correctedEnt == otherEnt

		-- Get the correction. It's different depending on which entity it's applied on.
		if isOther then from, to = to, from end
		local correction = to * from:GetInverseTR()

		-- Save the new transform for the entity that got corrected.
		mats[correctedEnt] = correction * ( mats[correctedEnt] or correctedEnt:GetWorldTransformMatrix() )

		-- Get the new transform for the bone (physobj) that got corrected, if needed.
		if correctedEnt:GetPhysicsObjectCount() > 1 then
			local correctedPhys = correctedEnt:GetPhysicsObjectNum( isOther and otherBone or newBone )
			-- TODO: might need to return from here if invalid phys? need to test if the constraint breaks or won't get created or something else if we keep going
			if IsValid( correctedPhys ) then
				mats[correctedPhys] = correction * ( mats[correctedPhys] or correctedPhys:GetPositionMatrix() )
			end
		end

	end

	return true

end


-- Arguments:
--	newConstrData (table): Table with the new values EXCEPT entities and bones
local function restoreConstrBehaviorAfterEntChange(
		newConstrData, BuildDupeInfo,
		entIndex, replacement,
		entKeys, boneKeys,
		preserveLocalBehavior
	)

	local oldEnt, oldBone	= replacement.old.ent, replacement.old.bone
	local newEnt, newBone	= replacement.new.ent, replacement.new.bone
	--local entKey, boneKey	= entKeys[entIndex], boneKeys[entIndex]

	if not ( isentity( oldEnt ) and isentity( newEnt ) ) or ( oldEnt == newEnt and oldBone == newBone ) then return end

	local otherEntIndex = 1 + entIndex % 2
	local otherEnt		= newConstrData[entKeys[otherEntIndex]] or game.GetWorld()
	local otherBone		= newConstrData[boneKeys[otherEntIndex]] or 0

	-- Get the positions and angles the old entities must be at during constraint creation
	local mats = ConstraintEditor.GetMatricesFromConstrCreation( BuildDupeInfo, newConstrData, entKeys, boneKeys )
	if not mats then return end

	if preserveLocalBehavior then
		-- Do as if the new entity had the replaced entity transforms then make the constraint data local to the new entity
		mats[newEnt] = mats[oldEnt]
		LocalToLocalConstrData( newConstrData, mats, { newEnt, newEnt } )
		mats[newEnt] = nil
	end

	if not inheritCorrection( mats, otherEnt, otherBone, newEnt, newBone, oldEnt, oldBone ) then
		return
	end

	if preserveLocalBehavior and not otherEnt:IsWorld() then
		local newEntCurrentMat	= newEnt:GetWorldTransformMatrix()
		local correction		= oldEnt:GetWorldTransformMatrix() * newEntCurrentMat:GetInverseTR()
		mats[newEnt]			= correction * ( mats[newEnt] or newEntCurrentMat )
		mats[otherEnt]			= correction * mats[otherEnt]
	end

	local entities	= { [entIndex] = newEnt, [otherEntIndex] = otherEnt }

	LocalToLocalConstrData( newConstrData, mats, entities )

	overwriteInfoFromConstrCreationTime( BuildDupeInfo, mats, entities, { [entIndex] = newBone, [otherEntIndex] = otherBone } )

end





-- Attempts to modify data so that a new constraint created using constrData preserves a certain behavior despite having changed entities:
--	with transferMode set to 1: Behavior preservation in World coordinates
--	with transferMode set to 2: Behavior preservation from replacedEnt to newEnt Local coordinates
local function restoreConstrBehaviorAfterEntsChange( constrData, newConstrData, BuildDupeInfo, transferMode )

	if not ( constrData and newConstrData ) then return end

	local entKeys	= ConstraintEditor.GetConstrEntKeys( newConstrData )
	local boneKeys	= ConstraintEditor.GetConstrBoneKeys( newConstrData )
	local update	= false

	local preserveLocalBehavior = transferMode == 2

	local replacements = {}
	for entIndex, entKey in pairs( entKeys ) do

		local boneKey	= boneKeys[entIndex]
		local oldEnt, oldBone = constrData[entKey], constrData[boneKey]

		replacements[entIndex] = {
			old	= {
				ent		= oldEnt,
				bone	= oldBone
			},
			new	= {
				ent		= newConstrData[entKey],
				bone	= newConstrData[boneKey]
			}
		}

		newConstrData[entKey]	= oldEnt
		newConstrData[boneKey]	= oldBone

	end

	for entIndex, entKey in pairs( entKeys ) do

		update = restoreConstrBehaviorAfterEntChange(
			newConstrData, BuildDupeInfo,
			entIndex, replacements[entIndex],
			entKeys, boneKeys,
			preserveLocalBehavior
		) or update

		print("------- done -------")
		PrintTable( constrData )
		print("--------------------\n")

	end

end


-- Similar to above but changes entities of constr
-- Returns updated constrData, can recreate constr
local function changeConstrEnts( entChange, constr, ply, delete )

	local constrData	= ConstraintEditor.GetConstrData( constr )
	local entKeys		= ConstraintEditor.GetConstrEntKeys( constrData )
	local update		= false

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

	for _, constr in pairs( constrs ) do

		if istable( constr ) then constr = constr.Constraint end
		if constr then changeConstrEnts( entChange, constr, ply, delete ) end

	end

end



----------------------------------
--  Actual Constraint Creation  --
----------------------------------

local function removeOldConstrIfNeeded( constr, newConstrData )

	local newConstrDataType = newConstrData.Type
	if newConstrDataType ~= "Weld" and newConstrDataType ~= "NoCollide" then return end

	local comparedKeys = { "Ent1", "Ent2", "Bone1", "Bone2" }
	for _, k in ipairs( comparedKeys ) do
		if constr[k] ~= newConstrData[k] then return end
	end

	local ent = constr.Ent1
	if not ent.Constraints then return end

	for k, v in pairs( ent.Constraints ) do
		if v == constr then
			ent.Constraints[k] = nil
			constr:Remove()
			break
		end
	end

	-- TODO: delete on break welds, updated to delete on break = false, still delete the 1st entity on 2nd entity removal

end


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

	-- TODO BUG IMPORTANT: Spawn two barrels, use a rope between them, select barrel 1, transfer to barrel 2, then select barrel 2, transfer to barrel 1. Barrel 1 goes to barrel 2 pos.
	-- IDEA: delete the whole code and restart from 0 since this error has literally no cause it's just here to annoy me as usual

	local restoreMats, restoreMotions = ConstraintEditor.ApplyTransformsSavedAtConstrCreation( BuildDupeInfo, constrData )

	ConstraintEditor.TransformConstrDataKeys( constrData, nil, true ) -- use numerical keys
	local constr, rope = createConstrBlindly( duplicatorFunc, constrData, ply, constrType )

	if constr and BuildDupeInfo then constr.BuildDupeInfo = copyInfoFromConstrCreationTime( BuildDupeInfo ) end

	for obj, mat in pairs( restoreMats ) do
		obj:SetAngles( mat:GetAngles() )
		obj:SetPos( mat:GetTranslation() )
	end

	for phys, b in pairs( restoreMotions ) do
		obj:EnableMotion( b )
	end

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


	local newConstr, newRope = createConstrAccurate( constrType, constrData, BuildDupeInfo, duplicatorFunc, ply )

	-- TODO: check how this interacts with wire controller stuff
	local limitSafe = ConstraintEditor.DoLimitsUndoCleanup( ply, newConstr, newRope, enforceLimits, addUndo )
	if not limitSafe then return end


	---------- WIRE HYDRAULICS (S) ----------
	-- We now need to link the newly created wire hydraulic to the hydraulic controller if it exists.
	if IsValid( wireController ) and wireController:GetClass() == "gmod_wire_hydraulic" then

		-- Unlink the old constraints and the hydraulic controller
		for _, ent in ipairs( { wireController.constraint, wireController.rope } ) do
			if isentity( ent ) then
				if ent.MyCrtl then ent.MyCrtl = -1 end -- if set to nil it's uneditable afterwards
				ent:DontDeleteOnRemove( wireController )
				wireController:DontDeleteOnRemove( ent )
			end
		end

		-- Link the new constraints to the hydraulic controller
		wireController:SetConstraint( newConstr, newRope )
		for _, ent in ipairs( { newConstr, newRope } ) do
			if isentity( ent ) then wireController:DeleteOnRemove( ent ) end -- check if entity exists since rope does not exist if constr width is 0
		end
		newConstr.MyCrtl = wireController:EntIndex()
	end
	---------- WIRE HYDRAULICS (E) ----------


	return newConstr, newRope

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

		-- We need a copy of the new values for each constraint since most of the
		-- time these have to be completed with the old values specific to each constraint
		local newConstrDataCopy = {}
		for k, v in pairs( newConstrData ) do
			newConstrDataCopy[k] = v
		end

		-- Safety measures for constrData.
		ConstraintEditor.TransformConstrDataKeys( newConstrDataCopy, desc, false, true ) -- Make sure we use str keys
		local isChanged = ConstraintEditor.CompleteConstrData( constrData, newConstrDataCopy, desc, ply )

		if delete and not isChanged then continue end

		local BuildDupeInfo = copyInfoFromConstrCreationTime( constr.BuildDupeInfo )

		if restoreBehavior and isChanged then restoreConstrBehaviorAfterEntsChange( constrData, newConstrDataCopy, BuildDupeInfo, transferMode ) end

		removeOldConstrIfNeeded( constr, newConstrDataCopy )

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

	local newConstrs = {}
	-- local deletedConstrs = {}

	for constr, newConstr in pairs( constrsReplacements ) do

		if not ( isentity( newConstr ) and newConstr:IsValid() ) or constr == newConstr then continue end

		local newConstrID = ConstraintEditor.RegisterConstr( newConstr )

		if setEdited then
			newConstrs[newConstrID] = true
		end


		if delete then
			-- local constrID = constr:GetCreationID()
			-- deletedConstrs[constrID] = true
			-- ConstraintEditor.constrs[constrID] = nil
			constr:Remove() -- TODO: the line above should be handled by the call on remove, do we keep it or not?
		end

	end

	if setEdited then

		local constrType = next( constrsReplacements ).Type

		if ConstraintEditor.NetStartWrite( NT.SELECT_CONSTRS, ply ) then
			ConstraintEditor.NetWriteConstrIDs( newConstrs )
			net.WriteString( constrType )
			-- TODO IMPORTANT: check if deselecting the constraints that are about to be deleted is truly needed
			-- ConstraintEditor.NetWriteConstrIDs( deletedConstrs )
			net.Send( ply )
		end

	end

end