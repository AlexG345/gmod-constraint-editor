-- Gets the constraint browser vgui element from the main menu (tool control panel)
function ConstraintEditor.GetConstrBrowser()
	local cPanel = controlpanel.Get( ConstraintEditor.Mode )
	return cPanel and cPanel.constrBrowser
end


-- Gets the constraint editor vgui element from the main menu (tool control panel)
function ConstraintEditor.GetConstrEditor()
	local constrBrowser = ConstraintEditor.GetConstrBrowser()
	return constrBrowser and constrBrowser.constraintEditor
end


-- Ask the server to send over the (optionally default) constrData for a constraint.
--
-- Arguments:
--	constrID (int): The constraint creation ID representative of the data we want to get
--	getDefault (boolean): true only if you want to ask for default data
function ConstraintEditor.FillConstrEditor( constrID, getDefault )
	ConstraintEditor.NetSend(
		ConstraintEditor.netTags.FILL_CONSTR_EDITOR,
		ConstraintEditor.ToNetConstrID( constrID ),
		{ getDefault }
	)
end