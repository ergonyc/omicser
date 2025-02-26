#pbmc3k_curate_configure.R
# Overview --------------
#### Create an app to browse PBMC3k data from 10X Genomics
require("reticulate")

DB_NAME <- list("10x PBMC3k" = "pbmc3k") # name our database


#-#_#_#_#_#_#_#_#_#_#_#_#_#_#_#__#_#_#_#_#_#_
#  Step 1: Set paths--------------
OMICSER_RUN_DIR <- getwd() # /path/to/cloned/omicser/examples or just where you run from

RAW_DATA_DIR <- file.path(OMICSER_RUN_DIR,"raw_data") # set the path for where the raw_data lives...
                                                      # here its going to be in our OMCISER_RUN_DIR


if (!dir.exists(RAW_DATA_DIR)) {
  dir.create(RAW_DATA_DIR) #fails if the path has multiple levels to generate
}

# set the path for where the databases live... here its going to be in our OMCISER_RUN_DIR
DB_ROOT_PATH <- file.path(OMICSER_RUN_DIR,"databases")

if (!dir.exists(DB_ROOT_PATH)) {
  dir.create(DB_ROOT_PATH)
}

OMICSER_PYTHON <-  "pyenv_omicser"
# installation type (see install_script.R)




# Step 2: Assert python back-end --------------------------------
#  for the curation we need to have scanpy
CONDA_INSTALLED <- reticulate:::miniconda_exists()
OMICSER_PYTHON_EXISTS <- any(reticulate::conda_list()["name"]==OMICSER_PYTHON)

if (!CONDA_INSTALLED){  #you should already have installed miniconda and created the env
  reticulate::install_miniconda() #in case it is not already installed
  }


if (!OMICSER_PYTHON_EXISTS){  #you should already have installed miniconda and created the env
  # simpler pip pypi install
  packages <- c("scanpy", "leidenalg")
  reticulate::conda_create(OMICSER_PYTHON, python_version = 3.8)
  reticulate::conda_install(envname=OMICSER_PYTHON,
                            # channel = "conda-forge",
                            pip = TRUE,
                            packages =  packages )

}

if ( Sys.getenv("RETICULATE_PYTHON") != "OMICSER_PYTHON" ) {
  Sys.setenv("RETICULATE_PYTHON"=reticulate::conda_python(envname = OMICSER_PYTHON))
}


# check that we have our python on deck
reticulate::py_discover_config()


# step2b:  troublshoot conda install--------
# full conda install
# packages1 <- c("seaborn", "scikit-learn", "statsmodels", "numba", "pytables")
# packages2 <- c("python-igraph", "leidenalg")
#
# reticulate::conda_create(OMICSER_PYTHON, python_version = 3.8,packages = packages1)
# reticulate::conda_install(envname=OMICSER_PYTHON,
#                         channel = "conda-forge",
#                         packages = packages2 )
# reticulate::conda_install(envname=OMICSER_PYTHON,
#                           channel = "conda-forge",
#                           pip = TRUE,
#                           packages = "scanpy" )

# if (!reticulate::py_module_available(module = "scanpy") ) {
#
#   reticulate::conda_install(envname=OMICSER_PYTHON,
#                             packages = "scanpy[leiden]",
#                             pip = TRUE,
#                             conda=reticulate::conda_binary())
#
#
# }

# reticulate::use_condaenv(condaenv = OMICSER_PYTHON,
#                          conda = reticulate::conda_binary(),
#                          required = TRUE)

# reticulate::conda_install(envname=OMICSER_PYTHON,
#                           packages = "leidenalg",
#                           pip = TRUE,
#                           conda=reticulate::conda_binary())



# Step 4:  get the data ---------------
# create directory structure for data and databases
DB_DIR = file.path(DB_ROOT_PATH,DB_NAME)
if (!dir.exists(DB_DIR)) {
  dir.create(DB_DIR)
}

# change paths to make data manipulations easier
setwd(RAW_DATA_DIR)
# download data
data_file <- "http://cf.10xgenomics.com/samples/cell-exp/1.1.0/pbmc3k/pbmc3k_filtered_gene_bc_matrices.tar.gz"
download.file(data_file, "pbmc3k_filtered_gene_bc_matrices.tar.gz")
# extract all downloaded files
untar("pbmc3k_filtered_gene_bc_matrices.tar.gz")
# compress individual files (required for scanpy)
tar("filtered_gene_bc_matrices/hg19/matrix.mtx.gz", files = "filtered_gene_bc_matrices/hg19/matrix.mtx", compression = "gzip")
tar("filtered_gene_bc_matrices/hg19/barcodes.tsv.gz", files = "filtered_gene_bc_matrices/hg19/barcodes.tsv", compression = "gzip")
tar("filtered_gene_bc_matrices/hg19/genes.tsv.gz", files = "filtered_gene_bc_matrices/hg19/genes.tsv", compression = "gzip")

# Step 6: Format and ingest raw data
# make scanpy functions available
sc <- reticulate::import("scanpy")

# load the PBMC dataset
adata <- sc$read_10x_mtx(
  # locate directory containing mtx file
  "filtered_gene_bc_matrices/hg19/",
  # use gene symbols for the variable names (variables-axis index)
  var_names='gene_symbols',
  # write a cache file for faster subsequent reading
  cache=TRUE)
# save as h5ad anndata file
adata$write_h5ad(file.path(DB_ROOT_PATH, DB_NAME,"core_data.h5ad"))

# reset working directory
setwd(OMICSER_RUN_DIR)


# Step 5:  define for source helper functions -------------------------
# N/A

# Step 6: load helper tools via the "omicser" browser package ---------
CLONED_OMICSER <- 
if ( CLONED_OMICSER ) {
  require("golem")
  REPO_DIR -> getwd()
  golem::document_and_reload(pkg = REPO_DIR)
} else {
  require("omicser")
  #see install_script.R if not installed
}



# Steps 7-9: CURATION
SAVE_INTERMEDIATE_FILES <- FALSE
# Step 7:  pack data into AnnData format --------------
# identify location of raw data
data_list <- list(object=file.path(DB_ROOT_PATH,DB_NAME,"core_data.h5ad"))

# create database formatted as AnnData
adata <- omicser::setup_database(database_name = DB_NAME,
                                 db_path = DB_ROOT_PATH,
                                 data_in = data_list,
                                 re_pack = TRUE)



# Step 8: additional data processing ----
adata$var_names_make_unique()
# unnecessary if using `var_names='gene_ids'` in `sc.read_10x_mtx`

# filter data
sc$pp$filter_cells(adata, min_genes=200)
sc$pp$filter_genes(adata, min_cells=10)

# annotate the group of mitochondrial genes as 'mt'
adata$var['mt'] <- startsWith(adata$var_names,'MT-')
sc$pp$calculate_qc_metrics(adata, qc_vars=list('mt'), percent_top=NULL, log1p=FALSE, inplace=TRUE)

# filter data
adata <- adata[adata$obs$n_genes_by_counts < 2500, ]
adata <- adata[adata$obs$pct_counts_mt < 5, ]
sc$pp$normalize_total(adata, target_sum=1e4)
sc$pp$log1p(adata)
sc$pp$highly_variable_genes(adata, min_mean=0.0125, max_mean=3, min_disp=0.5)

# transform data
#adata = adata[, adata$var$highly_variable]
sc$pp$regress_out(adata, list('total_counts', 'pct_counts_mt'))
sc$pp$scale(adata, max_value=10)

# choose top 40 genes by variance across dataset as "targets"
adata$var$var_rank <- order(adata$var$dispersions_norm)

# calculate deciles
adata$var$decile <- dplyr::ntile(adata$var$dispersions_norm, 10)
#raw <- ad$raw$to_adata()

# save intermediate database file
if (SAVE_INTERMEDIATE_FILES){
  adata$write_h5ad(filename=file.path(DB_ROOT_PATH,DB_NAME,"normalized_data.h5ad"))
}

#7-b. dimension reduction - PCA / umap
#pca
sc$pp$pca(adata)
# compute neighbor graph
sc$pp$neighbors(adata)
## infer clusters
sc$tl$leiden(adata)
# compute umap
sc$tl$umap(adata)

# save intermediate database file
if (SAVE_INTERMEDIATE_FILES){
  adata$write_h5ad(filename=file.path(DB_ROOT_PATH,DB_NAME,"norm_data_plus_dr.h5ad"))
}

# Step 8: pre-compute differential expression
# identify stats
# see scanpy documentation for possible stat test choices
test_types <- c('wilcoxon')
comp_types <- c("grpVrest")
obs_names <- c('leiden')
# calculate DE
diff_exp <- omicser::compute_de_table(adata,comp_types, test_types, obs_names,sc)

### WARNING:  there's an overflow bug in the logfoldchange values for this dataset
### Might need to rescale?

# save intermediate database file
if (SAVE_INTERMEDIATE_FILES){
  adata$write_h5ad(filename=file.path(DB_ROOT_PATH,DB_NAME,"norm_data_with_de.h5ad"))
}

# save DE tables
saveRDS(diff_exp, file = file.path(DB_ROOT_PATH, DB_NAME, "db_de_table.rds"))


# Step 9: Write data files to database directory -----------
# write final database
adata$write_h5ad(filename = file.path(DB_ROOT_PATH, DB_NAME, "db_data.h5ad"))

# set to TRUE and restart from here for re-configuring
if (FALSE) {
  adata <- anndata::read_h5ad(filename=file.path(DB_ROOT_PATH,DB_NAME,"db_data.h5ad"))
  diff_exp <- readRDS( file = file.path(DB_ROOT_PATH,DB_NAME, "db_de_table.rds"))
}
if (FALSE) adata <- anndata::read_h5ad(filename=file.path(DB_ROOT_PATH,DB_NAME,"db_data.h5ad"))



# Step 10:  configure browser ----
omic_type <- "transcript" #c("transcript","prote","metabol","lipid","other")
aggregate_by_default <- (if (omic_type=="transcript") TRUE else FALSE ) #e.g.  single cell
# choose top 40 genes by variance across dataset as our "targets"
target_features <- adata$var_names[which(adata$var$var_rank <= 40)]
#if we care we need to explicitly state. defaults will be the order...
config_list <- list(
  # meta-tablel grouping "factors"
  group_obs = c("leiden"),
  group_var = c("decile","highly_variable"),

  # LAYERS
  # each layer needs a label/explanation
  layer_values = c("X","raw"),
  layer_names = c("norm-count","counts" ),

  # ANNOTATIONS / TARGETS
  # what adata$obs do we want to make default values for...
  # # should just pack according to UI?
  default_obs =  c("Condition","leiden"), #subset & ordering

  obs_annots = c( "leiden", "n_genes","n_genes_by_counts","total_counts","total_counts_mt","pct_counts_mt"),

  default_var = c("decile"),#just use them in order as defined
  var_annots = c(
    "n_cells",
    "mt",
    "n_cells_by_counts",
    "mean_counts",
    "pct_dropout_by_counts",
    "total_counts",
    "highly_variable",
    "dispersions_norm",
    "decile"),


  target_features = target_features,
  feature_details = c( "feature_name",
                     "gene_ids",
                     "n_cells",
                     "mt",
                     "n_cells_by_counts",
                     "mean_counts",
                     "pct_dropout_by_counts",
                     "total_counts",
                     "highly_variable",
                     "means",
                     "dispersions",
                     "dispersions_norm",
                     "mean",
                     "std",
                     "var_rank",
                     "decile" ),

  filter_feature = c("dispersions_norm"), #if null defaults to "fano_factor"
  # differential expression
  diffs = list( diff_exp_comps = levels(factor(diff_exp$versus)),
                diff_exp_obs_name =  levels(factor(diff_exp$obs_name)),
                diff_exp_tests =  levels(factor(diff_exp$test_type))
  ),

  # Dimension reduction (depricated)
  dimreds = list(obsm = adata$obsm_keys(),
                 varm = adata$varm_keys()),

  omic_type = omic_type, #c("transcript","prote","metabol","lipid","other")
  aggregate_by_default = aggregate_by_default, #e.g.  single cell

  #meta info
  meta_info = list(
    annotation_database =  NA,
    publication = "TBD",
    method = "single-cell", # c("single-cell","bulk","other")
    organism = "human",
    lab = "?",
    source = "peripheral blood mononuclear cells (PBMCs)",
    title = "pbmc3k",
    measurment = "normalized counts- via regression",
    pub = "10X Genomics",
    url = "https://support.10xgenomics.com/single-cell-gene-expression/datasets/1.1.0/pbmc3k",
    date = format(Sys.time(), "%a %b %d %X %Y")
  )
)

omicser::write_db_conf(config_list,DB_NAME, db_root = DB_ROOT_PATH)


# BOOTSTRAP the options we have already set up...
# NOTE: we are looking in the "quickstart" folder.  the default is to look for the config in with default getwd()
omicser_options <- omicser::get_config(in_path = OMICSER_RUN_DIR)
omicser_options <- omicser::get_config()
DB_ROOT_PATH_ <- omicser_options$db_root_path
if (DB_ROOT_PATH_==DB_ROOT_PATH){
  # add the database if we need it...
  if (! (DB_NAME %in% omicser_options$database_names)){
    omicser_options$database_names <- c(omicser_options$database_names,DB_NAME)
  }

} else {
  omicser_options$db_root_path <- DB_ROOT_PATH
  if (any(omicser_options$database_names == "UNDEFINED")) {
    omicser_options$database_names <- DB_NAME
  } else {
    omicser_options$database_names <- c(omicser_options$database_names,DB_NAME)
  }
}


# write the configuration file
omicser::write_config(omicser_options,in_path = OMICSER_RUN_DIR )


# Step 11: Run the browser -------------
