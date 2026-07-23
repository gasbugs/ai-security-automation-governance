PROJECT ?=

.PHONY: list fmt init validate plan setup destroy

list:
	@./scripts/project.sh list

fmt:
	@./scripts/project.sh fmt "$(PROJECT)"

init:
	@./scripts/project.sh init "$(PROJECT)"

validate:
	@./scripts/project.sh validate "$(PROJECT)"

plan:
	@./scripts/project.sh plan "$(PROJECT)"

setup:
	@./scripts/project.sh setup "$(PROJECT)"

destroy:
	@./scripts/project.sh destroy "$(PROJECT)"
