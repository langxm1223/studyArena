#include <iostream>
#include <glog/logging.h>
#include "CmakeConfig.h"

int main(int argc, char *argv[]){
	std::cout << "***** This is a StudyArena for some C++ projects! *****" << std::endl;
	std::cout << "******* The current development version is v" <<
						StudyArena_VERSION_MAJOR << "." << StudyArena_VERSION_MINOR << " *******" << std::endl;
	// LOG(INFO) << "Hello,GLOG!";
	return 0;
}