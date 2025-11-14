util.AddNetworkString( "constraint_editor_net" )

local REMOVE_CONSTR			= 0
local UPDATE_CONSTR			= 1
local DUPLIC_CONSTR			= 2
local SET_MENU_SURFACE_DATA	= 3
local SET_MENU_DEEP_DATA	= 4
local GET_MENU_DEEP_DATA	= 5
local REMOVE_MENU_CONSTR	= 6
local ADD_MENU_SURFACE_DATA	= 7
local GET_ALL_CONSTRS		= 8

local BIT_COUNT_TAG			= 3
local BIT_COUNT_CONSTR_ID	= 24 -- creation ids go up to 10 million

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

	if not allow then ConstraintEditor.SendDataToClient( REMOVE_MENU_CONSTR, constrID, ply ) end

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
		local surfaceConstrData = { [newConstr.Type] = { newConstrID } }
		ConstraintEditor.SendDataToClient( ADD_MENU_SURFACE_DATA, surfaceConstrData, ply )

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
			ConstraintEditor.SendDataToClient( REMOVE_MENU_CONSTR, constrID, ply )
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


--------------------------------
--  Constraint Manipulation   --
--------------------------------


-- Try to get the descriptor of the constraint type represented by the argument
function ConstraintEditor.GetConstrDescriptor( a )

	local constrType = isstring( a ) and a or ( istable( a ) or isentity( a ) ) and a.Type

	local desc = duplicator.ConstraintType[ constrType ]

	if desc then return desc, constrType end

end


-- First returned table contains lists of creation IDs of ent's valid constraints.
-- The keys used to access those lists are constraint types.
-- Second returned table's keys are creation IDs, values are constraint entities
function ConstraintEditor.GetSurfaceConstrData( ent )

	if not ( isentity( ent ) and ( ent:IsValid() or ent:IsWorld() ) ) then return false end

	local surfaceConstrData = {}
	local constrs = {}
	local constrTable = constraint.GetTable( ent )

	for _, constrData in ipairs( constrTable ) do

		local constrType	= constrData.Type
		local constr		= constrData.Constraint or NULL
		local constrID		= constr.GetCreationID and constr:GetCreationID()

		if constr:IsValid() and not constr.CEInvalid and constrType and constrID then
			constrs[constrID] = constr
			surfaceConstrData[constrType] = surfaceConstrData[constrType] or {}
			table.insert( surfaceConstrData[constrType], constrID )
		end

	end

	return surfaceConstrData, constrs

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


-- Tries to create a new constraint.
function ConstraintEditor.CreateConstr( constr, constrData, ply )

	local buildInfo = constr and constr.BuildDupeInfo

	local _, desc = ConstraintEditor.GetConstrData( constr, true )

	local newConstr

	if buildInfo then
		-- Uses BuildDupeInfo (needs advanced duplicator 2 to work)
		newConstr = ConstraintEditor.CreateWithBuildInfo( constr, buildInfo, desc.Func, constrData, ply )
	else
		-- Uses normal duplicator. Has information loss (e.g Ent1 and Ent2's relative position is lost)
		newConstr = desc.Func( unpack( constrData ) )
	end

	if ply and isentity( newConstr ) and newConstr:IsValid() then ply:AddCount( "ropeconstraints", newConstr ) end

	return newConstr

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


-- Constraint editing / deletion happens here
function ConstraintEditor.UpdateConstr( constr, newData, ply, sanitize, duplicate )

	if duplicate and ply and not ply:CheckLimit( "ropeconstraints" ) then return end

	if sanitize then ConstraintEditor.SanitizeConstrData( newData ) end

	local isChanged = ConstraintEditor.CompleteConstrData( constr, newData )
	if not ( isChanged or duplicate ) then return end

	local newConstr = ConstraintEditor.CreateConstr( constr, newData, ply )

	if not ( isentity( newConstr ) and newConstr:IsValid() ) then return false end

	-- Give permissions to edit the new constraint to all players that had access to the old one.
	-- Comes before the "SetEditedConstr" to prevent 2 nodes appearing for the same constraint in ply's editor
	ConstraintEditor.TransferAccess( constr, newConstr )

	if duplicate then return end

	undo.ReplaceEntity( constr, newConstr)
	cleanup.ReplaceEntity( constr, newConstr )

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

	local ok, Ent = pcall( factory, unpack( newData, 1, #newData ) )

	if ply and not ( ok and Ent ) then
		ply:ChatPrint( "Constraint Editor - ERROR: Failed to create " .. constr.Type or "unknown type" .. " constraint!" )
	end

	if Ent then Ent.BuildDupeInfo = table.Copy( buildInfo ) end

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

	if Ent and Ent.length then
		Ent.length = constr.length
	end -- Fix for weird bug with ropes

	return Ent
end


--------------------------------
--       Network things       --
--------------------------------


function ConstraintEditor.SendDataToClient( tag, data, ply )

	if not isnumber( tag ) then return end
	if not isentity( ply ) and ply:IsPlayer() then return end

	net.Start( "constraint_editor_net" )
		net.WriteUInt( tag, BIT_COUNT_TAG )
		if istable( data ) then
			net.WriteTable( data )
		else
			net.WriteUInt( data, BIT_COUNT_CONSTR_ID )
		end
	net.Send( ply )

end


function ConstraintEditor.SetEditedEntity( ent, ply )

	ConstraintEditor.ClearAccess( ply )

	ConstraintEditor.EditedEnts[ply] = ent

	local surfaceConstrData, constrs = ConstraintEditor.GetSurfaceConstrData( ent )

	for constrID, constr in pairs( constrs ) do
		ConstraintEditor.SetAccess( ply, constrID, true, constr )
	end
	ConstraintEditor.SendDataToClient( SET_MENU_SURFACE_DATA, surfaceConstrData, ply )

end


function ConstraintEditor.SetEditedConstr( constr, ply )

	local constrData, desc = ConstraintEditor.GetConstrData( constr, true )
	if not ( constrData and desc ) then return end
	ConstraintEditor.SendDataToClient( SET_MENU_DEEP_DATA, { constrData, desc.Args }, ply )

end


-- Client safety checks are here
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		local tag		= net.ReadUInt( BIT_COUNT_TAG )
		local constrID	= net.ReadUInt( BIT_COUNT_CONSTR_ID )
		local constr	= ConstraintEditor.Access( ply, constrID )

		if not constr then ConstraintEditor.SendDataToClient( REMOVE_MENU_CONSTR, constrID, ply ) return end
		if not IsValid ( constr ) then ConstraintEditor.ForgetConstr( constrID ) return end

		if tag == GET_MENU_DEEP_DATA then

			ConstraintEditor.SetEditedConstr( constr, ply )

		elseif tag == REMOVE_CONSTR then

			ConstraintEditor.DeleteConstr( constr )

		elseif tag == UPDATE_CONSTR then

			local newData = net.ReadTable()
			ConstraintEditor.UpdateConstr( constr, newData, ply, true )

		elseif tag == DUPLIC_CONSTR then

			ConstraintEditor.UpdateConstr( constr, {}, ply, true, true )

		end

	end )

end
