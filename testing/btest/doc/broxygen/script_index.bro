# @TEST-EXEC: bro -b -X broxygen.config %INPUT
# @TEST-EXEC: btest-diff test.rst

@TEST-START-FILE broxygen.config
script_index	broxygen/*	test.rst
@TEST-END-FILE

@load broxygen
