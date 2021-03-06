library(tidyverse)
#library(ggforce)
#library(ggrepel)
library(cowplot)
library(scattermore)

args <- commandArgs(trailingOnly = TRUE)

red <- args[1]
load(args[2])
ptsize = 4

if (grepl('onlyWELL', args[2])){
 	celltype_col <- 'CellType_predict'
 	print('woo')
    ptsize = 20
 } else { 
 	celltype_col <- 'CellType' 
 }

if (!"cluster" %in% colnames(umap)){
  umap$cluster <- umap$clusters
} 

# filter
umap <- umap %>% 
  #rename(Stage = integration_group) %>% 
  mutate(CellType = gsub('Rod Bipolar Cells', 'Bipolar Cells', !!as.symbol(celltype_col))) %>% 
  filter(!is.na(CellType), 
         !is.na(study_accession), 
         !CellType %in% c('Doublet', 'Doublets'),
         !grepl('Mesenchyme/Lens', CellType))  %>% 
  mutate(Size = case_when(organism == 'Homo sapiens' ~ 0.015,
                          TRUE ~ 0.01)) 

# attach colors to cell types
cell_types <- umap %>% 
  pull(CellType) %>% unique() %>% sort()
type_val <- setNames(c(pals::alphabet(), pals::alphabet2())[1:length(cell_types)], cell_types)
type_col <- scale_colour_manual(values = type_val)
type_fill <- scale_fill_manual(values = type_val)

# cell type known
plot1 <- umap %>% 
  ggplot() + 
  geom_scattermore(aes(x=umap[,paste0(red,'_1')] %>% pull(1), 
                       y = umap[,paste0(red,'_2')] %>% pull(1), 
                       colour = CellType), pointsize = (ptsize/3), alpha = 0.1) + 
  guides(colour = guide_legend(override.aes = list(size=8, alpha = 1))) + 
  theme_cowplot() + 
  #geom_label_repel(data = cluster_labels, aes(x=x, y=y, label = seurat_cluster_CellType_num ), alpha = 0.8, size = 2) +
  type_col + 
  theme(axis.text.x=element_text(angle = 90, vjust = 0.5)) +
  xlab(paste(red, '1')) + ylab(paste(red, '2'))

# Age
#plot2 <- umap %>% 
#  ggplot() + 
#  geom_scattermore(aes(x = umap[,paste0(red,'_1')] %>% pull(1), 
#                       y = umap[,paste0(red,'_2')] %>% pull(1),  
#                       colour = Stage), pointsize = ptsize, alpha = 0.1) + 
#  guides(colour = guide_legend(override.aes = list(size=8, alpha = 1))) + 
#  theme_cowplot() + 
#  #geom_label_repel(data = cluster_labels, aes(x=x, y=y, label = seurat_cluster_CellType_num )) +
#  scale_color_manual(values = as.vector(pals::alphabet()) %>% tail(2)) + 
#  theme(axis.text.x=element_text(angle = 90, vjust = 0.5)) +
#  xlab(paste(red, '1')) + ylab(paste(red, '2'))

# facet by organism
plot3 <- umap %>% 
  ggplot() + 
  geom_scattermore(aes(x = umap[,paste0(red,'_1')] %>% pull(1), 
                       y = umap[,paste0(red,'_2')] %>% pull(1),   
                       colour = CellType, pointsize = ptsize), alpha = 0.1) + 
  guides(colour = guide_legend(override.aes = list(size=10, alpha = 1))) + 
  theme_cowplot() + 
  scale_size(guide = 'none') +
  scale_alpha(guide = 'none') +
  #geom_label_repel(data = cluster_labels, aes(x=x, y=y, label = seurat_cluster_CellType_num )) +
  type_col + 
  theme(axis.text.x=element_text(angle = 90, vjust = 0.5)) +
  facet_wrap(~organism) +
  xlab(paste(red, '1')) + ylab(paste(red, '2'))


# facet by celltype, color by organism
plot4 <- umap %>% 
  ggplot() + 
  geom_scattermore(aes(x = umap[,paste0(red,'_1')] %>% pull(1), 
                       y = umap[,paste0(red,'_2')] %>% pull(1), 
                       colour = organism), pointsize = ptsize,  alpha = 0.1) + 
  guides(colour = guide_legend(override.aes = list(size=10, alpha = 1))) + 
  theme_cowplot() + 
  scale_size(guide = 'none') +
  scale_alpha(guide = 'none') +
  #geom_label_repel(data = cluster_labels, aes(x=x, y=y, label = seurat_cluster_CellType_num )) +
  theme(axis.text.x=element_text(angle = 90, vjust = 0.5)) +
  facet_wrap(~CellType) +
  xlab(paste(red, '1')) + ylab(paste(red, '2'))

# facet by cluster, color by CellType
plot5 <- umap %>% 
  ggplot() + 
  geom_scattermore(aes(x = umap[,paste0(red,'_1')] %>% pull(1), 
                       y = umap[,paste0(red,'_2')] %>% pull(1),  
                       colour = CellType), pointsize = ptsize, alpha = 0.05) + 
  guides(colour = guide_legend(override.aes = list(size=10, alpha = 1))) + 
  theme_cowplot() + 
  type_col + 
  scale_size(guide = 'none') +
  scale_alpha(guide = 'none') +
  #geom_label_repel(data = cluster_labels, aes(x=x, y=y, label = seurat_cluster_CellType_num )) +
  theme(axis.text.x=element_text(angle = 90, vjust = 0.5)) +
  facet_wrap(~cluster) +
  xlab(paste(red, '1')) + ylab(paste(red, '2'))

# facet by celltype, color by study
plot6 <- umap %>% 
  ggplot() + 
  geom_scattermore(aes(x = umap[,paste0(red,'_1')] %>% pull(1), 
                       y = umap[,paste0(red,'_2')] %>% pull(1), 
                       colour = study_accession), 
                   pointsize = ptsize, alpha = 0.1) + 
  guides(colour = guide_legend(override.aes = list(size=10, alpha = 1))) + 
  theme_cowplot() + 
  scale_size(guide = 'none') +
  scale_alpha(guide = 'none') +
  #geom_label_repel(data = cluster_labels, aes(x=x, y=y, label = seurat_cluster_CellType_num )) +
  theme(axis.text.x=element_text(angle = 90, vjust = 0.5)) +
  scale_color_manual(values = pals::alphabet() %>% unname()) +
  facet_wrap(~CellType + organism) +
  xlab(paste(red, '1')) + ylab(paste(red, '2'))

png(args[3], width = 1800, height = 7500, res = 150)
plot_grid(plot1, plot4, plot5, plot6, ncol = 1, rel_heights = c(0.5,0.5,1, 1))
dev.off()
