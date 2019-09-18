# run integration methods that support Seurat objects directly

library(tidyverse)
library(Seurat)
library(SeuratWrappers)
library(harmony)
library(reticulate)
scanorama <- import('scanorama')

run_merge <- function(seurat_obj, method, covariate = 'study_accession'){
  # covariate MUST MATCH what was used in build_seurat_obj.R
  # otherwise weird-ness may happen
  # the scaling happens at this level
  # e.g. DO NOT use 'batch' in build_seurat_obj.R then 'study_accession' here
  if (method == 'CCA'){
    seurat_list <- SplitObject(seurat_obj, split.by = covariate)
    anchors <- FindIntegrationAnchors(object.list = seurat_list, dims = 1:20)
    obj <- IntegrateData(anchorset = anchors, verbose = TRUE)
    obj <- ScaleData(obj)
    obj <- RunPCA(obj, npcs = 100)
  } else if (method == 'fastMNN'){
    ## uses list of seurat objects (each obj your "covariate")
    seurat_list <- SplitObject(seurat_obj, split.by = covariate)
    obj <- RunFastMNN(object.list = seurat_list)
  } else if (method == 'harmony'){
    ## uses one seurat obj (give covariate in meta.data to group.by.vars)
    obj <- RunHarmony(seurat_obj, group.by.vars = covariate,
                      max.iter.harmony = 15, 
                      epsilon.harmony = -Inf)
  } else if (method == 'liger'){
    ## like harmony above, give one seurat obj
    ## NMF requires POSITIVE values
    ## ScaleData can return negative values
    ## so re-run with CENTER false (like the tutorial) 
    ## and, UNLIKE the tutorial set the lowest value to 0.1 in the matrix
    var_genes <- grep('^MT-', seurat_obj@assays$RNA@var.features, value = TRUE, invert = TRUE)
    obj <-  ScaleData(seurat_obj, split.by = covariate, vars.to.regress = var_genes, do.center = FALSE)
    obj@assays$RNA@scale.data <- obj@assays$RNA@scale.data - min(obj@assays$RNA@scale.data) + 0.1 # <- yeah this is hacky but I think OK...
    # ...the alternative would be to re-run from scratch with raw counts, which would mean 
    # liger would be getting differently scaled values
    # than the other methods...
    obj <- RunOptimizeALS(obj, 
                          k = 20, 
                          lambda = 5, 
                          split.by = covariate)
    obj <- RunQuantileAlignSNF(obj, split.by = "Method")
    # finally re-do scaledata in case I use it in the future...I prob won't be expecting
    # it to not be centered and with no neg values....
    obj <- ScaleData(obj,  
                     features = var_genes,
                     do.center = TRUE,
                     do.scale = TRUE,
                     vars.to.regress = c("nCount_RNA", "nFeature_RNA", "percent.mt"))
  } else if (method == 'scanorama'){
    # scanorama can return "integrated" and/or "corrected" data
    # authors say that the "integrated" data is a low-dimension (100) representation
    # of the integration, which is INTENDED FOR PCA/tSNE/UMAP!!!
    # the corrected data returns all of the sample x gene matrix with batch
    # corrected values
    assay <- 'RNA'
    d <- list() # d is lists of scaled Data
    g <- list() # g is lists of gene names for each matrix in d
    seurat_list <- SplitObject(seurat_obj, split.by = covariate)
    # build name-less list of expression values
    # and name-less list of gene names
    # if you give a list with names then reticulate / python integration explodes
    # well actully just the name are given to python...which took me
    # forever to figure out. stupid annoying. 
    for (i in seq(1, length(seurat_list))){
      # print(i);
      var_genes <- grep('^MT-', seurat_list[[i]]@assays$RNA@var.features, value = TRUE, invert = TRUE)
      d[[i]] <- t((seurat_list[[i]]@assays[[assay]]@scale.data[var_genes,])) %>% as.matrix(); 
      d[[i]][is.na(d[[i]])] <- 0; 
      g[[i]] <- colnames(d[[i]]) 
    }
    print('Run scanorama')
    integrated.corrected.data <- 
      scanorama$correct(d, g , return_dimred=TRUE, return_dense=TRUE)
    print('Scanorama done')
    # get the cell names back in as they aren't returned for some reason (reticulate?)
    for (i in seq(1, length(d))){
      # first is in the integrated data (dim reduced for UMAP, etc)
      row.names(integrated.corrected.data[[1]][[i]]) <- row.names(d[[i]])
    }
    
    # glue reduced matrix values into seurat for later UMAP, etc
    scanorama_mnn <- Reduce(rbind, integrated.corrected.data[[1]])
    colnames(scanorama_mnn) <- paste0("scanorama_", 1:ncol(scanorama_mnn))
    obj <- seurat_obj
    obj[["scanorama"]] <- CreateDimReducObject(embeddings = scanorama_mnn, key = "scanorama_", assay = DefaultAssay(obj))
    
  } else {
    print('Supply either CCA, fastMNN, harmony, liger, or scanorama as a method')
    NULL
  }
  obj
}

create_umap_neighbors <- function(integrated_obj, 
                                  max_dims = 20, 
                                  reduction_name = 'pca', 
                                  reduction_name_key = 'ccaUMAP_'){
  # UMAP
  integrated_obj <- RunUMAP(integrated_obj, 
                            dims = 1:max_dims, 
                            reduction = reduction_name, 
                            reduction.key = reduction_name_key)
  # clustering 
  integrated_obj <- FindNeighbors(integrated_obj, 
                                  dims = 1:max_dims, 
                                  nn.eps = 0.5, 
                                  reduction = reduction_name)
  integrated_obj <- FindClusters(integrated_obj, 
                              #resolution = c(0.1,0.3,0.6,0.8,1,2,3,4,5),
                              save.SNN = TRUE,
                              do.sparse = TRUE,
                              algorithm = 2,
                              random.seed = 23)
  integrated_obj
}