print('UI Start')
print(Sys.time())

library(shiny)
library(Cairo)
library(ggplot2)
library(scattermore)
library(pals)
library(shinythemes)
library(cowplot)
library(formattable)
shinyUI(
  navbarPage('Ocular scAnthology',
             theme = shinytheme('flatly'),
             selected = 'Overview',
             navbarMenu('Viz', # UMAP ----------
                        tabPanel('UMAP - Tables', 
                                 fluidPage(
                                   fluidRow(
                                     # Gene Scatter  ---------------
                                     column(6,
                                            plotOutput('gene_scatter_plot', 
                                                       dblclick = "gene_scatter_plot_dblclick",
                                                       brush = brushOpts(
                                                         id = "gene_scatter_plot_brush",
                                                         resetOnNew = TRUE)),
                                            fluidRow(column(5,
                                                            selectizeInput('Gene', strong('Gene: '),
                                                                           choices=NULL, multiple=FALSE)),
                                                     column(5,
                                                            selectizeInput('pt_size_gene', strong('Point Size: '),
                                                                           choices=c(1,3,5,10), 
                                                                           selected = 1, multiple=FALSE))),
                                            fluidRow(column(5,
                                                            sliderInput("gene_scatter_slider", label = strong("Expression Range: "), min = 1, 
                                                                        max = 15, value = c(1, 15))
                                            )),
                                            fluidRow(column(5,
                                                            selectizeInput('gene_filter_cat', strong('Filter Category: '),
                                                                           choices = NULL, selected = NULL)),
                                                     column(5,
                                                            selectizeInput('gene_filter_on', strong('Filter on: '),
                                                                           choices = NULL, selected = NULL, multiple = TRUE)))),
                                     # Meta Plot ------
                                     column(6,
                                            plotOutput('meta_plot',
                                                       dblclick = "meta_plot_dblclick",
                                                       brush = brushOpts(
                                                         id = "meta_plot_brush",
                                                         resetOnNew = TRUE)),
                                            fluidRow(column(5, 
                                                            selectizeInput('meta_column', strong('Color: '),
                                                                           choices= NULL, selected = 'CellType_predict')),
                                                     column(5, 
                                                            selectizeInput('pt_size_meta', strong('Point Size: '),
                                                                           choices=c(1,3,5), 
                                                                           selected = 1, multiple=FALSE))),
                                            fluidRow(column(5, 
                                                            selectInput("label_toggle", label = strong("Label: "), 
                                                                        choices = list("None" = 0,
                                                                                       "CellType (published)" = 1,
                                                                                       "CellType (predict)" = 2,
                                                                                       "Cluster" = 3), multiple = FALSE,
                                                                        selected = 2)),
                                                     column(2, 
                                                            radioButtons('meta_column_transform', 
                                                                         label = 'Numeric Transform', inline = FALSE,
                                                                         choices = list("None" = "None", "log2" = "log2")))
                                            ),
                                            fluidRow(column(5,
                                                            selectizeInput('meta_filter_cat', strong('Filter Category: '),
                                                                           choices = NULL, selected = NULL)),
                                                     column(5,
                                                            selectizeInput('meta_filter_on', strong('Filter on: '),
                                                                           choices = NULL, selected = NULL, multiple = TRUE)))
                                     )
                                   ),
                                   fluidRow(
                                     column(6, 
                                            fluidRow( 
                                              column(12, actionButton('BUTTON_draw_scatter',' Draw Scatter Plot', icon = icon("arrow-up"),
                                                                      style='background-color: #3399ff; color: #ffffff'),
                                                     actionButton('BUTTON_make_gene_table',' Make Gene Table', icon = icon("arrow-down"),
                                                                  style='background-color: #3399ff; color: #ffffff'))),
                                            br(),
                                            selectizeInput('grouping_features', strong('Gene Table Grouping(s)'),
                                                           choices = NULL, 
                                                           multiple = TRUE),
                                            div(DT::dataTableOutput('gene_cluster_stats'), style='font-size:75%')),
                                     column(6,
                                            fluidRow( 
                                              column(12,
                                                     actionButton('BUTTON_draw_meta',' Draw Meta Plot', icon = icon("arrow-up"),
                                                                  style='background-color: #3399ff; color: #ffffff'),
                                                     actionButton('BUTTON_make_meta_table',' Make Meta Table', icon = icon("arrow-down"),
                                                                  style='background-color: #3399ff; color: #ffffff'))),
                                            br(),
                                            selectizeInput('meta_groupings', strong('Metadata Table Groupings '),
                                                           choices = NULL, 
                                                           multiple = TRUE),
                                            div(DT::dataTableOutput('metadata_stats'), style='font-size:75%'))
                                   )
                                 )
                        ),
                        # exp_plots ------
                        tabPanel('Expression Plot by Groupings', 
                                 column(12,
                                        fluidRow(
                                          column(3, 
                                                 fluidRow(selectizeInput('exp_plot_genes', strong('Gene(s): '),
                                                                         choices = NULL, multiple = TRUE))),
                                          column(3,
                                                 fluidRow(selectizeInput('exp_plot_groups', strong('Grouping feature(s): '),
                                                                         choices = NULL, multiple = TRUE))),
                                          
                                          column(2,
                                                 selectizeInput('exp_plot_height', strong('Plot Height: '),
                                                                choices = seq(200, 2000, by = 100),
                                                                selected = 400, multiple = FALSE)),
                                          column(2,
                                                 selectInput('exp_plot_ylab', strong('Value: '),
                                                             choices = c('Mean CPM', '% of Cells Detected')))),
                                        fluidRow(
                                          column(3,
                                                 fluidRow(checkboxInput('exp_plot_facet', 'Facet on 1st Group', TRUE)))
                                          
                                        ),
                                        fluidRow(column(10, actionButton('BUTTON_draw_exp_plot','Draw Plot', icon = icon("arrow-down"),
                                                                         style='background-color: #3399ff; color: #ffffff'))),
                                        br(),
                                        fluidRow(column(10, plotOutput('exp_plot'))))),
                        tabPanel('Facet UMAP', # Facet UMAP ---------
                                 column(10, 
                                        fluidRow(
                                          column(10,
                                                 fluidRow(column(5,
                                                                 selectizeInput('facet', strong('Facet On: '),
                                                                                choices=NULL, multiple=FALSE)),
                                                          column(5,
                                                                 selectizeInput('facet_color', strong('Color On: '),
                                                                                choices=NULL, multiple=FALSE)),
                                                          column(5,
                                                                 selectizeInput('pt_size_facet', strong('Point Size: '),
                                                                                choices=c(1,3,5,10), 
                                                                                selected = 1, multiple=FALSE)),
                                                          column(5,
                                                                 selectizeInput('facet_height', strong('Plot Height: '),
                                                                                choices = c(100,200,300,400,600, 800),
                                                                                selected = 400, multiple = FALSE))),
                                                 fluidRow(column(10, actionButton('BUTTON_draw_filter','Draw Plot', icon = icon("arrow-down"),
                                                                                  style='background-color: #3399ff; color: #ffffff'))),
                                                 br(),
                                                 plotOutput('facet_plot'))
                                        )
                                        
                                 )),
                        # temporal plot -----
                        tabPanel('Temporal Gene x Cell Type',
                                 column(10,
                                        fluidRow(
                                          column(10,
                                                 fluidRow(column(3, selectizeInput('temporal_gene', strong('Gene(s): '),
                                                                                   choices = NULL, multiple = TRUE)),
                                                          column(3, selectInput('temporal_group', strong('Split on: '),
                                                                                choices = c('CellType', 'CellType (predict)'))),
                                                          column(3, selectInput('temporal_y_val', strong('Value: '),
                                                                                choices = c('Mean CPM', 'Ratio Detected')))))),
                                        fluidRow(column(5, 
                                                        actionButton('BUTTON_draw_temporal','Draw Plot', icon = icon("arrow-down"),
                                                                     style='background-color: #3399ff; color: #ffffff'))),
                                        br(), br(), 
                                        fluidRow(column(10, plotOutput('temporal_plot')))
                                 )),
                        tabPanel('Dotplot', # Dotplot ---------
                                 column(8,
                                        fluidRow(
                                          column(5, selectizeInput('dotplot_Gene', strong('Genes: '),
                                                                   choices=NULL, multiple=TRUE)),
                                          column(4, selectizeInput('dotplot_groups', strong('Group by (two max): '),
                                                                   choices=NULL, multiple=TRUE)),
                                          column(3, selectizeInput('dotplot_height', strong('Plot Height: '),
                                                                   choices = seq(400, 2000, by = 100), selected = 800))),
                                        actionButton('BUTTON_draw_dotplot','Draw Dotplot!', icon = icon("arrow-down"),
                                                     style='background-color: #3399ff; color: #ffffff'),
                                        br(), br(),
                                        plotOutput('dotplot')))
             ),
             # diff testing  tables ------------
             tabPanel('Diff Testing',
                      fluidPage(column(8,
                                       fluidRow(
                                         selectInput('diff_table_select', strong('Differential testing by: '),
                                                     choices = c('Cluster', 'SubCluster', 'CellType', 'CellType (predict)')),
                                         selectInput('search_by', strong('Search by: '), 
                                                     choices = c('Gene','Term'), 
                                                     selected = 'Gene')
                                       )),
                                column(8,
                                       fluidRow(
                                         conditionalPanel("input.search_by == 'Gene'",
                                                          selectizeInput('diff_gene', strong('Genes: '), 
                                                                         choices =  NULL,
                                                                         multiple = TRUE)),
                                         conditionalPanel("input.search_by == 'Term'",
                                                          selectizeInput('diff_term', strong('Term: '), 
                                                                         choices =  NULL,
                                                                         multiple = TRUE))
                                       )),
                                column(8,
                                       div(DT::dataTableOutput('make_diff_table'), style='font-size:75%')))),
             tabPanel('Overview', # Overview ------
                      fluidPage(
                        fluidRow(column(width = 8, offset = 1, h2('scAnthology v0.23'))),
                        br(),
                        fluidRow(column(width = 8, offset = 1, h2('Overview'))),
                        fluidRow(column(width = 8, offset = 1, 'The light-sensitive portion of the mammalian eye is the retina. The retina itself is not a monolithic tissue - there are, depending on how you count, over 10 major cell types. The cones and rods which convert light into signal are supported by a wide variety of neural cell types with distinct roles in interpretting and transmitting the signals to the brain. scAnthology is a meta-analysis project over 900,000 single-cell transcriptomes across 15 studies and 3 species across the retina cell types. Deep metadata minining, rigorous quality control analysis, differential gene expression testing, and deep learning based batch effect correction in a unified bioinformatic framework allow the universe of retina single cell expression information to be analyzed in one location.')),
                        fluidRow(column(width = 8, offset = 1, h2('Data Sources'))),
                        fluidRow(column(width = 8, offset = 1, formattableOutput("formattable01"))),
                        fluidRow(column(width = 8, offset = 1, h2('Cell Types'))),
                        fluidRow(column(width = 6, offset = 1, formattableOutput("formattable02"))),
                        br(),
                        fluidRow(column(width = 8, offset = 1, h2('Change log'))),
                        fluidRow(column(width = 8, offset = 1, '0.23 (2020-06-16): Remove low N cell type from diff expression tables, tweak Overview with br() and updated text.')),
                        fluidRow(column(width = 8, offset = 1, '0.22 (2020-06-15): Added expression plot by user selected groups plot view. Fixed bug in mean cpm expression calculation for Viz -> UMAP - Table gene tables')),
                        fluidRow(column(width = 8, offset = 1, '0.21 (2020-06-15): Added subcluster diff testing tables, temporal gene expression by celltype plot section.')),
                        fluidRow(column(width = 8, offset = 1, '0.20 (2020-06-06): New 2D UMAP projection that includes the full Yu - Clark Human scRNA dataset. Added tables to "Overview" section showing data stats. Added "filtering" functionality to UMAP plot section.')),
                        br(), br(), br()
                      ))
  )
)
