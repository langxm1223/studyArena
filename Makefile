all: 
	@[ -d build ] || mkdir build;\
	cd build; cmake .. && make
# The other way to execute them in one shell is
# .ONESHELL:

.PHONY: install
install:
	cd build && make install

clean:
	@ rm -rf build
	@ echo $@
