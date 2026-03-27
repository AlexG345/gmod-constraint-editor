
-- Surface constraints data is a table used for the menus and HUD clientside
-- It is structured like that (constrType -> constrID = creation ID -> information):
--
--	surfaceConstrsData = {
--		constrType_1 = {
--
--			constrID_1 = {
--				firstEntity, secondEntity, firstLocalPos, secondLocalPos, worldPos_1, worldPos_2, localAxis
--			},
--
--			etc...
--
--		},
--
--		etc...
--
--	}


------------------------------------------
--  Surface Constraint(s) Data Getters  --
------------------------------------------


-- Gets the surface constraints data associated with all the constraints linked to the given entity
--
-- Arguments:
--	ent (Entity): The entity whose linked constraints we want information about
--
-- Returns:
--	surfaceConstrsData (table): Surface constraints data associated with all the constraints linked to ent (arg)
--	constrs (table): Table of all found constraints, each constraint can be accessed by its creation ID.
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


-- Gets the surface constraint data associated with the given constraint
--
-- Arguments:
--	constr (table | Entity): The constraint we want information about
--
-- Returns:
--	(table): Surface constraint data associated with constr (arg)
--	constrType (string): The constraint type of constr (arg)
--	constrID (int): The creation ID of constr (arg)
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