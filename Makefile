SRCS=$(shell find src/ -type f)
EXTS=GHC2021 NoImplicitPrelude PackageImports LambdaCase MultiWayIf OverloadedStrings OverloadedLists OverloadedRecordDot DuplicateRecordFields RecordWildCards NoFieldSelectors BlockArguments ViewPatterns TypeFamilies DataKinds GADTs
EXTOPTS=$(foreach opt, $(EXTS), -X$(opt))
GHCOPTS=$(EXTOPTS) -isrc -odir build -hidir build

.PHONY: clean

bless: $(SRCS)
	ghc $(GHCOPTS) --make main/Main.hs -o $@

clean:
	rm bless
	rm -r build/
