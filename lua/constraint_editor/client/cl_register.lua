ConstraintEditor.constrs = {}


-- Register constraints so that they become visible and editable in the HUD and menu.
--
-- Arguments:
--	surfaceConstrsData (table): Table from the server, it should look like this:
--		{
--			[constrType_1] = {
--				[constrID_1] = {
--					firstEntity, secondEntity, firstLocalPos, secondLocalPos, worldPos_1, worldPos_2, localAxis
--				},
--				etc...
--			},
--			etc...
--		}
function ConstraintEditor.RegisterConstrs( surfaceConstrsData )

	local constrBrowser	= ConstraintEditor.GetConstrBrowser()
	if IsValid( constrBrowser ) then constrBrowser:RegisterConstrs( surfaceConstrsData ) end

	table.Merge( ConstraintEditor.constrs, surfaceConstrsData )

end


-- Unregister constraints by their creation IDs
--
-- Arguments:
--	A table whose keys are the constraint creation IDs of the constraints we want to unregister
function ConstraintEditor.UnregisterConstrs( constrIDs )

	-- Because unregistering constraints from the constraint browser can change the selection,
	-- it is necessary to use the function below which automatically asks the server for new data if needed
	ConstraintEditor.CallSelectFuncOnConstraintBrowser("UnregisterConstrs", constrIDs)

	for constrType, constrDatas in pairs( ConstraintEditor.constrs ) do
		for constrID, _ in pairs( constrIDs ) do
			constrDatas[constrID] = nil
		end
	end

end


-- Unregister all constraints
function ConstraintEditor.UnregisterAllConstrs()

	ConstraintEditor.constrs = {}

	local constrBrowser	= ConstraintEditor.GetConstrBrowser()

	if IsValid( constrBrowser ) then
		constrBrowser:Clear()
	end

end