///////////////////////////////////////////////////////////////////////////////
///
///	\file    GenerateTransposeMap.cpp
///	\author  Paul Ullrich
///	\version June 19th, 2017
///
///	<remarks>
///		Copyright 2000-2014 Paul Ullrich
///
///		This file is distributed as part of the Tempest source code package.
///		Permission is granted to use, copy, modify and distribute this
///		source code and its documentation under the terms of the GNU General
///		Public License.  This software is provided "as is" without express
///		or implied warranty.
///	</remarks>

#include "CommandLine.h"
#include "Announce.h"
#include "OfflineMap.h"

#include "netcdfcpp.h"

#include <cmath>
#include <iostream>

///////////////////////////////////////////////////////////////////////////////

int main(int argc, char** argv) {

	NcError error(NcError::silent_nonfatal);

try {
	// Map file for input
	std::string strInputMapFile;

	// Overlap mesh file
	//std::string strOverlapMesh;

	// Map file for output
	std::string strOutputMapFile;

	// Do not verify the mesh
	bool fNoCheck;

	// Check monotonicity
	bool fCheckMonotone;

	// Parse the command line
	BeginCommandLine()
		CommandLineString(strInputMapFile, "in", "");
		//CommandLineString(strOverlapMesh, "ov_mesh", "");
		CommandLineString(strOutputMapFile, "out", "");
		CommandLineBool(fNoCheck, "nocheck");
		CommandLineBool(fCheckMonotone, "checkmono");

		ParseCommandLine(argc, argv);
	EndCommandLine(argv)

	// Check arguments
	if (strInputMapFile == "") {
		_EXCEPTIONT("Input map file (--in) must be specified");
	}
	//if (strOverlapMesh == "") {
	//	_EXCEPTIONT("Overlap mesh file (--in) must be specified");
	//}
	if (strOutputMapFile == "") {
		_EXCEPTIONT("Output map file (--out) must be specified");
	}

	// Load map from file
	AnnounceStartBlock("Loading input map");
	OfflineMap mapIn;
	mapIn.Read(strInputMapFile);
	AnnounceEndBlock("Done");

	// Generate transpose map
	AnnounceStartBlock("Generating transpose map");
	OfflineMap mapOut;
	mapOut.SetTranspose(mapIn);
	AnnounceEndBlock("Done");

	// Verify map
	if (!fNoCheck) {
		AnnounceStartBlock("Verifying map");
		mapOut.IsConsistent(1.0e-8);
		mapOut.IsConservative(1.0e-8);

		if (fCheckMonotone) {
			mapOut.IsMonotone(1.0e-12);
		}
		AnnounceEndBlock("Done");
	}

	// Write map to file
	AnnounceStartBlock("Writing transpose map");
	mapOut.Write(strOutputMapFile);
	AnnounceEndBlock("Done");

	return (0);

} catch(Exception & e) {
	Announce(e.ToString().c_str());
	return (-1);

} catch(...) {
	return (-2);
}
}


///////////////////////////////////////////////////////////////////////////////

