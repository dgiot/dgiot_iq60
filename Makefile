PROJECT = dgiot_iq60
PROJECT_DESCRIPTION = dgiot_iq60 Plugin
PROJECT_VERSION = 1.5.4

CUR_BRANCH := $(shell git branch | grep -e "^*" | cut -d' ' -f 2)
BRANCH := $(if $(filter $(CUR_BRANCH), master develop), $(CUR_BRANCH), develop)

BUILD_DEPS = emqx cuttlefish
dep_emqx = git-emqx https://github.com/emqx/emqx $(BRANCH)
dep_cuttlefish = git-emqx https://github.com/emqx/cuttlefish v2.2.1

DIALYZER_DIRS := ebin/
DIALYZER_OPTS := --verbose --statistics -Werror_handling \
                 -Wrace_conditions #-Wunmatched_returns

ERLC_OPTS += +'{parse_transform, lager_transform}'


include erlang.mk

app.dgiot_group::
	./deps/cuttlefish/cuttlefish -l info -e etc/ -c etc/dgiot_iq60.conf -i priv/dgiot_iq60.schema -d data
