.PHONY: preflight init fmt validate plan setup start stop destroy

preflight:
	@bash infrastructure/scripts/student/preflight-local.sh

init:
	@../../scripts/project.sh init owasp-top10

fmt:
	@../../scripts/project.sh fmt owasp-top10

validate:
	@../../scripts/project.sh validate owasp-top10

plan:
	@../../scripts/project.sh plan owasp-top10

setup:
	@../../scripts/project.sh setup owasp-top10

start:
	@bash infrastructure/scripts/student/start-lab.sh

stop:
	@bash infrastructure/scripts/student/stop-lab.sh

destroy:
	@../../scripts/project.sh destroy owasp-top10
