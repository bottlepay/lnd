DEV_TAGS = dev
RPC_TAGS = autopilotrpc chainrpc invoicesrpc routerrpc signrpc verrpc walletrpc watchtowerrpc wtclientrpc
LOG_TAGS =
TEST_FLAGS =
ITEST_FLAGS = 
COVER_PKG = $$(go list -deps ./... | grep '$(PKG)' | grep -v lnrpc)
NUM_ITEST_TRANCHES = 6
ITEST_PARALLELISM = $(NUM_ITEST_TRANCHES)

# If rpc option is set also add all extra RPC tags to DEV_TAGS
ifneq ($(with-rpc),)
DEV_TAGS += $(RPC_TAGS)
endif

# Scale the number of parallel running itest tranches.
ifneq ($(tranches),)
NUM_ITEST_TRANCHES = $(tranches)
ITEST_PARALLELISM = $(NUM_ITEST_TRANCHES)
endif

# Give the ability to run the same tranche multiple times at the same time.
ifneq ($(parallel),)
ITEST_PARALLELISM = $(parallel)
endif

# If specific package is being unit tested, construct the full name of the
# subpackage.
ifneq ($(pkg),)
UNITPKG := $(PKG)/$(pkg)
UNIT_TARGETED = yes
COVER_PKG = $(PKG)/$(pkg)
endif

# If a specific unit test case is being target, construct test.run filter.
ifneq ($(case),)
TEST_FLAGS += -test.run=$(case)
UNIT_TARGETED = yes
endif

# Define the integration test.run filter if the icase argument was provided.
ifneq ($(icase),)
TEST_FLAGS += -test.run="TestLightningNetworkDaemon/.*-of-.*/.*/$(icase)"
endif

# Run itests with etcd backend.
ifeq ($(etcd),1)
ITEST_FLAGS += -etcd
DEV_TAGS += kvdb_etcd
endif

ifneq ($(tags),)
DEV_TAGS += ${tags}
endif

# Define the log tags that will be applied only when running unit tests. If none
# are provided, we default to "nolog" which will be silent.
ifneq ($(log),)
LOG_TAGS := ${log}
else
LOG_TAGS := nolog
endif

# If a timeout was requested, construct initialize the proper flag for the go
# test command. If not, we set 20m (up from the default 10m).
ifneq ($(timeout),)
TEST_FLAGS += -test.timeout=$(timeout)
else
TEST_FLAGS += -test.timeout=40m
endif

GOLIST := go list -tags="$(DEV_TAGS)" -deps $(PKG)/... | grep '$(PKG)'| grep -v '/vendor/'
GOLISTCOVER := $(shell go list -tags="$(DEV_TAGS)" -deps -f '{{.ImportPath}}' ./... | grep '$(PKG)' | sed -e 's/^$(ESCPKG)/./')

# UNIT_TARGTED is undefined iff a specific package and/or unit test case is
# not being targeted.
UNIT_TARGETED ?= no

# If a specific package/test case was requested, run the unit test for the
# targeted case. Otherwise, default to running all tests.
ifeq ($(UNIT_TARGETED), yes)
UNIT := $(GOTEST) -tags="$(DEV_TAGS) $(LOG_TAGS)" $(TEST_FLAGS) $(UNITPKG)
UNIT_RACE := $(GOTEST) -tags="$(DEV_TAGS) $(LOG_TAGS)" $(TEST_FLAGS) -race $(UNITPKG)
endif

ifeq ($(UNIT_TARGETED), no)
UNIT := $(GOLIST) | $(XARGS) env $(GOTEST) -tags="$(DEV_TAGS) $(LOG_TAGS)" $(TEST_FLAGS)
UNIT_RACE := $(UNIT) -race
endif


# Default to btcd backend if not set.
ifeq ($(backend),)
backend = btcd
endif

# Construct the integration test command with the added build flags.
ITEST_TAGS := $(DEV_TAGS) $(RPC_TAGS) rpctest $(backend)

ITEST := rm -f lntest/itest/*.log; date; $(GOTEST) -v ./lntest/itest -tags="$(ITEST_TAGS)" $(TEST_FLAGS) $(ITEST_FLAGS) -logoutput -goroutinedump
