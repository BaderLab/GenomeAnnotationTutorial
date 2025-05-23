# This notebook reads in Mikado gene models labeled by Infernal, and assigns Infernal gene names to all gene models.

## Read in file


library(rtracklayer)
library(dplyr)


# Read in GFF file of Mikado features that overlap with Infernal lncRNAs


mikado <- BiocGenerics::as.data.frame(rtracklayer::readGFF("mikado.infernal.lncRNALabeled.mikadoInfo.gff"))
head(mikado)


# Now read in Infernal lncRNA information 

infernal <- BiocGenerics::as.data.frame(rtracklayer::readGFF("mikado.infernal.lncRNALabeled.infernalInfo.gff"))
head(infernal)


## Combine information

# The goal of this section is to:
  # - Combine multiexonic IDs from Infernal to be a single transcript feature
# - Update general ncRNA and ncRNA_gene features to be lncRNAs specifically
# - Add Infernal information to Mikado features

# First, let's combine multiexonic IDs from infernal. Multiexonic IDs have an underscore followed by a number to represent an exon. Therefore, we can remove everything after and including the last underscore in the infernal ID column. We also want to do this for the IDs of the Infernal-only genes located in the Mikado file. These genes will have "cmscan" as the source.


infernal$ID <- gsub("_(?!.*_).*$", "", infernal$ID, perl = TRUE)
mikado$ID[mikado$source == "cmscan"] <- gsub("_(?!.*_).*$", "", 
                                             mikado$ID[mikado$source == "cmscan"], 
                                             perl = TRUE)


# Along these same lines, we want to make the product names so that they don't define distinct exons or regions. Therefore, we would like to remove anything after "conserved region" or "exon" in the product column.


infernal$product <- gsub(" (conserved region|exon).*$", "", infernal$product)
mikado$product[mikado$source == "cmscan"] <- gsub(" (conserved region|exon).*$", "", 
                                                  mikado$product[mikado$source == "cmscan"])


# Second, we can change all "ncRNA" and "ncRNA_gene: features to lncRNA and lncRNA_gene respectively in Mikado. Note that some lncRNA IDs in Infernal have overlapped with mRNA features from Mikado. This may be because Mikado mistakenly identified some regions as coding when they are truly ncRNAs, or this particular species has extended transcripts with coding regions added.


mikado$type <- gsub("^ncRNA_gene$", "lncRNA_gene", mikado$type)
mikado$type <- gsub("^ncRNA$", "lncRNA", mikado$type)


# Finally, we want to add information from Infernal to the Mikado gene models. We only want to add this information to gene, mRNA, lncRNA_gene, and lncRNA features. This is because not all exons or other features associated with genes or transcripts were captured using `bedtools intersect`, and generally, child features (i.e. features contained within specific genes or transcripts) only need to associate with their parent features (i.e. corresponding genes and transcripts) to be sufficiently interpreted.

# Therefore, we will isolate any gene and transcript features and add the information from column nine of Infernal (i.e. the metadata). We will want to change the "ID" column to "predicted_gene_symbol".


mikado$predicted_gene_symbol <- NA
mikado$infernal_product <- NA
mikado$gbkey <- NA
mikado$gene_biotype <- NA
for(row in 1:nrow(mikado)) {
  if(mikado$type[row] %in% c("gene","mRNA","lncRNA_gene","lncRNA")) {
    mikado$predicted_gene_symbol[row] <- infernal$ID[row]
    mikado$infernal_product[row] <- infernal$product[row]
    if(mikado$type[row] %in% c("gene","lncRNA_gene")) {
      mikado$gene_biotype[row] <- "lncRNA"
    } else {
      mikado$gbkey[row] <- "ncRNA"
    }
  }
}
head(mikado)


## Remove redundancies

# We are dealing with a lot of redundant information in each file, since BedTools reported each unique overlap between a feature in Mikado and a feature from Infernal. Therefore, if multiple exons from the same gene in Infernal lined up to a single transcript in the Mikado GFF, then each of these overlaps would be reported on a distinct line. We therefore want to collapse a lot of this information.

# Since we removed the unique characters in the Infernal gene symbols and product descriptions, we can remove unique rows. If different Infernal gene symbols matched to the same Mikado gene/transcript, we want to preserve this information.

# Specify columns we want to make sure are unique


uniq_cols <- BiocGenerics::setdiff(names(mikado), c("predicted_gene_symbol", "infernal_product"))


# Group by these columns; if `predicted_gene_symbol` and `infernal_product` differ, these will be separated by semi-colons


mikado <- mikado %>%
  dplyr::group_by(dplyr::across(dplyr::all_of(uniq_cols))) %>%
  dplyr::summarize(
    dplyr::across(all_of(c("predicted_gene_symbol", "infernal_product")), ~ paste(unique(.), collapse = ";")),
    .groups = "drop"
  )



## Additional feature adjustments for Infernal genes

# Now all of the Infernal features that overlapped with Mikado features are dealt with, but we still need to do some extra work on the features found only by Infernal. You can check to see if any of these exist by looking for anything in the Mikado GFF that has "cmscan" in the column "source". 


head(mikado[mikado$source == "cmscan",])


# The first thing we want to do is make sure that all separate "cmscan" lncRNAs have a unique gene and transcript ID. We will assume that any of these lncRNAs that are on the same contig are actually multiple exons derived from the same lncRNA gene, and that lncRNAs on separate contigs are different genes. Therefore, we will loop through any lncRNAs that share the same ID, and determine if they are on the same or different contigs. If they are on the same contig, they will share the same ID; if they are on different contigs, they will get a unique ID.


# Isolate unique Infernal gene symbols with no Mikado overlap
genes <- unique(mikado$predicted_gene_symbol[mikado$source == "cmscan"])
# Loop through genes
for(gene in genes) {
  # Gather the different contigs that the gene is on
  contigs <- unique(mikado$seqid[mikado$predicted_gene_symbol == gene])
  # If there is more than one contig, loop through the different contigs
  if(length(contigs) > 1) {
    # Start a counter at 0
    i <- 0
    for(contig in contigs) {
      # Only add modifications at the second contig onward
      if(i > 0){
        # Create new unique ID name
        new_id <- paste(gene, "-copy", i, sep = "")
        # Replace the current ID for this gene and contig with new_id
        mikado$ID[mikado$ID == gene & mikado$seqid == contig] <- rep(new_id, length(mikado$ID[mikado$ID == gene & mikado$seqid == contig]))
        }
      # Increase counter assuming we are working with the next lncRNA copy
      i <- i + 1
    }
  }
}
# Look at all of the unique gene symbols to see if any copies were made
# (They will have "copy#" after the gene symbol)
unique(mikado$predicted_gene_symbol[mikado$source == "cmscan"])



# Now we need to create lncRNA and gene IDs for these features, especially combining the multi-exonic features. We can treat everything that currently exists as an exon, and create transcript and gene features above these features. Note that the following code assumes that every feature listed above has "lncRNA" in the "type" column, and "cmscan" in the source column (which should be true - this is just a sanity check).


# Add gbkey=NA, gene_biotype=NA, Parent=NA to all cmscan rows just in case there was no overlap with Mikado
# so that rbind will work
mikado$gbkey[mikado$source == "cmscan"] <- rep(NA, length(mikado$source == "cmscan"))
mikado$gene_biotype[mikado$source == "cmscan"] <- rep(NA, length(mikado$source == "cmscan"))
mikado$Parent[mikado$source == "cmscan"] <- rep(NA, length(mikado$source == "cmscan"))
# Isolate unique Infernal gene symbols with no Mikado overlap
genes <- unique(mikado$predicted_gene_symbol[mikado$source == "cmscan"])
# Loop through genes
for(gene in genes) {
  # Gather the different contigs that the gene is on
  contigs <- unique(mikado$seqid[mikado$predicted_gene_symbol == gene])
  # Loop through contigs
  for(contig in contigs){
    # Get indexing in terms of where these occur in the dataframe to reduce code
    i <- mikado$predicted_gene_symbol == gene & mikado$seqid == contig
    # First, duplicate one of the "exon" rows - this will become our gene feature
    gene_feat <- mikado[i,][1,]
    # Change type to lncRNA_gene
    gene_feat$type <- "lncRNA_gene"
    # Add gene_biotype=lncRNA
    gene_feat$gene_biotype <- "lncRNA"
    # Make the start value the lowest of all "exon" start values
    gene_feat$start <- min(mikado$start[i])
    # Make the end value the highest of all "exon" end values
    gene_feat$end <- max(mikado$end[i])
    # Create a transcript feature by copying the gene feature
    transcript <- gene_feat
    # Make the gbkey ncRNA and set gene_biotype=NA
    transcript$gbkey <- "ncRNA"
    transcript$gene_biotype <- "NA"
    # Add .1 to the transcript ID
    transcript$ID <- paste(transcript$ID, ".1", sep = "")
    # Add Parent pointing to gene
    transcript$Parent <- gene_feat$ID
    # Change the type back to lncRNA
    transcript$type <- "lncRNA"
    # Now change the lncRNA designation to exon for the specified gene symbol and contig in the loop
    mikado$type[i] <- rep("exon", length(mikado$type[i]))
    # Add a "Parent ID" pointing to the new transcript ID that we created
    mikado$Parent[i] <- rep(transcript$ID, length(mikado$type[i]))
    # Now change ID to end with .exon1, .exon2, etc.
    for(exon in 1:sum(i)) {
      # Create new ID with paste
      mikado$ID[which(i)[exon]] <- paste(mikado$ID[which(i)[exon]],".1.exon",exon, sep = "")
    }
    # Add gene and transcript features to mikado dataframe, inserting it just before the "exons"
    # First line needs an exception to prevent duplicating an exon
    if(which(i)[1] - 1 == 0) {
      mikado <- rbind(gene_feat,
                      transcript,
                      mikado[which(i)[1]:nrow(mikado), ])
    } else {
      mikado <- rbind(mikado[1:(which(i)[1] - 1), ],
                      gene_feat,
                      transcript,
                      mikado[which(i)[1]:nrow(mikado), ])
    }
  }
}


# Now hopefully all is well and we can export the new GFF file in peace. Please view the GFF file before moving forward to make sure nothing funky happened. We'll try to monitor for issues as it's very possible that some may arise.

rtracklayer::export.gff3(mikado, "mikado.infernal.lncRNALabeled.polished.gff", format = "gff3")

