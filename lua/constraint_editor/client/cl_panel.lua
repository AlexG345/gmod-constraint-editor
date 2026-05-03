-- Gets the constraint browser panel from the main menu (tool control panel)
function ConstraintEditor.GetConstrBrowser()
	local cPanel = controlpanel.Get( ConstraintEditor.Mode )
	return cPanel and cPanel.constrBrowser
end


-- Gets the constraint editor panel from the main menu (tool control panel)
function ConstraintEditor.GetConstrEditor()
	local constrBrowser = ConstraintEditor.GetConstrBrowser()
	return constrBrowser and constrBrowser.constraintEditor
end