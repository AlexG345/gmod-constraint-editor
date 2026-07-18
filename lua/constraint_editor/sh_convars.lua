CreateConVar(
	"sv_constraint_editor_max_edit",
	game.SinglePlayer() and "2048" or "32",
	{ FCVAR_REPLICATED },
	"The maximum amount of constraints that can be modified at once using constraint editor.",
	-- 64 kB limit can theoretically be reached starting at 2665 constraints or so,
	-- without taking into account how much space is taken by the new properties.
	1, 2048
)

-- CreateConVar(
-- 	"sv_constraint_editor_allow_ent_change",
-- 	"1",
-- 	{ FCVAR_REPLICATED },
-- 	"Allow changing the entities constraints are linked to using constraint editor.",
-- 	0, 1
-- )
