# build/Makefile -- the GHC 6.2.2 bootstrap chain as one dependency graph.
#
#   make -f build/Makefile [-jN] [target]        (from anywhere; sets GHC_BOOTSTRAP_ROOT itself)
#
#   stage1     build/ghc622-mhs/ghc        GHC 6.2.2 compiled by mhs (comb -> ghc-data.c -> cc)
#   base       libHSbase.a                 147 modules compiled by stage 1, .hc -> .o, archived
#   haskell98  libHShaskell98.a            30 modules
#   stage2     build/ghc622-stage2/ghc     the compiler proper, 220 modules, linked against rts622
#   test       test/Hello.hc               compiled by stage 2 (the acceptance test)
#   stage3     build/ghc622-stage2/ghc-stage3   the same 220 modules compiled by the native
#                                          stage 2 from the pristine source (stage3/, obj-stage3/)
#   test3      test/stage3/Hello.hc        compiled by stage 3, and diffed against stage 2's
#   stage4     build/ghc622-stage2/ghc-stage4   the 220 modules compiled by ghc-stage3, linked
#   stage5     stage5/*.hc                 the 220 modules compiled by ghc-stage4 (no objects, no link)
#   compare3   stage3/*.hc against stage2/*.hc: stage 2 as a compiler against stage 1 (the
#              mhs-built one runs on shims whose FastString uniques differ, so local names
#              and emission order differ; only the smallest modules come out identical)
#   compare4   stage4/*.hc against stage3/*.hc: stage 3 against stage 2, both native, both
#              from the same source -- the fixed point; every file should be identical
#   compare5   stage5/*.hc against stage4/*.hc: stage 4 against stage 3, and the two
#              compiler binaries ghc-stage3 and ghc-stage4 against each other
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
G     := $(R)/ghc622
G2    := $(G)/stage2
MK    := $(R)/build/mk
TREE  := $(R)/build/ghc-6.2.2-run1/ghc/compiler
INC1  := $(R)/build/ghc-6.2.2-run1/ghc/includes
BASE  := $(M1)/libraries/base
H98   := $(S2)/libraries/haskell98
SRC2  := $(S2)/src/ghc-6.2.2/ghc/compiler
INC2  := $(S2)/src/ghc-6.2.2/ghc/includes
ODIR2 := $(S2)/stage2
ODIR3 := $(S2)/stage3
# compile-stage2.sh for stage 3: the native compiler, pristine sources (no fixups:
# they only stood in for what the MicroHs runtime could not read), an unseeded
# retry ladder (flags.tsv records stage 1's needs, not the native compiler's),
# its own results and logs; a native compile of a module runs about 20x faster.
STAGE3_ENV := GHC=$(S2)/ghc OUTDIR=$(ODIR3) OUT=$(S2)/results-stage3.tsv LOGS=$(S2)/logs/stage3 \
              USE_FIXUPS=0 FLAGS=/dev/null MODTIMEOUT=1800
ODIR4 := $(S2)/stage4
STAGE4_ENV := GHC=$(S2)/ghc-stage3 OUTDIR=$(ODIR4) OUT=$(S2)/results-stage4.tsv LOGS=$(S2)/logs/stage4 \
              USE_FIXUPS=0 FLAGS=/dev/null MODTIMEOUT=1800
ODIR5 := $(S2)/stage5
STAGE5_ENV := GHC=$(S2)/ghc-stage4 OUTDIR=$(ODIR5) OUT=$(S2)/results-stage5.tsv LOGS=$(S2)/logs/stage5 \
              USE_FIXUPS=0 FLAGS=/dev/null MODTIMEOUT=1800
RTS   := $(R)/build/rts622
CC    ?= gcc

.DEFAULT_GOAL := stage2
.DELETE_ON_ERROR:
.PHONY: stage1 base haskell98 stage2 test stage3 test3 stage4 stage5 compare3 compare4 compare5 deps status

# ---------------------------------------------------------------- stage 1
# Everything mhs reads: the patched tree, the shims, the hs-boot and generated
# modules, the includes. build.sh comb takes ~9 min whatever changed: mhs's
# cache validation looks for <Module>.hs, so every .lhs module and its
# importers are always recompiled (build/ghc622-stage2/LOG.md, 2026-09-16).
STAGE1_SRCS := $(shell find $(TREE) $(INC1) $(R)/ghc622/shims \
    $(R)/common/shims $(R)/ghc622/shims-ghc $(R)/ghc622/shims-h98 \
    $(R)/ghc622/hsboot $(R)/ghc622/gen -type f \
    \( -name '*.hs' -o -name '*.lhs' -o -name '*.h' -o -name '*.hs-boot' \
       -o -name '*.hi-boot' -o -name '*.hs-incl' -o -name '*.txt' \) -not -path '*/tmp/*')

$(M1)/ghc.comb: $(STAGE1_SRCS) $(M1)/build.sh
	sh $(M1)/build.sh comb
$(M1)/ghc-data.c: $(M1)/ghc.comb $(G)/stage1/comb2c.py
	sh $(M1)/build.sh c
$(M1)/ghc: $(M1)/ghc-data.c $(G)/stage1/ffi.c $(G)/stage1/stubs.c $(G)/stage1/stubs.h $(M1)/build.sh
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

$(MK)/deps.mk: $(MK)/gen-deps.py $(G)/base/base-rebuild-order.txt $(G2)/order.txt
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
# The compiler's two C files, once per object directory (link-stage2.sh links
# everything in one directory).
define CC_COMPILER_C
	@mkdir -p $(dir $@)
	$(CC) -c -std=gnu89 -O -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
	  -I$(INC2) -I$(SRC2)/parser -I$(SRC2) -I$(S2)/libraries/base/include $< -o $@
endef
$(S2)/obj/c_hschooks.o $(S2)/obj-stage3/c_hschooks.o $(S2)/obj-stage4/c_hschooks.o: $(SRC2)/parser/hschooks.c
	$(CC_COMPILER_C)
$(S2)/obj/c_rawSystem.o $(S2)/obj-stage3/c_rawSystem.o $(S2)/obj-stage4/c_rawSystem.o: $(SRC2)/cbits/rawSystem.c
	$(CC_COMPILER_C)

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

# ---------------------------------------------------------------- stage 3
$(S2)/ghc-stage3: $(STAGE3_OBJS) $(S2)/obj-stage3/c_hschooks.o $(S2)/obj-stage3/c_rawSystem.o \
           $(M1)/lib/libHSbase.a $(M1)/lib/libHSbase_cbits.a $(H98)/libHShaskell98.a $(RTS)/libHSrts.a $(S2)/link-stage2.sh
	OUTDIR=stage3 sh $(S2)/link-stage2.sh
stage3: $(S2)/ghc-stage3

# Stage 3 compiles Hello.hs and its Abstract C is diffed against what stage 2
# wrote (a difference is reported, not a failure of the rule). Hello is small
# enough to come out identical; see compare3/compare4 for the real comparison.
$(S2)/test/stage3/Hello.hc: $(S2)/test/Hello.hs $(S2)/ghc-stage3 $(S2)/test/Hello.hc
	@mkdir -p $(dir $@)
	cd $(S2)/test && rm -f stage3/Hello.hc stage3/Hello.hi && ulimit -s unlimited && \
	  timeout 900 ../ghc-stage3 -B../topdir -v1 -C -O -o stage3/Hello.hc -ohi stage3/Hello.hi Hello.hs \
	    > stage3/Hello.compile.log 2>&1 && \
	  sh $(MK)/check-hi.sh stage3/Hello.hi && \
	  { cmp -s Hello.hc stage3/Hello.hc && echo 'stage 2 and stage 3 agree on test/Hello.hc' \
	    || echo "stage 2 and stage 3 DIFFER on test/Hello.hc: $$(diff Hello.hc stage3/Hello.hc | grep -c '^[<>]') lines"; }
test3: $(S2)/test/stage3/Hello.hc

$(S2)/ghc-stage4: $(STAGE4_OBJS) $(S2)/obj-stage4/c_hschooks.o $(S2)/obj-stage4/c_rawSystem.o \
           $(M1)/lib/libHSbase.a $(M1)/lib/libHSbase_cbits.a $(H98)/libHShaskell98.a $(RTS)/libHSrts.a $(S2)/link-stage2.sh
	OUTDIR=stage4 sh $(S2)/link-stage2.sh
stage4: $(S2)/ghc-stage4
stage5: $(STAGE5_HIS)

# $(call COMPARE_HC,<dir written by the newer compiler>,<dir written by the older>,<label>)
define COMPARE_HC
	@same=0; diff=0; missing=0; \
	for hc in $(STAGE2_HIS:.hi=.hc); do rel=$${hc#$(ODIR2)/}; \
	  if [ ! -f "$(1)/$$rel" ] || [ ! -f "$(2)/$$rel" ]; then missing=$$((missing+1)); \
	  elif cmp -s "$(1)/$$rel" "$(2)/$$rel"; then same=$$((same+1)); \
	  else diff=$$((diff+1)); echo "differs: $$rel"; fi; done; \
	echo "$(3) .hc: $$same identical, $$diff differ, $$missing not built on one side"
endef
compare3:
	$(call COMPARE_HC,$(ODIR3),$(ODIR2),stage 3 vs stage 2)
compare4:
	$(call COMPARE_HC,$(ODIR4),$(ODIR3),stage 4 vs stage 3)
compare5:
	$(call COMPARE_HC,$(ODIR5),$(ODIR4),stage 5 vs stage 4)
	@if cmp -s $(S2)/ghc-stage3 $(S2)/ghc-stage4; then echo 'ghc-stage3 and ghc-stage4 are byte-identical'; \
	else echo "ghc-stage3 and ghc-stage4 differ: $$(cmp -l $(S2)/ghc-stage3 $(S2)/ghc-stage4 2>/dev/null | wc -l) bytes"; fi
	@same=0; diff=0; for o in $(STAGE3_OBJS); do rel=$${o#$(S2)/obj-stage3/}; \
	  if cmp -s "$$o" "$(S2)/obj-stage4/$$rel"; then same=$$((same+1)); else diff=$$((diff+1)); echo "object differs: $$rel"; fi; done; \
	echo "obj-stage4 vs obj-stage3: $$same identical, $$diff differ"

# ---------------------------------------------------------------- status
status:
	@printf 'stage1     %s\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage1 | grep -c '^sh ' ) steps stale"
	@printf 'base       %s of 147 modules to compile, %s objects\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n base | grep -c 'compile-base.sh' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n base | grep -c -- '-o $(M1)/hcobj/' )"
	@printf 'haskell98  %s of 30 modules to compile\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n haskell98 | grep -c 'compile-h98.sh' )"
	@printf 'stage2     %s of 220 modules to compile, %s objects, link: %s\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage2 | grep -c 'compile-stage2.sh' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage2 | grep -c -- '-o $(S2)/obj/' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage2 | grep -c 'link-stage2.sh' )"
	@printf 'stage3     %s of 220 modules to compile, %s objects, link: %s\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage3 | grep -c 'compile-stage2.sh' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage3 | grep -c -- '-o $(S2)/obj-stage3/' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage3 | grep -c 'link-stage2.sh' )"
	@printf 'stage4     %s of 220 modules to compile, %s objects, link: %s\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage4 | grep -c 'compile-stage2.sh' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage4 | grep -c -- '-o $(S2)/obj-stage4/' )" "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage4 | grep -c 'link-stage2.sh' )"
	@printf 'stage5     %s of 220 modules to compile\n' "$$( $(MAKE) -s -f $(firstword $(MAKEFILE_LIST)) -n stage5 | grep -c 'OUTDIR=$(ODIR5) .*compile-stage2.sh' )"
