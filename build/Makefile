
TESTRESULTDIR := ./test-results
TESTDIR := ../t
TESTS := $(wildcard ../t/*.t)
TESTRESULTS := $(patsubst $(TESTDIR)/%.t,$(TESTRESULTDIR)/%.xml,$(TESTS))

test : $(TESTS) $(TESTRESULTS)

$(TESTS) : | $(TESTRESULTDIR)

$(TESTRESULTDIR) :
	mkdir $(TESTRESULTDIR)

$(TESTRESULTDIR)/%.xml : $(TESTDIR)/%.t
	prove --formatter TAP::Formatter::JUnit $< > $@ || exit 0

clean :
	rm -f $(TESTRESULTS)
	rm -rf $(TESTRESULTDIR)



