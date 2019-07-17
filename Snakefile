import glob as glob
import subprocess as sp

srr_sample_file = config['srr_sample_file']
srr_sample_discrepancy_file = config['srr_discrepancy_file']

# builds dictionary of dictionaries where first dict key is SRS 
# and second dict key are SRS properties
def metadata_builder(file, SRS_dict = {}, discrepancy = False):
	with open(file) as file:
		for line in file:
			info = line.strip('\n').split('\t')
			if info[0] == 'sample_accession':
				continue
			SRS = info[0]
			if SRS not in SRS_dict:
				SRS_dict[SRS]={'SRR': [info[1]],
					    	  'paired':True if info[2]=='PAIRED' else False, 
					          'organism':info[3],
		            	      'tech':info[4],
						      'UMI':True if info[5]=='YES' else False}
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
									 'UMI':True if info[5]=='YES' else False}
				else:
					runs = SRS_dict[SRS]['SRR']
					runs.append(info[1])
					SRS_dict[SRS]['SRR'] = runs
	return(SRS_dict)

SRS_dict = metadata_builder(srr_sample_file)
# hand edited file which corrects mistakes that in the 
# various databases
# SRS_dict = metadata_builder(srr_sample_discrepancy_file, SRS_dict, discrepancy = True)

def lookup_run_from_SRS(SRS):
	#i = '0'
	#print(SRS)
	#if '_' in SRS:
	#	i= '1' if SRS[-1]=='1' else '2'# check L/R file
	#	SRS=SRS[:-2]
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

def SRS_info(SRS, data_to_return):
	organism = SRS_dict[SRS]['organism']
	if organism.lower() == 'mus musculus':
		idx = 'references/kallisto_idx/gencode.vM22.pc_transcripts.fa.gz.idx'
		txnames = 'references/gencode.vM22.metadata.MGI_tx_mapping.tsv'
	elif organism.lower() == 'homo sapiens':
		idx = 'references/kallisto_idx/gencode.v31.pc_transcripts.fa.gz.idx'
		txnames = 'references/gencode.v31.metadata.HGNC_tx_mapping.tsv'
	elif organism.lower() == 'macaca fascicularis':
		idx = 'references/kallisto_idx/GCF_000364345.1_Macaca_fascicularis_5.0_rna.fna.gz.idx'
		txnames = 'references/GCF_000364345.1_Macaca_fascicularis_5.0_tx_mapping.tsv'
	else:
		print(SRS + ' ' + organism + " NO SPECIES MATCH!")
	if data_to_return == 'idx':
		out = idx
	else:
		out = txnames
	return(out)


SRS_UMI_samples = []
SRS_nonUMI_samples = []
for SRS in SRS_dict.keys():
	if SRS_dict[SRS]['UMI'] and SRS_dict[SRS]['paired']:
		SRS_UMI_samples.append(SRS)
	elif SRS_dict['tech'] != 'BULK':
		SRS_nonUMI_samples.append(SRS)

wildcard_constraints:
	SRS = '|'.join(SRS_UMI_samples)

rule all:
	input:
		expand('quant/{SRS}/genecount/gene.mtx', SRS = SRS_UMI_samples), # UMI data
		expand('quant/{SRS}/abundances.tsv', SRS = SRS_nonUMI_samples) # non UMI data
		# expand('quant/{SRS}/output.bus', SRS = SRS_UMI_samples)

# mouse, human, macaque fasta and gtf
rule download_references:
	output:
		mouse_fasta = 'references/gencode.vM22.pc_transcripts.fa.gz',
		macaque_fasta = 'references/GCF_000364345.1_Macaca_fascicularis_5.0_rna.fna.gz',
		human_fasta = 'references/gencode.v31.pc_transcripts.fa.gz'
	shell:
		"""
		mkdir -p references
		wget ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M22/gencode.vM22.pc_transcripts.fa.gz  
		wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/364/345/GCF_000364345.1_Macaca_fascicularis_5.0/GCF_000364345.1_Macaca_fascicularis_5.0_rna.fna.gz
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
		mf = 'references/GCF_000364345.1_Macaca_fascicularis_5.0_tx_mapping.tsv',
		hs = 'references/gencode.v31.metadata.HGNC_tx_mapping.tsv',
		mm = 'references/gencode.vM22.metadata.MGI_tx_mapping.tsv'
	shell:
		"""
		zgrep "^>" references/gencode.vM22.pc_transcripts.fa.gz | \
			sed 's/>//g' | \
			awk 'BEGIN {{OFS = "\t"; FS = "|"}}; {{print $0, $2, $6}}' > {output.mm}

		wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/364/345/GCF_000364345.1_Macaca_fascicularis_5.0/GCF_000364345.1_Macaca_fascicularis_5.0_feature_table.txt.gz
		zcat GCF_000364345.1_Macaca_fascicularis_5.0_feature_table.txt.gz | \
			grep "^mRNA" | \
			awk -v OFS="\t" 'BEGIN {{FS="\t"}}; {{print $11,$15,$14}}' > {output.mf}
		rm GCF_000364345.1_Macaca_fascicularis_5.0_feature_table.txt.gz

		zgrep "^>" references/gencode.v31.pc_transcripts.fa.gz | \
			sed 's/>//g' | \
			awk 'BEGIN {{OFS = "\t"; FS = "|"}}; {{print $0, $2, $6}}' > {output.hs}
		"""

# this does the pseudoalignment for UMI data (e.g. 10x)
rule kallisto_bus:
	input:
		fastq = lambda wildcards: lookup_run_from_SRS(wildcards.SRS),
		idx = lambda wildcards: SRS_info(wildcards.SRS, 'idx')
	output:
		bus = 'quant/{SRS}/output.bus',
		ec = 'quant/{SRS}/matrix.ec',
		tx_name = 'quant/{SRS}/transcripts.txt'
	params:
		tech = lambda wildcards: SRS_dict[wildcards.SRS]['tech'],
		paired = lambda wildcards: SRS_dict[wildcards.SRS]['paired']
	run:
		if params.paired:
			job = "kallisto bus -x {tech} \
					-i {idx} -o quant/{SRS} {fastq}".format(fastq = input.fastq,
                                                    tech = params.tech,
													idx = input.idx,
													SRS = wildcards.SRS)
		else:
			job = "kallisto bus --single -x {tech} \
					-i {idx} -o quant/{SRS} {fastq}".format(fastq = input.fastq,
                                                    tech = params.tech,
													idx = input.idx,
													SRS = wildcards.SRS)
		sp.run("echo " + job + '\n', shell = True)
		sp.run(job, shell = True)	

# pseudoaligment for nonUMI data (e.g. smartseq)
rule kallisto_quant:
	input:
		fastq = lambda wildcards: lookup_run_from_SRS(wildcards.SRS),
		idx = lambda wildcards: SRS_info(wildcards.SRS, 'idx')
	output:
		quant = 'quant/{SRS}/abundances.tsv'
	params:
		paired = lambda wildcards: SRS_dict[wildcards.SRS]['paired']
	threads: 8
	run:
		if params.paired:
			job = "kallisto quant -t {t} -b 100 --plaintext --bias \
					-i {idx} -o quant/{SRS} {fastq}".format(fastq = input.fastq,
                                                    t = threads,
													idx = input.idx,
													SRS = wildcards.SRS)
		else:
			job = "kallisto bus --single -t {t} -b 100 --plaintext --bias \
					-i {idx} -o quant/{SRS} {fastq}".format(fastq = input.fastq,
                                                    t = threads,
													idx = input.idx,
													SRS = wildcards.SRS)
		sp.run("echo " + job + '\n', shell = True)
		sp.run(job, shell = True)	
			
			
# sorting required for whitelist creation and correction
# make these temp files
rule bustools_sort:
	input:
		'quant/{SRS}/output.bus'
	output:
		('quant/{SRS}/output.sorted.bus')
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
		bus = 'quant/{SRS}/output.sorted.bus',
		ec = 'quant/{SRS}/matrix.ec',
		tx_name = 'quant/{SRS}/transcripts.txt',
		tx_map = lambda wildcards: SRS_info(wildcards.SRS, 'tx')
	output:
		whitelist = 'whitelist/{SRS}_whitelist',
		bus_matrix = 'quant/{SRS}/genecount/gene.mtx'
	params:
		bus_out = 'quant/{SRS}/genecount/gene'
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
		
#rule profit: