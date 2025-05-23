## Read in GFF output from Infernal
  

library(rtracklayer)
library(dplyr)
library(tidyr)


# Read in GFF output from Infernal; file path must be specified for GFF file if "infernal.gff" is not in the working directory

infernal <- rtracklayer::readGFF("infernal.gff")


## Read in and reformat RFam table

  # Read in RFam table; file path must be specified if "family.txt" is not in the working directory. Run the "unique" function on column 19 to see the different types of ncRNAs that exist in this table.

rfam <- read.delim("family.txt", header = FALSE, sep = "\t")
# unique(rfam$V19)


# Rename feature types (V19 column) to standard, singular features; note that order matters for these commands as some features are labelled as e.g. "Gene; snRNA; snoRNA; scaRNA;" and we have tried to pick the most appropriate name.


rfam$V19[grepl("scaRNA", rfam$V19)] <- "scaRNA"
rfam$V19[grepl("splicing", rfam$V19)] <- "snRNA"
rfam$V19[grepl("tRNA", rfam$V19)] <- "tRNA"
rfam$V19[grepl("rRNA", rfam$V19)] <- "rRNA"
rfam$V19[grepl("lncRNA", rfam$V19)] <- "lncRNA"
rfam$V19[grepl("snoRNA", rfam$V19)] <- "snoRNA"
rfam$V19[grepl("sRNA", rfam$V19)] <- "sRNA"
rfam$V19[grepl("miRNA", rfam$V19)] <- "microRNA"
rfam$V19[grepl(";", rfam$V19)] <- "misc_RNA"
# unique(rfam$V19)


## Reconstruct the GFF file

# Create a copy of the GFF


output <- infernal


# When the FASTA file was fed into Infernal, the file consisted of specific contigs and coordinates that Infernal would scan. The coordinates are therefore still included in the first column of the GFF, and the GFF coordinates in columns four and five need to be added onto the starting coordinate to adjust everything properly. E.g. if the FASTA provided to Infernal started at base pair 1186 on a specific contig, but then the ncRNA started at position 720 of that contig fragment, 1186 + 720 would be the true starting position. Therefore, we need to correct this.

# First, split the "seqid" column into three at the colon and dash. Remove the "seqid" column. Label the first new column "chromosome", and the second and third "start1" and "end1" respectively. "start1" is the starting position of the contig/chromosome fragment that was submitted to Infernal, and "end1" is the ending position.


output <- output %>%
  tidyr::separate(seqid, into = c("chromosome", "positions"), sep = ":", remove = FALSE) %>%
  tidyr::separate(positions, into = c("start1", "end1"), sep = "-", convert = TRUE)
output$seqid <- NULL


# Add the "start1" column to the "start" column, and replace "start" with this value; add the "start1" column to the "end" column and use this to replace the "end" value. These represent the true coordinates where the ncRNA is.

output <- output %>%
  dplyr::mutate(
    start = start + start1,
    end = end + start1
  )
output$start1 <- NULL
output$end1 <- NULL


# Now take the current "type" column, which actually has a more descriptive name for the ncRNA that was identified, and relabel this column as "ID". Move the "ID" column to be located to the left of the "evalue" column, as this represents the first bit of the metadata in column nine that we want in the GFF file.

output$ID <- output$type
output <- output %>%
  dplyr::relocate(ID, .before = evalue)


# Then, to add the info from RFam table, we will start simply be combining the RFam table with the Infernal GFF file. To do this, use dplyr's "left_join" function to join the objects, using the "type" column from the Infernal GFF and the second column of the RFam table to align the rows.


output <- output %>%
  dplyr::left_join(rfam, by = c("type" = "V2"))


# Now that the two are combined, we will make the following modifications to format the GFF file:
  # - Replace the "type" column with simplified feature types in column "V19"
  # - Rename "V1" column as "RFamID"
  # - Rename "V4" column with the longer description as the ncRNA product
  # - Add a final column identifying the "gbkey" as ncRNA to match RefSeq formatting
  # - Remove all other columns beginning with "V"


output$type <- output$V19
colnames(output)[11] <- "RFamID"
colnames(output)[13] <- "product"
output$gbkey <- "ncRNA"
output <- output[,!grepl("^V", colnames(output))]
head(output)


# Export the new GFF file called "infernal.types.gff"


rtracklayer::export.gff3(output, "infernal.types.gff", format = "gff3")
