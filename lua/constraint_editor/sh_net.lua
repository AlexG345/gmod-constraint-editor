ConstraintEditor.netTags = {
	CLEAR_ENTITY_SELECTION	= 0,
	SELECT_ENTITY			= 1,
	TOGGLE_ENTITY			= 2,
	TOOLGUN_LEFT_CLICK		= 3,
	TOOLGUN_RIGHT_CLICK		= 4,
	TOOLGUN_MIDDLE_CLICK	= 5,
	UPDATE_CONSTRS			= 6,
	REMOVE_CONSTRS			= 7,
	DUPLIC_CONSTRS			= 8,
	UPDATE_TYPE				= 9,
	UNREGISTER_ALL_CONSTRS	= 10,
	REGISTER_CONSTRS		= 11,
	FILL_CONSTR_EDITOR		= 12,
	CLEAR_EDITOR_DATA		= 13,
	SELECT_CONSTRS			= 14,
	UNREGISTER_CONSTRS		= 15,
	TRANSFER_CONSTRS		= 16,
	TRANSFER_ALL_CONSTRS	= 17,
}


-- Debug function to get the name of a net tag
--
-- Arguments:
--	netTag (number)
--
-- Returns:
--	(string): The key used to access netTag (arg) through ConstraintEditor.netTags
function ConstraintEditor.GetNetTagName( netTag )
	for name, tag in pairs( ConstraintEditor.netTags ) do
		if tag == netTag then return name end
	end
	return "UNKNOWN"
end


local function netDebug( isDebugHeader, isSender, netTag, args )

	if isDebugHeader then

		local text1, text2 = "SERVER", "CLIENT"

		if ( CLIENT and isSender ) or ( SERVER and not isSender ) then
			text1, text2 = text2, text1
		end

		print( "" )
		print( "----- netDebug -----" )
		print( "" )
		print( text1 .. " tells " .. text2 .. " to " .. ConstraintEditor.GetNetTagName( netTag ) .. "(" .. netTag .. ")" )

	end

	if args then PrintTable( { args = args } ) end

	print( "" )

end


-- Returns how many bits are needed to represent the given
local function getBitCount( number )
	return math.ceil( math.log( number + 1, 2 ) )
end


ConstraintEditor.netBitCounts = {
	TAG			= getBitCount( table.Count( ConstraintEditor.netTags ) - 1 ),
	ENT_ID		= getBitCount( 8192 ), -- up to 8192 entities can exist
	CREATION_ID	= getBitCount( 10000000 ), -- https://wiki.facepunch.com/gmod/Entity:GetCreationID
}


ConstraintEditor.netWriteFuncs = {
	[TYPE_STRING]		= net.WriteString,
	[TYPE_NUMBER]		= net.WriteUInt,
	[TYPE_TABLE]		= net.WriteTable,
	[TYPE_BOOL]			= net.WriteBool,
	[TYPE_ENTITY]		= net.WriteEntity,
	[TYPE_VECTOR]		= net.WriteVector,
	[TYPE_ANGLE]		= net.WriteAngle,
	[TYPE_MATRIX]		= net.WriteMatrix,
	[TYPE_COLOR]		= net.WriteColor,
}


local BIT_COUNT = ConstraintEditor.netBitCounts



function ConstraintEditor.GetNetWriteFunc( v )
	return ConstraintEditor.netWriteFuncs[TypeID( v )]
end


-- Starts a net message with a tag and optional arguments.
-- Note that this does not send the message, only starts it and writes some data.
--
-- Arguments:
--	tag (int): A number from the ConstraintEditor.netTags table. Used to describe the goal of the message and the data held by it.
--	... (tuple of tables | nil): A tuple of tables in the form { v, arg }, where:
--		v (string | unsigned integer | table | boolean | entity | vector | angle | matrix | color) is some data that you want to send
--		arg (int | nil) is the second argument to be passed to the net write function (e.g. the maximum bit count of a constraint creation ID...)
function ConstraintEditor.NetStartWrite( tag, ... )

	if not isnumber( tag ) then return false end

	netDebug( true, true, tag, nil )

	net.Start( "constraint_editor_net" )

		net.WriteUInt( tag, BIT_COUNT.TAG )

		ConstraintEditor.NetAdd( ... )

	return true

end


-- Writes data to the current net message.
-- Note that this does not send or start the message, only writes some data.
--
-- Arguments:
--	... (tuple of tables | nil): A tuple of tables in the form { v, arg }, where:
--		v (string | unsigned integer | table | boolean | entity | vector | angle | matrix | color) is some data that you want to send
--		arg (int | nil) is the second argument to be passed to the net write function (e.g. the maximum bit count of a constraint creation ID...)
function ConstraintEditor.NetAdd( ... )

	netDebug( false, true, nil, { ... } )

	for _, tab in ipairs( { ... } ) do
		local v, arg = tab[1], tab[2]
		local write = ConstraintEditor.GetNetWriteFunc( v )
		if write then write( v, arg ) end
	end

end



-- Put a constraint creation ID into an appropriate format for the net send functions
--
-- Arguments:
--	constrID (int): A constraint creation ID
--
-- Returns:
--	(table): A table containing constrID (arg) and its maximum bit count
function ConstraintEditor.ToNetConstrID( constrID )
	return { constrID, BIT_COUNT.CREATION_ID }
end


-- Puts many constraint creation IDs into an appropriate format for the net send functions
--
-- Arguments:
--	constrIDs (table): A table whose keys are constraint creation IDs, and whose values should be boolean (true to include the constraint creation ID to the final result)
--	dontAddCount (boolean): only if true, does not add the number of included constraints
--
-- Returns:
--	(tuple): The unpacked table of constraint IDs:
--		First table, only if addCount (arg) is true, is { how many IDs will be sent, bits for max entity (constraint) count }
--		Consecutive tables are { creation ID of the constraint, maximum bit count for a creation ID }
function ConstraintEditor.ToNetConstrIDs( constrIDs, dontAddCount )

	if not constrIDs then return end

	local tab = {}

	if not dontAddCount then table.insert( tab, { 0, BIT_COUNT.ENT_ID } ) end

	local constrCount = 0

	for constrID, include in pairs( constrIDs ) do
		if include then
			table.insert( tab, ConstraintEditor.ToNetConstrID( constrID ) )
			constrCount = constrCount + 1
		end
	end

	if not dontAddCount then tab[1][1] = constrCount end

	return unpack( tab )
end


-- Call this to start listening to net messages
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		if SERVER and not ( ply and ply:IsPlayer() ) then return end

		local tag = net.ReadUInt( BIT_COUNT.TAG )
		local data = { ConstraintEditor.netFunctions[tag]( ply ) }

		--netDebug( true, false, tag, data )

	end )

end