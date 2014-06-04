all: build tests clean

build: builder checker	 
	javac -cp "lib/*" -d ./bin -sourcepath ./src ./src/LCPL*.java ./src/ro/pub/cs/lcpl/*.java


builder:
	java -cp lib/antlrworks-1.4.jar org.antlr.Tool src/LCPLTreeBuilder.g

checker:
	java -cp lib/antlrworks-1.4.jar org.antlr.Tool src/LCPLTreeChecker.g

clean:
	rm -rf ./bin/*
	rm -f ./src/LCPLTreeBuilder.tokens
	rm -f ./src/LCPLTreeBuilderLexer.java
	rm -f ./src/LCPLTreeBuilderParser.java
	rm -f ./src/LCPLTreeChecker.tokens
	rm -f ./src/LCPLTreeChecker.java

tests:
	java -cp "lib/*:./bin" LCPLParser test/hello.lcpl bin/hello.ast
