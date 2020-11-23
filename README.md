# Spatial organization of Colon Crypts from Second Harmonic Generation (SHG) images of fibrillar collagen of mouse colons  

## Overview

Segment colon crypts from z-projection of SHG images of fibrillar collagen and Quantify fibrosis by analyzing the spatial organization of the crypts.

This macro was used in:  <br/> <br/>
<p align="center">
	<strong>Heat Shock Factor 1-dependent extracellular matrix remodeling mediates the transition from chronic intestinal inflammation to colon cancer </strong><br/> <br/>
	</p>
	
<p align="center">
	<strong>Oshrat Levi-Galibov, Hagar Lavon, Rina Wassermann-Dozorets, Meirav Pevsner-Fischer, Shimrit Mayer, Esther Wershof, Yaniv Stein, Lauren Brown, Wenhan Zhang, Gil Friedman, Reinat Nevo,
Ofra Golani, Lior Katz, Rona Yaeger, Ido Laish, John A. Porco, Jr, Erik Sahai, Dror S. Shouval, David Kelsen and Ruth Scherz-Shouval </strong><br/> <br/>
	</p>

Software package: Fiji (ImageJ)

Workflow language: ImageJ macro

<p align="center">
<img src="https://github.com/WIS-MICC-CellObservatory/Crypts_SpatialOrganization/blob/master/SampleData/Out/Hsf1_null_day20.png" width="250" title="Input">
<img src="https://github.com/WIS-MICC-CellObservatory/Crypts_SpatialOrganization/blob/master/SampleData/Out/Hsf1_null_day20_BB_Dist_BBNN1_Flatten.png" width="250" title="Dist to Closest Crypt">
<img src="https://github.com/WIS-MICC-CellObservatory/Crypts_SpatialOrganization/blob/master/SampleData/Out/Hsf1_null_day20_NumNeighbWithinDist_Flatten.png" width="250" title="Num Neighbours within 20um">
	</p>

It assumes that the samples are carefully posioned and sectioned so that z-projection capture their shape correctly, and that z-projection was done prior to running the macro
The macro relies on (auto-context) pixel classification with Ilastik, it assumes that the given classifier was trained to predict fibrillar collagen (first class) vs crypt (second class)
  
## Workflow

1. Open selected image
2. Segment the crypts
- Apply Ilastik pixels classification to get Probability map (and save it to output folder)
- Smooth the crypt prediction probabilities using gaussian blur (sigma=2) 
- Use Hysteresis Thresholding on the crypt prediction probabilities to get labeled mask of candidate crypt objects
- Fill holes in candidate Crypt objects
- Filter candidate Crypt objects by size (>300 um^2) and Circularity (>0.1)
- Save the segmented ROIS, the labeled image and original image with overlay of the segmentation
3. Perform spatial analysis
- Calculate border-to-border distances between crypts (just as a way to save computation time) 
- Calculate border-to-border (b2b) distances to the N Center-to-Center closet crypts (CCNN=8) 
- For each crypt measure: size (um2), b2b distance to closest crypt, average b2b distance to 3 closest crypts, number of crypts for which b2b distance is smaller than DistToCheckNN (=20um)
- Calculate average values for all crypts in the image and add line with number of crypts (including border-touching crypts) and average values to the summary table
- Save images color-coded with the above measures
  	
## Output

The macro saves the following output files for each image (eg with name FN) in a subfolder (ResultsSubFolder) under the original folder location:  
- All ROIs (FN_RoiSet.zip)
- The original image with overlay of the segmented crypts (FN_Overlay.tif) 
- Result table with (FN_DistTable.csv) : one line for each crypt with all the calculated values
- Images of the segmented crypts color-coded by the closest dist (FN_BB_Dist_BBNN1_Flaten.tif), average dist to 3 closest crypts (FN_BB_AvgDist_BBNN3_Flaten.tif),  
  number of neighbor within dist (FN_NumNeighbWithinDist_Flatten.tif) 
  Apearance of the color-coded images can be changed by setting Min/Max values and colomap (aka LUT) , which are avilable at the Parameters section at the begining of the macro
  Note that you can use negative number for Min value eg to be able to see crypts with NumNeighbors=0
  
## Dependencies
- Fiji: https://imagej.net/Fiji
- Ilastik pixel classifier (ilastik-1.3.3post1) https://www.ilastik.org/ 
- Ilastik Fiji Plugin (we used Ilastik4ij1.7.0.jar which is available in: https://sites.imagej.net/Ilastik/plugins/ this one works with the autocontext pixel classifier that we trained, the latest version supports only "regular" ilastik pixel classifier)
- 3D suite plugin: make sure you have 3.94 (at least) : http://imagejdocu.tudor.lu/doku.php?id=plugin:stacks:3d_ij_suite:start#download 
- MorphoLibJ plugin: https://imagej.net/MorphoLibJ 

To install them in Fiji:
 - Help=>Update
 - Click “Manage Update sites”
 - Check "3D ImageJ Suite", “Ilastik”, “IJPB-plugins”
 - Click “Close”
 - Click “Apply changes”

##  Usage Instructions
Make sure Fiji Ilastik Plugin is installed in your Fiji (see dependencies above)
Drag and Drop the Macro into Fiji 
Click "Run" , this will open a window asking you to set parameters: 
- Set RunMode to "Segment"
- Select if you want to process Single File or Whole folder 
- Use Browse to select the File_name to analyze (or File within the folder that you want to analyze)
- Set the location of executable (ilastik.exe in the ilastik installation folder)
- Set the location of the ilastik pixel classifier (XX.ilp)
  
Click OK to run. Note that the files are quite big so analysis may take a lot of time
(you may be asked to select the *ilastik.exe file location* and than to choose *Probabilities* as your target ilastik classification)
  
To save time when processing again already-processed file and changing only Fiji parameters, 
you can use previous ilastik clasification by checking "CheckForExistingIlastikOutputFile"
  
##  Manual Correction
The above automatic process segment correctly most of the crypts. 
Further manual correction is supported by switching from Segment Mode to Update Mode.   
In Update mode the macro skips the segmentation step 2 above, instead it gets the segmented ROIS from a file, and calculate their updated measurements. 
The ROIs are read either from manually corrected file (FN_RoiSet_Manual.zip if exist) or otherwise from the original file (FN_RoiSet.zip)

### To start manual correction: 
- Open the original image (FN)
- make sure there is no RoiManager open
- drag-and-drop the "FN_RoiSet.zip" into Fiji main window 
- in RoiManager: make sure that "Show All" is selected. Ususaly it is more conveinient to unselect Labels 
  
### Select A ROI
- You can select a ROI from the ROIManager or with long click inside a crypt to select its outer ROI (with the Hand-Tool selected in Fiji main window), 
  this will highlight the (outer) ROI in the RoiManager, the matching inner Roi is just above it
   
### Delete falsely detected objects
- select a ROI
- click "Delete" to delete a ROI. 
  
### Fix segmentation error 
- select a ROI
- you can update it eg by using the brush tool (deselecting Show All may be more convnient) 
- Hold the shift key down and it will be added to the existing selection. Hold down the alt key and it will be subracted from the existing selection
- click "Update"
  
- otherwise you can delete the ROI (see above) and draw another one instead (see below)
  
### Add non-detected Crypt
- You can draw a ROI using one of the drawing tools 
- an alternative can be using the Wand tool , you'll need to set the Wand tool tolerance first by double clicking on the wand tool icon. 
  see also: https://imagej.nih.gov/ij/docs/tools.html
- click 't' from the keyboard or "Add" from RoiManger to add it to the RoiManager 
  
### Save ROIs
When done with all corrections make sure to 
- from the RoiManager, click "Deselect" 
- from the RoiManager, click "More" and then "Save" , save the updated file into a file named as the original Roi file with suffix "_Manual":  
  "FN_RoiSet_Manual.zip", using correct file name is crucial
    
### Run in Update Mode
- when done with correction run the macro again, and change "RunMode" to be "Update" (instead of "Segment")
 
## Notes Regarding Ilastik Classifier
- If your data include images with different contrast, make sure to include  representative images of all conditions When training the classifier
- It is assumed that all images have the same pixel size, identical to that used for training (here it is 0.416 um/pixel). It is not checked however. 
  up to 20% (PixelSizeCheckFactor) different from the pixel size used for training the Ilastik classifier (PixelSizeUsedForIlastik)
  
