util.AddNetworkString( "constraint_editor_net" )

local NT = ConstraintEditor.NetTags
local BIT_COUNT_TAG			= ConstraintEditor.NetBitCounts.TAG
local BIT_COUNT_CONSTR_ID	= ConstraintEditor.NetBitCounts.CONSTR_ID

--------------------------------
--    Constraint Accessing    --
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
function ConstraintEditor.TransferAccess( constr, newConstr )

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
		ConstraintEditor.SendDataToClient( NT.ADD_SHOWN_CONSTRS, surfaceConstrData, ply )

	end

end


-- Returns constraint associated with constrID only if it exists and player ply has permissions to edit it
function ConstraintEditor.Access( ply, constrID )

	local data = ConstraintEditor.KnownConstrs[constrID]

	return data and data.allowedPlayers[ply] and data.ent or false

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

	if ent:IsWorld() and not game.SinglePlayer() then return false end

	if ent ~= NULL and not hook.Run( "CanTool", ply, { Entity = ent or NULL }, mode ) then return end

	ConstraintEditor.ClearAccess( ply )

	ConstraintEditor.EditedEnts[ply] = ent

	local surfaceConstrsData, constrs = ConstraintEditor.GetEntSurfaceConstrsData( ent )

	if not constrs then
		--ConstraintEditor.ClearAccess( ply )
		ConstraintEditor.SendDataToClient( NT.SET_SHOWN_CONSTRS, {}, ply )
		return
	end

	for constrID, constr in pairs( constrs ) do
		ConstraintEditor.SetAccess( ply, constrID, true, constr )
	end
	ConstraintEditor.SendDataToClient( NT.SET_SHOWN_CONSTRS, surfaceConstrsData, ply )

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

	if constr.CEInvalid or not ( constr:IsValid() and constrType and constrID ) then return nil end

	return {
		[constrType] = {
			[constrID] = {
				constr.Ent1, constr.Ent2 or constr.Ent4, constr.LPos1 or constr.LPos, constr.LPos2 or constr.LPos4, constr.WPos2, constr.WPos3
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
		data[coded and i or arg] = a[arg]
	end

	if next( data ) == nil then return end

	data.constrID = a.constrID or a.GetCreationID and a:GetCreationID()
	data.Type = constrType

	return data, desc

end


function ConstraintEditor.DecodeConstrData( data )

	local desc = ConstraintEditor.GetConstrDescriptor( data )

	if not desc then return end

	for i, arg in ipairs( desc.Args ) do
		data[arg] = data[i] or data[arg]
		data[i]	  = nil
	end

	return data

end


-- Prevent some unsafe data manipulation
function ConstraintEditor.SanitizeConstrData( constrData )
	for k, v in pairs( constrData ) do
		if type( v ) == "Entity" or type( v ) == "Player" then
			constrData[k] = nil
		end
	end
end


local function createConstrWithDuplicator( factory, constrData, ply, constrType )
	local ok, constr, rope = pcall( factory, unpack( constrData, 1, #constrData ) )
	if ply and not ( ok and constr ) then
		ply:ChatPrint( "Constraint Editor - ERROR: Failed to create " .. constrType or "unknown type" .. " constraint properly!" )
	end
	return constr, rope
end


-- Tries to create a new constraint.
-- This is long mostly because of having to handle wire hydraulics
function ConstraintEditor.CreateConstr( constr, constrData, ply, enforceLimits )

	local buildInfo = constr and constr.BuildDupeInfo

	local data, desc = ConstraintEditor.GetConstrData( constr, true )

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

	local limitSafe, cleanupType = ConstraintEditor.DoPlayerLimits( ply, newConstr, rope, enforceLimits )
	if not limitSafe then return nil, nil, cleanupType end

	if wireController and wireController:GetClass() == "gmod_wire_hydraulic" then
		for _, ent in ipairs( { wireController.constraint, wireController.rope } ) do
			if isentity( ent ) then
				ent.MyCrtl = -1 -- if set to nil it's uneditable afterwards
				wireController:DontDeleteOnRemove( ent )
				ent:DontDeleteOnRemove( wireController )
			end
		end
		wireController:SetConstraint( newConstr, rope )
		wireController:DeleteOnRemove( newConstr )
		wireController:DeleteOnRemove( rope )
		newConstr.MyCrtl = wireController:EntIndex()
		constr.MyCrtl = -1
	end

	return newConstr, rope, cleanupType

end


-- Completes any value newData is missing based on data available in constr
-- Returns true if the completed data is different than the data available in constr, false otherwise
-- todo: add type check
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



-- Links constraint data handling, constraint creation, player permissions, ...
function ConstraintEditor.UpdateConstr( constr, newData, ply, sanitize, duplicate )

	if sanitize then ConstraintEditor.SanitizeConstrData( newData ) end

	local isChanged = ConstraintEditor.CompleteConstrData( constr, newData )
	if not ( isChanged or duplicate ) then return end

	local newConstr, _, cleanupType = ConstraintEditor.CreateConstr( constr, newData, ply, duplicate )

	if not ( isentity( newConstr ) and newConstr:IsValid() ) then return false end

	-- Give permissions to edit the new constraint to all players that had access to the old one.
	-- Comes before the "SetEditedConstr" to prevent 2 nodes appearing for the same constraint in ply's editor
	ConstraintEditor.TransferAccess( constr, newConstr )

	if ply then
		cleanup.Add( ply, cleanupType, newConstr )
		undo.Create( newConstr.Type )
			undo.SetPlayer( ply )
			undo.AddEntity( newConstr )
		undo.Finish()
	end

	if duplicate then return end

	--[[ not used like this?
	undo.Create( newConstr.Type )
	undo.ReplaceEntity( constr, newConstr)
	undo.Finish()
	cleanup.ReplaceEntity( constr, newConstr )
	--]]

	-- todo: check if players other than ply are editing the constr so that editor stays open for them
	if ply then ConstraintEditor.SetEditedConstr( newConstr, ply ) end

	-- Comes after the "SetEditedConstr" to keep the node open in ply's menu in some specific cases
	ConstraintEditor.DeleteConstr( constr )

end


-- Based on AdvDupe2's CreateConstraintFromTable implementation
-- Credits: Advanced Duplicator 2 team (https://github.com/wiremod/advdupe2)
function ConstraintEditor.CreateWithBuildInfo( constr, buildInfo, factory, newData, ply )

	local first, second = constr.Ent1, constr.Ent2 or constr.Ent4
	local firstPosReset, secondPosReset = first:GetPos(), second:GetPos()
	local firstAngReset, secondAngReset = first:GetAngles(), second:GetAngles()
	local firstValid, secondValid = ( first ~= nil and not first:IsWorld() ), ( second ~= nil and not second:IsWorld() )

	local Bone1, Bone1Index, ReEnableFirst, Bone1PosReset, Bone1AngReset
	local Bone2, Bone2Index, ReEnableSecond, Bone2PosReset, Bone2AngReset

	if buildInfo then

		if first ~= nil and secondValid and buildInfo.EntityPos ~= nil then
			local SecondPhys = second:GetPhysicsObject()
			if IsValid( SecondPhys ) then
				ReEnableSecond = SecondPhys:IsMoveable()
				SecondPhys:EnableMotion(false)
				second:SetPos( first:GetPos() - buildInfo.EntityPos )
				if buildInfo.Bone2 then
					Bone2Index = buildInfo.Bone2
					Bone2 = second:GetPhysicsObjectNum( Bone2Index )
					if IsValid( Bone2 ) then
						Bone2PosReset = Bone2:GetPos()
						Bone2AngReset = Bone2:GetAngles()
						Bone2:EnableMotion(false)
						Bone2:SetPos(second:GetPos() + buildInfo.Bone2Pos)
						Bone2:SetAngles(buildInfo.Bone2Angle)
					end
				end
			end
		end

		if firstValid and buildInfo.Ent1Ang ~= nil then
			local FirstPhys = first:GetPhysicsObject()
			if IsValid( FirstPhys ) then
				ReEnableFirst = FirstPhys:IsMoveable()
				FirstPhys:EnableMotion(false)
				first:SetAngles(buildInfo.Ent1Ang)
				if buildInfo.Bone1 then
					Bone1Index = buildInfo.Bone1
					Bone1 = first:GetPhysicsObjectNum(Bone1Index)
					if IsValid( Bone1 ) then
						Bone1PosReset = Bone1:GetPos()
						Bone1AngReset = Bone1:GetAngles()
						Bone1:EnableMotion(false)
						Bone1:SetPos(first:GetPos() + buildInfo.Bone1Pos)
						Bone1:SetAngles(buildInfo.Bone1Angle)
					end
				end
			end
		end

		if secondValid then
			if buildInfo.Ent2Ang ~= nil then
				second:SetAngles(buildInfo.Ent2Ang)
			elseif buildInfo.Ent4Ang ~= nil then
				second:SetAngles(buildInfo.Ent4Ang)
			end
		end
	end

	local newConstr, rope = createConstrWithDuplicator( factory, newData, ply, constr.Type )

	if newConstr then newConstr.BuildDupeInfo = table.Copy( buildInfo ) end

	-- Move the entities back after constraining them. No point in moving the world though.

	if firstValid then
		first:SetPos( firstPosReset )
		first:SetAngles( firstAngReset )
		if IsValid(Bone1) and Bone1Index ~= 0 then
			Bone1:SetPos( Bone1PosReset ) -- + firstPosReset
			Bone1:SetAngles( Bone1AngReset )
		end

		local FirstPhys = first:GetPhysicsObject()
		if IsValid(FirstPhys) and ReEnableFirst then
			FirstPhys:EnableMotion(true)
		end
	end

	if secondValid then
		second:SetPos( secondPosReset )
		second:SetAngles( secondAngReset )
		if IsValid( Bone2 ) and Bone2Index ~= 0 then
			Bone2:SetPos( Bone2PosReset ) -- + secondPosReset
			Bone2:SetAngles( Bone2AngReset )
		end

		local SecondPhys = second:GetPhysicsObject()
		if IsValid( SecondPhys ) and ReEnableSecond then
			SecondPhys:EnableMotion(true)
		end
	end

	--[[
	if newConstr and newConstr.length then
		newConstr.length = constr.length
	end -- Fix for weird bug with ropes
	]]

	print(newConstr, rope)
	return newConstr, rope
end


--------------------------------
--       Limits Check         --
--------------------------------


-- You have to create the constraint first to know if it's a ropeconstraint or not
-- Note that ropeconstraints name come from the fact that they involve keyframe_rope entities
function ConstraintEditor.DoPlayerLimits( ply, constr, rope, enforceLimits )

	local cleanupType = ConstraintEditor.GetCleanupType( constr, rope )

	if ply and ( constr or rope ) then
		if not game.SinglePlayer() and enforceLimits and ply:GetCount( cleanupType ) >= cvars.Number( "sbox_max" .. cleanupType, 0 ) then
			ply:LimitHit( cleanupType )
			SafeRemoveEntity( constr )
			SafeRemoveEntity( rope )
			return false, cleanupType
		end

		ply:AddCount( cleanupType, constr or rope )
	end

	return true, cleanupType

end


function ConstraintEditor.GetCleanupType( constr, rope )
	return ( isentity( rope ) and rope:IsValid() and "ropeconstraints" ) or ( isentity( constr ) and constr:IsValid() and "constraints" )
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

	local constrData, desc = ConstraintEditor.GetConstrData( constr, true )
	if not ( constrData and desc ) then return end
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


-- Client safety checks are here
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		local tag = net.ReadUInt( BIT_COUNT_TAG )

		if tag == NT.UNSET_EDITED_ENTITY then

			if not ( ply and ply:IsPlayer() ) then return end
			ConstraintEditor.SetEditedEntity( nil, ply )

		elseif tag == NT.SET_EDITED_ENTITY then

			if not ( ply and ply:IsPlayer() ) then return end
			local ent = net.ReadEntity()
			ConstraintEditor.SetEditedEntity( ent, ply )


		end

		local constrID	= net.ReadUInt( BIT_COUNT_CONSTR_ID )
		local constr	= ConstraintEditor.Access( ply, constrID )

		if not constr then ConstraintEditor.SendDataToClient( NT.FORGET_CONSTR, constrID, ply ) return end
		if not IsValid ( constr ) then ConstraintEditor.ForgetConstr( constrID ) return end

		if tag == NT.GET_MENU_DEEP_DATA then

			ConstraintEditor.SetEditedConstr( constr, ply )

		elseif tag == NT.REMOVE_CONSTR then

			ConstraintEditor.DeleteConstr( constr )

		elseif tag == NT.UPDATE_CONSTR then

			local newData = net.ReadTable()
			ConstraintEditor.UpdateConstr( constr, newData, ply, true )

		elseif tag == NT.DUPLIC_CONSTR then

			ConstraintEditor.UpdateConstr( constr, {}, ply, true, true )

		end

	end )

end
