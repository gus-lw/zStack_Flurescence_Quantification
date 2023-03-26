// zStack Fluorescence Quantification
// Version: 3.2.1
// Authors: Augustin WALTER
//
// ChangeLog:
//			- Add option to process only TIFF files





requires("1.52r");
run("Bio-Formats Macro Extensions");

var ver = "3.0.1";
var name = "zStack Fluorescence Quantification";

var startTime = getTime();

var devMode = false; // Use this option to debug the script


createROI_zProj = "Sum Slices"; //"Max Intensity";

// Clear ROI Manager and close all opened windows
clearROIMan();
run("Close All");

// Clear log
print("\\Clear");
print("\n\r\n\r================================================================================\nRunning macro '" + name + "' v." + ver +
	  "\n\r                                                                                                                    by Augustin Walter." +
	      "\n\r================================================================================" );
print("\n\r\n\r");

if ( isOpen( "Log" ) ) { selectWindow("Log"); }


var settingFilePath = getDirectory("macros") + "zStack_Fluorescence_Quantification_v2_Settings.ini";
print("> Setting file path: " + settingFilePath);

// Main operation to perform vars
var startupChoice = newArray("Create/Modify ROIs set", "Perform Analysis", "Create/Modify ROIs set and Perform Analysis (depreciated)");
var operationToPerform = "";
operationToPerform = settingRead(settingFilePath, "operationToPerform", "Create/Modify ROIs set");;


var subBk = false; var mFilter = false; // Var for sub bk and filter on create roi set

//var fluoMeasurments = newArray(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
var listOfImages = newArray();
var listOfSelectedImages = newArray();
var tempsSelectedSeries = newArray(); var listOfSelectedSeries = newArray(); var currentSelectedSeries = newArray();
var totalImages = 0; var totalSeries = 0; var totalSeriesOfAllFiles = 0;

var thresholdsList = getList("threshold.methods");
var filterList = newArray("Gaussian Blur...", "Median...", "no filter");
var pixelHeight, pixelWidth, unit, depth; 
var sizeZ = 0;
var startTime = getTime();
var calibrationMsgDisplayed = false;

var selectedAnalysisSet = "";
selectedAnalysisSet = settingRead(settingFilePath, "selectedAnalysisSet", "Create a new set of ROIs" );
//var setROIsFound = newArray("Create a new set of ROIs", "Do not use ROIs set");

var inDir; var filesList; var stacksSize = 1000000; var nameOfSmallerStack = "";

var imagesInDirCount = 0;
var currentImg = 0;

//var drawROI = false;
//drawROI = settingRead(settingFilePath, "drawROI", "" ); ///////// A MODIFIER

var useSignalThreshold = false;
if ( parseInt( settingRead(settingFilePath, "useSignalThreshold", "1" ) ) == 1 )  { useSignalThreshold = 1; } else { useSignalThreshold = 0; }

var signalCh;
signalCh = parseInt( settingRead(settingFilePath, "signalCh", 1) );

var soiChannelName;
soiChannelName = settingRead(settingFilePath, "soiChannelName", "cell");

var filter = "Median..."; 
filter = settingRead(settingFilePath, "filter", "Median...");

var filterRadius = 2;
filterRadius = parseInt( settingRead(settingFilePath, "filterRadius", 2) );

var signalThresholdMethod = "";
signalThresholdMethod = settingRead(settingFilePath, "signalThresholdMethod", "Default");

var subBkSize = 50;
subBkSize = parseInt( settingRead(settingFilePath, "subBkSize", 50 ) );

var outDir;
outDir = settingRead(settingFilePath, "outDir", "out");

var selectImgs;
selectImgs = settingRead(settingFilePath, "selectImgs", "No");

var selectSeries;
selectSeries = settingRead(settingFilePath, "selectSeries", "No");

var forceSpatialCalib = "Use images spatial calibration";
forceSpatialCalib = settingRead(settingFilePath, "forceSpatialCalib", "Use images spatial calibration");

var customX = 0.103;
customX = parseFloat( settingRead(settingFilePath, "customX", 0.103) );

var customY = 0.103;
customY = parseFloat( settingRead(settingFilePath, "customY", 0.103) );

var processOnlyTiffFiles;
if ( parseInt( settingRead(settingFilePath, "processOnlyTiffFiles", "1" ) ) == 1 )  { useSignalThreshold = 1; } else { useSignalThreshold = 0; };

//var customZStep = 0.5;
//customZStep = settingRead(settingFilePath, "customZStep", 0.5);

//var useCustomZStep = false;
//if ( parseInt( settingRead(settingFilePath, "useCustomZStep", "0" ) ) == 1 )  { useCustomZStep = 1; } else { useCustomZStepuseCustomZStep = 0; }

run("Set Measurements...", "area mean standard min centroid perimeter fit shape feret's integrated limit redirect=None decimal=2");


// First ask user what operation to perform
showStatus("Define operation to perform...");
Dialog.create(name);
Dialog.addHelp(dialog1);
Dialog.addRadioButtonGroup("Select an operation to perform", startupChoice, 3, 1, operationToPerform);
Dialog.addMessage("");
Dialog.addCheckbox("Process only TIFF files in the selected directory", processOnlyTiffFiles);
Dialog.show();

operationToPerform = Dialog.getRadioButton();
processOnlyTiffFiles = Dialog.getCheckbox();;

settingWrite(settingFilePath, "operationToPerform", operationToPerform);
settingWrite(settingFilePath, "processOnlyTiffFiles", processOnlyTiffFiles);

print("> Perform: " + operationToPerform);
print("     - Process only TIFF files in the selected directory: " + processOnlyTiffFiles);


// find first nd file to extract channel info
function ndInfo(nd_file) { 
	  nbChannel = 0;
	
	lines = split(File.openAsString(nd_file), "\n"); 
	// find number of channels
	for (i = 0; i < lines.length; i++) {
		if (startsWith(lines[i],"\"NWavelengths\"")) {
			nWaves = split(lines[i],", ");
			nbChannel = nWaves[1];
			i = lines.length;
		}
	}
	wave = newArray(parseInt(nbChannel));
	n = 0;
	for (i = 0; i < lines.length; i++) {
		w = n +1;
		if (startsWith(lines[i],"\"WaveName"+w)) {
			waves = split(lines[i],"\"");
			wave[n] = "_w1"+replace(waves[2],"_","-");
			//wave[n] = "_w1"+waves[2];
			n++;
		}
	}
	return wave;
}

// Ask user for directory where images are saved
inDir = getDirectory("Choose directory ");
analysisFilesDir = inDir + "_AW_Analysis_Files" + File.separator;
if ( !File.exists(analysisFilesDir) ) { File.makeDirectory(analysisFilesDir); print("> Analysis directory created."); }

filesList = getFileList(inDir);
print(" > Processing files in the directory: '" + inDir + "'");


print("> Scanning files inside the main directory (it can take some time)...");
showStatus("Scanning files inside the main directory (it can take some time)...");

// List all image files
wavesname = newArray();
findSmallerStack( filesList, false );
imagesInDirCount = currentImg;

showStatus("Select files and series");

print(" > " + imagesInDirCount + " image files found in the directory\n\r" );

// Check if 
if ( stacksSize == 1000000 ) {
	print("### ERROR ### No image file found in the directory:\n\r          " + inDir);
	exit("                 ### ERROR ###\n\r\n\rNo image file found in the directory:\n\r" + inDir);
	
}

// Look for set of ROIS in the analysis folder
setROIFiles = getFileList(analysisFilesDir); // get the files inside the analysis directory

if ( operationToPerform == "Perform Analysis" ) {
	setROIsFound = newArray("Do not use ROIs set, performe analysis on whole image field");
	
} else  {
	setROIsFound = newArray("Create a new set of ROIs");
	
}

for ( file = 0; file < setROIFiles.length; file++ ) {
	if ( File.isDirectory( analysisFilesDir + setROIFiles[file] ) ) {
		setROIsFound = Array.concat(setROIsFound, replace(setROIFiles[file], "/", "" ));
		
	}
	
}


// Ask user if he wants to manually select image files and series to process
Dialog.create( "Select ROIs set and Files Series" );
//Dialog.addMessage(	"This macro uses 'sets of ROIs' (or 'ROIs set') that stores ROIs and reSlice parameters of each image of the data set under one name.\n\rThis allow the user to creates different sets of ROIs and reSlices " +
//					"for a same raw data set allowing different kind of analysis on the same data set.\n\r" +
//					"Note that the ROIs and the reSlice STACK files are stored in the following directory: '/main_image_dir/_AW_Analysis_Files/name_of_the_set_Of_ROIs/'");

if ( operationToPerform == "Perform Analysis" ) {
	Dialog.addHelp(dialog2b);
	
} else {
	Dialog.addHelp(dialog2a);
	
}

Dialog.addChoice("> Select an existing set of ROIs or create a new one", setROIsFound, selectedAnalysisSet);
if ( operationToPerform == "Perform Analysis" ) { Dialog.addMessage("NB: to create new ROIs sets, select the option 'Create/Modify ROIs set' at macro startup"); }
Dialog.addMessage("--------------------------------------------------------------------------------------------------");
Dialog.addMessage("> This macro will look for files into the directory and measure the volume of the field of view.");
Dialog.addMessage(listOfImages.length + " image files found in the directory.");
Dialog.addMessage("");
Dialog.addRadioButtonGroup("Do you want to manually select the files to process?", newArray("Yes", "No, process all files"), 1, 2, selectImgs);
Dialog.addRadioButtonGroup("Do you want to manually select the series to process?", newArray("Yes", "No, process all series"), 1, 2, selectSeries);
Dialog.addMessage("(if the 'No' button is checked, all the files/series will be processed)");
Dialog.show();

selectedAnalysisSet = Dialog.getChoice();
settingWrite(settingFilePath, "selectedAnalysisSet", selectedAnalysisSet);
	
selectImgs = Dialog.getRadioButton();
selectSeries = Dialog.getRadioButton();
settingWrite(settingFilePath, "selectImgs", selectImgs);
settingWrite(settingFilePath, "selectSeries", selectSeries);


if ( operationToPerform == "Perform Analysis" && selectedAnalysisSet == "") {
	
}

// Select Images to Process Dialog
if ( selectImgs == "Yes" ) {
	listOfSelectedImages = selectImages( listOfImages, "Select images", "Select image files to process:", analysisFilesDir + selectedAnalysisSet + File.separator, true );

} else { // if not, sets all img to 1
	for ( img = 0; img < listOfImages.length; img++ ) {
		listOfSelectedImages = Array.concat(listOfSelectedImages, 1);
		
	}
	
}

// Select Series
if ( selectSeries == "Yes" ) {
	for ( fi = 0; fi < listOfImages.length; fi++ ) {
		seriesCount = 0;
		
		//print("     - " + listOfImages[fi]);
	
		if ( listOfSelectedImages[fi] == 1 ) {
			if ( endsWith( toLowerCase( listOfImages[fi] ), ".merge" ) ) {
				seriesCount = 1;
			
			} else {
				file = inDir + listOfImages[fi];
				Ext.setId(file);
				Ext.getSeriesCount(seriesCount);	//showMessage(seriesCount);	
			
				listOfs = newArray();
				for (ser = 0; ser < seriesCount; ser++ ) {
					Ext.setSeries(ser);
					Ext.getSeriesName(seriesName);
					Ext.getImageCount(imageCount);
					Ext.getSizeX(sizeX);
					Ext.getSizeY(sizeY);
					Ext.getSizeZ(sizeZ);
					Ext.getSizeC(sizeC);	
				
					listOfs = Array.concat(listOfs, "Series " + (ser+1) + ":    " + seriesName + "  -  " + imageCount + " images; Dim: " + sizeX + "x" + sizeY + 
												"x" + sizeZ + "x" + sizeC + " (XYZC)" );
												
				}

				if ( seriesCount > 1 ) {
					tempsSelectedSeries = selectImages( listOfs, "Select series", "Select series to process in image file '" + listOfImages[fi] + "':", analysisFilesDir + selectedAnalysisSet + File.separator + listOfImages[fi], false );
			
					// write series to array
					tempSerieName = tempsSelectedSeries[0] + "-";
					for (ser = 1; ser < seriesCount - 1; ser++ ) {
						tempSerieName += tempsSelectedSeries[ser] + "-";
						if ( tempsSelectedSeries[ser] == 1 ) { totalSeriesOfAllFiles ++; }
				
					}
					tempSerieName += tempsSelectedSeries[seriesCount - 1];
				
					listOfSelectedSeries = Array.concat(listOfSelectedSeries, tempSerieName);
			
				} else {
					listOfSelectedSeries = Array.concat(listOfSelectedSeries, "1-");
					totalSeriesOfAllFiles ++;
				
				}

			}
			
		
		} else { // and empty value for unselected images
			listOfSelectedSeries = Array.concat(listOfSelectedSeries, -1);
		
		}		
	
	}
	
} else {
	for ( img = 0; img < listOfImages.length; img++ ) {
		if ( listOfSelectedImages[img] == 1 ) {
		
			file = inDir + listOfImages[img];
			Ext.setId(file);
			Ext.getSeriesCount(seriesCount);

			tempArray = "1-";
			totalSeriesOfAllFiles ++;
		
			if (seriesCount > 1 ) {
				if (seriesCount > 2 ) { 
					for ( ser = 1; ser < (seriesCount-1); ser++ ) { tempArray += "1-"; totalSeriesOfAllFiles ++; }
				
				}

				tempArray += "1"; 
				totalSeriesOfAllFiles ++;
		
			}

			listOfSelectedSeries = Array.concat(listOfSelectedSeries, tempArray);

		} else {
			listOfSelectedSeries = Array.concat(listOfSelectedSeries, -1);
			
		}
		
	}
	
}

// Find smaller zStack
print("> Getting smaller stack size...");
findSmallerStack( filesList, true );

// Get the total number of selected images and series
for ( img = 0; img < listOfSelectedImages.length; img++ ) {
	if ( listOfSelectedImages[img] == 1 ) { totalImages++; }
	
}

print("> Images file selected by the user: " + totalImages);
print("> Total series selected by the user: " + totalSeriesOfAllFiles);


showStatus("General Settings...");

// First settings dialog
if ( selectedAnalysisSet == "Create a new set of ROIs" ) {
	comboChoices = newArray("Draw and Save ROIs");
	//drawROIDefault = "Draw and Save ROIs";
	Col = 1;
	
} else {
	comboChoicies = newArray("Use ROIs sets (if exists)", "Process all image field");
	//drawROIDefault = drawROI;
	Col = 3;
}

Dialog.create("General settings");
Dialog.addMessage("> Image files selected: " + totalImages + "          > Total series selected: " + totalSeriesOfAllFiles);
Dialog.addMessage("--------------------------------------------------------------------------------------------------");

if ( operationToPerform != "Create/Modify ROIs set" ) {
	Dialog.addMessage("> Analysis Parameters");
	Dialog.addCheckbox(" Use a threshold to measure signal intensity inside it", useSignalThreshold);
	Dialog.addMessage("If checked, a threshold will be applyed on the signal channel and the signal intensity will be measured within the threshold.");
	Dialog.addMessage("--------------------------------------------------------------------------------------------------");

	Dialog.addMessage("> Smaller stack found:");
	Dialog.addNumber("Number of slices", stacksSize);
	Dialog.addMessage("Name of the smaller stack: " + nameOfSmallerStack);
	Dialog.addMessage("");
	Dialog.addHelp(dialog3a);

} else {
	Dialog.addHelp(dialog3b);

}

Dialog.addString("> Name of the output directory", outDir);
Dialog.addMessage("--------------------------------------------------------------------------------------------------");

Dialog.addRadioButtonGroup("> Spatial Calibration", newArray("Use images spatial calibration", "Force Custom spatial calibration"), 2, 1, forceSpatialCalib);
Dialog.addMessage("");
Dialog.addNumber("X px value in µm:", parseFloat(customX)); Dialog.addToSameRow();
Dialog.addNumber("Y px value in µm:", parseFloat(customY));
Dialog.addMessage("(Use this option if you want to change the spatial calibration of all images)");

Dialog.show();

if ( operationToPerform != "Create/Modify ROIs set" ) {
	useSignalThreshold = Dialog.getCheckbox();
	tempSmallerStack = Dialog.getNumber();

}

outDir = Dialog.getString();
forceSpatialCalib = Dialog.getRadioButton();
customX = Dialog.getNumber();
customY = Dialog.getNumber();

if ( selectedAnalysisSet != "Create a new set of ROIs" ) {
	settingWrite(settingFilePath, "useSignalThreshold", useSignalThreshold);

}
settingWrite(settingFilePath, "outDir", outDir);

settingWrite(settingFilePath, "forceSpatialCalib", forceSpatialCalib);
settingWrite(settingFilePath, "customX", customX);
settingWrite(settingFilePath, "customY", customY);

if ( operationToPerform != "Create/Modify ROIs set" ) {
	showStatus("Signal Of Interest Settings...");

	// Signal Settings
	Dialog.create("Signal of Interest Settings"); 
	Dialog.addMessage("> Signal of Interest (SOI) settings:                     ");
	Dialog.addSlider("Channel number of the Signal of Interest (SOI)", 1, 10, signalCh);
	Dialog.addString("Name of the channel", soiChannelName);
	Dialog.addMessage("");
	Dialog.addNumber("Subtract background Rolling Ball radius", subBkSize);

	if ( useSignalThreshold ) {
		Dialog.addMessage("--------------------------------------------------------------------------------------------------");
		Dialog.addMessage("> Thresholds settings                     ");
		Dialog.addChoice("Filter to reduce image noise", filterList, filter);
		Dialog.addNumber("Filter radius", filterRadius);
		Dialog.addChoice("Signal threshold method", thresholdsList, signalThresholdMethod);

	}

	Dialog.show();

	signalCh = Dialog.getNumber();
	soiChannelName = Dialog.getString();
	subBkSize = Dialog.getNumber();


	if ( useSignalThreshold ) {
		filter = Dialog.getChoice();
		filterRadius = Dialog.getNumber();
		signalThresholdMethod = Dialog.getChoice();

		settingWrite(settingFilePath, "filter", filter);
		settingWrite(settingFilePath, "filterRadius", filterRadius);
		settingWrite(settingFilePath, "signalThresholdMethod", signalThresholdMethod);

	}

	settingWrite(settingFilePath, "signalCh", signalCh);
	settingWrite(settingFilePath, "soiChannelName", soiChannelName);
	settingWrite(settingFilePath, "subBkSize", subBkSize);

}

// Print settings
print("> Image and series selected:");
print("    + Name of the set of ROIs" + selectedAnalysisSet);
print("    + Image files: " + totalImages);
print("    + Series: " + totalSeriesOfAllFiles + "\n\r");

print("> Settings:");
if ( selectedAnalysisSet != "Create a new set of ROIs" ) {
	print("   + Use threshold to measure signal intensity: " + useSignalThreshold);

	if ( useSignalThreshold ) {
		print("      - Filter method: " + filter);
		print("      - Filter radius/sigma: " + filterRadius);
		print("      - Signal threshold method: " + signalThresholdMethod );
	
	}

}

print("   + Global spatial calibration: " + forceSpatialCalib);
print("      - X pixel value: " + customX + "\n\r      - Y pixel value:" + customY);

if ( operationToPerform != "Create/Modify ROIs set"  ) {
	print("   + Channel number of the SOI: " + signalCh);
	print("   + SOI name: " + soiChannelName);
	print("   + Subtract background Rolling Ball radius: " + subBkSize);
	print("   + Name and size of the smaller stack found: " + nameOfSmallerStack + ", " + stacksSize + " slides");

	if ( tempSmallerStack > stacksSize ) {
		if ( !getBoolean("/!\\ The size of the smaller zStacks is higher than the value automatically found.\n\rThis mean that the z-projections will not have the same number of slides" +
						" and it will not be possible to compare all the result values together.\n\r\n\r" +
						"Do you want to use the recommended value (" + stacksSize + ")?") ) {
			stacksSize = tempSmallerStack;

			print("      - @@@ CAUTION @@@ user sets the stack size to a higher value than the one of the smaller stacks");
						
		}
	
	} else if ( tempSmallerStack < stacksSize ) {
		print("      - User sets the stack size to " + tempSmallerStack);
		stacksSize = tempSmallerStack;
	
	} else {
		print("      - User did not change the stack size");
		stackSize = tempSmallerStack;
	
	}

}

// Create Output directory
outDir = inDir + File.separator + outDir + File.separator;
if (!File.isDirectory(outDir)) {
	File.makeDirectory(outDir);
	print("> Output directory sucessfully created!");
	
}

currentImg = 0;


// Load imgs and allow user to draw ROIs if option was previously checked
if ( operationToPerform == "Create/Modify ROIs set" || operationToPerform == "Create/Modify ROIs set and Perform Analysis" ) {
	if ( selectedAnalysisSet == "" ) { 
		print("\n\r"); print("> Create an new ROIs set");

	} else {
		print("> Modifiy the ROIs set '" + selectedAnalysisSet + "'");
		
	}
	
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);

	// Create a new set of ROIs if no set is selected
	if ( selectedAnalysisSet == "" || selectedAnalysisSet == "Create a new set of ROIs") {
		print("   + Creating a new set of ROIs...");
		
		tempsSetName = ""; selectedAnalysisSet = "";
		while (selectedAnalysisSet == "" ) {
			// Create the set of ROIs
			Dialog.create("Create a set of ROIs");
			Dialog.addMessage("The macro allow the user toperationToPerformo create multiple sets of ROIs-reSlice to perform different analysis with the same raw data set.\n\r" +
							  "The ROIs and the STACKs files will be created and saved in the '_AW_Analysis_Files' folder inside a new subfolder.");
			Dialog.addString("Define the name of the new set", "analysis_" + (year) + (month) + (dayOfMonth) + (hour) + (minute) + (second)); //Dialog.setInsets(0, 10, 5)
			Dialog.addMessage(" ");

			Dialog.show();
			

			tempsSetName = Dialog.getString();

			if ( !File.isDirectory( analysisFilesDir + tempsSetName ) ) {
				tempsSetName = replace(tempsSetName, "/", "_");
				File.makeDirectory( analysisFilesDir + tempsSetName);

				if ( !File.exists(analysisFilesDir + tempsSetName) ) {
					showMessage("An error occured when trying to create the directory:\n\r'" + analysisFilesDir + tempsSetName + "'\n\r\n\rTry again with another name."); 
					
				} else {
					print("      - New set of ROIs sucessfully created!");
					print("      - Name of the set: " + tempsSetName);
					print("      - Directory: " + analysisFilesDir + tempsSetName);
					selectedAnalysisSet = tempsSetName;
					
				}
				
			} else {
				showMessage("The set of ROIs '" + tempsSetName + "' already exists, try another name.");
				
			}

		}

	}

	increaseROINb = false;
	

	for (i = 0; i < listOfImages.length; i++) {

		// Check if file is selected by user
		if ( listOfSelectedImages[i] == 1 ) {

			clearROIMan();

			nd = false;
			roi = false;
			roiCount = 1;
		
			seriesFileType = ( endsWith(listOfImages[i], ".lif") || endsWith(listOfImages[i], ".nd") || endsWith(listOfImages[i], ".ics") );
	
			// for all lif or nd files 
			if ( seriesFileType || (processOnlyTiffFiles && endsWith(listOfImages[i], ".tif")) ) {
				currentImg ++;
				seriesCount = 0;
				file = inDir + listOfImages[i];

				print( "   + Processing image " + currentImg + "/" + totalImages );

				if ( seriesFileType ) {
					Ext.setId(file);
					Ext.getSeriesCount(seriesCount);	// get number of series

				} else {
					seriesCount = 1;
				
				}
				
				currentSelectedSeries = split(listOfSelectedSeries[i], "-");

				// open all series
				for ( s = 0; s < seriesCount; s++ ) {
					if ( currentSelectedSeries[s] == 1 ) {

						loadPreviousROIs = true;
					
						if ( seriesFileType ) { 
							Ext.setSeries(s); 
							Ext.getSizeC(sizeC);
							Ext.getSizeZ(sizeZ);
				
						}
				
						roiCount = 1;

						print("         - Processing serie " + (s + 1) );

						loadROI = false;
						fileName = File.getNameWithoutExtension(listOfImages[i]);

						if (endsWith(toLowerCase(listOfImages[i]), ".lif")) {
							rootName = substring(listOfImages[i], 0, indexOf(toLowerCase(listOfImages[i]), ".lif")); // get file name without extension
				
						} else if (endsWith(toLowerCase(listOfImages[i]), ".nd")) {
							wavesName = ndInfo(file);
							rootName = substring(listOfImages[i], 0, indexOf(toLowerCase(listOfImages[i]),".nd")); // get file name without extension
							nd = true;
						
						} else if (endsWith(toLowerCase(listOfImages[i]), ".ics")) {
							rootName = substring(listOfImages[i], 0, indexOf(toLowerCase(listOfImages[i]),".ics")); // get file name without extension
				
						} else {
							rootName = fileName;
							
						}

						print("            ...opening zStack, please wait...");
						selectWindow("Log");
						showStatus("Opening zStack, please wait...");
						selectWindow("ImageJ");

						// Process file only if the file is a zStack
						if ( sizeZ > 1 ) {
							startSlice = 1;

							// Check if the size of stack must be modified
							if ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack") ) {
								print( "   + Stack file found" );
								sCrop = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (s + 1), "1-" + sizeZ);
						
								if (sCrop != -1) {
									startSlice = parseInt( substring( sCrop, 0, indexOf(sCrop, "-") ) );
									endSlice = parseInt( substring( sCrop, indexOf(sCrop, "-") + 1 ));
						
								}

								if ( startSlice < 1 ) { startSlice = 1; }
								//if ( (endSlice > stacksSize) || (endSlice == NaN) ) { endSlice = stacksSize; }

								//endSlice = (stacksSize + startSlice);


							} else {
								startSlice = 1;
								endSlice = sizeZ;
							}

							// Open zStack
							if ( seriesFileType ) {
								run("Bio-Formats Importer", "open=[&file] autoscale color_mode=Composite specify_range " +
									"view=Hyperstack stack_order=XYCZT series_" + (s + 1) + " z_begin_" + (s+1) + "=" + 1 + " z_end_" + (s+1) + "=" + sizeZ + " z_step_" + (s+1) + "=1 ");
						
							} else {
							openMergeFile( file, startSlice, stacksSize, 0, 0 );
				
							}

							showStatus("Opening zStack, please wait...");
							selectWindow("ImageJ");

							getVoxelSize(width, height, depth, unit);
							getLocationAndSize(winX_0, winY_0, winWidth_0, winHeight_0);

							if ( forceSpatialCalib == "Force Custom spatial calibration" ) {
								print( "   + Spatial calibration set" );
								setVoxelSize(customX, customY, depth, "microns");
							}

							// Move the window
							setLocation(winX_0, 25);
							getLocationAndSize(winX_1, winY_1, winWidth_1, winHeight_1);
	
							// Enhance image
							imageName = getTitle();
							//rename("merge");
							if (subBk) {run("Subtract Background...", "rolling=&subBkSize stack");}
							showStatus("Opening zStack, please wait...");
							selectWindow("ImageJ");
	
							// Apply filter
							if (mFilter) {run("Median...", "radius=" + 2 + " stack");}
							showStatus("Opening zStack, please wait...");
							selectWindow("ImageJ");

							enhanceBC();
				
				
							// Open previous ROIs if exist 
							if ( ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].zip") || 
								   File.exists(analysisFilesDir + rootName + "_[ROIs-s" + (s+1) + "].roi") ) && File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].tif") ) {
								print("   + ROI found for this image, loading ROIs from the 'zip' file...");
					
								// Open files with overlay
								open( analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].tif" );
								rename("zProject");

								// Load previuous ROIs
								if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].zip") ) { 
									roiManager("Open", analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].zip");

								} else {
									roiManager("Open", analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].roi");
					
								}
								roiCount = ( roiManager("count") +1 );
	
								loadROI = true;

				
							} else {
	
								if ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].zip") || File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + selectedAnalysisSet + File.separator + rootName + "_[ROIs-s" + (s+1) + "].roi") ) {
									print("   + ROI 'zip' file found but cannot be loaded");
					
								}				
								selectWindow(imageName);

								run("Z Project...", "projection=[" + createROI_zProj + "]");
								rename("zProject");

							}
							zProjectID = getImageID();

							enhanceBC();
							setLocation(winX_1 + winWidth_1, winY_1);
							//winX_1, winY_1, winWidth_1, winHeight_1

							setTool("polygon");

							// Clear ROI Manager
							if ( !loadROI ) { clearROIMan(); }

							if ( loadROI ) {
								if ( !getBoolean("Previous ROI found and loaded, do you want to add a new ROIs?") ) {
									loadPreviousROIs = false;
						
								}
					
							}

							selectImage(zProjectID);
							enhanceBC();

							if ( loadPreviousROIs ) {		
								while ( true ) {

									selectWindow("zProject");
									run("Select None");
									increaseROINb = false;
									waitForUser("Use a selection tool to draw the " + roiCount + "° ROI and click the 'Ok' button.\n \n \n" +
												"(Hold down 'Shift' key and press 'Ok' button to skip)");

									if ( !isKeyDown("shift") ) {
										increaseROINb = true;

										// Check if selection is empty, i.e. no ROI drawn
										if ( selectionType() == -1 ) {
											// Check on both windows if there is an ROI
											if ( isActive(zProjectID) ) {
												selectWindow(imageName);
											
											} else {
												selectWindow("zProject");
											
											}
											// if not then display a message to ask user to draw an ROI
											if ( selectionType() == -1 ) {							
												while ( selectionType() == -1 ) {
													selectWindow("zProject");
													waitForUser("NO SELECTION found, please use a selection tool to draw the " + roiCount + "° ROI and click the 'Ok' button.\n\r\n\r(draw on the image entitled 'zProject')");
	
												}
											
											}

										}

										if ( !isActive(zProjectID) ) {
											selectWindow("zProject");
											run("Restore Selection");

											selectWindow(imageName);
											run("Select None");
						
										}
							
										selectWindow("zProject");
										roiManager("Add");

										setColor('yellow');
										Overlay.addSelection("yellow", 4);
										getSelectionBounds(x, y, width, height);
	
										setColor("yellow");
										setFont("SansSerif", 54, " antialiased");
										Overlay.drawString(roiCount, x + width/2, y+height/2, 0.0);
										Overlay.show;

									}

									if ( !getBoolean("Draw another ROI?") ) { break; }

									if ( increaseROINb ) { roiCount ++;	}

								}

							}
							

							// Ask user to crop the zStack
							error = 0; comment = "";
							while ( error != -1 ) {
		
								Dialog.createNonBlocking("reCrop the zStack");
								Dialog.addMessage("> Crop of the zStack");
								Dialog.addNumber("First slice", startSlice);
								Dialog.addNumber("Last slice", endSlice);
								Dialog.addMessage("-----------------------------------------------");
								Dialog.addMessage("> Add a comment to this image/serie");
								Dialog.addString("                     Comment", comment );
								Dialog.show();

								startSlice = Dialog.getNumber();
								endSlice = Dialog.getNumber();
								comment = Dialog.getString();

								// Detect errors in .stack files
								if ( startSlice > endSlice ) {
									error = "'start slice > end slice'";
								
								} else if ( startSlice == endSlice ) {
									error = "'start slice = end slice'";

								} else if ( (endSlice - startSlice) < 2 ) {
									error = "'(end slice - start slice) < 2'   ==>   the result file is not a zStack";
								
								} else {
									error = -1;
																	
								}
								
								if ( error != -1) {
									showMessage( "### ERROR ###\n\r\n\r" + "   Please check start and last slices values." + "\n\r   Details: " + error );
								
								}
							
							}

							settingWrite(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (s+1), "" + startSlice + "-" + endSlice);
							settingWrite(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "comment_" + (s+1), "" + comment);
							
	
							// export rois
							if ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "].zip") ) { 
								File.delete( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "].zip" ); 

							}
	
							selectWindow("zProject");
							exportAllRois( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" );
							saveAs("Tiff",  analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".tif");
							run("Close All");
						
							// Remove previous .roi file if a .zip file exists
							if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "].roi") && File.exists(analysisFilesDir + fileName + "_[ROIs-s" + (s+1) + "].zip") ) {
								File.delete( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "].roi");
					
							}

						} else {
							print("         @ Serie is not a z-Stack, skipping it");
					
						}

					}
			
				}

			} else if ( endsWith(listOfImages[i], ".merge") ) {
				print("\n\r> File not yet supported.\n\r      NB: only MetaMorph (ND) and Leica Image Filse (LIF) are supported (support for MERGE files coming soon).");

			} 

		}
	
	}

	// Find smaller zStack
	print("");
	print("> Getting new smaller stack size...");
	findSmallerStack( filesList, true );
	print("    - New stack size: " + stacksSize + " slices");
	/*print("\n\r> Asking user if she/he wants to begin analysis...");
	// Ask user if he/she wants to begin analysis now
	if ( !getBoolean("ROIs draw end.\n\r\n\rDo you want to proceed to image analysis?") ) {
		print("      - User said no, ending here.");
		exit();
	
	}*/
	print("\n\r> End of the creation/modification of ROIs set (@ time " + returnTime( getTime() - startTime ) + ")" );
	
} // End Of 'User draw ROIs'


run("Close All");

if ( operationToPerform != "Create/Modify ROIs set" ) {
	// Analsis part
	setBatchMode(!devMode);

	print("> BatchMode enabled");

	print("\n\r\n\r>Starting image anaysis");
	print("   @ time " + returnTime( getTime() - startTime ) );

	// Set Measurments
	run("Set Measurements...", "area mean standard min centroid perimeter fit shape feret's integrated limit redirect=None decimal=2");


	currentImg = 0;

	/*if ( File.exists( outDir + soiChannelName + "_1" + ".xls" ) ) {
		i = 1;
		while (true) {
			i++;
			if ( !File.exists( outDir + soiChannelName + "_" + i + ".xls" ) ) {
				fileResults = File.open(outDir + soiChannelName + "_" + i + ".xls");	
				break;
			
			}
		
		}
	
	} else {
		fileResults = File.open(outDir + soiChannelName + "_1" + ".xls");	
	
	} */

	if ( File.exists( outDir + "log_1.txt" ) ) {
		i = 1;
		while (true) {
			i++;
			if ( !File.exists( outDir + "log_" + i + ".txt" ) ) {
				fileResults = File.open(outDir + soiChannelName + "_" + i + ".xls");
				break;
			
			}
		
		}
	
	} else {
		fileResults = File.open(outDir + soiChannelName + "_1" + ".xls");	
	
	}
	
				
	print(fileResults,	"Signal of Interest: " + soiChannelName + "\n\r" +
						"Image\t" +
						"Comment\t" +
						"set of ROIs used\t" +
						"Stack Size (slices)\t" +
						"ROI nb\t" +
						"mass_X\t" +
						"mass_Y\t" +
						"Perimiter\t" +
						"Area\t" +
						"Elipse Major Axis\t" +
						"Elipse Minor Axis\t" +
						"Elipse Axis Angle\t" +
						"Circularity\t" +
						"Aspect Ratio\t" +
						"Roundness\t" +
						"Solidity\t" +
						"Feret X\t" +
						" Feret Y\t" +
						"Feret Angle\t" +
						"Feret min\t" +
						"Feret max\t" +
						"Mean Intensity\t" +
						"StdDev\t" +
						"Min intensity\t" +
						"Max intensity\t" +
						"Integrated Density\t" +
						"Raw Integrated Density\t" +
						"Unit\t" +
						"bit-Depth");

	imgBitDepth = 0;

	// Analyse images
	for (i = 0; i < listOfImages.length; i++) {
	
		roi = false;
		seriesFileType = ( endsWith(toLowerCase(listOfImages[i]), ".lif") || endsWith(toLowerCase(listOfImages[i]), ".nd") || endsWith(toLowerCase(listOfImages[i]), ".ics") ); // ajouter le case des fichiers MERGE
	
		// Check if file is selected by user
		if ( listOfSelectedImages[i] == 1 ) {
			currentImg ++;

			print("\n\r   * Processing file " + (currentImg) + "/" + (totalImages) + " (elapsed time: " + returnTime( getTime() - startTime ) + ")  ¬  entitled: " + listOfImages[i] );
		
			seriesCount = 0;
			file = inDir + listOfImages[i];

			if ( seriesFileType ) {
				Ext.setId(file);
				Ext.getSeriesCount(seriesCount);	// get number of series

			} else {
				seriesCount = 1;
			
			}

			currentSelectedSeries = split(listOfSelectedSeries[i], "-");

			// open all series
			for ( s = 0; s < seriesCount; s++ ) {
				clearROIMan();

				if ( currentSelectedSeries[s] == 1 ) {
			
					if ( seriesFileType ) { 
						Ext.setSeries(s);
						Ext.getSizeZ(sizeZ);
			
					}

					print("      + Processing serie " + (s+1));
	
					fileName = File.getNameWithoutExtension(listOfImages[i]);

					if (endsWith(toLowerCase(listOfImages[i]), ".lif")) {
						rootName = substring(listOfImages[i],0,indexOf(listOfImages[i],".lif")); // get file name without extension
				
					} else if ( endsWith( toLowerCase( listOfImages[i] ), ".nd" ) ) {
						wavesName = ndInfo(file);
						rootName = substring(listOfImages[i],0,indexOf(listOfImages[i],".nd")); // get file name without extension
						nd = true;
					
					} else if ( endsWith( toLowerCase( listOfImages[i] ), ".ics" ) ) {
						rootName = substring(listOfImages[i],0,indexOf(listOfImages[i],".ics")); // get file name without extension
				
					} else {
						//rootName = substring(toLowerCase(filesList[i]),0,indexOf(filesList[i],".merge"));
						rootName File.getNameWithoutExtension(filesList[i]);	
						
							
					}

					startSlice = 0; 

					if ( devMode ) { print("DEV >>> sizeZ > 1: " + (sizeZ > 1) ); }

					// Process file only if this file is a zStack
					if ( sizeZ > 1 ) {

						// Check if the size of stack must be modified
						if ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack") ) {
							print( "         - Stack file found" );
							sCrop = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (s + 1), "1-" + stacksSize);
							if (sCrop != -1) {
								startSlice = parseInt( substring( sCrop, 0, indexOf(sCrop, "-") ) );
								endSlice = parseInt( substring( sCrop, indexOf(sCrop, "-") + 1 ));
						
							}
					
							if ( startSlice < 1 ) { startSlice = 1; }
							//if ( (endSlice > stacksSize) || (endSlice == NaN) ) { endSlice = stacksSize; }					

							endSlice = (stacksSize + startSlice) - 1;

							if ( devMode ) { print("DEV >>> startSlice = " + startSlice + "; endSlice = " + endSlice); }

						} else {
							startSlice = 1;
							endSlice = stacksSize;
						
						}

						// ----------- Opening SOI channel -----------
						print("         - Opening image of the " + soiChannelName + "..."); 
						if ( devMode ) { print("DEV>>> start slice: " + startSlice + "; end slice: " + endSlice); }
						if ( seriesFileType ) {
							if ( seriesCount > 1 ) { // Open LIF series file
								if ( devMode ) { print("DEV >>> file contains multiple series"); }
								run("Bio-Formats Importer", "open=[&file] autoscale color_mode=Default rois_import=[ROI manager] specify_range " +
															"view=Hyperstack stack_order=XYCZT series_" + (s + 1) + 
															" c_begin_" + (s + 1) + "=" + signalCh + " c_end_" + (s + 1) + "=" + signalCh + " c_step_" + (s + 1) + "=1" +
															" z_begin_" + (s + 1) + "=" + startSlice + " z_end_" + (s + 1) + "=" + endSlice + " z_step_" + (s + 1) + "=1 " );

							} else { // Open nd files
								run("Bio-Formats Importer", "open=[&file] autoscale color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT " +
															"c_begin=&signalCh c_end=&signalCh c_step=1 z_begin=&startSlice z_end=&endSlice z_step=1");
							
							}
						
						} else {
							//openMergeFile( file, startSlice, stacksSize, signal1Ch - 1, 1 );
				
						}
						rename("SOI");
						getVoxelSize(pixelWidth, pixelHeight, pixelDepth, unit);

						if ( devMode ) { waitForUser("DEV >>> Checkpoint: 'Open SOI Ch'"); }

						if ( devMode ) { 
							Stack.getDimensions(width, height, channels, slices, frames);
							print("DEV >>> Stack dim: - w= " + width); 
							print("                   - h= " + height); 
							print("                   - ch= " + channels); 
							print("                   - slices= " + slices); 
							print("                   - frames= " + frames); 
					
						}					

					
						if ( forceSpatialCalib == "Force Custom spatial calibration" ) {
							print( "   + Spatial calibration set" );
							setVoxelSize(customX, customY, depth, "microns");
						}
					
						print("         - Image scale:   * Width: " + pixelWidth +
							  "                          * Height: " + pixelHeight +
							  "                          * Depth: " + pixelDepth +
							  "                          * Unit: " + unit);
						nbOfSlices = nSlices;

						if ( forceSpatialCalib == "Force Custom spatial calibration" ) {
							print( "   + Spatial calibration set" );
							setVoxelSize(customX, customY, depth, "microns");
						}
	
						// ROIs selection
						if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".zip" ) || 
							 File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".roi" ) ) {
							roisFound = true;
							 	
						} else {
							roisFound = false;
							
						}

						
						if ( roisFound ) {		/////////////////////////////////////////////		
	
							// Check if there are ROIs for this image
							if ( !File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "].zip" ) && 
								 !File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "].roi" ) ) {
								print("         #### ERROR ####  no ROIs found for this image, processing the whole image");
								nbOfROIs = 1;
								run("Select All");
								roiManager("Add");
				
							} else {
								clearROIMan();

								if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".zip" ) ) {				
									// Load ROIs
									roiManager("Open", analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".zip");

								} else if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".roi" ) ) {
									// Load ROIs
									roiManager("Open", analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (s+1) + "]" + ".roi");
						
								}

								nbOfROIs = totalROI = roiManager("count"); 
								print("         - " + nbOfROIs + " ROIs found and loaded");

							}
	
						} else {
							nbOfROIs = 1;
							// No ROI created, an ROI corresponding to the whole image is created
							run("Select All");
							roiManager("Add");

						}

						currentROI = 0;	

						run("Select None");

						// Substract bk
						print("         - Substracting background..");
						run("Subtract Background...", "rolling=&subBkSize stack");
	
						run("Z Project...", "projection=[Sum Slices]");
						rename("SOIzP");
			

						// Prepare Analyze Particles if option selected by the user
						if ( useSignalThreshold ) {
							/* The aim here is to use the SOI zStack after background substraction,
							 * then the stack is duplicated and a median filter is applyied on the duplicate.
							 * The image is thresholded with an auto-threshold previously defined by the user  
							 * and, after a max intensity zProjzction, a binary image of the SOI is created.
							 * From this binary image, a selection corresponding to the threshold is created 
							 * and applyied to the sum-slices-zProjection of the original unfiltered SOI zStack.
							 * The outside of the selection is cleared.
							 * Then the signal intensity is measured inside each ROI.
							 */
				
				
							print("         - Measuring SOI using an auto threshold:");
							run("Colors...", "foreground=white background=black selection=yellow");
		
							selectWindow("SOI");
					
							// Duplicate stack
							run("Duplicate...", "duplicate");
							rename( "duplicate" );

							// Close the original SOI zStack
							selectWindow("SOI");
							close();
		
							selectWindow("duplicate");

							// Apply filter on duplicated stack
							if ( filter == "Median..." ) {
								 run("Median...", "radius=" + filterRadius  + " stack");
								 print("         - Aplying Median filter...");

							} else if ( filter == "Gaussian Blur..." ) {
								run("Gaussian Blur...", "sigma=" + filterRadius + " stack");
								print("         - Applying Gaussian blur...");
					
							} else {
								print("         - No filter applyed");
					
							}
						
							// Applying threshold
							print("         - Converting image to mask...");
							Stack.setSlice(nSlices/2);
							setAutoThreshold(signalThresholdMethod + " dark");
							Stack.setSlice(1);
							run("Convert to Mask", "method=&signalThresholdMethod background=Dark calculate");

							run("Set Measurements...", 	"area mean standard modal min centroid center perimeter fit shape " +
													"feret's integrated limit redirect=&SOIzP decimal=2");

							// zProject sum slices
							print("         - Max Intensity zProjection (to create SOI mask)...");
							run("Z Project...", "projection=[Max Intensity]"); 	// Here we must use "Max intensity" because the stack contains binary slides!
																	// and at the end we want a binary zProjection so we must select de white pixels
							rename("filteredSOI_Mask");
						
							// Close the filtered SOI zStack
							selectWindow("duplicate");
							close();

							selectWindow("filteredSOI_Mask");

							// Set threshold and convert it into a selection
							print("         - Creating selection from thresold...");
							setAutoThreshold(signalThresholdMethod);
							run("Create Selection");
			
							selectWindow("SOIzP");
							run("Restore Selection");

							//Clear px outside selection
							run("Clear Outside");
							run("Select None");

							// Close the filtered mask of the SOI
							selectWindow("filteredSOI_Mask");
							close();

							selectWindow("SOIzP");
							imgBitDepth = bitDepth();

							// Save the thresholded SOI zProjection
							run("Set Scale...", "distance=1 known=&pixelWidth unit=&unit");
							saveAs("Tiff", outDir + rootName + "_[threshold_zP-Sum_s" + s + "].tif]");
							rename("SOIzP");

						} else {
							print("         - Measuring SOI using global quantification (without thresholding image):");
							selectWindow("SOIzP");
							imgBitDepth = bitDepth();

						}
				

						// Parse ROIs and measure
						print("         - Measuring SOI signal (" + soiChannelName + ")...");
					
						for ( roi = 0; roi < nbOfROIs; roi++ ) {
							selectWindow("SOIzP");
							roiManager("Select", roi);
							run("Measure");

							if ( roisFound ) { 
								roiTxt = (roi + 1);

							} else {
								roiTxt = "whole field";
						
							}

							if ( selectedAnalysisSet == "" ) { selectedAnalysisSet = " "; }

							// Collect results and add them to first xls file
							print(fileResults, fileName + " (serie-" + ( s + 1 ) + ")\t" +
												settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "comment_" + (s+1) , "" ) + "\t" +
												selectedAnalysisSet + "\t" +
												nbOfSlices + "\t" +
												roiTxt + "\t" +
												getResult("X", nResults - 1) + "\t" +
												getResult("Y", nResults - 1) + "\t" +
												getResult("Perim.", nResults - 1) + "\t" +
												getResult("Area", nResults - 1) + "\t" +
												getResult("Major", nResults - 1) + "\t" +
												getResult("Minor", nResults - 1) + "\t" +
												getResult("Angle", nResults - 1) + "\t" +
												getResult("Circ.", nResults - 1) + "\t" +
												getResult("AR", nResults - 1) + "\t" +
												getResult("Round", nResults - 1) + "\t" +
												getResult("Solidity", nResults - 1) + "\t" +
												getResult("FeretX", nResults - 1) + "\t" +
												getResult("FeretY", nResults - 1) + " \t" +
												getResult("FeretAngle", nResults - 1) + "\t" +
												getResult("MinFeret", nResults - 1) + "\t" +
												getResult("Feret", nResults - 1) + "\t" +
												getResult("Mean", nResults - 1) + "\t" +
												getResult("StdDev", nResults - 1) + "\t" +
												getResult("Min", nResults - 1) + "\t" +
												getResult("Max", nResults - 1) + "\t" +
												getResult("IntDen", nResults - 1) + "\t" +
												getResult("RawIntDen", nResults - 1) + "\t" +
												unit + "\t" +
												imgBitDepth );
									
					
						}
						selectWindow("SOIzP");
						close();
						run("Close All");

					} else {
						print("         - File is not a zStack, skipping it.");

					}

				}

			}

		} else if (endsWith(listOfImages[i], ".merge")) {
				print("\n\r> File not yet supported.\n\r      NB: only MetaMorph (ND) and Leica Image Filse (LIF) are supported (support for MERGE files coming soon).");

		}

	}

	File.close(fileResults);

}

showStatus("Process done...");
					

print("\n\r\n\rThe END, elapsed time: " + returnTime( getTime() - startTime ) );
print("");


if ( File.exists( outDir + "log_1.txt" ) ) {
	i = 1;
	while (true) {
		i++;
		if ( !File.exists( outDir + "log_" + i + ".txt" ) ) {
			selectWindow("Log");
			saveAs("Text", outDir + "Log_" + i + ".txt");
			break;
			
		}
		
	}
	
} else {
	selectWindow("Log");
	saveAs("Text", outDir + "Log_1.txt");
	
}



exit("Analysis finished!\n\r(elapsed time: " + returnTime( getTime() - startTime ) + ")");



			
// Other functions =============================================================================================

function selectImages( listeOfFiles, title, message, comment, forceFirstSeries) {
	nbOfImageFiles = listeOfFiles.length;
	selectedFiles = newArray();
	
	// Divide all files from list into sublists of 15 elements
	if ( nbOfImageFiles > 2 ) {
		nbOfDialogs = Math.ceil(nbOfImageFiles / 20);

	} else {
		nbOfDialogs = 1;
		
	}
	
	// Parse nb of dialogs
	for ( d = 0; d < nbOfDialogs; d++ ) {
		Dialog.create(title + " (" + (d+1) + "/" + nbOfDialogs + ")");
		Dialog.addMessage(message);

		fileStart = (20 * d);
		filesCount = 20 * (d+1);
		if ( filesCount > nbOfImageFiles ) { filesCount = nbOfImageFiles; }


		for (f = fileStart; f < filesCount; f ++) { // fileName + ".stack"
			comment2 = "";
			if ( forceFirstSeries ) { 
				s = 0; 
				comment2 = "" + comment + listeOfFiles[f];
				
			} else {
				s = f;
				
			}
			
			if ( endsWith( comment2, ".nd" ) ) {
				comment2 = replace(comment2, ".nd", ".stack");

			} else if ( endsWith( comment2, ".lif" ) ) {
				comment2 = replace(comment2, ".lif", ".stack");
			
			} else if ( endsWith( comment2, ".ics" ) ) {
				comment2 = replace(comment2, ".ics", ".stack");
				
			} else {
				comment2 = replace(comment2, ".merge", ".stack");
				comment2 = replace(comment2, ".tif", ".stack");
				
			}

			//print( ">>>DEV: file: " + comment2 +  "\n\r    Comm: " + settingRead(comment2, "comment_" + (s+1) , "" ) );
			
			
			if ( !endsWith(listeOfFiles[f], File.separator) ) { // filtrer les nd, lif et merge
				theComment = "";
				if ( comment2 != "" ) { 
					read = settingRead(comment2, "comment_" + (s+1) , "" );
					if ( read != "" ) {
						theComment = " | Comment: " + read; 

					}
				
				}
				
				Dialog.addCheckbox(listeOfFiles[f] + theComment, true);
		
			}
	
		}
		Dialog.addMessage("");
		Dialog.addMessage("Files displayed: " + filesCount + "/" + nbOfImageFiles);
		
		Dialog.show();

		// Collect data    
		for (f = fileStart; f < filesCount; f ++) {
			selectedFiles = Array.concat( selectedFiles, Dialog.getCheckbox() );
			
		}

	}

	return selectedFiles;

}




function findSmallerStack( listOfFiles, excludedFiles ) {
	// Find smaller stack
	isBatchMode = is("Batch Mode"); setBatchMode(true);
	selectWindow("ImageJ");
	currentImg = 0;
	theArray = newArray();
	error = -1;
	seriesFileType = false;

	stacksSize = 1000000; nameOfSmallerStack = "";

	// Switch between files array and images array
	if ( !excludedFiles ) {
		theArray = listOfFiles;
		
	} else {
		theArray = listOfImages;
		
	}

	for (i = 0; i < theArray.length; i++) {
	
		roi = false;
		seriesFileType = ( endsWith(toLowerCase(theArray[i]), ".lif") || endsWith(toLowerCase(theArray[i]), ".nd") || endsWith(toLowerCase(theArray[i]), ".ics") ); // add MERGE file suport

		showStatus("Scan: " + theArray[i] );
		
		print("     - Scaning: " + theArray[i]);
	
		// for all lif or nd files 
		if ( seriesFileType || (processOnlyTiffFiles && endsWith(toLowerCase(theArray[i]), ".tif")) ) {
			if ( !excludedFiles ) { listOfImages = Array.concat(listOfImages, theArray[i]); }
		
			seriesCount = 0;
			file = inDir + theArray[i];

			if ( seriesFileType ) { print("DEV >>>>>>>>>> serieFileType = true");
				Ext.setId(file);
				Ext.getSeriesCount(seriesCount);	// get number of series

			} else {
				seriesCount = 1;
			
			}

			startSlice = 0; endSlice = 0;

			if ( excludedFiles ) { currentSelectedSeries = split(listOfSelectedSeries[i], "-"); }
		

			// open all series
			for ( s = 0; s < seriesCount; s++ ) {
				if ( seriesFileType ) {  print("DEV >>>>>>>>>> serieFileType = true");
					Ext.setSeries(s); 
					Ext.getSizeZ(sizeZ);
					Ext.getSeriesName(seriesName);
				
				} else {
					open(file);
					Stack.getDimensions(width, height, channels, slices, frames);
					close();
					sizeZ = slices;
					seriesName = "";
					
					
				}

				//if ( excludedFiles ) { print(">>DEV>> current series selected (findSmaStack): " + currentSelectedSeries[s]); }

				
				fileName = File.getNameWithoutExtension(theArray[i]);

				if (endsWith(toLowerCase(theArray[i]), ".lif")) {
					rootName = substring(theArray[i],0,indexOf(theArray[i],".lif")); // get file name without extension
					
				} else if (endsWith(toLowerCase(theArray[i]), ".nd")) {
					wavesName = ndInfo(file);
					rootName = substring(theArray[i],0,indexOf(theArray[i],".nd")); // get file name without extension
					nd = true;
					
				} else if (endsWith(toLowerCase(theArray[i]), ".ics")) {
					rootName = substring(theArray[i],0,indexOf(theArray[i],".ics")); // get file name without extension
				
				} else {
					//rootName = substring(theArray[i],0,indexOf(theArray[i],".merge"));
					rootName = File.getNameWithoutExtension(theArray[i]);
							
				}

				if ( sizeZ > 1 ) { 

					// Check if the size of stack must be modified
					if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack") ) {
						sCrop = settingRead( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (s + 1), "1-" + sizeZ);
						if (sCrop != -1) {
							startSlice = parseInt( substring( sCrop, 0, indexOf(sCrop, "-") ));
							endSlice = parseInt( substring( sCrop, indexOf(sCrop, "-") + 1 ));

							if ( startSlice < 0 ) { startSlice = 1; }
							if ( (endSlice > sizeZ) || (endSlice == NaN) ) { endSlice = sizeZ; }
							
							// Detect errors in .stack files
							if ( startSlice > endSlice ) {
								error = "'start slice > end slice'";
								
							} else if ( startSlice == endSlice ) {
								error = "'start slice = end slice'";

							} else if ( (endSlice - startSlice) < 2 ) {
								error = "'(end slice - start slice) < 2'   ==>   the result file is not a zStack";
								
							}								
								
							if ( error != -1) {
								print("\n\r\n\r");
								print("### ERROR ###");
								print("An error occured while reading the STACK file '" + analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack" + "'");
								print("   in series No: " + (s+1) + "\n\r   Details: " + error);

								exit( "### ERROR ###\n\r\n\r" + "An error occured while reading the STACK file '" + analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack" + "'\n\r" + "   in series No: " + (s+1) + "\n\r   Details: " + error );
								
							}

							sizeZ = (endSlice - startSlice);
						
						} else {
							endSlice = sizeZ;
							startSlice = 1;
							
						}

					} else {
						endSlice = sizeZ;
						startSlice = 1;
						
					}

					if ( excludedFiles ) { 
						if ( parseInt( listOfSelectedImages[i] ) == 1 ) {
							if ( parseInt( currentSelectedSeries[s] ) == 1 ) { 
								if ( ( sizeZ < stacksSize ) ) {
									stacksSize = (endSlice - startSlice) + 1;
									nameOfSmallerStack = theArray[i] + "  (series " + (s+1) + ", " + seriesName +")";

								}
								
							}
							
						}
						
					} else {
						if ( ( sizeZ < stacksSize ) ) {
							stacksSize = ( endSlice - startSlice ) + 1;
							nameOfSmallerStack = theArray[i] + "  (series " + (s+1) + ")";

						}
						
					}
				
				}

			}

		}

		currentImg++;

	}
	if (!isBatchMode) { setBatchMode(false); }
	print("   > Smaller zStack size found: " + stacksSize);
	
	return stacksSize;

} 

function exportAllRois( filePath ) { 
	totalROI = roiManager("count"); 
	selection = newArray(0);
	
	for ( roi = 1; roi < totalROI; roi++ ) { selection = Array.concat(selection, roi); }

	roiManager("Select", selection);
	roiManager("Save", filePath + ".zip");
	
}

function clearROIMan() {
	/*
	if (isOpen("ROI Manager")) {
    	selectWindow("ROI Manager");
    	
  	} else {
  		run("ROI Manager...");
  		
  	}
  	*/

	totalROI = roiManager("count");  
	
  	for ( roi = 0; roi < totalROI; roi++ ) {	
		roiManager("Select", 0 );
		roiManager("Delete");

	}
	
}


function enhanceBC() {

	Stack.getDimensions(width, height, channels, slices, frames)

	if (is("composite")) {
		for (ch = 1; ch <= channels; ch++) {
			if ( slices > 1 ) {
				Stack.setPosition(ch, slices/2, 1);
				run("Enhance Contrast", "saturated=0.35");
				Stack.setSlice(1);
			} else {
				run("Enhance Contrast", "saturated=0.35");
				
			}
			
		}
		
	} else {
		if ( slices > 1 ) {
			Stack.setPosition(0, slices/2, 1);
			run("Enhance Contrast", "saturated=0.35");
			Stack.setSlice(1);

		} else {
			run("Enhance Contrast", "saturated=0.35");
			
		}
		
	}

}

// Settings functions
function settingWrite(filePath, parameterName, parameterValue) {
	// Write a setting file to save macro parameters
	// v.1.0
	// by Augustin Walter

	heading = ""; // heading for softs
	parameterItemExists = false; newFileCOntent = "";

	if ( !File.exists(filePath) ) {

		File.saveString(heading + "\n", filePath);
		
	}


	fileContent = File.openAsString(filePath);
	fileContent = split(fileContent, "\n");

	for (i = 0; i < lengthOf(fileContent); i++) {

		indexOfEqual = indexOf(fileContent[i], "=");
		splitString = split(fileContent[i], "=");
			
		if (indexOfEqual != -1) {
	
			if (splitString[0] == parameterName) {

				if ( lengthOf(splitString) == 1 ) { splitString = newArray(splitString[0], ""); }
				fileContent[i] = replace(fileContent[i], splitString[0] + "=" + splitString[1], splitString[0] + "=" + parameterValue);
				parameterItemExists = true;
					
			}
				
		}
			
	}
	newFileCOntent += fileContent[0];
	for (i = 1; i < lengthOf(fileContent); i++) {

		newFileCOntent = newFileCOntent + "\n" + fileContent[i];
		
	}

	if (parameterItemExists == false) {
		newFileCOntent += "\n" + parameterName + "=" + parameterValue;
		
	}
	
	//File.delete(filePath);
	File.saveString(newFileCOntent, filePath);
	
}

function settingRead(filePath, parameterName, defaultValue) {
	// Read a setting file to load macro parameters
	// v.1.0
	// by Augustin Walter
		
	if ( File.exists(filePath) ) {

		fileContent = File.openAsString(filePath);
		fileContent = split(fileContent, "\n");

		for (i = 0; i < lengthOf(fileContent); i++) {

			indexOfEqual = indexOf(fileContent[i], "=");
			splitString = split(fileContent[i], "=");
			
			if (indexOfEqual != -1) {

				if (splitString[0] == parameterName) {

					if ( lengthOf(splitString) == 1 ) { splitString = newArray(splitString[0], ""); }
					return splitString[1];
					
				}
				
			}
			
		}

		return defaultValue;
		
	} else {

		return defaultValue;
		
	}

}

function openMergeFile( pathToTheFile, sliceStart, sliceEnd, channelStart, channelCount ) {
	// This function opens files '.merge"
	// Parameters :
	//				- pathToTheFile: the path to the ".merge" file
	//				- sliceStart: the index of the first slice of the z-stack
	//				- sliceEnd: the number of slice to open (from the first slice)
	//				- channelStart: the index of the first channel to open
	//				- channelCount: thenumber of channel to open
	//   NB: for the 4 previous parameters, set value to 0,0 if you want to open all the stack/channels
	// Returns:
	//			- (0): the file is not an ".merge" file type
	//			- (-1): channelStart or channelCount exceed the real nb of channels
	//			- (-2): error in channels name or channel(s) file(s) not found
	//			- (1): succes!
	//
	// Important: if you open more than one channel, a merge will be created!
	
	nbOfChannels = 0; nbOfSlices = 0; channelsAreNotSplitted = false;
	chCommandID = newArray("c1", "c2", "c3", "c4", "c5", "c6", "c7");

	print("\n\r*** Function 'openMergeFile' by A. Walter ***");

	parentDir = File.getParent(pathToTheFile);

	if ( !endsWith(pathToTheFile, ".merge") ) { 
		return 0; 
	
	} else {

		nbOfChannels = parseInt( settingRead(pathToTheFile, "channels", 1) );
		tempName = settingRead(pathToTheFile, "channel_1", "NO NAME");

		// Check abnormalities in function parameters
		if ( ( channelStart > nbOfChannels ) || ( (channelStart + channelCount -1) > nbOfChannels ) ) { return -1; }
		
		chNames = newArray( tempName );

		for (i = 2; i <= nbOfChannels; i++) {
			tempName = settingRead(pathToTheFile, "channel_" + (i), "NO NAME");
			chNames = Array.concat( chNames, tempName );
		
		}

		print("   - Nb of channels: " + nbOfChannels);
		print("   - Channels names:");
		Array.print(chNames);

		oldName = chNames[0]; tempName = 0;
		for (i = 1; i < chNames.length; i++) {
			if ( chNames[i] == oldName ) {
				tempName++;
				
			}
			oldName = chNames[i];
		
		}

		if ( tempName == (nbOfChannels - 1) ) {
			channelsAreNotSplitted = true;
			
		} else if ( tempName != 0 ) {
			return -2;
			
		}

		nbOfSlices = settingRead(pathToTheFile, "slices", 0);

		firstSlice = 0; lastSlice = 0;

		if ( nbOfSlices != 0 ) {
			firstSlice = parseInt( substring( nbOfSlices, 0, indexOf(nbOfSlices, "-") ) );
			lastSlice = parseInt( substring( nbOfSlices, indexOf(nbOfSlices, "-") + 1 ) );

			if ( firstSlice < sliceStart ) { firstSlice = sliceStart; }
			if ( lastSlice > sliceEnd ) { lastSlice =  sliceEnd; }
			
			openParameters = " z_begin=" + firstSlice + " z_end=" + lastSlice + " z-step=1";

			print("    - Opening image from slide " + firstSlice + " to slide " + lastSlice);
		
		} else {
			if ( sliceEnd != 0 && sliceStart != 0) {
				openParameters = " z_begin=" + sliceStart + " z_end=" + ( sliceEnd ) + " z-step=1";

			} else {
				openParameters = "";
				
			}
			
		}
		print(openParameters);

		mergeCommand = "";

		// Open files with bioformat plugin
		if ( (channelStart + channelCount) == 0 ) { 
			firstCh = 0; lastCh = nbOfChannels;
			
		} else {
			firstCh = channelStart; lastCh = ( channelStart + channelCount);
			
		}

		print( "   - Opening channels " + firstCh + " to " + (lastCh -1) );

		if ( channelsAreNotSplitted ) {
			colorMode = "Default";
			if ( nbOfChannels > 1 ) {
				colorMode = "Composite";
			}
			print("colormode= " + colorMode);
			
			// Set channel range
			openParameters += " c_begin=" + (firstCh + 1) + " c_end=" + (lastCh) + " c=step=1";	
			
			tempName = parentDir + File.separator + chNames[0];
			print("   - Opening img: " + tempName);
			run("Bio-Formats Importer", "open=[&tempName] autoscale color_mode=&colorMode specify_range view=Hyperstack stack_order=XYCZT " + openParameters);
				
		} else {
			ch = 0;
			for ( i = firstCh; i < lastCh; i++ ) {
				print("   - Channel " + i);
				tempName = parentDir + File.separator + chNames[i];
				print("   - Opening img: " + tempName);
				run("Bio-Formats Importer", "open=[&tempName] autoscale color_mode=Default specify_range split_channels view=Hyperstack stack_order=XYCZT " + openParameters);
				tempName = getTitle();

				mergeCommand += chCommandID[ch] + "=[" + tempName + "] ";
				ch++;

			}

			if ( (lastCh - firstCh) > 1 ) {
				print("   - " + mergeCommand + " create");
				run("Merge Channels...", mergeCommand + "create");

			}

		}

		return 1;

	}
		
}


function returnTime( timeInMs ) {
	// This function returns the time in the most appropriate unit.

	if ( timeInMs < 1000 ) {
		return  "" + (timeInMs) + " ms";
		
	} else {
		timeInMs = round(timeInMs / 1000);
		
	}

	if ( timeInMs < 60 ) {
		return "" + (timeInMs) + "s"; // return time in seconds
		
	} else if ( (timeInMs > 59) && (timeInMs < 3600) ) {
		 return "" + ( floor( timeInMs / 60) % 60) + "m:" + ( timeInMs % 60 ) + "s"; // return time in minutes
		 
	} else if ( timeInMs > 3599 ) {
		return "" + floor(timeInMs / 3600) + "h:" + ( floor( timeInMs / 60) % 60) + "m:" + ( timeInMs % 60 ) + "s"; // return time in hours
		
	}
	
}


// ++++++++ HELP vars ==========================================================

var dialog1 = 	'<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: ;">About the Macro' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<p><span style="color: #000000;">The macro uses <strong>sets of Region Of Interest</strong> (ROIs Sets) to perform the analysis. The sets are defined by the user prior to the analysis. Each set can contains as many ROIs as the user wishes and during the analysis, the fluorescent signal will be measured in each ROIs of each sets. The ROIs set also allow the user to recrop zStacks by defining a new first and last slice index.</span></p>' +
				'<p><span style="color: #000000;">In the current dialog box, the 3 following options are proposed:<br /></span></p>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #000000;"><em><strong>Create/Modify ROIs set</strong></em>: create a new roi set or modify an existing one (i.e. define ROIs for each image of the analysis),</span></li>' +
				'<li><span style="color: #000000;"><em><strong>Perform Analysis</strong></em>: do the analysis using a previously created ROIs set or without using ROIs set,</span></li>' +
				'<li>The<strong> last option</strong> allow the user to directly run the analysis after defining/modifying an ROIs set.</li>' +
				'</ul>' +
				'<p>&nbsp;</p>' +
				'<p>NB: to perform the best analysis, all the zStacks must have the same number of slices, that is why it is better to define data set for all images of the experiment and then relaunch the macro to perform the analysis especially if images are in different directories.&nbsp;</p>';

var dialog2a = 	'<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: ;">About the Macro' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<h3><span style="text-decoration: underline; color: #102e3f;">Select ROIs set and Files Series:</span></h3>' +
				'<h4><span style="color: #102e3f;">Select set of ROIs or create a new one:</span></h4>' +
				'<p><span style="color: #102e3f;">The first option lists the previously created ROIs sets. Select <strong>one of these sets</strong> to modify the ROIs and the z-Reslice of images. To create a new ROIs set, select ' + "'<em><strong>Create a new set of ROIs</strong></em>'" + '.</span></p>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select files to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> select each image file to process inside the selected directory,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No, process all files</strong></em>: process all files in the selected directory.</span></li>' +
				'</ul>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select series to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> some image files contains multiple images called '+ "'series'" + ', select this option to list each series of each selected files and select series to process,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No,</strong></em> process all series: process all series of the selected image files.</span></li>' +
				'</ul>';

var dialog2b = '<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: ;">About the Macro ' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<h3><span style="text-decoration: underline; color: #102e3f;">Select ROIs set and Files Series:</span></h3>' +
				'<h4><span style="color: #102e3f;">Select set of ROIs or create a new one:</span></h4>' +
				'<p><span style="color: #102e3f;">The first option lists the previously created ROIs sets. Select <strong>one of these sets</strong> to perform the analysis using this set of ROIs. Select the option ' +"'<em><strong>Do not use ROIs set...</strong></em>' " + ' to perform the analysis without using set of ROIs (i.e. perform the analysis on entires images). Before using this option, be sure that <span style="text-decoration: underline;"><strong>all the zStacks have the same number of slices</strong></span>.</span></p>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select files to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> select each image file to process inside the selected directory,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No, process all files</strong></em>: process all files in the selected directory.</span></li>' +
				'</ul>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select series to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> some image files contains multiple images called ' + "'series'" + ', select this option to list each series of each selected files and select series to process,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No,</strong></em> process all series: process all series of the selected image files.</span></li>' +
				'</ul>';

var dialog3a = '<html>';

var dialog3b = '<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: underline;">About the Macro ' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<h3><span style="text-decoration: underline; color: #102e3f;">General Settings:</span></h3>' +
				'<h4><span style="color: #102e3f;">Name of the output directory:</span></h4>' +
				'<p><span style="color: #102e3f;">The result files and the log are saved in the result directory. This directory is created inside the directory that contains image files. The name of the result directory can be specified in the text field.</span></p>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Spatial Calibration:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Use images spatial calibration</strong></em>: use the default spatial calibration of each image to perform the analysis,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>Force Custom spatial calibration</strong></em>: specify a global spatial calibration to use in the analysis. <strong>/‼\</strong> The spatial calibration is applyed to all images.<br /></span><span style="color: #102e3f;">The value of 1 pixel in &micro;m along the X and Y axis must be specified in the two text fields.</span></li>' +
				'</ul>';