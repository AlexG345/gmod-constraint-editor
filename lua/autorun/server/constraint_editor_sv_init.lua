util.AddNetworkString( "constraint_editor_net" )

local mode = "constraint_editor" -- name of the tool

local NT = ConstraintEditor.NetTags
local BIT_COUNT_TAG			= ConstraintEditor.NetBitCounts.TAG
local BIT_COUNT_CONSTR_ID	= ConstraintEditor.NetBitCounts.CONSTR_ID


--------------------------------
--      Various helpers       --
--------------------------------


local function isConstrLinkedToEnt( constr, ent )
	return ent == constr.Ent1 or ent == ( constr.Ent2 or constr.Ent4 )
end


local function findConstrWeirdKeys( constrData )
	local ent1, ent2, ent4 = constrData.Ent1, constrData.Ent2, constrData.Ent4
	local entKeys = { ent1 and "Ent1" or nil, ent2 and "Ent2" or ent4 and "Ent4" or nil }
	local posKeys = { constrData["LPos1"] and "LPos1" or "LPos", "LPos2" }
	return entKeys, posKeys
end


local function setEntMotion( ent, b )
	local phys = isentity( ent ) and ent:IsValid() and ent:GetPhysicsObject()
	if IsValid( phys ) then
		local reset = phys:IsMoveable()
		phys:EnableMotion( b )
		return phys, reset
	end
end


local function disableEntsMotions( ents )
	local motionRestores = {}
	for ent1, ent2 in pairs( ents ) do
		for _, ent in ipairs( { ent1, ent2 } ) do
			local phys, b = setEntMotion( ent, false )
			if phys then motionRestores[phys] = b end
		end
	end
	return motionRestores
end


local function restoreEntsMotions( motionRestores )
	for phys, b in pairs( motionRestores ) do
		phys:EnableMotion( b )
	end
end


-- If one of the args is nil for a constraint, this table gives you a lot of default, fallback values
local constrArgsDefaults = {

	Weld = { nocollide = false },

	color			= color_white,
	material		= "cable/rope",
	width			= 0,

	deleteonbreak	= false,
	disableOnRemove	= true,
	toggle			= false,
	starton			= false,
	stretchonly		= false,
	rigid			= false,

	fixed			= 0,
	nocollide		= 0,
	onlyrotation	= 0,

	xmin			= -180,
	ymin			= -180,
	zmin			= -180,
	xmax			= 180,
	ymax			= 180,
	zmax			= 180,
	xfric			= 0,
	yfric			= 0,
	zfric			= 0,

	friction		= 0,
	forcelimit		= 0,
	torquelimit		= 0,

	key				= 0,
	fwd_bind		= 0,
	bwd_bind		= 0,
	numpadkey_fwd	= 0,
	numpadkey_bwd	= 0,

	direction		= 1,
	fwd_speed		= 0,
	bwd_speed		= 0,
	torque			= 0,
	forcetime		= 0,
	period			= 0,
	amplitude		= 0,

	constant		= 0,
	damping			= 0,
	rdamping		= 0,

	length			= 0,
	addlength		= 0,
	Length1			= 0,
	Length2			= 0,

	LPos1			= vector_origin,
	LPos2			= vector_origin,
	LocalAxis		= vector_origin,
	WPos2			= vector_origin,
	WPos3			= vector_origin,
	LPos4			= vector_origin,
}


--------------------------------
--     Player permissions     --
--------------------------------


-- Keys are constraint IDs, values are tables containing:
-- 	ent: the constraint entity,
-- 	allowedPlayers: players who can ask server to edit the constraint
ConstraintEditor.KnownConstrs = {}

-- Keys are players, values are entities (props)
ConstraintEditor.EditedEnts = {}

-- Time since last table cleanup
ConstraintEditor.lastTablesCleanup = CurTime()

-- Revoke all the constraint editing permissions of the player ply
function ConstraintEditor.ClearAccess( ply )

	if not ply then return end

	ConstraintEditor.EditedEnts[ply] = nil

	for constrID, data in pairs( ConstraintEditor.KnownConstrs ) do
		local allowed = data.allowedPlayers
		allowed[ply] = nil
		if next( allowed ) == nil then ConstraintEditor.ForgetConstr( constrID ) end
	end

end


-- Give or revoke the player ply's permission to edit the constraint associated with constrID (or ent)
function ConstraintEditor.SetAccess( ply, constrID, allow, ent )

	constrID = constrID or ent and ent:GetCreationID()

	if not constrID then return end

	if not ConstraintEditor.KnownConstrs[constrID] then

		if not allow then return end
		ConstraintEditor.KnownConstrs[constrID] = { allowedPlayers = {}, ent = ent }

	end

	local plys = ConstraintEditor.KnownConstrs[constrID].allowedPlayers

	plys[ply] = allow and true or nil

	if next( plys ) == nil then ConstraintEditor.ForgetConstr( constrID ) end

	if not allow then ConstraintEditor.SendDataToClient( NT.FORGET_CONSTR, constrID, ply ) end

end


-- Transfers players permissions from constr to newConstr
function ConstraintEditor.TransferAccess( constr, newConstr, checkLink )

	if not ( constr and newConstr ) then return end

	local constrID = constr:GetCreationID()
	local newConstrID = newConstr:GetCreationID()
	local data = ConstraintEditor.KnownConstrs[constrID]

	if not data then return end

	for ply in pairs( data.allowedPlayers ) do

		--ConstraintEditor.SetAccess( ply, constrID, false, constr )
		ConstraintEditor.SetAccess( ply, newConstrID, true, newConstr )

		-- Update the menus
		local surfaceConstrData = ConstraintEditor.GetSurfaceConstrData( newConstr )
		if isConstrLinkedToEnt( newConstr, ConstraintEditor.GetEditedEntity( ply ) ) then
			ConstraintEditor.SendDataToClient( NT.ADD_SHOWN_CONSTRS, surfaceConstrData, ply )
		end

	end

end


-- Returns constraint associated with constrID only if it exists and player ply has permissions to edit it
-- TODO: check if ply lost prop permission (CanTool) while editing the prop !
function ConstraintEditor.Access( ply, constrID )

	local data = ConstraintEditor.KnownConstrs[constrID]

	return data and data.allowedPlayers[ply] and data.ent or false

end


function ConstraintEditor.AccessEntity( ply, ent, button )
	button = button or 1
	return ( ply and isentity( ent ) and ent ~= NULL and ( game.SinglePlayer() or not ent:IsWorld() ) and hook.Run( "CanTool", ply, { Entity = ent }, mode, button ) and ent ) or false
end


-- Forgets data related to this constrID (the associated constraint and the players editing permissions)
function ConstraintEditor.ForgetConstr( constrID )

	local data = ConstraintEditor.KnownConstrs[constrID]

	if data then
		for ply in pairs( data.allowedPlayers ) do
			ConstraintEditor.SendDataToClient( NT.FORGET_CONSTR, constrID, ply )
		end
	end

	ConstraintEditor.KnownConstrs[constrID] = nil

end


-- Forgets constrIDs:
--		that have no related data
-- 		whose associated constraint is not valid (e.g. has been removed)
-- 		that have no player permissions
-- Also clears EditedEnts if player or entity is invalid
function ConstraintEditor.CleanupTables()

	for constrID, data in pairs( ConstraintEditor.KnownConstrs ) do
		if not data or not IsValid( data.ent ) or next( data.allowedPlayers ) == nil then
			ConstraintEditor.ForgetConstr( constrID )
		end
	end

	for ply, ent in pairs( ConstraintEditor.EditedEnts ) do
		if not IsValid( ply ) then
			ConstraintEditor.ClearAccess( ply )
		elseif not IsValid( ent ) then
			ConstraintEditor.EditedEnts[ply] = nil
		end
	end

end


-- Don't clean up tables if it was already done not long ago
function ConstraintEditor.TryCleanupTables()
	local now = CurTime()
	if now - ( ConstraintEditor.lastTablesCleanup or 0 ) < 30 then return end
	ConstraintEditor.lastTablesCleanup = now

	ConstraintEditor.CleanupTables()
end


-- Deletes a constraint and data associated to its constrID
function ConstraintEditor.DeleteConstr( constr )
	constr.CEInvalid = true
	local constrID = constr:GetCreationID()
	ConstraintEditor.ForgetConstr( constrID )
	SafeRemoveEntity( constr )
end


function ConstraintEditor.SetEditedEntity( ent, ply )

	if not isentity( ent ) then ent = NULL end

	if not ply or ( ent ~= NULL and not ConstraintEditor.AccessEntity( ply, ent, 1 ) ) then return end

	ConstraintEditor.ClearAccess( ply )

	ConstraintEditor.EditedEnts[ply] = ent

	local surfaceConstrsData, constrs = ConstraintEditor.GetEntSurfaceConstrsData( ent )
	local tool = ply.GetTool and ply:GetTool( mode )

	if not constrs then
		--ConstraintEditor.ClearAccess( ply )
		ConstraintEditor.SendDataToClient( NT.SET_SHOWN_CONSTRS, {}, ply )
		if tool then tool:SetStage( 0 ) end
		return
	end
	if tool then tool:SetStage( 1 ) end

	for constrID, constr in pairs( constrs ) do
		ConstraintEditor.SetAccess( ply, constrID, true, constr )
	end
	ConstraintEditor.SendDataToClient( NT.SET_SHOWN_CONSTRS, surfaceConstrsData, ply )

end


function ConstraintEditor.GetEditedEntity( ply )

	return ConstraintEditor.EditedEnts[ply]

end


--------------------------------
--  Constraint Manipulation   --
--------------------------------


-- Try to get the descriptor of the constraint type represented by the argument
function ConstraintEditor.GetConstrDescriptor( a )

	local constrType = isstring( a ) and a or ( istable( a ) or isentity( a ) ) and a.Type

	local desc = duplicator.ConstraintType[constrType]

	if desc then return desc, constrType end

end


-- First returned table contains lists of creation IDs of ent's valid constraints.
-- The keys used to access those lists are constraint types.
-- Second returned table's keys are creation IDs, values are constraint entities
function ConstraintEditor.GetEntSurfaceConstrsData( ent )

	if not ( isentity( ent ) and ( ent:IsValid() or ent:IsWorld() ) ) then return false end

	local surfaceConstrsData = {}
	local constrs = {}
	local constrTable = constraint.GetTable( ent )

	for _, constrData in ipairs( constrTable ) do

		local constr = constrData.Constraint or NULL

		local surfaceConstrData, constrType, constrID = ConstraintEditor.GetSurfaceConstrData( constr )
		if constrID then
			surfaceConstrsData[constrType] = surfaceConstrsData[constrType] or {}
			surfaceConstrsData[constrType][constrID] = surfaceConstrData[constrType][constrID]
			constrs[constrID] = constr
		end
	end

	return surfaceConstrsData, constrs

end


function ConstraintEditor.GetSurfaceConstrData( constr )

	if not constr then return end

	local constrType	= constr.Type
	local constrID		= constr.GetCreationID and constr:GetCreationID()

	if constr.CEInvalid or not ( constr:IsValid() and constrType and constrID ) then return end

	return {
		[constrType] = {
			[constrID] = {
				constr.Ent1, constr.Ent2 or constr.Ent4, constr.LPos1 or constr.LPos, constr.LPos2 or constr.LPos4, constr.WPos2, constr.WPos3, constr.LocalAxis
			}
		}
	}, constrType, constrID

end


function ConstraintEditor.GetConstrData( a, coded )

	local desc, constrType = ConstraintEditor.GetConstrDescriptor( a )

	if not desc then return end

	local data	= {}

	local args = desc.Args
	for i, arg in ipairs( args ) do
		local key = coded and i or arg
		local v = a[arg]
		if v == nil then
			v = constrArgsDefaults[arg]
		end
		data[key] = v
	end

	if next( data ) == nil then return end

	data.constrID = a.constrID or a.GetCreationID and a:GetCreationID()
	data.Type = constrType

	return data, desc

end


function ConstraintEditor.DecodeConstrData( data, desc )

	desc = desc or ConstraintEditor.GetConstrDescriptor( data )

	if not desc then return end

	for i, arg in ipairs( desc.Args ) do
		data[arg] = data[i] or data[arg]
		data[i]	  = nil
	end

	return data

end


function ConstraintEditor.EncodeConstrData( data, desc )

	desc = desc or ConstraintEditor.GetConstrDescriptor( data )

	if not desc then return end

	for i, arg in ipairs( desc.Args ) do
		data[i]		= data[arg] or data[i]
		data[arg]	= nil
	end

	return data

end


-- Prevent some unsafe data manipulation
function ConstraintEditor.SanitizeConstrData( constrData, ply )
	for k, v in pairs( constrData ) do
		local t = type( v )
		if t == "Player" then
			constrData[k] = nil
		end
		if ply and t == "Entity" then
			constrData[k] = ConstraintEditor.AccessEntity( ply, v, 3 ) or nil
		end
	end
end


-- Completes any value newData is missing based on data available in constr
-- Returns true if the completed data is different than the data available in constr, false otherwise
-- TODO: add type check
function ConstraintEditor.CompleteConstrData( constr, newData, ply )

	local data, desc = ConstraintEditor.GetConstrData( constr, true )

	local isChanged = false

	for i, arg in ipairs( desc.Args ) do

		if newData[i] == nil then newData[i] = data[i] end

		if isentity( newData[i] ) and isfunction( newData[i].GetClass ) and newData[i]:GetClass() == "gmod_anchor" then -- without this sliders get deleted if they are constrained to world

			newData[i] = duplicator.CreateEntityFromTable( ply, duplicator.CopyEntTable( newData[i] ) )

		end

		isChanged = isChanged or newData[i] ~= data[i]

	end

	return isChanged

end


--------------------------------
--     Entity change (WIP)    --
--------------------------------


-- TODO: check pulley since it doesn't seem to update LPos properly ?
-- it has something to do with Ent4 not being used? while Ent1 works properly?

-- Tries to udate the constrData and buildInfo from a constraint considering we want to change its i-th entity to newEnt
-- Returns true only if the data has been updated
local function auxChangeConstrEnt( constrData, buildInfo, newEnt, i, entKey, posKeys )

	local ent = constrData[entKey]
	if not isentity( ent ) or not isentity( newEnt ) or ent == newEnt then return false end
	constrData[entKey] = newEnt

	local isFirst = i == 1
	local entAng, entPos, newEntAng, newEntPos = ent:GetAngles(), ent:GetPos(), newEnt:GetAngles(), newEnt:GetPos()

	if buildInfo then

		local buildAng = buildInfo[entKey .. "Ang"]
		if isangle( buildAng ) then
			-- Get the "equivalent" rotation for the new entity, update buildInfo accordingly
			local newBuildAng = newEnt:AlignAngles( entAng, buildAng )
			buildInfo[entKey .. "Ang"] = newBuildAng

			-- Restore ent's angles from those at constraint creation, move and turn newEnt as if it was parented to ent
			-- This is needed for the local positions changes that come afterwards
			local newEntLocalPos = ent:WorldToLocal( newEntPos )
			ent:SetAngles( buildAng )
			newEnt:SetAngles( buildAng )
			newEnt:SetPos( ent:LocalToWorld( newEntLocalPos ) )
		end

		local entityPos = buildInfo.EntityPos
		if isvector( entityPos ) then
			-- buildInfo.EntityPos is the vector from the second entity's pos to the first entity's pos
			-- Get the "equivalent" vector for the new entity, update buildInfo accordingly
			entityPos[ isFirst and "Sub" or "Add" ]( entityPos, newEnt:GetPos() - ent:GetPos() )
		end

	end

	-- Try to convert all the LPoses and LocalAxis to newEnt coordinate space
	-- Note that LocalAxis is always in first ent's coordinate space
	for _, posKey in ipairs( { posKeys[i], isFirst and "LocalAxis" or nil } ) do
		if isvector( constrData[posKey] ) then
			constrData[posKey] = newEnt:WorldToLocal( ent:LocalToWorld( constrData[posKey] ) )
		end
	end

	ent:SetPos( entPos )
	ent:SetAngles( entAng )
	newEnt:SetPos( newEntPos )
	newEnt:SetAngles( newEntAng )

	return true

end



-- 1. Change ent to entChange[ent] if it exists, does not work with ragdolls
-- 2. With lower priority, change first ent to entChange[1] and second ent to entChange[2] if they exist
-- The constraint (constr) is left untouched (except if delete is true). Instead, we create a new constraint with the updated data.
-- this function does not freeze the entities hence it's unsafe when used alone
local function auxChangeConstrEnts( entChange, constr, ply, delete, createNew )

	if not constr then return end
	if constr.Constraint then constr = constr.Constraint end -- if constr is a table use entity instead

	local buildInfo = table.Copy( constr.BuildDupeInfo or {} )
	if not buildInfo then return false end

	local constrData = ConstraintEditor.GetConstrData( constr, true )
	--ConstraintEditor.CompleteConstrData( constr, constrData, ply )

	ConstraintEditor.DecodeConstrData( constrData )
	local entKeys, posKeys = findConstrWeirdKeys( constrData )
	local update = false

	for i, entKey in ipairs( entKeys ) do

		local ent = constrData[entKey]
		local newEnt = entChange[ent] or entChange[i]
		update = auxChangeConstrEnt( constrData, buildInfo, newEnt, i, entKey, posKeys ) or update

	end

	ConstraintEditor.EncodeConstrData( constrData )

	if not createNew then return constrData, buildInfo end

	local newConstr = update and ConstraintEditor.CreateConstr( constr, constrData, buildInfo, ply, not delete )

	ConstraintEditor.HandleNewConstrAccess( constr, newConstr, ply, delete )
	--local newConstr = update and ConstraintEditor.CreateWithBuildInfo( constr, buildInfo, desc.Func, constrData, ply )
	--if delete and IsValid( newConstr ) then SafeRemoveEntity( constr ) end

end


-- Lets you transfer constraints between entities, if they break by doing so, does nothing
-- entChange table can contain ent indices and/or index 1 and 2 (to change constraint's first/second entities), while values are always entities
-- Apply auxChangeConstrEnts to each constraint in constrs (from constraint.GetTable for example) considering entChange table
function ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, delete )

	for _, newEnt in pairs( entChange ) do
		if not ( isentity( newEnt ) and ( newEnt:IsWorld() or newEnt:IsValid() ) ) then return false end
	end

	local motionRestores = disableEntsMotions( entChange )

	for _, constr in pairs( constrs ) do

		auxChangeConstrEnts( entChange, constr, ply, delete, true )

	end

	restoreEntsMotions( motionRestores )

end



--------------------------------
--   Constraint Creation (+)  --
--------------------------------



local function createConstrWithDuplicator( factory, constrData, ply, constrType )
	local ok, constr, rope = pcall( factory, unpack( constrData, 1, #constrData ) )
	if ply and not ( ok and constr ) then
		ply:ChatPrint( "Constraint Editor - ERROR: Failed to create " .. constrType or "unknown type" .. " constraint properly!" )
	end
	return constr, rope
end


-- Based on AdvDupe2's CreateConstraintFromTable implementation
-- Credits: Advanced Duplicator 2 team (https://github.com/wiremod/advdupe2)
-- TODO: move stuff away such as physobject motion enabling/disabling
function ConstraintEditor.CreateWithBuildInfo( constrType, buildInfo, duplicatorFunc, constrData, ply )

	--[[
	local firstEnt, secondEnt = constrData[1], constrType ~= "Keepupright" and constrData[2] or game.GetWorld()
	local firstValid, secondValid = IsValid( firstEnt ), IsValid( secondEnt )

	local firstPosReset, firstAngReset, FirstPhys, Bone1, Bone1Index, ReEnableFirst, Bone1PosReset, Bone1AngReset
	local secondPosReset, secondAngReset, SecondPhys, Bone2, Bone2Index, ReEnableSecond, Bone2PosReset, Bone2AngReset
	]]

	local data = { {}, {} }
	local first, second = data[1], data[2]
	first.ent, second.ent = constrData[1], constrType ~= "Keepupright" and constrData[2] or game.GetWorld()

	if buildInfo then

		--[[
		if firstEnt ~= nil and secondValid and buildInfo.EntityPos ~= nil then
			SecondPhys, ReEnableSecond = setEntMotion( secondEnt, false )
			if IsValid( SecondPhys ) then
				secondPosReset, secondAngReset = secondEnt:GetPos(), secondEnt:GetAngles()
				secondEnt:SetPos( firstEnt:GetPos() - buildInfo.EntityPos )
				if buildInfo.Bone2 then
					Bone2Index = buildInfo.Bone2
					Bone2 = secondEnt:GetPhysicsObjectNum( Bone2Index )
					if IsValid( Bone2 ) then
						Bone2PosReset, Bone2AngReset = Bone2:GetPos(), Bone2:GetAngles()
						Bone2:EnableMotion(false)
						Bone2:SetPos(secondEnt:GetPos() + buildInfo.Bone2Pos)
						Bone2:SetAngles(buildInfo.Bone2Angle)
					end
				end
			end
		end

		if firstValid and buildInfo.Ent1Ang ~= nil then
			FirstPhys, ReEnableFirst = setEntMotion( firstEnt, false )
			if IsValid( FirstPhys ) then
				firstPosReset, firstAngReset = firstEnt:GetPos(), firstEnt:GetAngles()
				firstEnt:SetAngles(buildInfo.Ent1Ang)
				if buildInfo.Bone1 then
					Bone1Index = buildInfo.Bone1
					Bone1 = firstEnt:GetPhysicsObjectNum(Bone1Index)
					if IsValid( Bone1 ) then
						Bone1PosReset, Bone1AngReset = Bone1:GetPos(), Bone1:GetAngles()
						Bone1:EnableMotion(false)
						Bone1:SetPos(firstEnt:GetPos() + buildInfo.Bone1Pos)
						Bone1:SetAngles(buildInfo.Bone1Angle)
					end
				end
			end
		end

		if secondValid then
			if buildInfo.Ent2Ang ~= nil then
				secondEnt:SetAngles(buildInfo.Ent2Ang)
			elseif buildInfo.Ent4Ang ~= nil then
				secondEnt:SetAngles(buildInfo.Ent4Ang)
			end
		end
		]]

		for i = 2, 1, -1 do

			local entData = data[i]

			local ent = entData.ent
			if not IsValid( ent ) then continue end
			entData.valid = true

			local buildData = ( i == 1 and buildInfo.Ent1Ang ) or ( i == 2 and first.ent and buildInfo.EntityPos )
			if not buildData then continue end

			entData.phys, entData.reEnable = setEntMotion( ent, false )
			if not IsValid( entData.phys ) then continue end

			entData.posReset, entData.angReset = ent:GetPos(), ent:GetAngles()
			if i == 1 then ent:SetAngles( buildData ) else ent:SetPos( first.ent:GetPos() - buildData ) end

			entData.boneIndex = buildInfo["Bone" .. i]
			if not entData.boneIndex then continue end

			local bone = ent:GetPhysicsObjectNum( entData.boneIndex )
			entData.bone = bone
			if not IsValid( bone ) then continue end

			entData.bonePosReset, entData.boneAngReset = bone:GetPos(), bone:GetAngles()
			bone:EnableMotion( false )
			bone:SetPos( ent:GetPos() + buildInfo["Bone" .. i .. "Pos"] )
			bone:SetAngles( buildInfo["Bone" .. i .. "Angle"] )
		end

		if second.valid then
			if buildInfo.Ent2Ang ~= nil then
				second.ent:SetAngles(buildInfo.Ent2Ang)
			elseif buildInfo.Ent4Ang ~= nil then
				second.ent:SetAngles(buildInfo.Ent4Ang)
			end
		end

	end

	local constr, rope = createConstrWithDuplicator( duplicatorFunc, constrData, ply, constrType )

	if constr then constr.BuildDupeInfo = table.Copy( buildInfo ) end

	-- Move the entities back after constraining them. No point in moving the world though.


	for _, entData in ipairs( data ) do
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

	--[[
	if firstPosReset then
		firstEnt:SetPos( firstPosReset )
		firstEnt:SetAngles( firstAngReset )
		if Bone1Index ~= 0 and Bone1PosReset then
			Bone1:SetPos( Bone1PosReset ) -- + firstPosReset
			Bone1:SetAngles( Bone1AngReset )
		end
	end

	if ReEnableFirst and IsValid(FirstPhys) then
		FirstPhys:EnableMotion(true)
	end

	if secondPosReset then
		secondEnt:SetPos( secondPosReset )
		secondEnt:SetAngles( secondAngReset )
		if Bone2Index ~= 0 and Bone2PosReset then
			Bone2:SetPos( Bone2PosReset ) -- + secondPosReset
			Bone2:SetAngles( Bone2AngReset )
		end
	end

	if ReEnableSecond and IsValid( SecondPhys ) then
		SecondPhys:EnableMotion(true)
	end
	]]

	--[[
	if constr and constr.length then
		constr.length = constr.length
	end -- Fix for weird bug with ropes
	]]

	return constr, rope
end


-- Tries to create a new constraint.
-- This is long mostly because of having to handle wire hydraulics
function ConstraintEditor.CreateConstr( constr, constrData, buildInfo, ply, enforceLimits, addUndo )

	buildInfo = buildInfo or ( constr and constr.BuildDupeInfo )

	local data, desc = ConstraintEditor.GetConstrData( constr, true )

	local updConstrData, updBuildInfo = auxChangeConstrEnts( { constrData[1], constrData[2] }, constr, ply, false, false )
	constrData	= updConstrData or constrData
	buildInfo	= updBuildInfo or buildInfo

	local wireController

	if data.Type == "WireHydraulic" then
		for i, arg in pairs( desc.Args ) do
			if arg == "MyCrtl" then
				wireController = constrData[i] and Entity( constrData[i] )
				constrData[i] = nil
			end
		end
	end

	local newConstr, rope

	if buildInfo then
		-- Uses BuildDupeInfo (needs advanced duplicator 2 to work)
		newConstr, rope = ConstraintEditor.CreateWithBuildInfo( constr, buildInfo, desc.Func, constrData, ply )
	else
		-- Uses normal duplicator. Has information loss (e.g Ent1 and Ent2's relative position is lost)
		newConstr, rope = createConstrWithDuplicator( desc.Func, constrData, ply, constr.Type )
	end

	local limitSafe = ConstraintEditor.DoLimitsUndoCleanup( ply, newConstr, rope, enforceLimits, addUndo )
	if not limitSafe then return end

	if wireController and wireController:GetClass() == "gmod_wire_hydraulic" then
		for _, ent in ipairs( { wireController.constraint, wireController.rope } ) do
			if isentity( ent ) then
				ent.MyCrtl = -1 -- if set to nil it's uneditable afterwards
				wireController:DontDeleteOnRemove( ent )
				ent:DontDeleteOnRemove( wireController )
			end
		end

		wireController:SetConstraint( newConstr, rope )
		for _, ent in ipairs( { newConstr, rope } ) do
			if isentity( ent ) then wireController:DeleteOnRemove( ent ) end -- check if entity exists since rope is deleted if width = 0 ?
		end

		newConstr.MyCrtl = wireController:EntIndex()
		constr.MyCrtl = -1
	end

	return newConstr, rope

end


-- Links together constraint data handling, constraint creation, player permissions, ...
function ConstraintEditor.UpdateConstr( constr, newData, ply, sanitize, duplicate )

	if sanitize then ConstraintEditor.SanitizeConstrData( newData, ply ) end

	local isChanged = ConstraintEditor.CompleteConstrData( constr, newData )
	if not ( isChanged or duplicate ) then return end

	local newConstr = ConstraintEditor.CreateConstr( constr, newData, nil, ply, duplicate )

	ConstraintEditor.HandleNewConstrAccess( constr, newConstr, ply, not duplicate, true )

end


function ConstraintEditor.HandleNewConstrAccess( constr, newConstr, ply, delete, setEdited )

	if not ( isentity( newConstr ) and newConstr:IsValid() ) then return false end

	-- Give permissions to edit the new constraint to all players that had access to the old one.
	-- Comes before the "SetEditedConstr" to prevent 2 nodes appearing for the same constraint in ply's editor
	ConstraintEditor.TransferAccess( constr, newConstr )

	if not delete then return end

	-- TODO: check if players other than ply are editing the constr so that editor stays open for them
	if setEdited and ply then ConstraintEditor.SetEditedConstr( newConstr, ply ) end

	-- Comes after the "SetEditedConstr" to keep the node open in ply's menu in some specific cases
	ConstraintEditor.DeleteConstr( constr )

end


--------------------------------
--  Limits, cleanup, undo...  --
--------------------------------


-- You have to create the constraint first to know if it's a ropeconstraint or not
-- Note that ropeconstraints name come from the fact that they involve keyframe_rope entities
function ConstraintEditor.DoLimitsUndoCleanup( ply, constr, rope, enforceLimits, addUndo )

	if not ( constr or rope ) then return end

	local cleanupType = ConstraintEditor.GetCleanupType( constr, rope )

	if ply then

		if not game.SinglePlayer() and enforceLimits and ply:GetCount( cleanupType ) >= cvars.Number( "sbox_max" .. cleanupType, 0 ) then
			ply:LimitHit( cleanupType )
			SafeRemoveEntity( constr )
			SafeRemoveEntity( rope )
			return false
		end

		if addUndo then
			undo.Create( constr.Type )
				undo.SetPlayer( ply )
				undo.AddEntity( constr or rope )
			undo.Finish()
		end

		ply:AddCount( cleanupType, constr or rope )
	end

	-- does this work if ply is nil?
	cleanup.Add( ply, cleanupType, constr or rope )

	return true

end


function ConstraintEditor.GetCleanupType( constr, rope )
	if isentity( rope ) and rope:IsValid() then
		return "ropeconstraints"
	elseif isentity( constr ) and constr:IsValid() then
		return constr.Type == "NoCollide" and "nocollide" or "constraints"
	end
end



--------------------------------
--       Network things       --
--------------------------------


function ConstraintEditor.SendDataToClient( tag, data, ply, ent )

	if not isnumber( tag ) then return end
	if not ( isentity( ply ) and ply:IsPlayer() ) then return end

	net.Start( "constraint_editor_net" )
		net.WriteUInt( tag, BIT_COUNT_TAG )
		if istable( data ) then
			net.WriteTable( data )
		elseif isnumber( data ) then
			net.WriteUInt( data, BIT_COUNT_CONSTR_ID )
		elseif isentity( data ) then
			net.WriteEntity( data )
		end
	net.Send( ply )

end


function ConstraintEditor.SetEditedConstr( constr, ply )

	if not ply then return end
	local tool = ply:GetTool( mode )

	if not constr then
		if tool then tool:SetStage( 1 ) end
		return
	end

	local constrData, desc = ConstraintEditor.GetConstrData( constr, true )
	if not ( constrData and desc ) then return end

	if tool then tool:SetStage( 2 ) end

	ConstraintEditor.SendDataToClient( NT.SET_MENU_DEEP_DATA, { constrData, desc.Args }, ply )

end


function ConstraintEditor.LeftClick( ent, ply )
	ConstraintEditor.SendDataToClient( NT.LEFT_CLICK, ent, ply )
end

function ConstraintEditor.RightClick( ply )
	ConstraintEditor.SendDataToClient( NT.RIGHT_CLICK, nil, ply )
end

function ConstraintEditor.Reload( ply )
	ConstraintEditor.SendDataToClient( NT.RELOAD, nil, ply )
end


local function getNetConstr( ply )
	local constrID = net.ReadUInt( BIT_COUNT_CONSTR_ID )
	local constr = ConstraintEditor.Access( ply, constrID )
	if not constr then ConstraintEditor.SendDataToClient( NT.FORGET_CONSTR, constrID, ply ) return end
	if not IsValid ( constr ) then ConstraintEditor.ForgetConstr( constrID ) return end
	return constr
end


local netFunctions = {

	[NT.UNSET_EDITED_ENTITY] = function( ply )
		ConstraintEditor.SetEditedEntity( nil, ply )
	end,

	[NT.SET_EDITED_ENTITY] = function( ply )
		local ent = net.ReadEntity()
		ConstraintEditor.SetEditedEntity( ent, ply )
	end,

	[NT.GET_MENU_DEEP_DATA] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.SetEditedConstr( constr, ply ) end
	end,

	[NT.REMOVE_CONSTR] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.DeleteConstr( constr ) end
	end,

	[NT.UPDATE_CONSTR] = function( ply )
		local constr = getNetConstr( ply )
		local newData = net.ReadTable()
		PrintTable( newData )
		if constr then ConstraintEditor.UpdateConstr( constr, newData, ply, true ) end
	end,

	[NT.DUPLIC_CONSTR] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.UpdateConstr( constr, {}, ply, true, true ) end
	end,

	[NT.TRANSFER_CONSTR_ENTS] = function( ply )
		local constr = getNetConstr( ply )
		local newEnt = ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )
		local editedEnt = ConstraintEditor.GetEditedEntity( ply )
		if not ( newEnt and editedEnt ) then return end
		ConstraintEditor.SetEditedConstr( nil, ply )
		ConstraintEditor.ChangeConstrsEnts( { [editedEnt] = newEnt }, { constr }, ply, true )
	end,

	[NT.TRANSFER_CONSTRS_ENTS] = function( ply )
		local newEnt = ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )
		local editedEnt = ConstraintEditor.GetEditedEntity( ply )
		if not ( newEnt and editedEnt ) then return end
		ConstraintEditor.SetEditedConstr( nil, ply )
		ConstraintEditor.ChangeConstrsEnts( { [editedEnt] = newEnt }, constraint.GetTable( editedEnt ), ply, true )
	end,
}

-- Client safety checks are here
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		if not ( ply and ply:IsPlayer() ) then return end

		local tag = net.ReadUInt( BIT_COUNT_TAG )

		netFunctions[tag]( ply )

	end )

end
