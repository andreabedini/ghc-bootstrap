# build/Makefile -- the GHC 6.2.2 bootstrap chain as one dependency graph.
#
#   make -f build/Makefile [-jN] [target]        (from anywhere; sets GHC_BOOTSTRAP_ROOT itself)
#
#   stage1     build/ghc622-mhs/ghc        GHC 6.2.2 compiled by mhs (comb -> ghc-data.c -> cc)
#   base       libHSbase.a                 147 modules compiled by stage 1, .hc -> .o, archived
#   haskell98  libHShaskell98.a            30 modules
#   stage2     build/ghc622-stage2/ghc     the compiler proper, 220 modules, linked against rts622
#   test       test/Hello.hc               compiled by stage 2 (the acceptance test)
#   deps       build/mk/deps.mk            regenerate the per-module rules from the sources
#   status     what is stale, in one line per phase
#
# Every .hi/.hc pair is a grouped target whose recipe removes the pair first
# (GHC 6.2.2's recompilation checker opens an existing .hi) and checks the new
# .hi decodes in the pristine format (build/mk/check-hi.sh). The per-module
# rules and their import edges are generated (build/mk/gen-deps.py) from the
# same scanners that produced the order files. The retry ladder, per-module
# flags and result tsvs live in the build/mk/compile-*.sh scripts.
#
# -j: each GHC compile may use up to 8 GB of address space (ulimit -v; the
# modules that die of "heap exhausted" at -O get there), so on this machine
# (16 cores, 30 GB) -j4 is the safe setting for the Haskell steps; the gcc
# and ar steps parallelise freely. pueue-agent is the place to run this from
# (it outlives the session); make is the record of what is done.
SHELL := /bin/sh
R := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
export GHC_BOOTSTRAP_ROOT := $(R)
M1    := $(R)/build/ghc622-mhs
S2    := $(R)/build/ghc622-stage2
MK    := $(R)/build/mk
TREE  := $(R)/build/ghc-6.2.2-run1/ghc/compiler
INC1  := $(R)/build/ghc-6.2.2-run1/ghc/includes
BASE  := $(M1)/libraries/base
H98   := $(S2)/libraries/haskell98
SRC2  := $(S2)/src/ghc-6.2.2/ghc/compiler
INC2  := $(S2)/src/ghc-6.2.2/ghc/includes
ODIR2 := $(S2)/stage2
RTS   := $(R)/build/rts622
CC    ?= gcc

.DEFAULT_GOAL := stage2
.DELETE_ON_ERROR:
.PHONY: stage1 base haskell98 stage2 test deps status

# ---------------------------------------------------------------- stage 1
# Everything mhs reads: the patched tree, the shims, the hs-boot and generated
# modules, the includes. build.sh comb takes ~9 min whatever changed: mhs's
# cache validation looks for <Module>.hs, so every .lhs module and its
# importers are always recompiled (build/ghc622-stage2/LOG.md, 2026-09-16).
STAGE1_SRCS := $(shell find $(TREE) $(INC1) $(R)/build/shims-6.2.2-run1 \
    $(R)/phase1/shims $(R)/phase1/shims-ghc $(R)/phase1/shims-h98 \
    $(R)/phase2/hsboot-6.2.2-run1 $(R)/phase2/gen-6.2.2 -type f \
    \( -name '*.hs' -o -name '*.lhs' -o -name '*.h' -o -name '*.hs-boot' \
       -o -name '*.hi-boot' -o -name '*.hs-incl' -o -name '*.txt' \) -not -path '*/tmp/*')

$(M1)/ghc.comb: $(STAGE1_SRCS) $(M1)/build.sh
	sh $(M1)/build.sh comb
$(M1)/ghc-data.c: $(M1)/ghc.comb $(M1)/comb2c.py
	sh $(M1)/build.sh c
$(M1)/ghc: $(M1)/ghc-data.c $(M1)/ffi.c $(M1)/stubs.c $(M1)/stubs.h $(M1)/build.sh
	sh $(M1)/build.sh cc
stage1: $(M1)/ghc

# ---------------------------------------------------------------- libraries
BASE_HDRS := $(wildcard $(BASE)/include/*.h)
define HC2O_BASE
	@mkdir -p $(dir $@)
	cd $(BASE) && $(CC) -c -x c -std=gnu89 -O -fwrapv -w -fmax-errors=20 \
	  -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=622 \
	  -I$(INC1) -Iinclude -I. -include $(INC1)/Stg.h $< -o $@
endef
define HC2O_H98
	@mkdir -p $(dir $@)
	$(CC) -c -x c -std=gnu89 -O -fwrapv -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
	  -I$(INC2) -I$(S2)/libraries/base/include -include $(INC2)/Stg.h $< -o $@
endef
define HC2O_STAGE2
	@mkdir -p $(dir $@)
	$(CC) -c -x c -std=gnu89 -O -fwrapv -w -fmax-errors=20 \
	  -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
	  -I$(INC2) -I$(SRC2)/parser -I$(SRC2) -I$(S2)/libraries/base/include \
	  -include $(INC2)/Stg.h $< -o $@
endef

# Stage 2 reads the libraries' interfaces through topdir/package.conf; one
# stamp stands for "the libraries are complete" in the 220 module rules.
# (Defined before the include: make expands prerequisites when it reads a rule.)
LIBS_STAMP := $(S2)/topdir/libs.stamp

include $(MK)/deps.mk

$(MK)/deps.mk: $(MK)/gen-deps.py $(M1)/diag/base-rebuild-order.txt $(S2)/order.txt
	python3 $(MK)/gen-deps.py > $@.tmp && mv $@.tmp $@
deps: $(MK)/deps.mk

$(M1)/lib/libHSbase.a $(M1)/lib/libHSbase_cbits.a &: $(BASE_OBJS) $(wildcard $(M1)/cbitsobj/*.o) $(M1)/build-libbase.sh
	sh $(M1)/build-libbase.sh
base: $(M1)/lib/libHSbase.a

$(H98)/libHShaskell98.a: $(H98_OBJS)
	rm -f $@ && ar rcs $@ $(H98_OBJS)
haskell98: $(H98)/libHShaskell98.a

$(LIBS_STAMP): $(BASE_HIS) $(H98_HIS) $(M1)/lib/libHSbase.a $(H98)/libHShaskell98.a
	touch $@

# ---------------------------------------------------------------- stage 2
$(S2)/obj/c_hschooks.o: $(SRC2)/parser/hschooks.c
	@mkdir -p $(dir $@)
	$(CC) -c -std=gnu89 -O -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
	  -I$(INC2) -I$(SRC2)/parser -I$(SRC2) -I$(S2)/libraries/base/include $< -o $@
$(S2)/obj/c_rawSystem.o: $(SRC2)/cbits/rawSystem.c
	@mkdir -p $(dir $@)
	$(CC) -c -std=gnu89 -O -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
	  -I$(INC2) -I$(SRC2)/parser -I$(SRC2) -I$(S2)/libraries/base/include $< -o $@

# link-stage2.sh links obj/*.o: stale objects of removed modules would go in too.
$(S2)/ghc: $(STAGE2_OBJS) $(S2)/obj/c_hschooks.o $(S2)/obj/c_rawSystem.o \
           $(M1)/lib/libHSbase.a $(M1)/lib/libHSbase_cbits.a $(H98)/libHShaskell98.a $(RTS)/libHSrts.a $(S2)/link-stage2.sh
	sh $(S2)/link-stage2.sh
stage2: $(S2)/ghc

$(S2)/test/Hello.hc: $(S2)/test/Hello.hs $(S2)/ghc
	cd $(S2)/test && rm -f Hello.hc Hello.hi && ulimit -s unlimited && \
	  timeout 900 ../ghc -B../topdir -v1 -C -O Hello.hs > Hello.compile.log 2>&1 && \
	  sh $(MK)/check-hi.sh Hello.hi
test: $(S2)/test/Hello.hc

# ---------------------------------------------------------------- status
status:
	@printf 'stage1     %s\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage1 | grep -c '^sh ' ) steps stale"
	@printf 'base       %s of 147 modules to compile, %s objects\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n base | grep -c 'compile-base.sh' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n base | grep -c -- '-o $(M1)/hcobj/' )"
	@printf 'haskell98  %s of 30 modules to compile\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n haskell98 | grep -c 'compile-h98.sh' )"
	@printf 'stage2     %s of 220 modules to compile, %s objects, link: %s\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage2 | grep -c 'compile-stage2.sh' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage2 | grep -c -- '-o $(S2)/obj/' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage2 | grep -c 'link-stage2.sh' )"
