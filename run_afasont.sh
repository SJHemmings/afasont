#!/bin/bash

#PBS -l select=1:ncpus=32:mem=120gb
#PBS -l walltime=24:00:00

#Author: Samuel J Hemmings
#Email:  s.hemmings@imperial.ac.uk
#Repo:   https://github.com/SJHemmings/afasont
#Cite:

##########################################
## Please Edit the Variables List Below ##
##########################################


WORK_DIR=/The/location/of/your/work/dir/to/put/results #Path to working directory, where you would like the assemblies to be made
ISOLATE=Example #Name of the isolate to be assembled
CONDA=/rds/general/user/.../home/anaconda3 #Path to conda directory

EPH=/The/Location/of/your/longread/fastq/pass/ephemeral/or/folder/that/can/be/deleted #Location for ephermal/intermediate files that can be late deleted

LONGREAD_DIR=/The/Location/of/your/longread/fastq/pass/folder #Path to Raw ONT data

PATH_SHORTREAD1=/The/Locaction/of/your/first/shortread/.fastq.gz #Path to 1st Illumina fastq
PATH_SHORTREAD2=/The/Locaction/of/your/second/shortread/.fastq.gz/2.fastq.gz #Path to 2nd Illumina fastq



###########################
## 0.1 conda environment ##
###########################

source ${CONDA}/etc/profile.d/conda.sh #Activate conda environement

if [ -d ${CONDA}/envs/afasont ]
       then
               conda activate afasont
       else
               conda create -n afasont
               conda activate afasont
               conda install -c bioconda nanofilt nanoplot nanolyse porechop fastqc cutadapt canu bowtie2 samtools pilon quast augustus trnascan-se busco
fi

#####################################
## Versions of packages first used ##
#####################################
#NanoFilt v2.8.0; NanoPlot v1.41.0; NanoLyse v1.2.1; porechop v0.2.4; FastQC v0.11.9; cutadapt v1.18; canu v2.2; bowtie2 v2.5.0; 
#samtools v1.6; pilon v1.24; QUAST v5.2.0; AUGUSTUS v3.5.0; tRNAscan-SE v2.0.11; BUSCO v5.4.4

##########################
## 0.2 Directory set-up ##
##########################

cd ${WORK_DIR}

if [ -d Nanopore_de_novo_assemblies ]
       then
               cd Nanopore_de_novo_assemblies
                       if [ -d ${ISOLATE} ]
                               then
                                       echo "(o) The isolate directory: ${ISOLATE} , already exists"
                               else
                                       mkdir ${ISOLATE}
                                       cd ${ISOLATE}
                                       mkdir 1.Long_read_filter 2.Short_read_filter 2.Short_read_filter/fastQC 2.Short_read_filter/filtered_fastq 3.Canu 4.Polish 4.Polish/bt2_index 5.Genome_stats \
5.Genome_stats/quast 5.Genome_stats/augustus 5.Genome_stats/trnascan
                                       echo "(o) ${ISOLATE} directory made"
                       fi

       else
               mkdir Nanopore_de_novo_assemblies
               cd Nanopore_de_novo_assemblies
               mkdir ${ISOLATE}
               cd ${ISOLATE}
               mkdir 1.Long_read_filter 2.Short_read_filter 2.Short_read_filter/fastQC 2.Short_read_filter/filtered_fastq 3.Canu 4.Polish 4.Polish/bt2_index 5.Genome_stats \
5.Genome_stats/quast 5.Genome_stats/augustus 5.Genome_stats/trnascan
               echo "(o) All directories made for ${ISOLATE}"
fi
#Make needed directories

WORK_DIR1=${WORK_DIR}/Nanopore_de_novo_assemblies/${ISOLATE}
#Set up new variable



#########################
## 1. Long_read_filter ##
#########################

for i in $(ls ${LONGREAD_DIR})
       do
               porechop -i ${LONGREAD_DIR}/${i} -o ${EPH}/porechop_${i} -t 20 --format fastq.gz
               zcat ${EPH}/porechop_${i} | NanoLyse --logfile ${EPH}/NanoLyse.log | NanoFilt -q 10 -l 1000 | gzip >> ${WORK_DIR1}/1.Long_read_filter/${ISOLATE}_high_qual_reads.fastq.gz
       done
#Filter fastq files to: Remove adapters, remove any kit control DNA, >Q10, >1000bp

NanoPlot -t 32 --fastq ${WORK_DIR1}/1.Long_read_filter/${ISOLATE}_high_qual_reads.fastq.gz --loglength -o ${WORK_DIR1}/1.Long_read_filter/NanoPlot --prefix ${ISOLATE}_high_qual_ --plots dot --format pdf --huge
#Make plots to view for QC



#########################
## 2.Short_read_filter ##
#########################

fastqc --extract -o ${WORK_DIR1}/2.Short_read_filter/fastQC/ ${PATH_SHORTREAD1}
fastqc --extract -o ${WORK_DIR1}/2.Short_read_filter/fastQC/ ${PATH_SHORTREAD2}
#Run fastqc of shortreads

NAME_SHORTREAD1=$(basename ${PATH_SHORTREAD1} | sed 's|.fastq||g' | sed 's|.gz||')
NAME_SHORTREAD2=$(basename ${PATH_SHORTREAD2} | sed 's|.fastq||g' | sed 's|.gz||') #retrieve original name of fastq file

ADAPT1=$(grep "Overrepresented" ${WORK_DIR1}/2.Short_read_filter/fastQC/${NAME_SHORTREAD1}_fastqc/fastqc_data.txt -A 2 | tail -n 1 | cut -f 1)
ADAPT2=$(grep "Overrepresented" ${WORK_DIR1}/2.Short_read_filter/fastQC/${NAME_SHORTREAD2}_fastqc/fastqc_data.txt -A 2 | tail -n 1 | cut -f 1)
#Pulls out the sequences of adapter sequences and removes them automatically, but please check the reports to be sure!

echo ""
echo "(o) cutadapt will remove the overrepresented sequence: '${ADAPT1}' from ${NAME_SHORTREAD1}"

cutadapt -a ${ADAPT1} -o ${WORK_DIR1}/2.Short_read_filter/filtered_fastq/${ISOLATE}_short1.fastq.gz ${PATH_SHORTREAD1}
#removes adapters

echo ""
echo "(o) cutadapt will remove the overrepresented sequence: '${ADAPT2}' from ${NAME_SHORTREAD2}"

cutadapt -a ${ADAPT2} -o ${WORK_DIR1}/2.Short_read_filter/filtered_fastq/${ISOLATE}_short2.fastq.gz ${PATH_SHORTREAD2}
#removes adapters



#############
## 3. Canu ##
#############

canu -d ${WORK_DIR1}/3.Canu -p ${ISOLATE}_canu_assembly \
        gridOptions="-lselect=1:ncpus=32:mem=64gb -lwalltime=10:00:00" \
        genomeSize=29m -nanopore ${WORK_DIR1}/1.Long_read_filter/${ISOLATE}_high_qual_reads.fastq.gz
#canu makes first assembly

until [ -e ${WORK_DIR1}/3.Canu/${ISOLATE}_canu_assembly.contigs.fasta ]
do
sleep 30m
done


###############
## 4. Polish ##
###############

bowtie2-build ${WORK_DIR1}/3.Canu/${ISOLATE}_canu_assembly.contigs.fasta ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE}
#build scafold from canu assembly

bowtie2 -x ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE} -1 ${WORK_DIR1}/2.Short_read_filter/filtered_fastq/${ISOLATE}_short1.fastq.gz -2 ${WORK_DIR1}/2.Short_read_filter/filtered_fastq/${ISOLATE}_short2.fastq.gz | \
samtools view -b -f 0x2 -o ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE}.bam - #align short reads to ONT assembly & make bam

samtools sort -o ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE}.sort.bam ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE}.bam #sort bam
#sort bam

samtools index -b ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE}.sort.bam #index bam
#index bam

java -Xmx120G -jar ${CONDA}/envs/polish/share/pilon-1.24-0/pilon.jar --genome ${WORK_DIR1}/3.Canu/${ISOLATE}_canu_assembly.contigs.fasta --bam ${WORK_DIR1}/4.Polish/bt2_index/${ISOLATE}.sort.bam --output ${ISOLATE}.pilon --outdir ${WORK_DIR1}/4.Polish/pilon
#Polish canu assembly using shortreads using pilon



####################
## 5.Genome_stats ##
####################

quast -o ${WORK_DIR1}/5.Genome_stats/quast ${WORK_DIR1}/4.Polish/pilon/${ISOLATE}.pilon.fasta
#quast stats about contigs, N50 ect

augustus --progress=true --strand=both --species=aspergillus_fumigatus --AUGUSTUS_CONFIG_PATH=${CONDA}/envs/afasont/config --gff3=on  \
${WORK_DIR1}/4.Polish/pilon/${ISOLATE}.pilon.fasta > ${WORK_DIR1}/5.Genome_stats/augustus/${ISOLATE}.augustus3.gff
#predicts number of protein coding genes

tRNAscan-SE -o ${WORK_DIR1}/5.Genome_stats/trnascan/results.txt ${WORK_DIR1}/4.Polish/pilon/${ISOLATE}.pilon.fasta
#predicts number of genes for tRNA

busco -f -c 32 -m genome --augustus --augustus_species aspergillus_fumigatus -i ${WORK_DIR1}/4.Polish/pilon/${ISOLATE}.pilon.fasta -l ascomycota -o busco --out_path ${WORK_DIR1}/5.Genome_stats/
#Predicts the genome completeness using busco

#(o) fin.