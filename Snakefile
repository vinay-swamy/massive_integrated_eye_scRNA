import pprint
pp = pprint.PrettyPrinter(width=41, compact=True) 
import subprocess as sp

srr_sample_file = config['srr_sample_file']
#srr_sample_discrepancy_file = config['srr_discrepancy_file']

# builds dictionary of dictionaries where first dict key is SRS 
# and second dict key are SRS properties
def metadata_builder(file, SRS_dict = {}, discrepancy = False):
	with open(file) as file:
		for line in file:
			if line[0] == '#':
				continue
			info = line.strip('\n').split('\t')
			if info[0] == 'sample_accession':
				continue
			SRS = info[0]
			if SRS not in SRS_dict:
				SRS_dict[SRS]={'SRR': [info[1]],
					    	  'paired':True if info[2]=='PAIRED' else False, 
					          'organism':info[3].replace(' ', '_'),
		            	      'tech':info[4],
						      'UMI':True if info[5]=='YES' else False,
							  'Study': info[6]}
			else:
				# this is mostly for SRA having the 'paired' status wrong
				# don't want to hand-edit the main metadata file
				# so I think better to create a new file with
				# hand edited values for just the ones i want to change
				if discrepancy:
					runs = SRS_dict[SRS]['SRR']
					SRS_dict[SRS] = {'SRR':runs,
									 'paired':True if info[2]=='PAIRED' else False,
									 'organism':info[3],
									 'tech':info[4],
									 'UMI':True if info[5]=='YES' else False,
									 'Study': info[6]}
				else:
					runs = SRS_dict[SRS]['SRR']
					runs.append(info[1])
					SRS_dict[SRS]['SRR'] = runs
	return(SRS_dict)

SRS_dict = metadata_builder(srr_sample_file)
# pp.pprint(SRS_dict)
# hand edited file which corrects mistakes that in the 
# various databases
# SRS_dict = metadata_builder(srr_sample_discrepancy_file, SRS_dict, discrepancy = True)

# build organism <-> SRS dict for nonUMI data
organism_well_dict = {}
for x in SRS_dict:
	if not SRS_dict[x]['UMI'] or not SRS_dict[x]['paired']:
		organism = SRS_dict[x]['organism']
		if organism not in organism_well_dict:
			organism_well_dict[organism] = [x]
		else:
			srs = organism_well_dict[organism]
			srs.append(x)
			organism_well_dict[organism] = srs
# build organsim <-> SRS dict for UMI/droplet data
organism_droplet_dict = {}
for x in SRS_dict:
	if SRS_dict[x]['UMI'] and SRS_dict[x]['paired']:
		organism = SRS_dict[x]['organism']
		if organism not in organism_droplet_dict:
			organism_droplet_dict[organism] = [x]
		else:
			srs = organism_droplet_dict[organism]
			srs.append(x)
			organism_droplet_dict[organism] = srs

def lookup_run_from_SRS(SRS):
	SRR_files=SRS_dict[SRS]['SRR']
	out = []
	for SRR in SRR_files:
		if SRS_dict[SRS]['paired']:
			#PE
			out.append('fastq/{}_1.fastq.gz'.format(SRR))
			out.append('fastq/{}_2.fastq.gz'.format(SRR))
		else:
			#SE
			out.append('fastq/{}.fastq.gz'.format(SRR))
	return(out)

# return dummy well file for macaca ,as there is no well data at this time
def well_and_droplet_input(organism, reference):
	if organism == 'Macaca_fascicularis':
		out = ['quant/' + x + '/' + reference + '/genecount/matrix.Rdata' for x in organism_droplet_dict[organism]]
	else:
		out = ['quant/' + organism + '/' + reference + '__counts.Rdata']	+ \
				['quant/' + x + '/' + reference + '/genecount/matrix.Rdata' for x in organism_droplet_dict[organism]]
	return(out)

def REF_idx(ref, data_to_return):
	organism = SRS_dict[SRS]['organism']
	if ref == 'mm':
		idx = 'references/kallisto_idx/gencode.vM22.pc_transcripts.fa.gz.idx'
		txnames = 'references/gencode.vM22.metadata.MGI_tx_mapping.tsv'
	elif ref == 'hs':
		idx = 'references/kallisto_idx/gencode.v31.pc_transcripts.fa.gz.idx'
		txnames = 'references/gencode.v31.metadata.HGNC_tx_mapping.tsv'
	elif ref == 'mf':
		idx = 'references/kallisto_idx/Macaca_mulatta.Mmul_10.cdna.all.fa.gz.idx'
		txnames = 'references/Macaca_mulatta.Mmul_10.cdna.all_tx_mapping.tsv'
	else:
		print(ref + " NO REF MATCH!")
	if data_to_return == 'idx':
		out = idx
	else:
		out = txnames
	return(out)

def ORG_ref(organism):
	if organism.lower() == 'mus_musculus':
		out = ['mm']
	elif organism.lower() == 'homo_sapiens':
		out = ['hs']
	elif organism.lower() == 'macaca_fascicularis':
		out = ['hs','mf']
	else:
		print(organism + ' NO MATCH')
	return(out)

SRS_UMI_samples = []
SRS_nonUMI_samples = []
for SRS in SRS_dict.keys():
	if SRS_dict[SRS]['UMI'] and SRS_dict[SRS]['paired']:
		SRS_UMI_samples.append(SRS)
	elif SRS_dict[SRS]['tech'] != 'BULK':
		SRS_nonUMI_samples.append(SRS)

method = ['insct','desc', 'magic', 'scVI','CCA', 'scanorama', 'harmony', 'liger', 'fastMNN', 'combat', 'none']
transform = ['libSize', 'sqrt', 'counts','standard', 'SCT','scran']
covariate = ['study_accession', 'batch']
organism = ['Mus_musculus', 'Macaca_fascicularis', 'Homo_sapiens']
combination = ['Mus_musculus', 'Mus_musculus_Macaca_fascicularis', 'Mus_musculus_Macaca_fascicularis_Homo_sapiens']
dims = [4,6,8,10,20,25,30,50,75,100,200]
model = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] # A is ~seuratCluster+batch+percent.mt and B is ~seuratCluster+batch+percent.mt+organism
wildcard_constraints:
	SRS = '|'.join(SRS_UMI_samples + SRS_nonUMI_samples),
	method = '|'.join(method),
	transform = '|'.join(transform),
	covariate = '|'.join(covariate),
	organism = '|'.join(organism),
	nfeatures = '|'.join([str(x) for x in [2000,5000]]),
	dims = '|'.join([str(x) for x in dims]),
	model = '|'.join(model)	

rule all:
	input:
		expand('quant/{sample}/hs/output.bus', sample = SRS_UMI_samples),	
		expand('plots/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.big_plot.png', \
				transform = ['counts'], \
				method = ['scVI'], \
				combination = ['Mus_musculus_Macaca_fascicularis_Homo_sapiens'], \
				partition = ['onlyDROPLET'], \
				n_features = [1000, 2000, 5000, 10000], \
				covariate = ['batch'], \
				dims = [4,6,8,10,20,30,50,100],
				dist = [0.001,0.1, 0.3],
				neighbors = [15, 30, 50, 100, 500]),
		expand('plots/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.big_plot.png', \
				transform = ['sqrt','libSize','scran', 'standard'], \
				method = ['insct',  'magic', 'scanorama', 'harmony', 'fastMNN', 'combat',  'none'], \
				combination = ['Mus_musculus_Macaca_fascicularis_Homo_sapiens'], \
				partition = ['onlyDROPLET'], \
				n_features = [2000], \
				covariate = ['batch'], \
				dims = [8, 30],
				dist = [0.3],
				neighbors = [30]),
		expand('perf_metrics/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.Rdata', \
				transform = ['counts'], \
				method = ['scVI'], \
				combination = ['Mus_musculus_Macaca_fascicularis_Homo_sapiens'], \
				partition = ['onlyDROPLET'], \
				n_features = [1000, 2000, 5000, 10000], \
				covariate = ['batch'], \
				dims = [4,6,8,10,20,30,50,100],
				knn = [4, 5, 7, 10]),
		expand('perf_metrics/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.Rdata', \
				transform = ['libSize','sqrt','scran', 'standard'], \
				method = ['insct', 'magic', 'scanorama', 'harmony', 'fastMNN', 'combat',  'none'], \
				combination = ['Mus_musculus_Macaca_fascicularis_Homo_sapiens'], \
				partition = ['onlyDROPLET','onlyWELL'], \
				n_features = [2000], \
				covariate = ['batch'], \
				dims = [8, 30],
				knn = [7]),
		expand('scIB_stats/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__knn{knn}___stats.csv', \	
				combination = ['Mus_musculus_Macaca_fascicularis_Homo_sapiens'], \
				n_features = [1000, 2000, 5000, 10000], \
				transform = ['counts'], \
				partition = ['onlyDROPLET'], \
				covariate = ['batch'], \
				method = ['scVI'], \
				dims = [4,6,8,10,20,30,50,100], \
				dist = [0.1], \
				neighbors = [500], \
				knn = [4,5,7,10]),
		expand('scIB_stats/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__knn{knn}___stats.csv', \
				transform = ['libSize','sqrt','scran', 'standard'], \
				method = ['insct', 'magic', 'scanorama', 'harmony', 'fastMNN', 'combat', 'none'], \
				combination = ['Mus_musculus_Macaca_fascicularis_Homo_sapiens'], \
				partition = ['onlyDROPLET'], \
				n_features = [2000], \
				covariate = ['batch'], \
				dims = [8, 30], \
				knn = [7], \
				dist = [0.3], \
				neighbors = [30]),
		#'site/MOARTABLES__anthology_limmaFALSE___Mus_musculus_Macaca_fascicularis_Homo_sapiens-2000-counts-onlyDROPLET-batch-scVI-6-0.1-500-10.sqlite.gz',

## mouse, human, macaque fasta and gtf
rule download_references:
	output:
		mouse_fasta = 'references/gencode.vM22.pc_transcripts.fa.gz',
		macaque_fasta = 'references/Macaca_mulatta.Mmul_10.cdna.all.fa.gz',
		human_fasta = 'references/gencode.v31.pc_transcripts.fa.gz'
	shell:
		"""
		mkdir -p references
		wget ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M22/gencode.vM22.pc_transcripts.fa.gz  
		#wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/364/345/GCF_000364345.1_Macaca_fascicularis_5.0/GCF_000364345.1_Macaca_fascicularis_5.0_rna.fna.gz
		wget ftp://ftp.ensembl.org/pub/release-98/fasta/macaca_fascicularis/cdna/Macaca_fascicularis.Macaca_fascicularis_5.0.cdna.all.fa.gz
		wget ftp://ftp.ensembl.org/pub/release-99/fasta/macaca_mulatta/cdna/Macaca_mulatta.Mmul_10.cdna.all.fa.gz
		wget ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_31/gencode.v31.pc_transcripts.fa.gz
		mv *fa*gz references/
		"""

# need to make mouse, human, macaque
rule kallisto_index:
	input:
		'references/{fasta}'
	output:
		'references/kallisto_idx/{fasta}.idx'
	shell:
		"""
		kallisto index {input} -i {output}
		"""

# get / make the bustool count tx file
# tsv three column
# transcript_ID gene_ID gene_name
# ENST ENSG gene_name
rule tx_gene_mapping:
	input:
		'references/gencode.vM22.pc_transcripts.fa.gz'
	output:
		mf = 'references/Macaca_mulatta.Mmul_10.cdna.all_tx_mapping.tsv',
		hs = 'references/gencode.v31.metadata.HGNC_tx_mapping.tsv',
		mm = 'references/gencode.vM22.metadata.MGI_tx_mapping.tsv'
	shell:
		"""
		zgrep "^>" references/gencode.vM22.pc_transcripts.fa.gz | \
			sed 's/>//g' | \
			awk 'BEGIN {{OFS = "\t"; FS = "|"}}; {{print $0, $2, $6}}' > {output.mm}

		zgrep "^>" references/Macaca_mulatta.Mmul_10.cdna.all.fa.gz | \
			sed 's/>//g' > mf.header
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/macaque_ensembl_fasta_header.R mf.header {output.mf}
		rm mf.header
		#wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/364/345/GCF_000364345.1_Macaca_fascicularis_5.0/GCF_000364345.1_Macaca_fascicularis_5.0_feature_table.txt.gz
		#zcat GCF_000364345.1_Macaca_fascicularis_5.0_feature_table.txt.gz | \
		#	grep "^mRNA" | \
		#	awk -v OFS="\t" 'BEGIN {{FS="\t"}}; {{print $11,$15,$14}}' > {output.mf}
		#rm GCF_000364345.1_Macaca_fascicularis_5.0_feature_table.txt.gz

		zgrep "^>" references/gencode.v31.pc_transcripts.fa.gz | \
			sed 's/>//g' | \
			awk 'BEGIN {{OFS = "\t"; FS = "|"}}; {{print $0, $2, $6}}' > {output.hs}
		"""

# this does the pseudoalignment for UMI data (e.g. 10x)
rule kallisto_bus:
	input:
		fastq = lambda wildcards: lookup_run_from_SRS(wildcards.SRS),
		idx = lambda wildcards: REF_idx(wildcards.reference, 'idx')
	output:
		bus = 'quant/{SRS}/{reference}/output.bus',
		ec = 'quant/{SRS}/{reference}/matrix.ec',
		tx_name = 'quant/{SRS}/{reference}/transcripts.txt'
	threads: 4
	params:
		tech = lambda wildcards: SRS_dict[wildcards.SRS]['tech'],
		paired = lambda wildcards: SRS_dict[wildcards.SRS]['paired']
	run:
		if params.paired:
			job = "kallisto bus -t 4 -x {tech} \
					-i {idx} -o quant/{SRS}/{reference} {fastq}".format(fastq = input.fastq,
                                                    tech = params.tech,
													idx = input.idx,
													reference = wildcards.reference,
													SRS = wildcards.SRS)
		else:
			job = "kallisto bus --single -x {tech} \
					-i {idx} -o quant/{SRS}/{reference} {fastq}".format(fastq = input.fastq,
                                                    tech = params.tech,
													idx = input.idx,
													reference = wildcards.reference,
													SRS = wildcards.SRS)
		sp.run("echo " + job + '\n', shell = True)
		sp.run(job, shell = True)	

# pseudoaligment for nonUMI data (e.g. smartseq)
rule kallisto_quant:
	input:
		fastq = lambda wildcards: lookup_run_from_SRS(wildcards.SRS),
		idx = lambda wildcards: REF_idx(wildcards.reference, 'idx')
	output:
		quant = 'quant/{SRS}/{reference}/abundance.tsv.gz'
	params:
		paired = lambda wildcards: SRS_dict[wildcards.SRS]['paired']
	threads: 8
	run:
		if params.paired:
			job = "kallisto quant -t {t} -b 100 --plaintext --bias \
					-i {idx} -o quant/{SRS}/{reference} {fastq}".format(fastq = input.fastq,
                                                    t = threads,
													idx = input.idx,
													reference = wildcards.reference,
													SRS = wildcards.SRS)
		else:
			job = "kallisto quant --single -l 200 -s 30  -t {t} -b 100 --plaintext --bias \
					-i {idx} -o quant/{SRS}/{reference} {fastq}".format(fastq = input.fastq,
                                                    t = threads,
													idx = input.idx,
													reference = wildcards.reference,
													SRS = wildcards.SRS)
		sp.run("echo " + job + '\n', shell = True)
		sp.run(job, shell = True)	
		sp.run('gzip quant/' + wildcards.SRS + '/' + wildcards.reference + '/*tsv', shell = True)
			
			
# sorting required for whitelist creation and correction
# make these temp files
rule bustools_sort:
	input:
		'quant/{SRS}/{reference}/output.bus'
	output:
		temp('quant/{SRS}/{reference}/output.sorted.bus')
	threads: 4
	shell:
		"""
		/home/mcgaugheyd/git/bustools/build/src/./bustools sort -t {threads} -m 16G \
			{input} \
			-o {output}
		"""

# find barcodes, correct barcodes
# make these temp files
rule bustools_whitelist_correct_count:
	input:
		bus = 'quant/{SRS}/{reference}/output.sorted.bus',
		ec = 'quant/{SRS}/{reference}/matrix.ec',
		tx_name = 'quant/{SRS}/{reference}/transcripts.txt',
		tx_map = lambda wildcards: REF_idx(wildcards.reference, 'tx')
	output:
		whitelist = 'whitelist/{SRS}/{reference}_whitelist',
		bus_matrix = 'quant/{SRS}/{reference}/genecount/gene.mtx'
	params:
		bus_out = 'quant/{SRS}/{reference}/genecount/gene'
	shell:
		"""
		/home/mcgaugheyd/git/bustools/build/src/./bustools whitelist \
			{input.bus} \
			-o {output.whitelist}

		/home/mcgaugheyd/git/bustools/build/src/./bustools correct \
			{input.bus} \
			-w {output.whitelist} \
			-p | \
		/home/mcgaugheyd/git/bustools/build/src/./bustools count \
			-o {params.bus_out} \
			-g {input.tx_map} \
			-e {input.ec} \
			-t {input.tx_name} \
			--genecounts -
		"""

rule create_sparse_matrix:
	input:
		'quant/{SRS}/{reference}/genecount/gene.mtx'
	output:
		stats = 'quant/{SRS}/{reference}/genecount/stats.tsv',
		matrix = 'quant/{SRS}/{reference}/genecount/matrix.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/remove_empty_UMI_make_sparse_matrix.R {wildcards.SRS} {wildcards.reference} {output.matrix} {output.stats}
		"""		

rule merge_nonUMI_quant_by_organism:
	input:
		quant = lambda wildcards: expand('quant/{SRS}/{{reference}}/abundance.tsv.gz', SRS = organism_well_dict[wildcards.organism]),
		tx_map = lambda wildcards: REF_idx(wildcards.reference, 'tx')
	output:
		'quant/{organism}/{reference}__counts.Rdata',
		'quant/{organism}/{reference}__counts_tx.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/merge_nonUMI_quant_by_organism.R {output} {input.tx_map} {input.quant} 
		"""

rule combine_well_and_umi:
	input:
		srr_metadata = config['srr_sample_file'],
		tx_map = lambda wildcards:  REF_idx(wildcards.reference, 'tx'),  # SRS_info(organism_droplet_dict[wildcards.organism][0], 'tx'),
		counts = lambda wildcards: well_and_droplet_input(wildcards.organism, wildcards.reference)
	output:
		cell_info = '{organism}_{reference}_cell_info.tsv',
		matrix = 'quant/{organism}/{reference}_full_sparse_matrix.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/build_sparse_matrix.R {wildcards.organism} {output} {input}
		"""

rule merge_across_references:
	input:
		cell_info = lambda wildcards: expand('{{organism}}_{reference}_cell_info.tsv', reference = ORG_ref(wildcards.organism)),
		matrix = lambda wildcards: expand('quant/{{organism}}/{reference}_full_sparse_matrix.Rdata', reference = ORG_ref(wildcards.organism))
	output:
		'quant/{organism}/full_sparse_matrix.Rdata',
		'{organism}_cell_info.tsv'
	shell:
		"""
		module load R/3.6
		# script analyzes, for macaque, which gene is more detected when using human or macaque ref
		# then creates new matrix blending "best" gene from either human or macaque
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/rebuild_macaque_sparse_matrix.R {wildcards.organism} {output} {input}
		"""	

localrules: cat_cell_info
rule cat_cell_info:
	input:
		expand('{organism}_cell_info.tsv', \
			organism = organism)
	output:
		'cell_info.tsv'
	shell:
		"""
		cat {input} | head -n 1 > header
		cat header <( grep -hv "^value" {input}) > {output}
		"""
		
rule make_seurat_objs:
	input:
		'cell_info.tsv',
		expand('quant/{organism}/full_sparse_matrix.Rdata', \
			 organism = organism)
	output:
		seurat = ('seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__preFilter.seuratV3.Rdata')
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/build_seurat_obj_classic.R \
			{output.seurat} {wildcards.partition} {wildcards.covariate} {wildcards.transform} \
			{wildcards.combination} {wildcards.n_features} {input}	
		"""

rule integrate_00:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__preFilter.seuratV3.Rdata',
	output:
		#temp('seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata')
		('seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata')
	threads: 2 
	run:
		job = "module load R/3.6; \
				Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/merge_methods.R \
				  {method} {transform} {covariate} {dims} {input} {output}".format(\
						method = wildcards.method, \
						transform = wildcards.transform, \
					    covariate = wildcards.covariate, \
						dims = wildcards.dims, \
			            output = output, input = input)
		sp.run("echo \"" +  job + "\"\n", shell = True)
		sp.run(job, shell = True)

rule label_known_cells_with_type:
	input:
		'cell_info.tsv',
		config['srr_sample_file']		
	output:
		'cell_info_labelled.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/label_known_cells.R 
		"""


# as the wellONLY data has no labelled cells, we need to use the droplet data to transfer labels
def predict_missing_cell_types_input(partition):
	if partition == 'onlyWELL':
		out = ['seurat_obj/{combination}__n_features{n_features}__{transform}__onlyWELL__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata',
				'seurat_obj/{combination}__n_features{n_features}__{transform}__onlyDROPLET__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata']
	else:
		out = ['seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata']
	return(out)

rule predict_missing_cell_types_00:
	input:
		lambda wildcards: predict_missing_cell_types_input(wildcards.partition),
		'cell_info_labelled.Rdata'
	output:
		'predictions/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter_cell_info_predictions.Rdata'
	run:
		if wildcards.partition == 'onlyWELL':
			command = 'module load R/3.6; ' \
						'Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/transfer_labels__sep_objs.R \
							{input} {transform} {output}'.format(input = ' '.join(input),
																			transform = wildcards.transform,
																			output = output) 
		else:
			command = 'module load R/3.6; ' \
						'Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/transfer_labels.R \
							{input} {transform} {output}'.format(input = ' '.join(input),
																			transform = wildcards.transform,
																			output = output)
		sp.run("echo \"" +  command + "\"\n", shell = True)
		sp.run(command, shell=True)


rule doublet_ID:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata'
	output:
		'doublet_calls/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}.doublets.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/doublet_ID.R {input} {output}
		"""

rule calculate_umap:
	input:
		obj = 'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata'
	output:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata'
	threads: 4
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/calculate_umap_and_cluster.R \
			{wildcards.method} {wildcards.dims} {wildcards.dist} {wildcards.neighbors} 1 FALSE TRUE {input} {output}
		"""

rule calculate_tsne:
	input:
		obj = 'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata'
	output:
		temp('seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__perplexity{perplexity}.tsne.Rdata')
	threads: 4
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/calculate_TSNE.R \
			{wildcards.method} {wildcards.dims} {wildcards.perplexity} {input} {output}
		"""

rule calculate_cluster:
	input:
		obj = 'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata'
	output:
		temp('seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.seuratV3.Rdata')
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/calculate_umap_and_cluster.R \
			{wildcards.method} {wildcards.dims} 1 1 {wildcards.knn} TRUE FALSE {input} {output}
		"""

rule run_phate:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata'
	output:
		'phate/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.phate.Rdata'
	threads: 24
	shell:
		"""
		module load R/3.6
		module load python/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/run_phate.R \
			seurat_obj/{wildcards.combination}__n_features{wildcards.n_features}__{wildcards.transform}__{wildcards.partition}__{wildcards.covariate}__{wildcards.method}__dims{wildcards.dims}.scVI_scaled.Rdata \
			{output}
		"""

rule extract_umap:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata',
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn7.cluster.Rdata',
		'cell_info_labelled.Rdata'
		#'predictions/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter_cell_info_predictions.Rdata'
	output:
		'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/extract_umap.R \
			{input} {output} {wildcards.method}	UMAP
		"""

rule extract_tsne:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__perplexity{perplexity}.tsne.Rdata',
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn7.cluster.seuratV3.Rdata',
		'cell_info_labelled.Rdata'
		#'predictions/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter_cell_info_predictions.Rdata'
	output:
		'tsne/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__perplexity{perplexity}.tsne.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/extract_umap.R \
			{input} {output} {wildcards.method} TSNE
		"""

rule extract_cluster:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.seuratV3.Rdata'
	output:
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.Rdata',
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.graph.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/extract_cluster.R \
			{input} {output}
		"""

rule plot_integration:
	input:
		'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata'
	output:
		'plots/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.big_plot.png'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/big_plots.R UMAP {input} {output}
		"""

rule plot_integration_tsne:
	input:
		'tsne/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__perplexity{perplexity}.tsne.Rdata'
	output:
		'plots/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__perplexity{perplexity}.big_tsne_plot.png'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/big_plots.R TSNE {input} {output}
		"""

rule monocle_diff_testing:
	input:
		'monocle_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__{knn}.monocle.Rdata'
	output:
		temp('diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__{dims}__{dist}__{knn}__{neighbors}.{piece}.{model}.diff.Rdata')
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/diff_testing_monocle.R {input} 200 {wildcards.piece} {wildcards.model} {output}
		"""

rule monocle_diff_testing_subcluster:
	input:
		'monocle_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__{knn}.monocle.Rdata'
	output:
		temp('diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__{dims}__{dist}__{knn}__{neighbors}.G.{cluster_chunk}.diff.Rdata')
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/diff_testing_monocle_subcluster.R {input} 200 {wildcards.cluster_chunk} G {output}
		"""

rule monocle_diff_merge:
	input:
		expand('diff_testing/{{combination}}__{{n_features}}__{{transform}}__{{partition}}__{{covariate}}__{{method}}__{{dims}}__{{dist}}__{{knn}}__{{neighbors}}.{piece}.{{model}}.diff.Rdata', piece = list(range(1,201)))
		#expand('diff_testing/{{combination}}__n_features{{n_features}}__{{transform}}__{{partition}}__{{covariate}}__{{method}}__dims{{dims}}__mindist{{dist}}__knn{{knn}}__nneighbors{{neighbors}}.{piece}pieces.model{{model}}.monocle_diff.Rdata',
		#		piece = list(range(1,201)))
	output:
		'diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__{dims}__{dist}__{knn}__{neighbors}.{model}.diff.coef_table.Rdata',
		#'diff_testing/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__knn{knn}__nneighbors{neighbors}.model{model}.monocle_diff.gene_fits.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/merge_diff_monocle.R {output} {wildcards.model} {input}
		"""

rule monocle_diff_merge_subcluster:
	input:
		expand('diff_testing/{{combination}}__{{n_features}}__{{transform}}__{{partition}}__{{covariate}}__{{method}}__{{dims}}__{{dist}}__{{knn}}__{{neighbors}}.G.{cluster_chunk}.diff.Rdata', cluster_chunk = list(range(1,41)))
	output:
		'diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__{dims}__{dist}__{knn}__{neighbors}.G.SC.diff.coef_table.Rdata',
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/merge_diff_monocle_subcluster.R {output} G {input}
		"""

rule monocle_marker_test:
	input:
		'monocle_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__{knn}.monocle.Rdata'
	output:
		'diff_test/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__{knn}__{group}.monocleTopMarker.Rdata'
	threads: 16
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/diff_testing_topMarker_monocle.R {input} {threads} {wildcards.group} {output}
		"""

rule build_monocle_obj:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata',
		'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata',
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.Rdata'
	output:
		#'plots/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.monocle_trajectory_labels.png',
		#'plots/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.monocle_trajectory.png',
		'monocle_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__{knn}.monocle.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/monocle.R {input} {output}
		"""

rule diff_test_wilcox:
	input:
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata',
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.Rdata',
		'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata'
	output:
		'diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__{knn}__{neighbors}__{dist}__{group}.sceWilcox.Rdata',
		'diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__{knn}__{neighbors}__{dist}__{group}.sceWilcox_summary.Rdata'
	threads: 4 
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/diff_testing_sce_wilcox.R {input} {wildcards.group} {threads} {output}
		"""

rule perf_metrics:
	input:
		'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist0.3__nneighbors30.umap.Rdata',
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist0.3__nneighbors30.umap.Rdata',
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.Rdata'
	output:
		'perf_metrics/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.Rdata'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/perf_metrics.R {input} {output}
		"""

rule make_h5ad_object:
	input:
		'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata',
		'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.Rdata',
		'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter.seuratV3.Rdata',
		'cell_info_labelled.Rdata',
		#'predictions/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter_cell_info_predictions.Rdata'
		#'monocle_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__{knn}.monocle.Rdata'
	output:
		'anndata/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__knn{knn}.h5ad'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/seurat_to_h5ad.R {input} {output}
		"""

rule scIB_stats:
	input:
		 'anndata/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__knn{knn}.h5ad'
	output:
		'scIB_stats/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}__knn{knn}___stats.csv'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/scIB_stats.R {wildcards.method} {input} {wildcards.dims} {output}
		"""

rule make_sqlite:
	input:
		predictions = 'predictions/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter_cell_info_predictions.Rdata',
		seurat = 'seurat_obj/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata',
		meta = 'umap/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__mindist{dist}__nneighbors{neighbors}.umap.Rdata',
		cluster = 'cluster/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}__preFilter__knn{knn}.cluster.Rdata'
	params:
		'site/anthology_limma{correction}___{combination}-{n_features}-{transform}-{partition}-{covariate}-{method}-{dims}-{dist}-{neighbors}-{knn}.sqlite'
	output:
		'site/anthology_limma{correction}___{combination}-{n_features}-{transform}-{partition}-{covariate}-{method}-{dims}-{dist}-{neighbors}-{knn}.sqlite.gz'
	shell:
		"""
		module load R/3.6
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/make_sqlite.R \
			{input.seurat} \
			{input.meta} \
			{input.cluster} \
			{input.predictions} \
			{params} \
			{wildcards.correction}
		pigz -p 32 {params}
		"""

rule sqlite_add_tables:
	input:
		sqlite = 'site/anthology_limma{correction}___{combination}-{n_features}-{transform}-{partition}-{covariate}-{method}-{dims}-{dist}-{neighbors}-{knn}.sqlite.gz',
		diff_wilcox = expand('diff_testing/{{combination}}__{{n_features}}__{{transform}}__{{partition}}__{{covariate}}__{{method}}__dims{{dims}}__{{knn}}__{{neighbors}}__{{dist}}__{group}.sceWilcox.Rdata', \
					group = ['subcluster', 'cluster','CellType_predict','CellType']),
		diff_glm = expand('diff_testing/{{combination}}__{{n_features}}__{{transform}}__{{partition}}__{{covariate}}__{{method}}__{{dims}}__{{dist}}__{{knn}}__{{neighbors}}.{model}.diff.coef_table.Rdata', \
					model = ['A','C', 'E']),
		diff_glm_subcluster = 'diff_testing/{combination}__{n_features}__{transform}__{partition}__{covariate}__{method}__{dims}__{dist}__{knn}__{neighbors}.G.SC.diff.coef_table.Rdata',
		marker_monocle = expand('diff_test/{{combination}}__n_features{{n_features}}__{{transform}}__{{partition}}__{{covariate}}__{{method}}__dims{{dims}}__preFilter__mindist{{dist}}__nneighbors{{neighbors}}__{{knn}}__{group}.monocleTopMarker.Rdata', \
					group = ['seuratCluster','CellType_predict']),
		doublet = 'doublet_calls/{combination}__n_features{n_features}__{transform}__{partition}__{covariate}__{method}__dims{dims}.doublets.Rdata'
	output:
		'site/MOARTABLES__anthology_limma{correction}___{combination}-{n_features}-{transform}-{partition}-{covariate}-{method}-{dims}-{dist}-{neighbors}-{knn}.sqlite.gz'
	params:
		inp = 'site/anthology_limma{correction}___{combination}-{n_features}-{transform}-{partition}-{covariate}-{method}-{dims}-{dist}-{neighbors}-{knn}.sqlite' 
	threads: 16
	shell:
		"""
		module load R/3.6
		pigz -d -p {threads} {input.sqlite}
		Rscript /home/mcgaugheyd/git/massive_integrated_eye_scRNA/src/sqlite_add_diff_tables.R {params} \
			'diff_testing/{wildcards.combination}__{wildcards.n_features}__{wildcards.transform}__{wildcards.partition}__{wildcards.covariate}__{wildcards.method}__{wildcards.dims}__{wildcards.dist}__{wildcards.knn}__{wildcards.neighbors}' \
			'diff_testing/{wildcards.combination}__{wildcards.n_features}__{wildcards.transform}__{wildcards.partition}__{wildcards.covariate}__{wildcards.method}__dims{wildcards.dims}__{wildcards.knn}__{wildcards.neighbors}__{wildcards.dist}'	\
			{input.doublet}
		pigz -p {threads} {params}
		mv {input.sqlite} {output}
		"""
		
			
