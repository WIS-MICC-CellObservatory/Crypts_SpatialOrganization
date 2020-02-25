// @string(choices=("Segment", "Update"), style="list") runMode
// @string(choices=("singleFile", "wholeFolder"), style="list") processMode
// @File (style="open") file_name
// @File (style="open") IlastikExecutableLocation
// @File (style="open") IlastikClassifierName
// @int MaxRAMMB
// @boolean checkForExistingIlastikOutputFile
// @boolean batchModeFlag

/* 
 *  CryptsAnalysis.ijm
 *  
 *  written by: Ofra Golani, MICC Cell Observatory, Weizmann Institute of Science
 *  For: Oshrat Galibov-Levi, Ruth Scherz-Shouval
 *  
 *  Segment colon crypts from z-projection of SHG images of fibrillar collagen and 
 *  Quantify fibrosis by analyzing the spatial organization of the crypts.
 *  
 *  It assumes that the samples are carefully posioned and sectioned so that z-projection capture their shape correctly, 
 *  and that z-projection was done prior to running the macro
 *  
 *  The macro relies on (auto-context) pixel classification with Ilastik, 
 *  it assumes that the given classifier was trained to predict fibrillar collagen (first class) vs crypt (second class)
 *  
 *  The macro can run on single file or the Whole folder in which the selected file is. Controlled by processMode
 *  
 *  Workflow 
 *  =========
 *  1. Open selected image
 *  2. Segment the crypts
 *  	a. Apply Ilastik pixels classification to get Probability map (and save it to output folder)
 *  	b. Smooth the crypt prediction probabilities using gaussian bluhr (sigma=2) 
 *  	c. Use Hysteresis Thresholding on the crypt prediction probabilities to get labeled mask of candidate crypt objects
 *  	d. Fill holes in candidate Crypt objects
 *  	e. Filter candidate Crypt objects by size (>300 um^2) and Circularity (>0.1)
 *  	f. Save the segmented ROIS, the labeled image and original image with overlay of the segmentation
 *  3. Perform spatial analysis
 *  	a. calculate border-to-border distances between crypts (just as a way to save computation time) 
 *  	b. calculate border-to-border (b2b) distances to CCNN (=8) closest crypts
 *  	c. for each crypt measure: 
 *  		- size, 
 *  		- b2b distance to closest crypt, 
 *  		- average b2b distance to 3 closest crypts, 
 *  		- number of crypts for which b2b distance is smaller than DistToCheckNN (=20um)
 *  	d. calculate average values for all crypts in the image and add line with averge values to the summary table
 *  	e. save images color-coded with the above measures
 *  	
 *  Output
 *  ======
 *  The macro saves the following output files for each image (eg with name FN) in a subfolder (ResultsSubFolder) under the original folder location:  
 *  - All ROIs (FN_RoiSet.zip)
 *  - The original image with overlay of the segmented rings (FN_Overlay.tif) 
 *  - Result table with (FN_DistTable.csv) : one line for each crypt with all the calculated values
 *  - Images of the segmented crypts color-coded by the closest dist (FN_BB_Dist_BBNN1_Flaten.tif), average dist to 3 closest crypts (FN_BB_AvgDist_BBNN3_Flaten.tif),  
 *    number of neighbor within dist (FN_NumNeighbWithinDist_Flatten.tif) 
 *    Apearance of the color-coded images can be changed by setting Min/Max values and colomap (aka LUT) , which are avilable at the Parameters section at the begining of the macro
 *    Note that you can use negative number for Min value eg to be able to see crypts with NumNeighbors=0
 *  
 *  Usage Instructions
 *  ==================
 *  Make sure Fiji Ilastik Plugin is installed in your Fiji (see dependencies below)
 *  Drag and Drop the Macro into Fiji 
 *  Click "Run" , this will envoke a window asking you to set parameters: 
 *  - Set RunMode to "Segment"
 *  - Use Browse to select the File_name to analyze
 *  - Set the location of executable (ilastik.exe in the ilastik installation folder)
 *  - Set the location of the ilastik pixel classifier (XX.ilp)
 *  
 *  Click OK to run. Note that the files are quite big so analysis may take a lot of time
 *  (you may be asked to select the *ilastik.exe file location* and than to choose *Probabilities* as your target ilastik classification)
 *  
 *  To save time when processing again already-processed file and changing only Fiji parameters, 
 *  you can use previous ilastik clasification by checking "CheckForExistingIlastikOutputFile"
 *  
 *  
 *  Manual Correction
 *  =================
 *  The above automatic process segment correctly most of the crypts. 
 *  Further manual correction is supported by switching from Segment Mode to Update Mode.   
 *  In Update mode the macro skips the segmentation step 2 above, instead it gets the segmented ROIS from a file, 
 *  and calculate theier updated measurements. 
 *  The ROIs are read either from manually corrected file (FN_RoiSet_Manual.zip if exist) or otherwise from the original file (FN_RoiSet.zip)
 *  see further instructions below 
 *  
 *  Manual Correction Instructions
 *  ==============================
 *  - Open the original image (FN)
 *  - make sure there is no RoiManager open
 *  - drag-and-drop the "FN_RoiSet.zip" into Fiji main window 
 *  - in RoiManager: make sure that "Show All" is selected. Ususaly it is more conveinient to unselect Labels 
 *  
 *  Select A ROI
 *  ------------
 *  - You can select a ROI from the ROIManager or with long click inside a ring to select its outer ROI (with the Hand-Tool selected in Fiji main window), 
 *    this will highlight the (outer) ROI in the RoiManager, the matching inner Roi is just above it
 *    
 *  Delete falsely detected objects
 *  -------------------------------
 *  - select a ROI
 *  - click "Delete" to delete a ROI. 
 *  
 *  Fix segmentation error 
 *  ----------------------
 *  - select a ROI
 *  - you can update it eg by using the brush tool (deselecting Show All may be more convnient) 
 *  - Hold the shift key down and it will be added to the existing selection. Hold down the alt key and it will be subracted from the existing selection
 *  - click "Update"
 *  
 *  - otherwise you can delete the ROI (see above) and draw another one instead (see below)
 *  
 *  Add non-detected Ring
 *  ---------------------
 *  - You can draw a ROI using one of the drawing tools 
 *  - an alternative can be using the Wand tool , you'll need to set the Wand tool tolerance first by double clicking on the wand tool icon. 
 *  see also: https://imagej.nih.gov/ij/docs/tools.html
 *  
 *  - click 't' from the keyboard or "Add" from RoiManger to add it to the RoiManager 
 *  
 *  Save ROIs
 *  ---------
 *  when done with all corrections make sure to 
 *  - from the RoiManager, click "Deselect" 
 *  - from the RoiManager, click "More" and then "Save" , save the updated file into a file named as the original Roi file with suffix "_Manual":  
 *    "FN_RoiSet_Manual.zip", using correct file name is crucial
 *    
 *  Run in Update Mode
 *  ------------------
 *  - when done with correction run the macro again, and change "RunMode" to be "Update" (instead of "Segment"
 *  
 *  Notes Regarding Ilastik Classifier
 *  ==================================
 *  - If your data include images with different contrast, make sure to include  representative images of all conditions When training the classifier
 *  - It is assumed that all images have the same pixel size, identical to that used for training (here it is 0.416 um/pixel). It is not checked however. 
 *    up to 20% (PixelSizeCheckFactor) different from the pixel size used for training the Ilastik classifier (PixelSizeUsedForIlastik)
 *  
 *  Dependencies 
 *  ============
 *  - ImageJ/Fiji: https://imagej.net/Citing, note that you need ImageJ 1.52s or newer (Help=>Update ImageJ...)
 *  - Ilastik pixel Auto-Context Classifier (or Pixel-Classifier), trained with version "ilastik-1.3.3b2)" https://www.ilastik.org/ 
 *  - Ilastik Fiji Plugin (add "Ilastik" to your selected Fiji Update Sites)
 *  - 3D suite plugin - (add "3D ImageJ Suite" to your selected Fiji Update Sites). make sure you have 3.94 (at least) : http://imagejdocu.tudor.lu/doku.php?id=plugin:stacks:3d_ij_suite:start#download 
 *  - MorphoLibJ plugin (add "IJPB-plugins" to your selected Fiji Update Sites), see: https://imagej.net/MorphoLibJ 
 *  
 *  Required Citations : 
 *  - Fiji, Ilastik, 3D suite, MorphoLibJ  
 *  
 */
  
var macroVersion = "v5";
var PixelSizeUsedForIlastik = 0.416 // um
var PixelSizeCheckFactor = 1.2; 

// Ilastik Parameters
//IlastikExecutableLocation = "C:\\Program Files\\ilastik-1.3.3b2\\ilastik.exe";
//IlastikClassifierName = "E:\\Ofra_Data\\RuthieShoval\\Oshrat\\ECM-SHG\\ECM_SHG_IlastikAutoContextClassifier_ForFiji.ilp";
var ChosenOutputType = "Probabilities";
var GaussBlurSigma = 2;
var Hyst_HighTh = 250;
var Hyst_LowTh = 200;

var MinCryptSize = 300; // um^2
var MinCryptCircularity = 0.1;

var CCNN = 8; // number of Center-Center NN to check , you may need to increase if your experiment has more close neighbors
var DistToCheckNN = 20; // um (~50 pixels); // pixels for now ToDo: convert to units

// Visualization parameters
// For Num of Neighbors
var NNWithinDist_MinVal = -1;
var NNWithinDist_MaxVal = 8;
var NNWithinDist_DecimalVal = 0;
var NNWithinDist_LUTName = "Fire";

// For Dist to nearest Neighbor
var BBNN1_MinVal = 0;
var BBNN1_MaxVal = 40; //100;
var BBNN1_DecimalVal = 0;
var BBNN1_LUTName = "Fire";

// For Average Dist to 3 nearest Neighbor
var AvgDist_BBNN3_MinVal = 0;
var AvgDist_BBNN3_MaxVal = 80; //200;
var AvgDist_BBNN3_DecimalVal = 0;
var AvgDist_BBNN3_LUTName = "Fire";

var SuffixStr = ""; // not used 
var ZoomFactorForCalibrationBar = 1;

// RunTime Parameters 
var SuffixStr = "";
var SummaryTable = "SummaryResults.xls"
var fileExtention = ".tif"; // ".ome.tif"; 
var saveIlastikOutputFileFlag = 1;
var DebugPrintFlag = 0;
var ResultsSubFolder = "Results";
var cleanupFlag = 1; //1;

// ================= Main Code ====================================

Initialization();

// It is assumed that image file is chosen, in WholeFolder - all the folder of that image is processed
directory = File.getParent(file_name);
resFolder = directory + File.separator + ResultsSubFolder + File.separator; 
File.makeDirectory(resFolder);
print("inDir=",directory," outDir=",resFolder);
if (batchModeFlag)
	setBatchMode(true);

if (matches(processMode, "singleFile")) {
	ProcessFile(directory, resFolder, file_name); }
else if (matches(processMode, "wholeFolder")) {
	ProcessFiles(directory, resFolder); }
	
setBatchMode(false);
PrintPrms();
print("Done !");

// ================= Helper Functions ====================================

//--------------------------------------
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory, resFolder) 
{
	// Get the files in the folder 
	fileListArray = getFileList(directory);
	
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], fileExtention) ) {
			file_name = directory+File.separator+fileListArray[fileIndex];
			//open(file_name);	
			print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			ProcessFile(directory, resFolder, file_name);
		} // end of if 
	} // end of for loop

	// Save Results
	if (isOpen(SummaryTable))
	{
		print("Saving SummryTable to ", resFolder+SummaryTable);
		selectWindow(SummaryTable);
		saveAs("Results", resFolder+SummaryTable);
		run("Close");  // To close non-image window
	}

	// Cleanup
	if (cleanupFlag==true) {
		if (isOpen(SummaryTable))
		{
			selectWindow(SummaryTable);
			run("Close");  // To close non-image window
		}
	}
} // end of ProcessFiles



//--------------------------------------
// Run analysis of single file
function ProcessFile(directory, resFolder, file_name) 
{

	// ===== Open File ========================
	// later on, replace with a stack and do here Z-Project, change the message above
	print(file_name);
	if ( endsWith(file_name, "h5") )
		run("Import HDF5", "select=["+file_name+"] datasetname=[/data: (1, 1, 1024, 1024, 1) uint8] axisorder=tzyxc");
	else
		open(file_name);
	run("Grays");

	// compare Pixelsize to the one used for Ilastik training
	getVoxelSize(width, height, depth, unit);
	if (width != height)
		exit("Pixel width and height are different: ", width, height);
	if ((width >  PixelSizeUsedForIlastik * PixelSizeCheckFactor) || (width <  PixelSizeUsedForIlastik / PixelSizeCheckFactor))
		exit("Pixel Size ("+width+" "+unit+") is different from the one used for Ilastik Training ("+PixelSizeUsedForIlastik+" "+PixelUnit+")\nPlease double check the settings of  PixelSize  parameter OR Use scaling !");
		
	directory = File.directory;
	origName = getTitle();
	origNameNoExt = replace(origName, ".tif","");

	// =====   Object Segmentation ===========
	// SegmentObjects: Output is an labeled image named "AllObjects" and objects in RoiManager
	SegmentObjects(directory, resFolder, origName, origNameNoExt);
	SaveOverlayImage(origName, origNameNoExt, "_Overlay"+SuffixStr+".tif", resFolder);
	
	// ===== Create Image of objects NOT touching the border
	selectWindow("AllObjects");
	run("Remove Border Labels", "left right top bottom");
	rename("AllObjects_NoBorders");

	// =====   Object Border-Border Nearest Neighbors Distance Calculation ===========
	/*  Fibrosis is quantified using shortest border-to-border (b2b) distance between crypts, 
	 *  however calculation of b2b distances is very time-consuming, so we first calculate the center-to-center (c2c) distances between all crypts, 
	 *  and then calculate b2b distances only to the CCNN (=8) closest crypts. 
	 *  If your sample exhibit more neighbors – you may need to increase this value.
	 *  
	 *  As ImageJ macro language does not support 2D arrays, the dist values are kept in auxiliary images (CCDist, BBDist)
	 */
	
	selectImage("AllObjects");
	run("3D Manager");
	Ext.Manager3D_Reset();
	Ext.Manager3D_AddImage();
	setBatchMode(true); 
	
	Ext.Manager3D_Count(nb_obj);
	print(origName, ": number of objects",nb_obj);
	
	// check "CCNN" NN and calc border-border distances for each of them 
	// then find 3 border-border NN and their distances
	newImage("CCDist", "32-bit black", nb_obj, nb_obj, 1);
	newImage("BBDist", "32-bit black", nb_obj, nb_obj, 1);
	Vol = newArray(nb_obj); 	    	// Crypt Area
	InsideArr = newArray(nb_obj); 	    // Inside: 0=touchBorder 1=Not touching the border
	InsideIdxArr = newArray(nb_obj); 	// Ids of inside objects
	BorderIdxArr = newArray(nb_obj); 	// Ids of border objects
	CCDistArr = newArray(nb_obj); 		// CC distances
	BBDistArr = newArray(CCNN);	
	BBObjArr  = newArray(CCNN);
	BB_NN1    = newArray(nb_obj);
	BB_NN2    = newArray(nb_obj);
	BB_NN3    = newArray(nb_obj);
	BB_Dist_BBNN1 = newArray(nb_obj);
	BB_Dist_BBNN2 = newArray(nb_obj);
	BB_Dist_BBNN3 = newArray(nb_obj);
	BB_AvgDist_BBNN3 = newArray(nb_obj);
	NumNeighbWithinDist = newArray(nb_obj);
	ObjName = newArray(nb_obj);
	IdArr = newArray(nb_obj);
	
	// for sanity check - no need for this late on
	CC_NN1 = newArray(nb_obj);
	CC_NN2 = newArray(nb_obj);
	CC_NN3 = newArray(nb_obj);
	BB_Dist_CCNN1 = newArray(nb_obj);
	BB_Dist_CCNN2 = newArray(nb_obj);
	BB_Dist_CCNN3 = newArray(nb_obj);
	BB_AvgDist_CCNN3 = newArray(nb_obj);
	
	selectWindow("AllObjects_NoBorders");
	nInside = 0;
	nBorder = 0;
	for (n=0; n<nb_obj; n++)
	{
		Ext.Manager3D_GetName(n, ObjName[n]);
		Ext.Manager3D_Quantif3D(n,"Max",insideFlag);
		if (insideFlag > 0)
		{
			InsideArr[n] = 1;
			InsideIdxArr[nInside] = n;
			nInside++;
		} else {
			BorderIdxArr[nBorder] = n;
			nBorder++;
		}
	}
	
	selectImage("AllObjects");
	for (n=0; n<nb_obj; n++)
	{
		Ext.Manager3D_Quantif3D(n,"Max",IdArr[n]);
		Ext.Manager3D_Measure3D(n,"Vol",Vol[n]);
		for (m=n+1; m<nb_obj; m++)
		{
			selectImage("AllObjects"); // it is important to make sure that the correct image is used for distance calculation
			Ext.Manager3D_Dist2(n,m,"cc",dist);
			selectImage("CCDist");
			setPixel(n, m, dist);
			setPixel(m, n, dist);
			if (DebugPrintFlag)
				print("Center to Center distance between "+n+" and "+m+" is",dist);
		}
		selectImage("CCDist");
		for (m=0; m<nb_obj; m++) 
			CCDistArr[m] = getPixel(n, m);
	
		sortedValues = Array.copy(CCDistArr);
		Array.sort(sortedValues);
		rankPosArr = Array.rankPositions(CCDistArr);
	
		if (DebugPrintFlag)
		{
			tCCNN = minOf(CCNN, CCDistArr.length-1);
			tCCNN = minOf(tCCNN, nb_obj-1);
			print ("\nSorted CCDist array (starting with smallest value) for "+n+":");
			for (jj = 0; jj <= tCCNN; jj++){
				print(sortedValues[jj]);
			}
		
			print ("\nRank CCDist Positions (starting with index of smallest value) for "+n+":");
			for (jj = 0; jj <= tCCNN; jj++){
				print(rankPosArr[jj]);
			}
		}
	
		tCCNN = minOf(CCNN, CCDistArr.length-1);
		tCCNN = minOf(tCCNN, nb_obj-1);
		for (j = 0; j < tCCNN; j++)
		{
			id = rankPosArr[j+1];
			selectImage("BBDist");
			dist = getPixel(n, id);
			if (dist == 0)
			{
				selectImage("AllObjects"); // it is important to make sure that the correct image is used for distance calculation
				Ext.Manager3D_Dist2(n,id,"bb",dist);
			}
			BBDistArr[j] = dist;
			BBObjArr[j]  = id;
			if (DebugPrintFlag)
				print("BB Dist Calc: ", n, j+1, id, dist);
			selectImage("BBDist");
			setPixel(n, id, dist);
			setPixel(id, n, dist);
			if (dist < DistToCheckNN)
				NumNeighbWithinDist[n] = NumNeighbWithinDist[n] + 1;
		}

		if (nb_obj <= CCNN)
		{
			BBDistArr = Array.trim(BBDistArr, nb_obj-1);
			BBObjArr = Array.trim(BBObjArr, nb_obj-1);			
		}
		// does not contain zero value
		sortedValues1 = Array.copy(BBDistArr);
		Array.sort(sortedValues1);
		rankPosArr1 = Array.rankPositions(BBDistArr);
	
		if (DebugPrintFlag)
		{
			print ("\nNonSorted BBDist array (starting with smallest value) for "+n+":");
			for (jj = 0; jj < CCNN; jj++){
				print(BBDistArr[jj]);
			}
			
			print ("\nSorted BBDist array (starting with smallest value) for "+n+":");
			for (jj = 0; jj < CCNN; jj++){
				print(sortedValues1[jj]);
			}
			
			print ("\nRank BBDist Positions (starting with index of smallest value) for "+n+":");
			for (jj = 0; jj < CCNN; jj++){
				print(rankPosArr1[jj]);
			}
		}	
		
		BB_NN1[n] = BBObjArr[rankPosArr1[0]];
		BB_NN2[n] = BBObjArr[rankPosArr1[1]];
		BB_NN3[n] = BBObjArr[rankPosArr1[2]];
		BB_Dist_BBNN1[n] = sortedValues1[0];
		BB_Dist_BBNN2[n] = sortedValues1[1];
		BB_Dist_BBNN3[n] = sortedValues1[2];
		BB_AvgDist_BBNN3[n] = (sortedValues1[0] + sortedValues1[1] + sortedValues1[2]) / 3;
		
		// for sanity check - no need for this late on
		// rankPosArr[0] is always 0 (self)
		CC_NN1[n] = BBObjArr[0];
		CC_NN2[n] = BBObjArr[1];
		CC_NN3[n] = BBObjArr[2];
		BB_Dist_CCNN1[n] = BBDistArr[0];
		BB_Dist_CCNN2[n] = BBDistArr[1];
		BB_Dist_CCNN3[n] = BBDistArr[2];
		BB_AvgDist_CCNN3[n] = (BBDistArr[0] + BBDistArr[1] + BBDistArr[2]) / 3;
		
	}
	if (!batchModeFlag) setBatchMode(false);
	// Create Results Table for all crypts ("BBDistTable"), and for inside-objects only ("Inside_BBDistTable")
	Array.show("BBDistTable",Array.getSequence(nb_obj), ObjName, IdArr, Vol, InsideArr, NumNeighbWithinDist, BB_Dist_BBNN1, BB_Dist_BBNN2, BB_Dist_BBNN3, BB_AvgDist_BBNN3, BB_NN1, BB_NN2, BB_NN3, BB_Dist_CCNN1, BB_Dist_CCNN2, BB_Dist_CCNN3, BB_AvgDist_CCNN3, CC_NN1, CC_NN2, CC_NN3);
	ShowInsideOnly(nInside, InsideIdxArr, nBorder, BorderIdxArr, Vol, NumNeighbWithinDist, BB_Dist_BBNN1, BB_Dist_BBNN2, BB_Dist_BBNN3, BB_AvgDist_BBNN3, BB_NN1, BB_NN2, BB_NN3, BB_Dist_CCNN1, BB_Dist_CCNN2, BB_Dist_CCNN3, BB_AvgDist_CCNN3, CC_NN1, CC_NN2, CC_NN3);
	
	// ============ Save Results ======================
	CreateAndSaveColorCodeImage("AllObjects_NoBorders", "Inside_BBDistTable", resFolder, origNameNoExt, "NumNeighbWithinDist", SuffixStr, NNWithinDist_MinVal, NNWithinDist_MaxVal, NNWithinDist_DecimalVal, ZoomFactorForCalibrationBar, NNWithinDist_LUTName);
	CreateAndSaveColorCodeImage("AllObjects_NoBorders", "Inside_BBDistTable", resFolder, origNameNoExt, "BB_Dist_BBNN1", SuffixStr, BBNN1_MinVal, BBNN1_MaxVal, BBNN1_DecimalVal, ZoomFactorForCalibrationBar, BBNN1_LUTName);
	CreateAndSaveColorCodeImage("AllObjects_NoBorders", "Inside_BBDistTable", resFolder, origNameNoExt, "BB_AvgDist_BBNN3", SuffixStr, AvgDist_BBNN3_MinVal, AvgDist_BBNN3_MaxVal, AvgDist_BBNN3_DecimalVal, ZoomFactorForCalibrationBar, AvgDist_BBNN3_LUTName);
	
	selectWindow("BBDistTable");
	Table.save(resFolder+origNameNoExt+"_DistTable"+SuffixStr+".xls");
	
	selectWindow("Inside_BBDistTable");
	Table.save(resFolder+origNameNoExt+"_InsideDistTable"+SuffixStr+".xls");
	rename("Inside_BBDistTable");
	IJ.renameResults("Inside_BBDistTable", "Results"); // rename to avoid table overwrite

	TotNumNeighbWithinDist = 0;
	TotBB_Dist_BBNN1 = 0;
	TotBB_Dist_BBNN2 = 0;
	TotBB_Dist_BBNN3 = 0;
	TotBB_AvgDist_BBNN3 = 0;
	TotVol = 0;
	for (n = 0; n < nResults; n++)
	{
		TotVol = TotVol + getResult("Vol", n);
		TotNumNeighbWithinDist = TotNumNeighbWithinDist + getResult("NumNeighbWithinDist", n);
		TotBB_Dist_BBNN1 = TotBB_Dist_BBNN1 + getResult("BB_Dist_BBNN1", n);
		TotBB_Dist_BBNN2 = TotBB_Dist_BBNN2 + getResult("BB_Dist_BBNN2", n);
		TotBB_Dist_BBNN3 = TotBB_Dist_BBNN3 + getResult("BB_Dist_BBNN3", n);
		TotBB_AvgDist_BBNN3 = TotBB_AvgDist_BBNN3 + getResult("BB_AvgDist_BBNN3", n);
	}
	meanVol = TotVol / nResults;
	meanNumNeighbWithinDist = TotNumNeighbWithinDist / nResults;
	meanBB_Dist_BBNN1 = TotBB_Dist_BBNN1 / nResults;
	meanBB_Dist_BBNN2 = TotBB_Dist_BBNN2 / nResults;
	meanBB_Dist_BBNN3 = TotBB_Dist_BBNN3 / nResults;
	meanBB_AvgDist_BBNN3 = TotBB_AvgDist_BBNN3 / nResults;
	IJ.renameResults("Results", "Inside_BBDistTable"); 

	// =========== Add line in Summary Table =============
	if (isOpen("Results"))
		run("Close");

	// Output the measured values into new results table
	if (isOpen(SummaryTable))
	{
		IJ.renameResults(SummaryTable, "Results"); // rename to avoid table overwrite
	}	
	else
		run("Clear Results");

	setResult("Label", nResults, origNameNoExt); 
	setResult("nAllCrypts", nResults-1, nb_obj); 
	setResult("nInsideCrypts", nResults-1, nInside); 
	setResult("meanArea", nResults-1, meanVol); 
	setResult("meanNumNeighbWithinDist", nResults-1, meanNumNeighbWithinDist); 
	setResult("meanBB_Dist_BBNN1", nResults-1, meanBB_Dist_BBNN1); 
	setResult("meanBB_Dist_BBNN2", nResults-1, meanBB_Dist_BBNN2); 
	setResult("meanBB_Dist_BBNN3", nResults-1, meanBB_Dist_BBNN3); 
	setResult("meanBB_AvgDist_BBNN3", nResults-1, meanBB_AvgDist_BBNN3); 

	// Save Results - actual saving is done at the higher level function as this table include one line for each image
	IJ.renameResults("Results", SummaryTable); // rename to avoid table overwrite

	if(cleanupFlag) Cleanup();
} // end of ProcessFile

//===============================================================================================================
function SegmentObjects(directory, resFolder, origName, origNameNoExt)
{
	SuffixStr = "";
	if (matches(runMode,"Segment")) {
		
		GetIlastikPixelProb(origName, origNameNoExt, checkForExistingIlastikOutputFile);
		
		rename("PC_Output");
		run("Duplicate...", "title=CryptProb duplicate channels=2");
		run("8-bit");
		run("Gaussian Blur...", "sigma="+GaussBlurSigma);
		run("3D Hysteresis Thresholding", "high="+Hyst_HighTh+" low="+Hyst_LowTh+" labelling");
		run("glasbey inverted");
		rename("CryptObjects");
		run("Fill Holes (Binary/Gray)");
		rename("tmpAllObjects");
		setVoxelSize(width, height, depth, unit);
		
		// Filter by size and circularity
		setThreshold(1, 65535);
		run("Convert to Mask");
		run("Analyze Particles...", "size="+MinCryptSize+"-Infinity circularity="+MinCryptCircularity+"-1.00 show=[Count Masks] add");
		run("glasbey on dark");
		rename("AllObjects");

		//rename to AllObjects, save ROI, object map , overlay image
		saveAs("Tiff", resFolder+origNameNoExt+"_AllObjects.tif");
		rename("AllObjects");
		roiManager("Save", resFolder+origNameNoExt+"_RoiSet.zip");
	} 	
	else 
	{ // Update mode
		baseRoiName = resFolder+origNameNoExt+"_RoiSet";
		manualROIFound = OpenExistingROIFile(baseRoiName);
		if (manualROIFound) 
			SuffixStr = "_Manual";
		else
			SuffixStr = "";

		// create labeled Image
		createLabelMaskFromRoiManager_byText (origName, "AllObjects");
		saveAs("Tiff", resFolder+origNameNoExt+"_AllObjects"+SuffixStr+".tif");
		rename("AllObjects");
	}	
}


//===============================================================================================================
// createLabelMaskFromRoiManager - Create Labeled Image from ROI Manager, apply scaling of the original image
function createLabelMaskFromRoiManager_byText (ImName, labeledName)
{
	selectWindow(ImName);
	getVoxelSize(width, height, depth, unit);
	newImage(labeledName, "16-bit black", getWidth(), getHeight(), 1);

	nRoi = roiManager("count");
	index = 0;
	for (id = 0; id < nRoi; id++) {
		roiManager("select", id);
		index = index+1;
		setColor(index);
		fill();
	}
	roiManager("Deselect");
	run("Select None");
	// apply scaling of original image
	setVoxelSize(width, height, depth, unit);
	
	resetMinAndMax();
	run("glasbey on dark");
}

//===============================================================================================================
function Initialization()
{
	print("Starting Initialization: Ilastik Path=",IlastikExecutableLocation);
	run("Configure ilastik executable location", "executablefilepath=["+IlastikExecutableLocation+"] numthreads=-1 maxrammb="+MaxRAMMB);	
	print("After Ilastik Config");
	run("Close All");
	print("\\Clear");
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area redirect=None decimal=3");
	if (isOpen("Results"))
	{
		selectWindow("Results");
		run("Close");  // To close non-image window
	}
	roiManager("Reset");

	// Name Settings, Set output Suffixes based on SegMode
	if (matches(runMode, "Segment")) 
	{
		SummaryTable = "SummaryResults.xls";
	} else  // (SegMode=="Update") 
	{
		SummaryTable = "SummaryResults_Manual.xls";
	}	
	
	if (isOpen(SummaryTable))
	{
		selectWindow(SummaryTable);
		run("Close");  // To close non-image window
	}
	
	print("Initialization Done");
}

//===============================================================================================================
function GetIlastikPixelProb(imageName, imageNameNoExt, checkForExistingIlastikOutputFile)
{
	selectWindow(imageName);
	getVoxelSize(width, height, depth, unit);

	found = 0;
	IlastikOutFile = imageNameNoExt+"_outProbabilities.h5";
	if (checkForExistingIlastikOutputFile)
	{
		if (File.exists(resFolder+IlastikOutFile))
		{
			print("Reading existing Ilastik output ...");
			run("Import HDF5", "select=["+resFolder+IlastikOutFile+"] datasetname=[/data: uint16] axisorder=tzyxc");
			found = 1;
		}
	}
	if (found == 0)
	{
		// run Ilastik Pixel Classifier - first channel is fibrillar collagen / second channel is Crypt
		print("Running Ilastik Pixel classifier...");
		run("Run Pixel Classification Prediction", "saveonly=false projectfilename=["+IlastikClassifierName+"] inputimage=["+imageName+"] chosenoutputtype=Probabilities");		
	}
	rename("outProbabilities");
	setVoxelSize(width, height, depth, unit);
	if (saveIlastikOutputFileFlag)
	{
		print("Saving Ilastik Pixel classifier output...");
		run("Export HDF5", "select=["+resFolder+IlastikOutFile+"] exportpath=["+resFolder+IlastikOutFile+"] datasetname=data compressionlevel=0 input="+"outProbabilities");	
		rename("outProbabilities");
	}

}

//===============================================================================================================
function CreateAndSaveColorCodeImage(labeledImName, TableName, resFolder, saveName, FtrName, SuffixStr, MinVal, MaxVal, decimalVal, calibrationZoom, LUTName)
{
	selectImage(labeledImName);
	run("Assign Measure to Label", "results="+TableName+" column="+FtrName+" min="+MinVal+" max="+MaxVal);
	run(LUTName);
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal="+decimalVal+" font=12 zoom="+calibrationZoom+" overlay");
	run("Flatten");
	saveAs("Tiff", resFolder+saveName+"_"+FtrName+"_Flatten"+SuffixStr+".tif");
}


//===============================================================================================================
function Cleanup()
{
	run("Close All");
	run("Clear Results");
	roiManager("reset");
	run("Collect Garbage");
	Ext.Manager3D_Close();
	//setBatchMode(false);
	CloseTable("BBDistTable");
	CloseTable("Inside_BBDistTable");
}


//===============================================================================================================
function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}


//===============================================================================================================
// Create Table excluding raws that refer to border-touching objects
function ShowInsideOnly(nInside, InsideIdxArr, nBorder, BorderIdxArr, Vol, NumNeighbWithinDist, BB_Dist_BBNN1, BB_Dist_BBNN2, BB_Dist_BBNN3, BB_AvgDist_BBNN3, BB_NN1, BB_NN2, BB_NN3, BB_Dist_CCNN1, BB_Dist_CCNN2, BB_Dist_CCNN3, BB_AvgDist_CCNN3, CC_NN1, CC_NN2, CC_NN3)
{
	for (n = nBorder-1;  n >= 0; n--)
	{
		print("deleting Index ", BorderIdxArr[n]);
		Vol = Array.deleteIndex(Vol, BorderIdxArr[n]); 	    
		BB_NN1 = Array.deleteIndex(BB_NN1, BorderIdxArr[n]); 	    
		BB_NN2 = Array.deleteIndex(BB_NN2, BorderIdxArr[n]); 	    
		BB_NN3 = Array.deleteIndex(BB_NN3, BorderIdxArr[n]); 	    
		BB_Dist_BBNN1 = Array.deleteIndex(BB_Dist_BBNN1, BorderIdxArr[n]); 	    
		BB_Dist_BBNN2 = Array.deleteIndex(BB_Dist_BBNN2, BorderIdxArr[n]); 	    
		BB_Dist_BBNN3 = Array.deleteIndex(BB_Dist_BBNN3, BorderIdxArr[n]); 	    
		BB_AvgDist_BBNN3 = Array.deleteIndex(BB_AvgDist_BBNN3, BorderIdxArr[n]); 	    
		NumNeighbWithinDist = Array.deleteIndex(NumNeighbWithinDist, BorderIdxArr[n]); 	    
		CC_NN1 = Array.deleteIndex(CC_NN1, BorderIdxArr[n]); 	    
		CC_NN2 = Array.deleteIndex(CC_NN2, BorderIdxArr[n]); 	    
		CC_NN3 = Array.deleteIndex(CC_NN3, BorderIdxArr[n]); 	    
		BB_Dist_CCNN1 = Array.deleteIndex(BB_Dist_CCNN1, BorderIdxArr[n]); 	    
		BB_Dist_CCNN2 = Array.deleteIndex(BB_Dist_CCNN2, BorderIdxArr[n]); 	    
		BB_Dist_CCNN3 = Array.deleteIndex(BB_Dist_CCNN3, BorderIdxArr[n]); 	    
		BB_AvgDist_CCNN3 = Array.deleteIndex(BB_AvgDist_CCNN3, BorderIdxArr[n]);
	}	

	InsideIdxArr = Array.trim(InsideIdxArr, nInside);
	Array.show("Inside_BBDistTable",Array.getSequence(nInside), Vol, InsideIdxArr, NumNeighbWithinDist, BB_Dist_BBNN1, BB_Dist_BBNN2, BB_Dist_BBNN3, BB_AvgDist_BBNN3, BB_NN1, BB_NN2, BB_NN3, BB_Dist_CCNN1, BB_Dist_CCNN2, BB_Dist_CCNN3, BB_AvgDist_CCNN3, CC_NN1, CC_NN2, CC_NN3);
}

//===============================================================================================================
function SaveOverlayImage(imageName, baseSaveName, Suffix, resDir)
{
	selectImage(imageName);
	roiManager("Deselect");
	roiManager("Show None");
	roiManager("Show All with labels");
	run("Flatten");
	saveAs("Tiff", resDir+baseSaveName+Suffix);
}


//===============================================================================================================
// Open File_Manual.zip ROI file  if it exist, otherwise open  File.zip
// returns 1 if Manual file exist , otherwise returns 0
function OpenExistingROIFile(baseRoiName)
{
	roiManager("Reset");
	manaulROI = baseRoiName+"_Manual.zip";
	origROI = baseRoiName+".zip";
	if (File.exists(manaulROI))
	{
		print("opening:",manaulROI);
		roiManager("Open", manaulROI);
		manualROIFound = 1;
	} else // Manual file not found, open original ROI file 
	{
		if (File.exists(origROI))
		{
			print("opening:",origROI);
			roiManager("Open", origROI);
			manualROIFound = 0;
		} else {
			print(origROI," Not found");
			exit("You need to Run the macro in *Segment* mode before running again in *Update* mode");
		}
	}
	return manualROIFound;
}


//===============================================================================================================
function PrintPrms()
{
	// print parameters to Prm file for documentation
	PrmFile = resFolder+"CryptAnalysisParameters.txt";
	File.saveString("macroVersion="+macroVersion, PrmFile);
	File.append("", PrmFile); 
	File.append("IlastikExecutableLocation="+IlastikExecutableLocation, PrmFile); 
	File.append("fileExtention="+fileExtention, PrmFile); 
	File.append("GaussBlurSigma="+GaussBlurSigma, PrmFile); 
	File.append("Hyst_HighTh="+Hyst_HighTh, PrmFile); 
	File.append("Hyst_LowTh="+Hyst_LowTh, PrmFile); 
	File.append("MinCryptSize="+MinCryptSize, PrmFile); 
	File.append("MinCryptCircularity="+MinCryptCircularity, PrmFile); 
	File.append("CCNN="+CCNN, PrmFile); 
	File.append("DistToCheckNN="+DistToCheckNN, PrmFile); 
	File.append("NNWithinDist_MinVal="+NNWithinDist_MinVal, PrmFile); 
	File.append("NNWithinDist_MaxVal="+NNWithinDist_MaxVal, PrmFile); 
	File.append("NNWithinDist_DecimalVal="+NNWithinDist_DecimalVal, PrmFile); 
	File.append("NNWithinDist_LUTName="+NNWithinDist_LUTName, PrmFile); 
	File.append("BBNN1_MinVal="+BBNN1_MinVal, PrmFile); 
	File.append("BBNN1_MaxVal="+BBNN1_MaxVal, PrmFile); 
	File.append("BBNN1_DecimalVal="+BBNN1_DecimalVal, PrmFile); 
	File.append("BBNN1_LUTName="+BBNN1_LUTName, PrmFile); 
	File.append("AvgDist_BBNN3_MinVal="+AvgDist_BBNN3_MinVal, PrmFile); 
	File.append("AvgDist_BBNN3_MaxVal="+AvgDist_BBNN3_MaxVal, PrmFile); 
	File.append("AvgDist_BBNN3_DecimalVal="+AvgDist_BBNN3_DecimalVal, PrmFile); 
	File.append("AvgDist_BBNN3_LUTName="+AvgDist_BBNN3_LUTName, PrmFile); 
}

