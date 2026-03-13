

include( "constraint_editor/sv_access.lua" )




---------------------------
--  Basis of the system  --
---------------------------


-- Returns the descriptor (desc) of the constraint type (constrType) represented by the argument, as well as the constraint type itself
-- desc is a table like this: { Args = (sequential table of argument names for the duplicator function), Func = (duplicator function used to create that type of constraint)}
-- constrType is a string (e.g. "Rope", "Weld", ...)
function ConstraintEditor.GetConstrDescriptor( v )

	-- v can be a string, a table, or an entity
	local constrType = isstring( v ) and thing or ( istable( v ) or isentity( v ) ) and v.Type
	local desc = duplicator.ConstraintType[constrType]
	if desc then return desc, constrType end

end




------------------------------
--  Default Values Getters  --
------------------------------


-- Arbitrary default values for constraint arguments.
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


-- Get the default value for the argument, optionally considering the constraint type (Rope, Weld, ...)
function ConstraintEditor.GetConstrArgDefault( arg, constrType )

	local value

	if constrType then
		local specificDefaults = constrArgsDefaults[constrType]
		local specificValue = specificDefaults and specificDefaults[arg]
		if specificValue ~= nil then value = specificValue end
	end

	if value == nil then value = constrArgsDefaults[arg] end

	if IsColor( value ) then value = value:Copy() end

	return value

end


-- Returns a table containing constraint data with default values
-- Keys are literal (str)
function ConstraintEditor.GetConstrDataDefault( v )

	local desc, constrType = ConstraintEditor.GetConstrDescriptor( v )
	if not desc then return end

	local data = {}
	for _, arg in ipairs( desc.Args ) do
		data[arg] = ConstraintEditor.GetConstrArgDefault( constrType, arg )
	end

end




-------------------------------
--  Constraint Data Setters  --
-------------------------------


-- Changes all values of constrData to known default ones
-- constrData keys must be literal (str)
function ConstraintEditor.DefaultizeConstrData( constrData )
	local constrType = constrData.Type
	constrData.constrID = nil
	for arg in pairs( constrData ) do
		local v = ConstraintEditor.GetConstrArgDefault( arg, constrType )
		if v ~= nil then constrData[arg] = v end
	end
end



-- Prevent some unsafe data manipulation
-- constrData can have numerical or literal (str) keys
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


-- Enables/disables numerical and/or literal (str) keys for constrData
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


-- Returns constraint information contained in first argument in an useful format
-- Also returns the descriptor (contains the arguments and factory function for the duplicator)
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