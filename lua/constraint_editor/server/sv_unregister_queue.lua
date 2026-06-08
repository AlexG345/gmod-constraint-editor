ConstraintEditor.UnregisterConstrQueue = {}


local identifier = "Constraint Editor - Unregister constr queue"


-- Unregisters all queued constraints
local function unregisterConstrsInQueue()

	ConstraintEditor.UnregisterConstrIDs( ConstraintEditor.UnregisterConstrQueue )

	ConstraintEditor.UnregisterConstrQueue = {}
end


-- Function that should be called when a KNOWN constr is about to get removed.
--
-- Arguments:
--	constr (Entity): The KNOWN constraint about to get removed
local function addConstrToUnregisterQueue( constr )

	ConstraintEditor.UnregisterConstrQueue[constr:GetCreationID()] = true

	if not timer.Exists( identifier ) then
		timer.Create( identifier, 0, 1, unregisterConstrsInQueue )
	end

end


-- Function that makes a constraint add itself to the unregister queue when it's aobut to get removed
--
-- Arguments:
--	constr (Entity): Constraint that should add itself to the unregister queue when soon removed
function ConstraintEditor.AddCallOnRemove( constr )
	constr:CallOnRemove( identifier, addConstrToUnregisterQueue )
end