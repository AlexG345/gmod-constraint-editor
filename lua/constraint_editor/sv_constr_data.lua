

include( "constraint_editor/sv_access.lua" )


-- For a given constraint type (a string such as Weld, Axis, Hydraulic...), there exists known keys (duplicator.ConstraintType[constrType].Args).
-- A constraint data is a table whose keys are those above, and whose values are of the proper type for these keys.
-- This table gives a (sadly) incomplete definition of a constraint. This is what's used by the duplicator to remake constraints upon duping.
-- Using an unpacked sequential constrData as argument for a duplicator constraint factory function, results in the creation of a constraint, if constrData is complete enough.
-- The order in which to read a constraint data that uses string keys is given by duplicator.ConstraintType[constrType].Args.
--	example of an incomplete constraint data that uses string keys: constrData = { Ent1: Entity(50), Ent2: Entity(51), nocollide: true }

-- Most of the time it's better to use string keys.



---------------------------
--  Basis of the system  --
---------------------------

-- Find the duplicator descriptor and constraint type for the given argument
--
-- Argument:
--	v (string | table | Entity): A constraint type, or a constraint entity or table, whose descriptor we want to get
--
-- Returns:
--	desc (table | nil): The duplicator descriptor for the constraint type represented by v (arg). It's a table that contains:
--		Func: the function used by the duplicator to build that type of constraint,
--  	Args: sequential table of the names of the arguments for the function above
--	constrType (string | nil): The constraint type represented by v (arg).
function ConstraintEditor.GetConstrDescriptor( v )

	local constrType = isstring( v ) and thing or ( istable( v ) or isentity( v ) ) and v.Type
	local desc = duplicator.ConstraintType[constrType]
	if desc then return desc, constrType end

end




------------------------------
--  Default Values Getters  --
------------------------------


-- Table of arbitrary default values for duplicator constraint arguments.
-- If a constraint type uses an argument whose name is shared by other constraints, but whose type is different
-- (e.g. nocollide for Weld is a boolean, while for other constraint types it's an integer), then we make an exception
-- by making a "subtable" ([constraint_type] = { [argument_name] = default_value })
local constrArgsDefaults = {

	Weld = {
		nocollide = false
	},

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


-- Gets the default value for a constraint duplicator argument, optionally considering the constraint type (Rope, Weld, ...)
--
-- Arguments:
--	arg (string): name of the constraint duplicator argument (e.g. width, length, material...)
--	constrType (string | nil): optional constraint type
--
-- Returns:
--	value (int | boolean | string | Vector | Color | Entity (NULL) | nil): if found, the arbitrary default value for arg (arg), optionally considering constrType (arg)
function ConstraintEditor.GetConstrArgDefault( arg, constrType )

	local value

	if constrType then
		local specificDefaults = constrArgsDefaults[constrType]
		value = specificDefaults and specificDefaults[arg]
	end

	if value == nil then value = constrArgsDefaults[arg] end

	-- TODO: check why we copy color but not vector?
	if IsColor( value ) then value = value:Copy() end

	return value

end


-- Gets the default values of the constraint duplicator arguments (e.g. nocollide), for the given argument. Choose numerical or/and string keys (defaulting to string keys)
--
-- Argument:
--	v (string | table | Entity): A constraint type, or a constraint entity or table, whose duplicator arguments arbitrary default values we want to get
--	numerical (boolean | nil): If true, the constraint data will use numerical keys, otherwise it won't
--	str (boolean | nil): If true, the constraint data will use str keys
--
-- Returns:
--	data (table): Its keys are constraint duplicator arguments names, its values are the arbitrary default values of these arguments, for v (arg).
function ConstraintEditor.GetConstrDataDefault( v, numerical, str )

	local desc, constrType = ConstraintEditor.GetConstrDescriptor( v )

	if not desc then return end

	if not ( numerical or str ) then str = true end

	local data = { Type = constrType }

	for i, arg in ipairs( desc.Args ) do
		local value = ConstraintEditor.GetConstrArgDefault( constrType, arg )
		if numerical then data[i] = value end
		if str then data[arg] = value end
	end

	return data

end




-------------------------------
--  Constraint Data Setters  --
-------------------------------


-- Transform a constraint data into its arbitrary default form by swapping all its values for arbitrary default ones.
--
-- Arguments:
--	constrData (table): The constraint data to be defaultized. Must only have string keys.
--
-- Returns:
--	(nil)
function ConstraintEditor.DefaultizeConstrData( constrData )
	local constrType = constrData.Type
	constrData.constrID = nil
	for arg in pairs( constrData ) do
		local v = ConstraintEditor.GetConstrArgDefault( arg, constrType )
		if v ~= nil then constrData[arg] = v end
	end
end


-- Prevent players from using (inside of a constraint data) entities that they shouldn't be able to tool or access.
--
-- Arguments:
--	constrData (table): The constraint data to be sanitized. Can have numerical and/or string keys.
--
-- Returns:
--	(nil)
function ConstraintEditor.SanitizeConstrData( constrData, ply )
	for k, v in pairs( constrData ) do
		local t = type( v )
		if t == "Player" then -- redundant with the next check?
			constrData[k] = nil
		end
		if ply and t == "Entity" then
			constrData[k] = ConstraintEditor.AccessEntity( ply, v, 3 ) or nil
		end
	end
end


-- Completes any value constrData is missing based on data available in refConstrData
--
-- Arguments:
--	refConstrData (table): The reference constraint data, used to complete the other. Must only use string keys.
--	constrData (table): The constraint data to be completed. Must only use string keys.
--	desc (table): The constraint descriptor
--	ply (Player): The player who caused this function call
--
-- Returns:
--	isChanged (boolean): true if constrData got completed
--
-- TODO: add type check
function ConstraintEditor.CompleteConstrData( refConstrData, constrData, desc, ply )

	local isChanged = false

	for i, arg in ipairs( desc.Args ) do

		if constrData[arg] == nil then constrData[arg] = refConstrData[arg] end

		local val = constrData[arg]

		-- Without this, sliders get deleted if they are constrained to the world.
		if isentity( val ) and isfunction( val.GetClass ) and val:GetClass() == "gmod_anchor" then

			constrData[arg] = duplicator.CreateEntityFromTable( ply, duplicator.CopyEntTable( val ) )

		end

		isChanged = isChanged or constrData[arg] ~= refConstrData[arg]

	end

	if not constrData.Type then constrData.Type = refConstrData.Type end

	return isChanged

end


-- Enable/disable numerical/string keys for the given constraint data
--
-- Arguments:
--	constrData (table): The constraint data whose keys we want to transform. Must contain a constraint type, if desc (arg) is nil.
--	desc (table): The optional constraint descriptor, used to know the argument names and their order
--	numerical (boolean | nil): If true, constrData (arg) will have numerical keys, otherwise it won't
--	str (boolean | nil): If true, constrData (arg) will have str keys, otherwise it won't
--
-- Returns:
--	constrData (table): The transformed table (this is the same table as constrData (arg))
function ConstraintEditor.TransformConstrDataKeys( constrData, desc, numerical, str )

	desc = desc or ConstraintEditor.GetConstrDescriptor( constrData )

	if not desc then return end

	for i, arg in ipairs( desc.Args ) do

		if constrData[arg] ~= nil then
			if numerical then constrData[i] = constrData[arg] else constrData[i] = nil end
			if not str then constrData[arg] = nil end
		elseif constrData[i] ~= nil then
			if str then constrData[arg] = constrData[i] else constrData[arg] = nil end
			if not numerical then constrData[i] = nil end
		end

	end

	return constrData

end




-------------------------------
--  Constraint Data Getters  --
-------------------------------


-- Get constraint data with numerical or/and string keys (defaulting to string keys)
--
-- Arguments:
--	v (string | table | Entity): A constraint type, or a constraint entity or table, whose constraint data we want to get
--	numerical (boolean | nil): If true, the constraint data will use numerical keys, otherwise it won't
--	str (boolean | nil): If true, the constraint data will use str keys
--
-- Returns:
--	data (table): v's constraint data with wanted keys format
--	desc (table): v's (arg) descriptor
function ConstraintEditor.GetConstrData( v, numerical, str )

	local desc, constrType = ConstraintEditor.GetConstrDescriptor( v )

	if not desc then return end

	-- By default use string keys
	if not ( numerical or str ) then str = true end

	local data	= {}

	for i, arg in ipairs( desc.Args ) do
		local value = v[arg]
		if value == nil then value = constrArgsDefaults[arg] end
		if numerical then data[i] = value end
		if str then data[arg] = value end
	end

	if next( data ) == nil then return end

	data.constrID = v.constrID or v.GetCreationID and v:GetCreationID()
	data.Type = constrType

	return data, desc

end


-- Get the names of the arguments corresponding to entities and local positions
--
-- Argument:
--	constrData (table): Constraint data that must use string keys
--
-- Returns:
--	entKeys (table): a table that contains:
--		the key of the first entity the constraint is linked to
--		the key of the second entity the constraint is linked to
--	posKeys (table): a table that contains:
--		a table containing the keys of the positions that are local to the first entity
--		a table containing the keys of the positions that are local to the second entity
function ConstraintEditor.GetConstrEntPosKeys( constrData )
	local ent1, ent2, ent4 = constrData.Ent1, constrData.Ent2, constrData.Ent4
	local LPos1, LPos2, LPos4, LPos, LocalAxis = constrData.LPos1, constrData.LPos2, constrData.LPos4, constrData.LPos, constrData.LocalAxis
	local entKeys = {
		ent1 and "Ent1" or nil,
		ent2 and "Ent2" or ent4 and "Ent4" or nil
	}
	local posKeys = {
		{
			LPos1 and "LPos1" or nil,
			LocalAxis and "LocalAxis" or nil
		},
		{
			LPos2 and "LPos2" or LPos4 and "LPos4" or LPos and "LPos" or nil
		}
	}

	return entKeys, posKeys
end
