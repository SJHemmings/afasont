# afasont

Author: Samuel J Hemmings <br>
Email: s.hemmings@imperial.ac.uk <br>
Repo:   https://github.com/SJHemmings/afasont <br>
Cite:

### Welcome to the afasont pipeline

afasont (*Aspergillus fumigatus* assembly for Oxford Nanopore Technologies) is a pipeline written in a bash script that can 
be used to make *de novo* genome assemblies from long read fastq files, sequenced using Oxford Nanopore Technologies. These 
assemblies will then be polished using paired end short read fastq files. The pipeline will then provide you with statistics 
on the quality of your assembly, number of genes and predicted completeness.

### The packages run by afasont are: 
porechop -> nanolyse -> nanofilt -> nanoplot -> fastqc -> cutadapt -> canu -> bowtie2 -> samtools -> 
pilon -> quast -> augustus -> trnascan-se -> busco

Please be aware that this pipeline was originally written to assemble *A. fumigatus* genomes (~29Mbp) in a conda 
environment on a HPC with a PBS queueing system. However, it should also be able to handle other small 
genomes with a small amount of editing, please let me know if you try!

### Things you need to do to run the script:

* Download run_afasont.sh and place the script in a directory you are happy to run it from.
* Give the script premission to run with 
```
chmod u+x run_afasont.sh
```
* Open the run_afasont.sh file with your prefered text editor and change the variables so they are paths to your 
short read fastq files, long read fastq folder, your conda directory and a working directory that you want the 
results to be placed in.  
* Run script.
* Once the run is completed, 5 directories will be made under the name of your sample which contain: 1.Long_read_filter; 
2.Short_read_filter; 3.Canu; 4.Polish (which contains your final assembly); 5.Genome_stats.
