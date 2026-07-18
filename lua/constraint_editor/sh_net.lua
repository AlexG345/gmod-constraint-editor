ConstraintEditor.netTags = {
	CLEAR_ENTITY_SELECTION	= 0,
	SELECT_ENTITY			= 1,
	TOGGLE_ENTITY			= 2,
	IGNORE_ENTITY			= 3,
	TOOLGUN_LEFT_CLICK		= 4,
	TOOLGUN_RIGHT_CLICK		= 5,
	TOOLGUN_RELOAD	= 6,
	UPDATE_CONSTRS			= 7,
	REMOVE_CONSTRS			= 8,
	DUPLIC_CONSTRS			= 9,
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
function getNetTagName( netTag )
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
		print( "\n----- Constraint Editor net debug -----\n" )
		print( text1 .. " tells " .. text2 .. " to " .. getNetTagName( netTag ) .. "(" .. netTag .. ")" )
	end
	if args then PrintTable( { args = args } ) end
	print( "" )
end


-- Returns how many bits are needed to represent the given
local function getUIntBitCount( number )
	return math.max(1, math.ceil( math.log( number + 1, 2 ) ) )
end


ConstraintEditor.netBitCounts = {
	TAG			= getUIntBitCount( table.Count( ConstraintEditor.netTags ) - 1 ),
	ENT_ID		= getUIntBitCount( 8192 ), -- Up to 8192 entities can exist. This means indexes probably go up to 8191, but i use 8192 to be safe (even if it's one more bit)
	CREATION_ID	= getUIntBitCount( 10000000 ), -- https://wiki.facepunch.com/gmod/Entity:GetCreationID
}
local BIT_COUNT = ConstraintEditor.netBitCounts
BIT_COUNT.BIT_COUNT_CREATION_ID = getUIntBitCount( BIT_COUNT.CREATION_ID )


local function netWriteType( v )
	local t = IsColor( v ) and TYPE_COLOR or TypeID( v )
	net.WriteUInt( t, 8 )
	ConstraintEditor.netWriteFuncs[t]( v )
end


local function netReadType()
	local t = net.ReadUInt( 8 )
	return ConstraintEditor.netReadFuncs[t]()
end


-- Works about the same as net.WriteTable but uses ConstraintEditor.NetReadPreciseVector
function ConstraintEditor.NetWriteTable( tab, seq )
	if seq then
		local len = #tab
		net.WriteUInt( len, 14 ) -- with a 64 kB limit per message you won't be able to write more than 8192 items
		for i = 1, len do
			netWriteType( tab[i] )
		end
	else
		for k, v in pairs( tab ) do
			netWriteType( k )
			netWriteType( v )
		end
		-- End of table
		netWriteType( nil )
	end
end


-- Works about the same as net.ReadTable but uses ConstraintEditor.NetReadPreciseVector
function ConstraintEditor.NetReadTable( seq )
	local tab = {}
	if seq then
		for i = 1, net.ReadUInt( 14 ) do
			tab[ i ] = netReadType()
		end
	else
		while true do
			local k = netReadType()
			if ( k == nil ) then break end
			tab[ k ] = netReadType()
		end
	end
	return tab
end



-- Starts a net message with a tag and optional arguments.
-- Note that this does not send the message, only starts it and writes some data.
--
-- Arguments:
--	tag (int): A number from the ConstraintEditor.netTags table. Used to describe the goal of the message and the data held by it.
--	... (tuple of tables | nil): A tuple of tables in the form { v, arg }, where:
--		v (string | unsigned integer | table | boolean | entity | vector | angle | matrix | color) is some data that you want to send
--		arg (int | nil) is the second argument to be passed to the net write function (e.g. the maximum bit count of a constraint creation ID...)
function ConstraintEditor.NetStartWrite( tag )

	if not isnumber( tag ) then return false end

	-- netDebug( true, true, tag, nil )

	net.Start( "constraint_editor_net" )

		net.WriteUInt( tag, BIT_COUNT.TAG )

	return true

end


-- Write the 3 components of a vector as floats
-- Useful because net.WriteVector won't go past 1 decimal precision
--
-- Arguments:
--	vec (Vector): The vector to write
function ConstraintEditor.NetWritePreciseVector( vec )
	for i = 1, 3 do net.WriteFloat( vec[i] ) end
end


-- Get a vector by reading 3 floats
--
-- Returns:
--	vec (Vector)
function ConstraintEditor.NetReadPreciseVector()
	vec = Vector()
	for i = 1, 3 do vec[i] = net.ReadFloat() end
	return vec
end


-- Write many constraint creation IDs efficiently
-- Note that this won't be more efficient than writing directly if there's just 1 ID to write
-- Also, the farther apart the IDs are, the less efficient this method is
-- Examples of when it's not more efficient:
--	1 ID
--	2 IDs, with a ID diff of 512 or more
--	3 IDs, with a ID diff of 16384 or more
--	4 IDs, with a ID diff of 65536 or more
--	8 IDs, with a ID diff of about 1048576 or more
--	100 IDs, with a ID diff of 8388608 or more
-- Keep in mind that ID diffs of more than a few thousand are very unlikely.
--
-- Arguments:
--	constrIDs (table): A table whose keys are the constraint creation IDs to send
--	addCount = true (boolean): Only if true, adds the number of IDs at the start
function ConstraintEditor.NetWriteConstrIDs( constrIDs, addCount )

	if addCount == nil then addCount = true end

	-- theoretically (untested) hits the 64 kB limit between about 2664 constraints (worst case), and about 4919 constraints (best case, diff of 1 between each constr ID.)

	if not constrIDs then return end

	-- maxConstrID could simply be set to 10 million initially since that's the max value for a creation id
	local constrCount, minConstrID, maxConstrID = 0, math.huge, 0

	for constrID, _ in pairs( constrIDs ) do
		constrCount = constrCount + 1
		if constrID < minConstrID then minConstrID = constrID end
		if constrID > maxConstrID then maxConstrID = constrID end
	end

	if constrCount == 0 then return end

	local diff			= maxConstrID - minConstrID
	local diffBitCount	= getUIntBitCount( diff )

	if addCount then
		net.WriteUInt( constrCount, BIT_COUNT.ENT_ID )				-- 14 bits
	end

	net.WriteUInt( minConstrID, BIT_COUNT.CREATION_ID )				-- 24 bits
	net.WriteUInt( diffBitCount, BIT_COUNT.BIT_COUNT_CREATION_ID )	-- 5 bits

	for constrID, _ in pairs( constrIDs ) do
		net.WriteUInt( constrID - minConstrID, diffBitCount )
	end

end


-- Call this to start listening to net messages
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		if SERVER and not ( ply and ply:IsPlayer() ) then return end

		local tag = net.ReadUInt( BIT_COUNT.TAG )
		ConstraintEditor.netFunctions[tag]( ply )

		-- local data = { ConstraintEditor.netFunctions[tag]( ply ) }
		--netDebug( true, false, tag, data )

	end )

end


ConstraintEditor.netWriteFuncs = {
	[TYPE_NIL]			= function() end,
	[TYPE_STRING]		= net.WriteString,
	[TYPE_NUMBER]		= net.WriteDouble,
	[TYPE_TABLE]		= ConstraintEditor.NetWriteTable,
	[TYPE_BOOL]			= net.WriteBool,
	[TYPE_ENTITY]		= net.WriteEntity,
	[TYPE_VECTOR]		= ConstraintEditor.NetWritePreciseVector,
	[TYPE_ANGLE]		= net.WriteAngle,
	[TYPE_MATRIX]		= net.WriteMatrix,
	[TYPE_COLOR]		= net.WriteColor,
}


ConstraintEditor.netReadFuncs = {
	[TYPE_NIL]			= function() end,
	[TYPE_STRING]		= net.ReadString,
	[TYPE_NUMBER]		= net.ReadDouble,
	[TYPE_TABLE]		= ConstraintEditor.NetReadTable,
	[TYPE_BOOL]			= net.ReadBool,
	[TYPE_ENTITY]		= net.ReadEntity,
	[TYPE_VECTOR]		= ConstraintEditor.NetReadPreciseVector,
	[TYPE_ANGLE]		= net.ReadAngle,
	[TYPE_MATRIX]		= net.ReadMatrix,
	[TYPE_COLOR]		= net.ReadColor,
}
