Hi Nayab, Hi Timo,
to have a clearer code, we wrote the code to multiple files.
The code can only be run, if the current workspace is set to this directory with all *.R-files.
The main model can be found in *allModelsVersion3.2.R*.
We excluded the parameter definition and some helper functions from the main file in *schedules.climate.parameters.R*.
Furthermore, each variation can be found in an additional file. All of them can be run consecutively by running *runAllVariations.R*.
Finally, the models themselves were outsourced to *modelsRun.R*, because this proved to be handy for the sensitivity analyses. 
The plots will be saved as png files in the plots directory.
