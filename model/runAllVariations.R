listfiles <- list.files()[grep("allModelsVersion3.2.sens.",list.files())]
listfiles

for (file in listfiles) {
  print(paste0("Running file: ", file))
  source(file)
}
