ConstraintEditor.netTags = {
	CLEAR_ENTITY_SELECTION	= 0,
	SELECT_ENTITY			= 1,
	TOOLGUN_LEFT_CLICK		= 2,
	TOOLGUN_RIGHT_CLICK		= 3,
	TOOLGUN_MIDDLE_CLICK	= 4,
	UPDATE_CONSTRS			= 5,
	REMOVE_CONSTRS			= 6,
	DUPLIC_CONSTRS			= 7,
	UPDATE_TYPE				= 8,
	UNREGISTER_ALL_CONSTRS	= 9,
	REGISTER_CONSTRS		= 10,
	FILL_CONSTR_EDITOR		= 11,
	CLEAR_EDITOR_DATA		= 12,
	UNREGISTER_CONSTRS		= 13,
	TRANSFER_CONSTRS		= 14,
	TRANSFER_ALL_CONSTRS	= 15,
}


ConstraintEditor.netBitCounts = {
	TAG				= 5,
	MAX_ENT_ID		= 13, -- up to 8192 entities can exist
	MAX_CREATION_ID	= 24, -- creation ids go up to 10 million
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

	net.Start( "constraint_editor_net" )

		net.WriteUInt( tag, BIT_COUNT.TAG )

		for _, tab in ipairs( { ... } ) do
			local v, arg = tab[1], tab[2]
			local write = ConstraintEditor.GetNetWriteFunc( v )
			if write then write( v, arg ) end
		end

	return true

end


-- Put a constraint creation ID into an appropriate format for the net send functions
--
-- Arguments:
--	constrID (int): A constraint creation ID
--
-- Returns:
--	(table): A table containing constrID (arg) and its maximum bit count
function ConstraintEditor.ToNetConstrID( constrID )
	return { constrID, BIT_COUNT.MAX_CREATION_ID }
end


-- Puts many constraint creation IDs into an appropriate format for the net send functions
--
-- Arguments:
--	constrIDs (table): A table whose keys are constraint creation IDs, and whose values should be boolean (true to include the constraint creation ID to the final result)
--	dontAddCount (boolean): only if true, does not add the number of included constraints
--
-- Returns:
--	(tuple): The unpacked table of constraint IDs:
--		First table, only if addCount (arg) is true, is { how many IDs will be sent, max entity (constraint) count }
--		Consecutive tables are { creation ID of the constraint, maximum bit count for a creation ID }
function ConstraintEditor.ToNetConstrIDs( constrIDs, dontAddCount )

	if not constrIDs then return end

	local tab = {}

	if not dontAddCount then table.insert( tab, { 0, BIT_COUNT.MAX_ENT_ID } ) end

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