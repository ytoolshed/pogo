
TESTRESULTDIR := ./test-results
TESTDIR := ../t
TESTS := $(wildcard ../t/*.t)
TESTRESULTS := $(patsubst $(TESTDIR)/%.t,$(TESTRESULTDIR)/%.xml,$(TESTS))

hudson : $(TESTS) $(TESTRESULTS)
  FORMATTER := --formatter TAP::Formatter::JUnit

hudson-clean :
	rm -f $(TESTRESULTS)
	rm -rf $(TESTRESULTDIR)

test: $(TESTS)
	prove -I../lib -I../t/lib --timer $(TESTS)
#	prove --timer $(TESTS) 2>/dev/null

$(TESTS) : | $(TESTRESULTDIR)

$(TESTRESULTDIR) :
	mkdir $(TESTRESULTDIR)

$(TESTRESULTDIR)/%.xml : $(TESTDIR)/%.t
	prove -I../lib -I../t/lib --timer $(FORMATTER) $< > $@ || exit 0



