.PHONY: playstore

ifeq ($(shell whoami),sungjunhong)
include ~/.alarmup-$(VAULT_ENV).sh
endif

playstore:
	./playstore/listings.sh
