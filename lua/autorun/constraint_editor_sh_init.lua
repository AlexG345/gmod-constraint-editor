ConstraintEditor = {}

ConstraintEditor.NetTags = {
	SET_EDITED_ENTITY		= 1,
	UNSET_EDITED_ENTITY		= 2,
	LEFT_CLICK				= 3,
	RIGHT_CLICK				= 4,
	RELOAD					= 5,
	UPDATE_CONSTR			= 6,
	REMOVE_CONSTR			= 7,
	DUPLIC_CONSTR			= 8,
	SET_SHOWN_CONSTRS		= 9,
	ADD_SHOWN_CONSTRS		= 10,
	GET_MENU_DEEP_DATA		= 11,
	SET_MENU_DEEP_DATA		= 12,
	FORGET_CONSTR			= 13,
}

ConstraintEditor.NetBitCounts = {
	TAG			= 4,
	CONSTR_ID	= 24, -- creation ids go up to 10 million
}