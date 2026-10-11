.DEFAULT_GOAL := all
.PHONY: all setup run stop status fclean

all:
	@if [ -x server/hlds_linux ] \
		&& [ -x server/cstrike/addons/amxmodx/scripting/amxxpc ] \
		&& [ -s server/cstrike/maps/deathrun_temple.bsp ] \
		&& [ -s server/cstrike/addons/amxmodx/plugins/account_guard.amxx ] \
		&& [ -s server/cstrike/addons/amxmodx/plugins/server_fun.amxx ] \
		&& [ -s server/cstrike/addons/amxmodx/plugins/admin_settings.amxx ]; then \
		$(MAKE) --no-print-directory run; \
	else \
		$(MAKE) --no-print-directory setup && $(MAKE) --no-print-directory run; \
	fi

setup:
	./scripts/install.sh

run:
	./scripts/start.sh

stop:
	./scripts/stop.sh

status:
	./scripts/status.sh

fclean:
	python3 tools/fclean.py
