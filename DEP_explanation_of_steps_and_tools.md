# 1. Repeat masking

The first step in genome annotation is to identify and mask repetitive regions. These can make up over half of a mammalian genome, and can cause trouble when generating genome annotations. For instance, repeat regions may interfere with sequence alignment, as they create an intractable number of alignment matches; repeats may also contain open reading frames (ORFs), and annotation software may mistake these ORFs as genes (therefore increasing the false positive rate when gene models are generated). Therefore it is important that a genome sequence is masked so that annotation software doesn't attempt to place gene models in these regions. Genomes can be soft-masked (repeat regions turned from uppercase letters to lowercase letters in the FASTA file) or hard-masked (repeat regions converted into strings of capital Ns). Soft-masking is generally recommended, and more leniant as it allows for gene-models initiated in non-repeat regions to extend into repeat regions.

Before repeat masking, it's best to check if your genome came with repeats already masked. You can do this by peaking into your genome file using `less genome.fa`, and check if you can see any Ns or lowercase letters.

#### Earl Grey

Repeat masking can be done with [Earl Grey](https://github.com/TobyBaril/EarlGrey). Earl Grey integrates multiple common repeat masking tools such as RepeatMasker, which maps repetitive elements from a database, and RepeatModeler, which identifies repeats de novo.  It also uses multiple tools such as cd-hit-est, LTR_finder, rcMergeRepeats, and custom scripts to identify, annotate, filter, and aggregate repeat regions genome wide. Earl Grey is a command-line tool that can be run with a single line of code in a Unix environment, and produces figure-quality summaries of a genome’s transposable element landscape in conjunction with repeats annotated in general feature format (GFF) which are required for downstream analysis. Earl Grey relies on databases of repeat elements, such as DFam, that are used to identify repeats in your genome. The user can specify what clade of species they are working with, which indicates which repeat database Earl Grey should use.

Input to Earl Grey is the FASTA file from your species, the name of your species, and the output directory. It is also helpful to specify the search term used for RepeatMasker with `-r`, which indicates which set of repeats to look for (e.g. “eukarya”). `-d` is a flag that indicates whether or not you would like soft-masking. If you put "yes", Earl Grey will output a soft-masked genome that you can use directly for subsequent annotation steps. The output is stored in multiple folders, with the most important information located in `summaryFiles`. 

```
earlGrey \
 -g your_genome.fasta \
 -s your_species_name \
 -o ./output_directory \
 -r repeat_clade \
 -d yes \
 -t number_of_threads
```
#### Earl Grey: installing/running/troubleshooting

- We have had success running Earl Grey on a desktop and high performance compute cluster
- Earl Grey can easily be installed using conda (e.g. `conda create -n earlgrey -c conda-forge -c bioconda earlgrey=4.4.0`); an error causing Earl Grey to crash mid-run required an update to Numpy (`pip install numpy --upgrade`)
- Earl Grey takes multiple days to run (be prepared for up to a week)
- Earl Grey does not like spaces in any directory names

# 2. Generating gene models

Gene models are hypotheses about the locations of genes and their corresponding features (e.g. mRNA, exons, introns) on the genome. These hypotheses are supported by a variety of evidence, including RNA-alignment information, the presence of ORFs, protein sequence conservation, gene structure and order along the sequence. As gene models are hypotheses to the locations and structures of real genes, annotations may contain both false positives (e.g. a random ORF-like sequence) and false negatives (e.g. a real gene that was missed in the annotation process). To reduce these errors, it is important to use high quality evidence for the existence of genes, and good annotation tools that perform well.

We thoroughly describe two complementary approaches to generate high-quality gene models: homology-based annotation and RNA-and-protein-alignment-based annotation (Figure 1). Broadly, homology-based annotations assume that thousands of gene models will be shared between a reference species (e.g. mouse) and a target species (e.g. woodchuck), at the level of DNA sequence similarity and gene structure (e.g., number of exons). In contrast, transcript assembly through functional annotation assumes that the location of uniquely mapping paired end RNA-seq data represents an expressed region of the genome and a candidate for a gene model.

It is important to note that resulting annotations vary depending on (1) the quality of the genome sequence being annotated, (2) the quality of the evidence provided to inform the annotation (e.g. RNA-seq, homology), and (3) the quality of the bioinformatic tool applied. Therefore, it is best to perform many different annotations, test each one for quality (described in box 1), and choose the best results that can be used in step three, which involves integrating gene models into a single, complete set. Although tools may change over time, homology- and alignment-based annotations should both be generated, tested, and combined.

### Homology-based annotation

Homology-based genome annotation is the derivation of gene models in your species from homologous gene models found in other species. Most gene structures and sequences are conserved across related species, making homologous alignments from a reference species with high-quality gene structures an accurate and computationally efficient method to annotate your species. Many tools are capable of performing homology-based annotation, but we have had the most luck with [LiftOff](https://github.com/agshumate/Liftoff) and [the Tool to infer Orthologs from Genome Alignments (TOGA)](https://github.com/hillerlab/TOGA).

#### Finding annotations for liftover

Before performing homology-based annotation, one needs to decide which genome to pull information from. The best homology-based annotations according to various quality metrics (e.g. BUSCO, GffCompare) occur when the reference genome is high-quality, with a high-quality annotation from a closely related species. To find such a genome, we recommend searching RefSeq or ENSEMBL for a few of the most closely related annotated species to yours, and trying liftover on those species. 

High-quality genomes tend to have smaller contig or scaffold numbers (i.e. the genome sequence is divided into larger chunks), ideally close to the number of chromosomes found in the species, smaller L50s (the smallest number of contigs that make up half of the genome sequence), and larger N50s (the smallest contig length that half of the genome sequence is contained in, of the largest contigs). High-quality annotations can be assumed if the genome is annotated by RefSeq or ENSEMBL. RefSeq annotations are also evaluated for quality using BUSCO, where a curated set of single-copy orthologs is compared to the gene models identified in the annotation; a high quality annotation is indicated by a single-copy ortholog detection rate close to 100%, and missing or fragment orthologs close to 0%. We recommend the user searching these databases for a few of the most closely-related species, comparing these genome statistics, and selecting the assembly and annotation (or multiple) with the most favorable statistics.

As an example, a user can search for RefSeq genomes here: https://www.ncbi.nlm.nih.gov/datasets/genome/. Once you find a genome that you are interested in that also has an item in the "RefSeq" column, click on the link to the assembly (e.g. mouse assembly: https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001635.27/). On the assembly page, there is a link to the FTP page where the genome sequencing and annotation files can be found (e.g. mouse FTP: https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/635/GCF_000001635.27_GRCm39/).

Genomes can be downloaded directly from the command line using the command `wget`. The command to download the mouse genome FASTA file would be: `wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/635/GCF_000001635.27_GRCm39/GCF_000001635.27_GRCm39_genomic.fna.gz`, and the command to get the annotation in GFF format is: `wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/635/GCF_000001635.27_GRCm39/GCF_000001635.27_GRCm39_genomic.gff.gz`. Typically the FASTA and GFF files are all that are required for genome liftover. `.gz` files can be unzipped with `gunzip name_of_file.gz`.

#### LiftOff

LiftOff is a gene liftover tool that aligns gene sequences from the reference genome to the target genome using a single line of Unix code, making it quick and easy to use. It uses minimap2 to align the genes to the genome with high accuracy and with relatively low computational resources, so the tool can be run on a desktop computer. LiftOff is a command-line tool that takes a FASTA file and GFF/GTF file from a reference species, and the FASTA file from the target species, and creates a GFF/GTF output file for your species based on the reference annotations. It also provides the user with a list of unmapped genes ("unmapped_features.txt"), which may indicate alignment challenges. The "-copies" flag indicates that LiftOff will look for additional gene copies in the new genome. Because LiftOff is so quick and easy to use, the user can easily use LiftOff to generate annotations from multiple reference species and compare the resulting annotation quality.

```
liftoff \
 -g annotation_of_related_species.gff \
 your_genome.fasta \
 genome_of_related_species.fasta \
 -o output_annotation.gff \
 -u unmapped_features.txt \
 -copies \
 -p number_of_threads
```

#### LiftOff: installing/running/troubleshooting

- Some Docker containers exist and work well for LiftOff (e.g. `docker run staphb/liftoff liftoff`)
- LiftOff also works well with a Conda environment (e.g. `conda create -n liftoff -c bioconda liftoff python=3`)

#### The Tool to infer Orthologs from Genome Alignments (TOGA)

TOGA accurately annotated genes across vertebrates with higher rates of divergence. TOGA relies on a chain file connecting the reference and target species, which is a file that indicates which sections of the reference genome align to which sections of the target genome. This allows TOGA to use synteny to inform its annotation liftover, which improves accuracy considering groups of genes are often conserved across species. Chain files are developed by post-processing whole genome alignments between two species, typically using executable binary scripts developed to improve the compatibility between genomic data types and [the UCSC genome browser](https://github.com/ucscGenomeBrowser/kent). We recommend using the [CACTUS alignment tool](https://github.com/ComparativeGenomicsToolkit/cactus) when generating the initial alignments between two distantly related species. Preparing the data for TOGA and running TOGA is a multistep process:

1. Align genomes with Cactus

   Cactus takes a text configuration file as input, which is a two-species phylogenetic tree of the reference and target species. A template of such a file is as follows, replacing “target” and “ref” with the species names and files:
   ```
   (target:1.0,ref:1.0);
   target       /path-to-target/target.soft.fa
   mouse      /path-to-reference/reference.soft.fa
   ```
   Since the FASTA files of each species are listed in the config file, these do not need to be specified as addition input to CACTUS. Note that each FASTA file is expected to be soft-masked. Cactus outputs a file ending in `.hal`, which stores information about the alignment. CACTUS requires you to specify a temporary directory where Cactus stores large quantities of files while it's running. This temporary directory will change depending on what system you are using to run Cactus. On a local desktop, a temporary directory may simply by `/tmp`, whereas a high performance compute cluster may have a designated temporary directory to use, such as `$SCRATCH/tmp`. Cactus can then be run as follows:

   ```
   cactus $SCRATCH/tmp \
   two_species_cactus_config.txt \
    target_ref.hal \
    --binariesMode local
   ```

2. Convert HAL file to chain file

   This is a multistep process also described by the ComparativeGenomicsToolkit [here](https://github.com/ComparativeGenomicsToolkit/hal/blob/chaining-doc/doc/chaining-mapping.md). The first step involves converting both the reference and target FASTA files to a compressed 2bit format. This can be done using additional tools that are accessible in the [Cactus Github repository](https://github.com/ComparativeGenomicsToolkit/cactus) in this directory: `/path-to-cactus/external/cactus-bin-v2.2.3/bin`. We can set this as a variable to make the tools easier to access.

   `cactusbin=/path-to-cactus/external/cactus-bin-v2.2.3/bin`

   Each FASTA file can be converted to 2bit with the following two commands below. Each `hal2fasta` command requires the HAL file output by CACTUS as input as well as the reference or target FASTA file. The output is directly piped into `faToTwoBit` ("stdin" indicates that `faToTwoBit` takes the piped input) which outputs a compressed [2bit file](https://genome.ucsc.edu/FAQ/FAQformat.html#format7).

   ```
   $cactusbin/hal2fasta target_ref.hal name_of_reference | faToTwoBit stdin reference.2bit
   $cactusbin/hal2fasta target_ref.hal name_of_target | faToTwoBit stdin target.2bit
   ```

   Convert the alignments stored in the HAL file to a BED file using the `halStats` command.

   ```
   $cactusbin/halStats --bedSequences name_of_reference target_ref.hal > reference.bed
   $cactusbin/halStats --bedSequences name_of_target target_ref.hal > target.bed
   ```

   Next, create pairwise alignments, which are stored in a resulting PSL file. This can be done using `halLiftover`. The `--outPSL` flag indicates that the output will be a PSL file; the command takes the HAL file, the name of the target species, the target BED file (created in the previous step), and the name of the reference species as input. The output is specified as `/dev/stdout` which means the output will be printed to the screen. This output is piped into the `pslPosTarget` command which forces the alignments to the positive strand, and outputs the results into a PSL file.

   ```
   $cactusbin/halLiftover --outPSL target_ref.hal name_of_target \
      target.bed name_of_reference /dev/stdout | \
      $cactusbin/pslPosTarget stdin reference-to-target.psl
   ```
   
   Finally, the PSL file can be converted to a chain file using the `axtchain` command from [ucscGenomeBrowser](https://github.com/ucscGenomeBrowser/kent) (sometimes referred to as KentUtils). This bins the alignments at various depths, generalizing the alignment so that instead of storing alignments at specific base pairs, they are stored as blocks of homologous regions. `axtChain` takes the flag `-psl` to indicate PSL input, the recommended parameter setting `-linearGaps=loose`, the PSL file, and both 2bit files as input. The output is the chain alignment file that can now be used for TOGA.

   ```
   axtChain -psl -linearGap=loose reference-to-target.psl reference.2bit target.2bit reference-to-target.chain
   ```
   
3. Perform homology-based annotation with TOGA

   Now that the input files have been prepared and processed, TOGA can be run with one line of UNIX code. The inputs to TOGA are the chain file created in the previous step, the 2bit files for both the reference and the target also created in the previous step, and transcript annotations from the reference species in [BED12](https://genome.ucsc.edu/FAQ/FAQformat.html#format1) format. GTF files can be converted to BED12 files using tools available from [ucscGenomeBrowser](https://github.com/ucscGenomeBrowser/kent). This is a two step process: First, convert the GTF file to a genePred file by performing `gtfToGenePred annotation.gtf annotation.genePred`. Then, convert the genePred file to a BED12 file with `genePredToBed annotation.genePred annotation.bed`.

   Isoform data from the reference species is highly recommended when running TOGA. These data are provided in a two-column TSV file with a header. The left column is the gene ID and the right column is the transcript ID; a single gene can be associated with multiple transcripts. This can be created directly from the BED or GFF annotation file of the reference species (we have provided a script XXX that can create this). 
   
   ```
   toga.py \
   reference-to-target.chain \
   reference_annotation.bed \
   reference.2bit target.2bit \
   --project_name ref_to_target \
   --isoforms isoforms.tsv
   ```

   The output of TOGA...

#### TOGA and associated tools: installing/running/troubleshooting

- TOGA may not work if run on a desktop; most genomes are large enough that they require a high performance compute cluster
- Cactus and TOGA can easily be installed with Conda

### Transcript assembly using RNA-sequencing data

RNA- and/or protein-sequence alignment data can be used to inform gene models. Alignment-based methods work by aligning RNA or protein sequences to the genome to determine the location of transcribed and/or protein-coding genes. The specific tools used to perform alignment-based annotation depend on the sequencing data available to the user. If the user has access to high-quality RNA-seq data (e.g. 2 x 100bp paired-end sequencing ideally from as many tissues as possible), [HISAT2](https://daehwankimlab.github.io/hisat2/) and [StringTie2](https://github.com/skovaka/stringtie2) can be used to create an annotation or "transcript assembly" directly from these data. Otherwise, [BRAKER3](https://github.com/Gaius-Augustus/BRAKER) can be used with shorter, lower-quality, or no RNA-seq reads and a database of protein sequences to create an annotation.

#### Finding publicly available RNA-seq data

If you can't generate your own RNA-seq data, there may be publically available data for your species you can use. One place where you can search for RNA-seq data is the [Sequence Read Archive (SRA)](https://www.ncbi.nlm.nih.gov/sra). In the SRA search bar, type `"species name" AND "rna seq"` to find RNA-seq for your species (e.g. `"mus musculus" AND "rna seq"` if you were annotating the mouse genome). If you see an RNA-seq dataset that fits your criteria and that you would like to download, find the experiment accession number that is listed two lines below the link to the data (often begins with "SRX"). SRA Toolkit (downloadable at https://github.com/ncbi/sra-tools/wiki/02.-Installing-SRA-Toolkit) can use that accession number to download the raw FASTQ files for that dataset.

```
prefetch accession_number
# Creates folder with .sra file inside; folder and SRA file have the same name
fasterq-dump --split-files file_name/file_name.sra
```

The output are the FASTQ files that were submitted for that experiment. For paired-end RNA-seq data, this often means that the output will be two FASTQ files, representing each end of the paired-end reads. Such paired files should be processed together downstream, for instance when being aligned to the genome. These FASTQ files can then be used for HISAT2 + StringTie2 or BRAKER3.

#### HISAT2 + StringTie2

To generate gene models directly from RNA-seq alignment, the RNA-seq reads first need to be aligned to your genome sequence. This can be done with the genome aligner HISAT2. In order to align the reads, an index needs to be generated for the genome you are annotating with HISAT2. The input is your genome FASTA sequence and the number of threads you would like to use to parallelize the process. HISAT2 outputs multiple files that either end in `.ht2` or `.ht2l` depending on the size of your genome.

```
hisat2-build \
 -p number_of_threads \
 your_genome.fasta \
 base_name_of_genome_index
```

Now you can Run HISAT2 to align the RNA-seq reads to the genome you are annotating. The input required is the genome index created by `hisat2-build` and the input RNA-seq files in FASTQ format (or FASTA format if specified with `-f`). The `--dta` flag reports alignments tailored for transcript assemblers (as in this case). The `-1` and `-2` indicate the mates for paired-end RNA-seq. HISAT2 outputs a SAM alignment file.

```
hisat2-align \
 -p number_of_threads \
 --dta \
 -x base_name_of_genome_index \
 -1 first_mate.fastq \
 -2 second_mate.fastq \
 -S name_of_sam_alignment.sam
```

Now that the reads are aligned, StringTie2 can be used to generate gene models (this language is used for simplicity - StringTie2 finds "transcripts" rather than "genes" since it is based on aligning RNA-seq to the genome, but the concept is similar to gene model generation). However, StringTie2 takes BAM files as input, which are a binary version of SAM files. Therefore you must first convert your SAM file(s) to BAM file(s) with [SAMtools](http://www.htslib.org/). The only input is the SAM file created with HISAT2. `-S` specifies SAM input, `-h` includes the header in the SAM output, `-u` indicates uncompressed BAM output (saves time when converting SAM to BAM).

```
samtools view \
 -@ number_of_threads \
 -Shu \
 -o name_of_sam_alignment.bam \
 name_of_bam_alignment.sam
```

StringTie2 also requires the BAM files to be sorted by reference position. This can also be done with SAMtools. 

```
samtools sort \
 -@ number_of_threads \
 -o name_of_sorted_bam_alignment.bam \
 name_of_bam_alignment.bam
```

Now the sorted BAM file can be used to predict gene models with StringTie2. The output is a GTF file.

```
stringtie \
 name_of_sorted_bam_alignment.bam \
 -o stringtie_output.gtf \
 -p number_of_threads
```

The only features in the output GTF file are transcripts and exons, with no prediction of coding sequences (typically indicated by "CDS" in the third column of the GTF file). Because of this, the output cannot be easily converted into a protein sequence and tested with BUSCO. Although this is not ideal, testing the quality and completeness of a genome annotation with BUSCO is not necessary if it will be combined with additional annotation sets and filtered using [Mikado](https://mikado.readthedocs.io/en/stable/) (explained later). If you used poor-quality or very short RNA-seq data, however (not recommended), there is a risk of generating short, fragmented, monoexonic transcripts. You can check to see if your annotation has many short, monoexonic transcripts using a summary statistics calculator provided by Mikado, `mikado util stats annotation.gff output_summary.tsv`, where `annotation.gff` is replaced by whatever annotation you want the summary statistics for, and `output_summary.tsv` is whatever you name the output summary statistics file. You can compare your summary statistics to that of another mammalian genome annotated by RefSeq or Ensembl. If the statistics are similar, this indicates an annotation that is likely of higher quality. However, if you notice that the average number of exons per transcript is very low and the number of monoexonic transcripts is very high in the genome you are annotating, this indicates that many of the gene models may be short or fragmented, and should potentially be excluded from the final annotation set or run through a pass of very stringent filtering with Mikado (tool explained later, noisy RNA-seq e.g. https://mikado.readthedocs.io/en/stable/Tutorial/Adapting/#case-study-2-noisy-rna-seq-data).

#### BRAKER3

If you don't have access to RNA-seq data or your RNA-seq reads are short (single-end short reads or paired-end reads shorter than 2x100bp), [BRAKER3](https://github.com/Gaius-Augustus/BRAKER) can be used to generate an annotation. BRAKER3 integrates RNA-seq alignment information with protein data and *ab initio* gene prediction. *Ab initio* gene predictors are mathematical models that are fed existing gene models to train their algorithms (i.e. the algorithms learn which aspects of genome structure are associated with different gene model features), so that they can then discover new gene models in genome sequences. The RNA sequences come from the species being annotated, whereas the protein sequences are typically from an online database of homologous sequences, like [OrthoDB](https://www.orthodb.org/). Internally, BRAKER3 uses HISAT2 to align the short RNA-seq reads to the genome, StringTie2 to create candidate gene models from these alignments, and [ProtHint](https://github.com/gatech-genemark/ProtHint) to predict CDS regions using these protein alignments. These data are then used as “hints” i.e. (estimations of CDS region and intron placements) when generating *ab initio* gene models with [GeneMark-ETP](https://github.com/gatech-genemark/GeneMark-ETP) and [Augustus](https://github.com/Gaius-Augustus/Augustus). Finally, BRAKER3 can also identify tRNAs, snoRNAs, and UTRs.

The input to BRAKER3 is the soft-masked genome you wish to annotate (`your_genome.fasta`), the RNA sequences you wish to align, and protein sequence database (`orthodb.fa`). If you generated the previous annotation using HISAT2 + StringTie, you would have already aligned RNA-seq to the genome which would otherwise be done internally by BRAKER3. Therefore, the sorted BAM file(s) that you used as input to StringTie2 can also be used as input for BRAKER3 (e.g. `rna1.bam,rna2.bam` with more comma-separated files listed if you have additional BAM files). `name_of_your_species` is whatever name you want to call you species to distinguish the output; `--etpmode` indicates that you are using both RNA and protein data; `number_of_cores` is the same as the number of threads used for other tools (they are slightly different ways to describe essentially the same thing); and `--gff3` indicates that the desired output is a GFF3 file.

```
singularity exec braker3.sif braker.pl \
 --cores=number_of_cores \
 --etpmode \
 --species=name_of_your_species \
 --genome=your_genome.fasta \
 --bam=rna1.bam,rna2.bam \
 --prot_seq=orthodb.fa \
 --gff3
```

If you do not have RNA-seq data and wish to run BRAKER3 in "protein mode", change the `--etpmode` flag to...

#### BRAKER3: installing/running/troubleshooting

- In our experience, BRAKER is most easily installed and implemented using the Singularity container that the BRAKER authors maintain: `singularity build braker3.sif docker://teambraker/braker3:latest`
- If installing Braker through other methods (e.g. a conda environment) then the `singularity exec braker3.sif` in the command is unnecessary
- We have found that the GFF file output by BRAKER3 has some formatting issues that can be fixed by running GFFRead, e.g. `gffread braker.gtf --keep-genes -o braker.gffread.gff`

# 3. Combining and filtering gene models

Completing the previous steps yields gene models from multiple homology-based annotations and transcript-assembly-based annotations. Most gene models will be identified across annotations, however some gene models will be method-specific.

#### Mikado

[Mikado](https://github.com/EI-CoreBioinformatics/mikado) is a tool designed to evaluate, combine, and filter gene models across multiple annotations in a way that mimics manual assembly curation. Mikado takes different GFF files as input, and outputs a filtered GFF file that is more accurate than any of the input annotation or evidence files on their own.

Mikado is directed by configuration and scoring files that can be customized to your annotation project. The four steps Mikado follows are:
1. Configure (Creates configuration files that guide Mikado)
2. Prepare (Prepares input GFF files for analysis)
3. Serialise (Creates database used for “Pick”)
4. Pick (Picks best transcripts for resulting annotation)

Mikado has a thorough user manual that includes a tutorial walking through how to use it: https://mikado.readthedocs.io/en/stable/Tutorial/. Before running the command to create the configuration file, it is best to organize your input GFF files that you would like to combine. The names of these files should be listed in a tab-delimited file, with one file described per row.

First column: the name of the file
Second column: short, unique identifier for the input file
Third column: True or False indicating whether or not the annotation is strand-specific
OPTIONAL COLUMNS:
Fourth column: Assignment of positive or negative weightings (e.g. if you think a particular input file is high quality, you can, say, put a 3 in that colum; a poor-quality dataset may have a -0.5)
Fifth column: True or False indicating if the annotation is a reference (important if updating an exising annotation, another function of mikado)

The easiest way to run everything is if you have all of these input files should be stored in a working directory that you are using to run Mikado, including the list of inputs. Here is an example of the tab-delimited file indicating the different input GFF files (note if items are separated by spaces instead of tabs, an error will be thrown):

```
braker.gff braker True 0 False
stringtie.gff stringtie True 0 False
liftoff.gff liftoff True 0 False
toga.gff toga True 0 False
```

#### 1. Mikado configure

To create the configuration file that runs Mikado, one must type `mikado configure` on the command line, pointing to the genome you are annotating, specifying the name of the configuration file, and pointing towards the TSV file of input files that you just created. Mikado provides a selection of scoring files you can use to cater your genome annotation to your species, which you can indicate with the `--scoring` argument - mammals will use built-in `mammalian.yaml`. An additional `--copy-scoring` flag can be used to copy a scoring file to your working directory so that you can customize it for your species. The scoring file is what Mikado will eventually use to selectively filter the input transcripts, and may need to be modified depending on what type of data or species you are working with (we’ll touch on this later). The configuration file that gets generated can also easily be modified if needed; the user can do this by either modifying their `mikado configure` command and rerunning it, or by modifying the resulting configuration file directly (e.g. using `nano conf.yaml`).

Below is an example command, with `-y` preceding the name of the configuration file, and `--reference` pointing to the soft-masked FASTA file of the genome that you're annotating.

```
mikado configure \
 --list list_of_inputs.tsv \
 --reference name_of_genome.fasta \
 -y conf.yaml \
 --scoring mammalian.yaml \
 --copy-scoring
```

#### 2. Mikado prepare

The next step is running `mikado prepare`, which requires any input GFF files you wish to combine. Since you have already created the configuration file and pointed Mikado to your list of input files, all you have to do is run `mikado prepare --json-conf conf.yaml`. This creates a GTF file containing non-redundant transcripts (`mikado_prepared.gtf`) and a corresponding FASTA file (`mikado_prepared.fasta`), as well as a log file. This step can be sped up by increasing the number of threads using the `-p` argument, and Mikado recommends adding the option `start-method spawn` when using parallelization.

```
mikado prepare \
 --json-conf conf.yaml
 --start-method spawn \
 -p number_of_threads
```

Before running `mikado serialise`, additional work should be done to provide Mikado with more information about the transcripts now stored in the `mikado_prepared` files. The steps are as follows, and are especially important when working with RNA-seq-derived gene models:
1. Validate splice junctions with [Portcullis](https://github.com/EI-CoreBioinformatics/portcullis)
2. Determine sequence similarity with [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)
3. Identify open reading frames (ORFs) with [TransDecoder](https://github.com/TransDecoder/TransDecoder/wiki)

#### Portcullis

Validating splice junctions can be done with [Portcullis](https://github.com/EI-CoreBioinformatics/portcullis), which filters out false positive intron/exon boundaries which are often found in the outputs of RNA-seq alignment tools. Portcullis can be run on a merged BAM file of all of your aligned RNA-seq reads. So if you had aligned RNA-seq datasets with RNA-seq alignment tools, you would have ended up with a BAM file for each alignment performed. All of these BAM files must first be merged with [SAMtools](https://www.htslib.org/). Three are given as an example, but any number of BAM files can be merged.

```
samtools merge \
 -@ number_of_threads \
 merged_bams.bam \
 bam_file_1.bam \
 bam_file_2.bam \
 bam_file_3.bam
```

Portcullis can now be run on the output, `merged_bams.bam`; this tool analyses all of the splice junctions in the BAM file and filters out the junctions that are not likely to be genuine. Portcullis has three steps: `prep`, which prepares the data for junction analysis; `junc`, which calculates junction metrics; and `filt`, which separates valid and invalid splice junctions. The easiest way to run the tool, however, is to run `portcullis full` which combines all three steps and produces a BED file of junctions that can be used as input for `mikado serialise` (`portcullis.pass.junctions.bed`).

```
portcullis full \
 -t number_of_threads \
 name_of_genome.fasta \
 merged_bams.bam
```

#### BLAST+

[BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi) can now be used to identify sequence similarity to known proteins. Different protein databases exist against which the predicted transcript sequences output by `mikado prepare` can be compared; we used the high-quality curated protein database, SwissProt. This database can be downloaded from [uniprot.org](https://www.uniprot.org/).

`wget ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz`

Once the database is downloaded, you can use BLAST to index it which is required to perform a BLAST+ search. `-dbtype` indicates that this is a protein database. `uniprot_sprot` is the base name of the FASTA file and the resulting BLAST database.

```
makeblastdb \
 -in uniprot_sprot.fasta \
 -dbtype prot \
 -out uniprot_sprot
```

BLAST the transcript sequences from `mikado prepare` against the SwissProt database using `blastx`, which is the command required to compare translated nucleotide sequences to protein sequences. BLAST needs to be run requesting the following output format: `-outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore ppos btop"`. This creates a TSV results file that Mikado uses to filter or score transcripts based on their homology to existing protein-coding sequences. `-max_target_seqs` indicates to keep a maximum of this number of hits (we used 5, as seen on the Mikado tutorial). `-query` is the transcript file BLASTed against the protein database. `-outfmt` specifies the format required by the next step of Mikado. `-db` is the SwissProt database. `-evalue` is a minimum measure of significance to consider a protein sequence in the SwissProt database a hit against the query.

```
blastx \
 -max_target_seqs num_of_seqs \
 -num_threads number_of_threads \
 -query mikado_prepared.fasta \
 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore ppos btop" \
 -db uniprot_sprot \
 -evalue 0.000001 \
 -out blast_results.tsv
```

The output is a TSV file of BLAST+ results called `blast_results.tsv`. Note that BLAST+ takes a very long time (maybe a day or so), also depending on the number of sequences output by `mikado prepare`. This time will increase significantly if a larger protein database is used. [Diamond](https://github.com/bbuchfink/diamond) is a much faster alternative than BLAST+, but it finds fewer hits even in ultra-sensitive mode.

#### TransDecoder

Open reading frames (ORFs) can be determined with [TransDecoder](https://github.com/TransDecoder/TransDecoder/wiki), a tool that scans transcripts for potential coding regions. A single transcript can produce multiple ORFs, and the user can set a minimum amino acid count using the `-m` flag. The default setting of TransDecoder is `-m 100` indicating that the minimum ORF detected is 100 amino acids long. Lowering this parameter increasing the number of false positive ORFs, but allows for shorter ORFs to be detected (we chose to set `-m 30`; Mikado also has an internal minimum ORF length of 50bp). The input to TransDecoder is the FASTA file generated by `mikado prepare`; `TransDecoder.LongOrfs` identifies the ORFs.

```
TransDecoder.LongOrfs \
 -t mikado_prepared.fasta \
 -m number_of_amino_acids
```

Next, run `TransDecoder.Predict` to predict the likely coding regions. The `--retain_long_orfs_length` argument retains all ORFs longer than this number of amino acids (again, we used 30).

```
TransDecoder.Predict \
 -t mikado_prepared.fasta \
 --retain_long_orfs_length number_of_bases
```

If there is an error in the second step, it may be fixed by adding the flag `--no_refine_starts`. This prevents the identification of potential start codons for 5' partial ORFs using a position weight matrix; this process may fail if there are not enough sequences to model the start site. Further, TransDecoder may fail if there are spaces in any of the file paths you are using.

TransDecoder outputs valid ORFs in a BED file (e.g. `mikado_prepared.fasta.transdecoder.bed`) that can now be used for Mikado serialise.

#### 3. Mikado serialise

Now that you have run Portcullis (if possible), BLAST+, and TransDecoder, it is possible to combine all of this information with Mikado serialise. Mikado serialise takes many different inputs that you point it at and creates an SQL database. Some of the different files and parameters that should be provided to Mikado include:
1. The FASTA output of `mikado prepare` (`mikado_prepared.fasta)
2. The configuration file (`conf.yaml`)
3. The genome index file (`name_of_genome.fai`)
4. The output of Portcullis (`portcullis.pass.junctions.bed`)
5. The output of BLAST (`blast_results.tsv`)
6. The FASTA file used for the BLAST search (`uniprot_sprot.fasta`)
7. The maximum number of discrete hits that can be assigned to a single sequence (we set this to 5)
8. The output of TransDecoder (`mikado_prepared.fasta.transdecoder.bed`)
9. The name of the log file to be produced by `mikado serliase` (`mikado_serialise.log`)

Here is an example of a Mikado serialise command:

```
mikado serialise \
 -p number_of_threads --start-method spawn \
 --transcripts mikado_prepared.fasta \
 --json-conf conf.yaml \
 --genome_fai name_of_genome.fai \
 --junctions portcullis.pass.junctions.bed \
 --tsv blast_results.tsv \
 --blast-targets uniprot_sprot.fasta \
 --max-target-seqs number_of_targets \
 --orfs mikado_prepared.fasta.transdecoder.bed \
 --log mikado_serialise.log
```

This creates a database called `mikado.db`. Note that if one of your input sources changes and you want to rerun `mikado serliase`, you have to manually delete `mikado.db` or else an error will be thrown.

#### 4. Mikado pick

The final step of the Mikado pipeline, `mikado pick`, takes this file as input and selects what it determines to be the best gene models. In order to perform this `pick` command, Mikado relies on a scoring file (e.g. `mammalian.yaml`) that guides the algorithm on what parameters create the best gene models. For instance, the best transcripts may long sequences with more than two exons, and introns less than 2000bp long (more parameters are considered, that was just an example). These parameters are described in the scoring file which may be customized by the user. Instructions on how to do this can be found in the [Mikado guidelines](https://mikado.readthedocs.io/en/stable/Tutorial/Scoring_tutorial/#configure-scoring-tutorial). Mikado has a flag `--no-purge` which can be used to prevent Mikado from throwing out gene models that fail specific requirements in the scoring and configuration files, but where there is no competing gene model. This dramatically increases the number of gene models in the final annotation, and we have found that it yields higher BUSCO scores (at the risk of including more false positives).

This is also where the user has to decide how they want to treat the chimeras in their gene models. Mikado has five different options that can be chosen by the user which range in stringency: nosplit, stringent, lenient, permissive, split. “nosplit” never splits any gene models, whereas “split” always splits multi-ORF transcripts. The other options land somewhere in between and really on homology results from BLAST hits (e.g. only splitting if consecutive ORFs have BLAST hits against two different targets).

```
mikado pick \
 --json-conf conf.yaml \
 -db mikado.db \
 --mode lenient \
 mikado_prepared.gtf \
 --scoring mammalian.yaml
 --loci-out name_of_final_annotation.gff \
 --log mikado_pick.log \
 --no-purge
```

The output of `mikado pick` is a GFF file containing the gene models selected based on the parameters in the scoring file and the information in `mikado_serialise.db`. At this point, the gene models can be analysed and visualised (if desired) for quality purposes. `mikado pick` is fairly quick to run, so it may be a good idea to run it a few times using different stringency levels on when to split chimeras, to see which setting results in the most expected gene model statistics (e.g. the highest BUSCO scores).

#### Mikado and associated tools: installing/running/troubleshooting

- Mikado has been challenging to install as it has a lot of dependencies. Therefore, we created a Docker image that can be run as follows: `docker run -v "$(pwd)":/tmp risserlin/mikado:ubuntu22_mikado2.3.2 mikado --help`
- Mikado has many steps but should not take more than two days to run; the slowest steps are BLAST+ and TransDecoder, followed by `mikado serialise`
- TransDecoder and Portcullis can be installed with Conda
- TransDecoder and creating a blast database do not work with spaces in the file paths
- `mikado_prepared.fasta.fai` and `mikado.db` need to be manually deleted if rerunning the whole Mikado pipeline in the same directory as the files will not be overwritten and confusing errors will be thrown
- Make sure that the input list of samples is a TSV separated file; spaces separating each column will throw an error

# 4. Annotating non-coding RNA genes

Non-coding RNAs do not contain highly conserved exons and protein domains typically seen in mammalian protein-coding genes. Accordingly, identifying non-coding genes requires algorithms that do not rely on the same genomic features used in the gene-model identification algorithms described in steps 1-3 (e.g. ORF evaluation, intron-exon ratio etc.). Instead of the evaluation of ORFs to determine if the coding-gene model is functional, non-coding gene models are evaluated for their potential functionality based on whether the predicted secondary structure of that non-coding RNA matches a previously identified secondary structure.

Non-coding annotations can be generated using [the RNA family (Rfam) database](https://rfam.org/), an open-access, and maintained database of non-coding RNAs. The primary tool used in non-coding gene annotation and classification is [INFERence of RNA ALignment (Infernal)](http://eddylab.org/infernal/). Briefly, Infernal builds covariance models of RNA molecules, to incorporate sequence homology and predicted RNA secondary structure in the annotation and classification on non-coding molecules in the genome. To reduce the runtime and memory requirement of this process, researchers typically pre-select sequences (seed) based on sequence homology to a non-coding database, RNA-seq alignments, and regions identified as “non-coding” in GFF post processing algorithms (e.g. Mikado).

#### Seeding by BLASTing against Rfam

To perform one round of seeding (i.e. identifying genomic regions likely to contain non-coding RNA molecules), you can first BLAST your unmasked genome FASTA file against the Rfam database of non-coding RNAs. The step-by-step process is explained [here](https://docs.rfam.org/en/latest/sequence-extraction.html), but we've also outlined our process. Start by downloading and unzipping the Rfam database:

```
wget ftp://ftp.ebi.ac.uk/pub/databases/Rfam/CURRENT/fasta_files/Rfam.fa.gz
gunzip Rfam.fa.gz
```

Then filter duplicate non-coding RNAs stored within the database, as duplicates can interrupt generating the BLAST database that you'll need to build in order to BLAST against it. There are many ways of doing this; we used [seqtk](https://github.com/lh3/seqtk).

```
seqkit rmdup Rfam.fa > Rfam.rmdup.fa
```

After the duplicates are removed, you can now create a BLAST database which requires the deduplicated Rfam database as input. `-input_type fasta` specifies that the database is a FASTA file; `-dbtype nucl` indicates that the database is made of nucleotides; `-title Rfam_ncRNA` is a recognizable title for the database; `-parse_seqids` is required to keep the original sequence identifiers; `-out Rfam_ncRNA` is the output base name for the database, and is often the same as the title.

```
makeblastdb -in Rfam_rmdup.fa \
-input_type fasta \
-dbtype nucl \
-title Rfam_ncRNA \
-parse_seqids \
-out Rfam_ncRNA
```

Next, BLAST your unmasked genome FASTA file against the Rfam BLAST database. `-db Rfam_ncRNA` points to the base name of the BLAST database; `-query genome.fasta` points to your genome sequence; `-evalue 1e-6` describes the number of hits expected by chance; `-max_hsps 6` indicates a maximum of 6 alignments for any query-subject pair; `-max_target_seqs 6` indicates that a maximum of 6 aligned sequences are to be kept; `-outfmt 6` specifies the type of output from BLAST; `-out assembly.rfam.blastn` is the name of the output file. This command outputs all of the BLAST alignments found in the search that match all of the given criteria.

```
blastn -db Rfam_ncRNA \ 
-query genome.fasta \
-evalue 1e-6 -max_hsps 6 -max_target_seqs 6 -outfmt 6 \
-num_threads number_of_threads \
-out assembly.rfam.blastn
```

After this, convert the BLAST output to a BED file by extracting the chromosome, start coordinate, end coordinate, and name columns (columns 1, 7, 8,and 2 of a blastn output tsv):

```
awk -F "\t" '{print $1 "\t" $7 "\t" $8 "\t" $2}' assembly.rfam.blastn > assembly.rfam.bed
```

#### Seeding with previously identified non-coding RNA gene models

GFF files processed with Mikado and RNA-seq data (and GFF files annotated from other approaches) will have “biotype” information already stored (e.g. indicating if the gene encodes ncRNA). These regions can be extracted from a GFF file and saved as a BED file with the same chromosome, start coodinate, end coordinate, and name columns. These coordinates will proceed to be added to `assembly.rfam.bed`. Here is a way to isolate these regions from a GFF file in R using the library [rtracklayer](https://bioconductor.org/packages/release/bioc/html/rtracklayer.html).

```
library(rtracklayer)

# Read in the GFF/GTF file
gtf <- rtracklayer::readGFF("mikado_annotation.gtf")

# Ensembl annotates biotypes. Mikado will simply return “non-coding”
# Isolate all features with the following biotypes from the GTF file
gtf_nonCoding <- gtf[ (gtf$gene_biotype %in% c("lncRNA","miRNA","rRNA","scaRNA","snoRNA",
                                  "snRNA")),]

# Only keep the transcripts that these biotypes encode
gtf_nonCoding_transcript <- gtf_nonCoding[gtf_nonCoding$type == "transcript",]

# Save new GFF file that only has non-coding transcripts
rtracklayer::export.gff3(gtf_nonCoding_transcript,"mikado_annotation_transcripts.gff3")

# Only isolate the specific columns that are needed for the BED file
gtf_nonCoding_transcript <- gtf_nonCoding_transcript[,c("seqid","start","end","transcript_id")]

# Create a BED file by exporting the object created above as a table
write.table(gtf_nonCoding_transcript, file = "mikado_annotation_noncoding.bed",quote=F,row.names = F,col.names = F,sep="\t")
```

#### Combine different seeding results

Combine candidate noncoding RNA containing genome coordinates (seeds) from each method into a master-list using concatenate:

```
cat assembly.rfam.bed mikado_annotation_noncoding.bed > assembly_ncRNA_seed.bed
```

Sort the full BED file:

```
bedtools sort -i assembly_ncRNA_seed.bed > assembly_ncRNA_seed.s.bed
```

If not done yet, index the unmasked genome FASTA file using SAMtools:

```
samtools faidx genome.fasta
```

Isolate DNA from the unmasked FASTA file that matches the genomic coordinates of the non-coding RNA seeds using `bedtools getfasta`. `-fi genome.fasta` specifies the input genome; `-bed assembly_ncRNA_seed.s.bed` are the bed coordinates that are used to specify the regions from the FASTA file to extract the sequences from; `-fo assembly_ncRNA_seed.fasta` is the name of the output FASTA file. The sequences in this FASTA file will be used by Infernal to determine ncRNA identities.

```
bedtools getfasta -fi genome.fasta -bed assembly_ncRNA_seed.s.bed -fo assembly_ncRNA_seed.fasta
```

#### Using Infernal to annotate non-coding genes

Once the probably DNA sequences that encode ncRNAs have been found (now located in `assembly_ncRNA_seed.fasta`), these can be searched against a database of covariance models (i.e. statistical models of RNA secondary structure and sequence consensus). Searching against these covariance models will help determine the identity of the non-coding genes. First, download the database of covariance models from Rfam, and unzip the file:

```
wget ftp://ftp.ebi.ac.uk/pub/databases/Rfam/CURRENT/Rfam.cm.gz
gunzip Rfam.cm.gz
```

You will also need information from Rfam.clanin, which lists which models belong to the same "clan" (i.e. a group of homologous models, like LSU rRNA archaea and LSU rRNA bacteria). Download and compress this file.

```
wget ftp://ftp.ebi.ac.uk/pub/databases/Rfam/CURRENT/Rfam.clanin
cmpress Rfam.cm
```

Then, run Infernal using the cmscan function, which searches each sequence against the covariance model database. `-Z 1` indicates that the e-values are calculated as if the search space size is 1 megabase; `--cut_ga` is a flag to turn on using the GA (gathering) bit scores in the model to set inclusion thresholds, which are generally considered reliable for defining family membership; `--rfam` is a flag for using a strict filtering strategy for large databases (> 20 Gb) which accelerates the search at a potential cost to sensitivity; `--nohmmonly` specifies that the command must use the covariance models; `--tblout assembly_genome.tblout` is the output summary file of hits in tabular format; `-o assembly_genome.cmscan` is the main output file; `--verbose` indicates to include extra statistics in the main output; `--fmt 2` adds additional fields to the tabular output file, including information about overlapping hits; `--clanin Rfam.clanin` points to the clan information file; the final two positional arguments, `Rfam.cm` and `assembly_ncRNA_seed.fa`, point to the covariance model database and FASTA file of sequences respectively.

```
cmscan --cpu number_of_threads -Z 1 \
 --cut_ga --rfam --nohmmonly \
 --tblout assembly_genome.tblout \
 -o assembly_genome.cmscan \
 --verbose --fmt 2 \
 --clanin Rfam.clanin \
 Rfam.cm assembly_ncRNA_seed.fa
```

Finally, the tabular output of infernal can be converted to a GFF file. The [perl script](https://raw.githubusercontent.com/nawrockie/jiffy-infernal-hmmer-scripts/master/infernal-tblout2gff.pl) to convert this output can be found in the Infernal documentation. The script can be run as follows with `--fmt2` and `--cmscan` indicating that the output of Infernal was generated with the `--fmt 2` option by cmscan. `assembly_ncRNA_seed.tblout` is the output of cmscan and the results are stored in `assembly_ncRNA.gff`.

```
perl infernal-tblout2gff.pl --fmt2 --cmscan assembly_ncRNA_seed.tblout > assembly_ncRNA.gff
```


