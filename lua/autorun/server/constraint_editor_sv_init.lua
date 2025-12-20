util.AddNetworkString( "constraint_editor_net" )

local mode = "constraint_editor" -- name of the tool

local NT = ConstraintEditor.NetTags
local BIT_COUNT_TAG			= ConstraintEditor.NetBitCounts.TAG
local BIT_COUNT_CONSTR_ID	= ConstraintEditor.NetBitCounts.CONSTR_ID
local TABLES_CLEANUP_CD		= 30 -- cooldown for table cleanup

--------------------------------
--      Various helpers       --
--------------------------------


local function isConstrLinkedToEnts( constr, entities )
	for ent in pairs( entities or {} ) do
		if ent == constr.Ent1 or ent == ( constr.Ent2 or constr.Ent4 ) then
			return true
		end
	end
	return false
end


local function findConstrWeirdKeys( constrData )
	local ent1, ent2, ent4 = constrData.Ent1, constrData.Ent2, constrData.Ent4
	local LPos1, LPos2, LPos4, LPos, LocalAxis = constrData.LPos1, constrData.LPos2, constrData.LPos4, constrData.LPos, constrData.LocalAxis
	local entKeys = {
		ent1 and "Ent1" or nil,
		ent2 and "Ent2" or ent4 and "Ent4" or nil
	}
	local posKeys = {
		[1] = {
			LPos1 and "LPos1" or nil, --or LPos and "LPos" or nil,
			LocalAxis and "LocalAxis" or nil
		},
		[2] = {
			LPos2 and "LPos2" or LPos4 and "LPos4" or LPos and "LPos" or nil
		}
	}

	return entKeys, posKeys
end


function ConstraintEditor.FindConstrsInEnts( entities, constrType )

	local constrs = {}
	local found = {}

	for ent in pairs( entities or {} ) do

		local c = constrType and constraint.FindConstraints( ent, constrType ) or constraint.GetTable( ent )

		for _, constrTable in ipairs( c ) do
			local constr = constrTable.Constraint
			if constr and not found[constr] then
				table.insert( constrs, constrTable )
				found[constr] = true
			end
		end
	end
	return constrs
end


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


-- If one of the args is nil for a constraint, this table gives you a lot of default, fallback values
local constrArgsDefaults = {

	Weld = { nocollide = false },

	Ent1			= NULL,
	Ent2			= NULL,
	Ent4			= NULL,
	Bone1			= 0,
	Bone2			= 0,

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

	LocalAxis		= vector_origin,
	LPos			= vector_origin,
	LPos1			= vector_origin,
	LPos2			= vector_origin,
	WPos2			= vector_origin,
	WPos3			= vector_origin,
	LPos4			= vector_origin,
}


local function defaultizeConstrData( constrData )
	for arg, v in pairs( constrData ) do
		if constrArgsDefaults[arg] ~= nil then
			constrData[arg] = constrArgsDefaults[arg]
		end
	end
end

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
		if isConstrLinkedToEnts( newConstr, ConstraintEditor.GetEditedEntities( ply ) ) then
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

	ConstraintEditor.lastTablesCleanup = CurTime()

	for constrID, data in pairs( ConstraintEditor.KnownConstrs ) do
		if not data or not IsValid( data.ent ) or next( data.allowedPlayers ) == nil then
			ConstraintEditor.ForgetConstr( constrID )
		end
	end

	for ply, entities in pairs( ConstraintEditor.EditedEnts ) do
		if not IsValid( ply ) then
			ConstraintEditor.ClearAccess( ply )
		else
			for ent in pairs( entities ) do
				if not IsValid( ent ) then
					ConstraintEditor.EditedEnts[ply][ent] = nil
				end
			end
		end
	end

end


-- Don't clean up tables if it was already done not long ago
function ConstraintEditor.TryCleanupTables()
	if CurTime() - ( ConstraintEditor.lastTablesCleanup or 0 ) < TABLES_CLEANUP_CD then return end

	ConstraintEditor.CleanupTables()
end


-- Deletes a constraint and data associated to its constrID
function ConstraintEditor.DeleteConstr( constr )
	constr.CEInvalid = true
	local constrID = constr:GetCreationID()
	ConstraintEditor.ForgetConstr( constrID )
	SafeRemoveEntity( constr )
end


-- Let ply edit all constraints attached to ent
function ConstraintEditor.AddEditedEntity( ent, ply )

	if not ConstraintEditor.AccessEntity( ply, ent, 1 ) then return end

	if not ConstraintEditor.EditedEnts[ply] then ConstraintEditor.EditedEnts[ply] = {} end

	ConstraintEditor.EditedEnts[ply][ent] = ent

	local surfaceConstrsData, constrs = ConstraintEditor.GetEntSurfaceConstrsData( ent )
	local tool = ply.GetTool and ply:GetTool( mode )

	if tool then tool:SetStage( 1 ) end

	for constrID, constr in pairs( constrs ) do
		ConstraintEditor.SetAccess( ply, constrID, true, constr )
	end
	ConstraintEditor.SendDataToClient( NT.ADD_SHOWN_CONSTRS, surfaceConstrsData, ply )

end


function ConstraintEditor.ClearEditedEntities( ply )

	ConstraintEditor.ClearAccess(ply)
	ConstraintEditor.SendDataToClient( NT.CLEAR_SHOWN_CONSTRS, nil, ply )
	local tool = ply.GetTool and ply:GetTool( mode )
	if tool then tool:SetStage( 0 ) end

end


function ConstraintEditor.GetEditedEntities( ply )

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
				constr.Ent1, constr.Ent2 or constr.Ent4, constr.LPos1, constr.LPos2 or constr.LPos4 or constr.LPos, constr.WPos2, constr.WPos3, constr.LocalAxis
			}
		}
	}, constrType, constrID

end


function ConstraintEditor.GetConstrData( a, numerical, str )

	local desc, constrType = ConstraintEditor.GetConstrDescriptor( a )

	if not desc then return end

	if not ( numerical or str ) then str = true end

	local data	= {}

	local args = desc.Args
	for i, arg in ipairs( args ) do
		local v = a[arg]
		if v == nil then v = constrArgsDefaults[arg] end
		if numerical then data[i] = v end
		if str then data[arg] = v end
	end

	if next( data ) == nil then return end

	data.constrID = a.constrID or a.GetCreationID and a:GetCreationID()
	data.Type = constrType

	return data, desc

end


function ConstraintEditor.TransformConstrDataKeys( data, desc, numerical, str )

	desc = desc or ConstraintEditor.GetConstrDescriptor( data )

	if not desc then return end

	for i, arg in ipairs( desc.Args ) do

		if data[arg] ~= nil then
			if numerical then data[i] = data[arg] else data[i] = nil end
			if not str then data[arg] = nil end
		elseif data[i] ~= nil then
			if str then data[arg] = data[i] else data[arg] = nil end
			if not numerical then data[i] = nil end
		end

	end

	return data

end


-- Prevent some unsafe data manipulation
-- constrData can have str or numerical keys
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


-- Completes any value constrData is missing based on data available in constr
-- Returns true if the completed data is different than the data available in constr, false otherwise
-- TODO: add type check
function ConstraintEditor.CompleteConstrData( refConstrData, constrData, desc, ply )

	local isChanged = false

	for i, arg in ipairs( desc.Args ) do

		if constrData[arg] == nil then constrData[arg] = refConstrData[arg] end

		local val = constrData[arg]

		if isentity( val ) and isfunction( val.GetClass ) and val:GetClass() == "gmod_anchor" then -- without this sliders get deleted if they are constrained to world

			constrData[arg] = duplicator.CreateEntityFromTable( ply, duplicator.CopyEntTable( val ) )

		end

		isChanged = isChanged or constrData[arg] ~= refConstrData[arg]

	end

	if not constrData.Type then constrData.Type = refConstrData.Type end

	return isChanged

end


local function LocalToWorldConstrData( constrData, overwrite )

	local entKeys, posKeys = findConstrWeirdKeys( constrData )
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


local function WorldToLocalConstrData( worldConstrData, entities, overwrite )

	local entKeys, posKeys = findConstrWeirdKeys( worldConstrData )
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
--    BuildDupeInfo helpers   --
--------------------------------


local function saveBuildDupeInfo( BuildDupeInfo, data, entKeys )
	if not BuildDupeInfo then return end
	local first, second = data[1], data[2]
	if first and second then BuildDupeInfo.EntityPos = first.ent:GetPos() - second.ent:GetPos() end
	for i, entData in pairs( data ) do
		BuildDupeInfo[entKeys[i] .. "Pos"] = entData.ent:GetPos()
		BuildDupeInfo[entKeys[i] .. "Ang"] = entData.ent:GetAngles()
	end
end


local function copyBuildDupeInfo( BuildDupeInfo )
	if not BuildDupeInfo then return end
	local newBuildDupeInfo = {}
	for k, v in pairs( BuildDupeInfo ) do
		if isvector( v ) then newBuildDupeInfo[k] = Vector( v )
		elseif isangle( v ) then newBuildDupeInfo[k] = Angle( v ) end
	end
	return newBuildDupeInfo
end


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

-- modified from advdupe2
-- current version works perfectly if world is not involved?
-- removes positional/angles error: puts constraint and associated entities back to their initial state
local function applyBuildDupeInfo( BuildDupeInfo, constrData, entKeys, staticEntIndex )

	if not BuildDupeInfo then return end

	entKeys = entKeys or findConstrWeirdKeys( constrData )

	local firstEnt, secondEnt = constrData[entKeys[1]], constrData[entKeys[2]] or game.GetWorld()
	--TODO: verify this line is useful
	if firstEnt == secondEnt then return end

	local data = { {}, {} }
	local first, second = data[1], data[2]

	first.ent, second.ent = firstEnt, secondEnt
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
		local entityPos = ( ent == followerEnt and followedEnt and BuildDupeInfo.EntityPos )

		entData.posReset, entData.angReset = ent:GetPos(), ent:GetAngles()
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

	if second.valid then
		local ang = BuildDupeInfo.Ent2Ang or BuildDupeInfo.Ent4Ang
		if ang then second.ent:SetAngles( ang ) end
	end

	-- dirty hack
	if staticEntIndex then

		local followed = data[staticEntIndex]
		local follower = data[1 + staticEntIndex % 2]

		local localAng = followed.ent:WorldToLocalAngles( follower.ent:GetAngles() )
		local localPos = followed.ent:WorldToLocal( follower.ent:GetPos() )

		restoreAfterBuildDupeInfo( { followed } )

		follower.ent:SetAngles( followed.ent:LocalToWorldAngles( localAng ) )
		follower.ent:SetPos( followed.ent:LocalToWorld( localPos ) )

		saveBuildDupeInfo( BuildDupeInfo, data, entKeys )

		data.followed = nil

	end

	return data

end


--------------------------------
--     Entity change (WIP)    --
--------------------------------

-- does not restore positions
local function convertApplyBuildDupeInfo( BuildDupeInfo, constrData, newEnt, i, entKeys )

	local entKey = entKeys[i]
	local data
	local j = 1 + i % 2
	local ent, otherEnt = constrData[entKey], constrData[entKeys[j]]

	-- when newEnt == otherEnt things break
	if BuildDupeInfo and not ( newEnt == otherEnt or ent:IsWorld() and otherEnt:IsWorld() ) then

		local isFirst = i == 1

		local entAng = ent:GetAngles()
		local newEntLocalPos = ent:WorldToLocal( newEnt:GetPos() )

		local staticEntIndex = ( newEnt:IsWorld() and i ) or ( otherEnt:IsWorld() and j )
		data = applyBuildDupeInfo( BuildDupeInfo, constrData, entKeys, staticEntIndex )
		if data then data.new = {
			ent			= newEnt,
			posReset	= newEnt:GetPos(),
			angReset	= newEnt:GetAngles()
		} end

		if newEnt:IsWorld() then
			BuildDupeInfo.EntityPos = nil
			BuildDupeInfo[entKey .. "Ang"] = nil
		else
			newEnt:SetPos( ent:LocalToWorld( newEntLocalPos ) )
			newEnt:SetAngles( newEnt:AlignAngles( entAng, ent:GetAngles() ) )

			BuildDupeInfo.EntityPos = otherEnt:GetPos() - newEnt:GetPos()
			BuildDupeInfo[entKey .. "Ang"] = newEnt:GetAngles()
			if isFirst then BuildDupeInfo.EntityPos:Negate() end
		end
	end

	return data, { [i] = newEnt, [j] = otherEnt }

end

-- Changes newConstrData by assuming that its i-th entity has been changed from ent to newEnt
-- The objective is that the new constraint (created using constrData) keeps the same behavior, world position and world rotation as the original constraint
-- newConstrData MUST have str keys (such as LPos1, LPos2, etc )
-- Returns true only if some data has been changed

-- TODO: find if it's possible to restore world attached advanced ballsockets properly
local function restoreConstrBehaviorAfterEntChange( constrData, BuildDupeInfo, ent, i, entKeys )

	local entKey = entKeys[i]
	local newEnt = constrData[entKey] or constrData[i]

	if not ( isentity( ent ) and isentity( newEnt ) ) or ent == newEnt then return false end

	constrData[entKey] = ent

	local data, newEntities = convertApplyBuildDupeInfo( BuildDupeInfo, constrData, newEnt, i, entKeys )

	LocalToWorldConstrData( constrData, true )
	constrData[entKey] = newEnt
	WorldToLocalConstrData( constrData, newEntities, true )

	if data then restoreAfterBuildDupeInfo( data ) end

	return true

end


local function imitateConstr( constrData, BuildDupeInfo, ent, i, entKeys )

	local entKey = entKeys[i]
	local newEnt = constrData[entKey] or constrData[i]

	if not ( isentity( ent ) and isentity( newEnt ) ) or ent == newEnt then return false end

	constrData[entKey] = ent

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
		newEnt:SetPos( ent:GetPos() )
		newEnt:SetAngles( ent:GetAngles() )
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



-- Changes constrData by assuming that its respective entities have been modified relative to oldEnts.
-- The original entities must be given in oldEnts, oldEnts can simply be a constrData with str or numerical keys.
-- All of the entities must exist.
-- The objective is that the new constraint (created using constrData) keeps the same behavior, world position and world rotation as the original constraint
-- This function does not freeze the entities hence it's unsafe when used alone
-- Does not work with ragdolls.
local function restoreConstrBehaviorAfterEntsChange( oldEnts, constrData, BuildDupeInfo, transferMode )

	if not ( oldEnts and constrData ) then return end

	local entKeys = findConstrWeirdKeys( constrData )
	local update = false

	local transferFunc = transferMode == 1 and restoreConstrBehaviorAfterEntChange or transferMode == 2 and imitateConstr
	if not transferFunc then return end

	for i, entKey in pairs( entKeys ) do

		local ent	= oldEnts[entKey] or oldEnts[i]
		update = transferFunc( constrData, BuildDupeInfo, ent, i, entKeys ) or update

	end

end


-- Similar to above but changes entities of constr
-- Returns updated constrData, can recreate constr
local function changeConstrEnts( entChange, constr, ply, delete )

	local constrData = ConstraintEditor.GetConstrData( constr )
	local entKeys = findConstrWeirdKeys( constrData )
	local update = false

	for i, entKey in pairs( entKeys ) do

		local ent		= constrData[entKey]
		local newEnt	= ent and entChange[ent] or entChange[i]
		if newEnt then
			update = ( newEnt ~= ent ) or update
			constrData[entKey] = newEnt
		end

	end

	if update then ConstraintEditor.CreateConstrFromConstr( constr, constrData, ply, true, true, delete ) end

	return constrData

end


-- Lets you transfer constraints between entities, if they break by doing so, does nothing
-- entChange table can contain ent indices and/or index 1 and 2 (to change constraint's first/second entities), while values are always entities
-- Apply changeConstrEnts to each constraint in constrs (from constraint.GetTable for example) considering entChange table
function ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, delete )

	PrintTable(entChange)
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


--------------------------------
--   Constraint Creation (+)  --
--------------------------------



local function createConstrBlindly( factory, constrData, ply, constrType )
	local ok, constr, rope = pcall( factory, unpack( constrData, 1, #constrData ) )
	print( ok, constr, rope, "error:", ply and not (ok and constr), "type:", constrType)
	if ply and not ( ok and constr ) then
		PrintTable( constrData )
		ply:ChatPrint( "Constraint Editor - ERROR: Failed to create " .. constrType or "unknown type" .. " constraint properly!" )
	end
	return constr, rope
end


-- Based on AdvDupe2's CreateConstraintFromTable implementation
-- Credits: Advanced Duplicator 2 team (https://github.com/wiremod/advdupe2)
-- TODO: Check if redundant ent motion disabling can be solved (won't have much impact)
local function createConstrAccurate( constrType, constrData, BuildDupeInfo, duplicatorFunc, ply )

	local data = applyBuildDupeInfo( BuildDupeInfo, constrData )

	ConstraintEditor.TransformConstrDataKeys( constrData, nil, true )
	local constr, rope = createConstrBlindly( duplicatorFunc, constrData, ply, constrType )

	if constr and BuildDupeInfo then constr.BuildDupeInfo = table.Copy( BuildDupeInfo ) end

	restoreAfterBuildDupeInfo( data )

	return constr, rope
end



-- Tries to create a new constraint.
-- Handles wire hydraulics problems.
function ConstraintEditor.CreateConstr( constrData, BuildDupeInfo, duplicatorFunc, ply, enforceLimits, addUndo )

	local constrType = constrData.Type

	if not duplicatorFunc then
		local _, desc = ConstraintEditor.GetConstrData( constrData )
		duplicatorFunc = desc.Func
	end

	-- Prevent the usage of a possibly nonexistent hydraulic controller.
	local wireController
	if constrType == "WireHydraulic" then
		wireController = constrData.MyCrtl and Entity( constrData.MyCrtl )
		constrData.MyCrtl = nil
	end

	local newConstr, rope = createConstrAccurate( constrType, constrData, BuildDupeInfo, duplicatorFunc, ply )

	local limitSafe = ConstraintEditor.DoLimitsUndoCleanup( ply, newConstr, rope, enforceLimits, addUndo )
	if not limitSafe then return end

	-- We now need to link the newly created wire hydraulic to the hydraulic controller if it exists.
	if IsValid( wireController ) and wireController:GetClass() == "gmod_wire_hydraulic" then
		for _, ent in ipairs( { wireController.constraint, wireController.rope } ) do
			if isentity( ent ) then
				ent.MyCrtl = -1 -- if set to nil it's uneditable afterwards
				ent:DontDeleteOnRemove( wireController )
				wireController:DontDeleteOnRemove( ent )
			end
		end

		wireController:SetConstraint( newConstr, rope )
		for _, ent in ipairs( { newConstr, rope } ) do
			if isentity( ent ) then wireController:DeleteOnRemove( ent ) end -- check if entity exists since rope does not exist if constr width is 0
		end
		newConstr.MyCrtl = wireController:EntIndex()
	end

	return newConstr, rope

end


-- Links together constraint data handling, constraint creation, player permissions, ...
-- Creates a new constraint assuming newConstrData is constr's constr data thas has been modified.
function ConstraintEditor.CreateConstrFromConstr( constr, newConstrData, ply, restoreBehavior, sanitize, delete, setEdited )

	local constrData, desc = ConstraintEditor.GetConstrData( constr )
	ConstraintEditor.TransformConstrDataKeys( newConstrData, desc, false, true ) -- make sure we use str keys

	if sanitize then ConstraintEditor.SanitizeConstrData( newConstrData, ply ) end

	local isChanged = ConstraintEditor.CompleteConstrData( constrData, newConstrData, desc, ply )
	if delete and not isChanged then return end

	local BuildDupeInfo = copyBuildDupeInfo( constr.BuildDupeInfo )

	local cvar = GetConVar( mode .. "_transfer_mode" )
	local transferMode = cvar and cvar:GetInt() or 1
	if restoreBehavior and isChanged then restoreConstrBehaviorAfterEntsChange( constrData, newConstrData, BuildDupeInfo, transferMode ) end

	local newConstr = ConstraintEditor.CreateConstr( newConstrData, BuildDupeInfo, desc.Func, ply, not delete, not delete )

	ConstraintEditor.HandleNewConstrAccess( constr, newConstr, ply, delete, setEdited )

end


function ConstraintEditor.HandleNewConstrAccess( constr, newConstr, ply, delete, setEdited )

	if not ( isentity( newConstr ) and newConstr:IsValid() ) then return false end

	-- Try to give permissions to edit the new constraint to all players that had access to the old one.
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

	ConstraintEditor.SendDataToClient( NT.SET_EDITOR_DATA, { constrData, desc.Args }, ply )

end

-- Lets the player's editor edit all constraints under the same type as constr at once
-- A constr entity is needed, otherwise a table of known keys per constraint type would be needed.
-- With the current approach only a table of known values per constraint type is needed, and this table already exists.
-- TODO: check this function and related systems (defaultizeConstrData...) work
function ConstraintEditor.SetEditedConstrType( constr, ply )

	if not ply then return end

	local tool = ply:GetTool( mode )

	if not constr then
		if tool then tool:SetStage( 1 ) end
		return
	end

	local constrData, desc = ConstraintEditor.GetConstrData( constr )
	if not ( constrData and desc ) then return end

	-- TODO: make new stage for this edit
	if tool then tool:SetStage( 1 ) end
	constrData.constrID = nil
	defaultizeConstrData( constrData )
	ConstraintEditor.TransformConstrDataKeys( constrData, desc, true )

	ConstraintEditor.SendDataToClient( NT.SET_EDITOR_DATA, { constrData, desc.Args }, ply )

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

	[NT.CLEAR_EDITED_ENTS] = function( ply )
		ConstraintEditor.ClearEditedEntities( ply )
	end,

	[NT.ADD_EDITED_ENTITY] = function( ply )
		local ent = net.ReadEntity()
		ConstraintEditor.AddEditedEntity( ent, ply, true )
	end,

	[NT.GET_CONSTR_DATA] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.SetEditedConstr( constr, ply ) end
	end,

	[NT.GET_DEF_CONSTR_DATA] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.SetEditedConstrType( constr, ply ) end
	end,

	[NT.REMOVE_CONSTR] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.DeleteConstr( constr ) end
	end,

	[NT.UPDATE_CONSTR] = function( ply )
		local constr = getNetConstr( ply )
		local newConstrData = net.ReadTable()
		if constr then ConstraintEditor.CreateConstrFromConstr( constr, newConstrData, ply, true, true, true, true ) end
	end,

	[NT.DUPLIC_CONSTR] = function( ply )
		local constr = getNetConstr( ply )
		if constr then ConstraintEditor.CreateConstrFromConstr( constr, {}, ply ) end
	end,

	[NT.UPDATE_TYPE] = function( ply )
		local constrType = net.ReadString()
		local newConstrData = net.ReadTable()
		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( constrType and newConstrData and editedEnts ) then return end
		local constrs = ConstraintEditor.FindConstrsInEnts( editedEnts, constrType )
		for _, constr in pairs( constrs ) do
			constr = constr.Constraint
			constr = ConstraintEditor.Access( ply, constr:GetCreationID() )
			local constrData = table.Copy( newConstrData )
			if constr then ConstraintEditor.CreateConstrFromConstr( constr, constrData, ply, true, true, true ) end
		end
	end,


	[NT.TRANSFER_CONSTR_ENTS] = function( ply )
		local constr = getNetConstr( ply )
		local newEnt = ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply ) or {}
		if not ( newEnt and editedEnts ) then return end
		local entChange = {}
		for ent in pairs( editedEnts ) do entChange[ent] = newEnt end

		ConstraintEditor.SetEditedConstr( nil, ply )
		-- try transferring and stop once it's done once? (for k ,v ... do if change then return end end)
		ConstraintEditor.ChangeConstrsEnts( entChange, { constr }, ply, true )
	end,

	[NT.TRANSFER_CONSTRS_ENTS] = function( ply )
		local newEnt = ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( newEnt and editedEnts ) then return end
		local entChange = {}
		for ent in pairs( editedEnts ) do entChange[ent] = newEnt end

		local constrs = ConstraintEditor.FindConstrsInEnts( editedEnts )

		ConstraintEditor.SetEditedConstr( nil, ply )
		ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, true )
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
