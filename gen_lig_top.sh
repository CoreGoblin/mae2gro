#!/bin/bash

#################################################################################
# Script Name: gen_lig_top.sh
# Description: This script automates the preparation of a new complex in GROMACS.
#              The script can be executed to perform the steps required for 
#              complex preparation. Run in the directory containing the PDB files. 
# Author: [Anton Sellerberg]
# Date: [09-08-24]
#################################################################################
# Run below line to make the script executable
# chmod +x N2A_AA3_IFD2GMX.sh 

# This script sets the shell option '-e' which causes the script to exit immediately if any command exits with a non-zero status.
set -e

# Activates compilers, parallell processing, visualisation and gromacs to the current lunarc session
module add GCC/11.2.0  OpenMPI/4.1.1 VMD/1.9.4a57 GROMACS/2021.5-PLUMED-2.8.0

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create a directory with _clean suffix
#CLEAN_DIR="$(basename "$(pwd)")_clean"
#mkdir "../$CLEAN_DIR"

# Search for the directory in the current directory
# PDB_DIR=$(find . -type d -name "N2*" -print -quit)

# Loop through each pdb file in the script directory
for pdb_file in *.pdb; do
    # Create a directory with the same name as the pdb file (without the extension)
    pdb_dir="${pdb_file%.*}"
    mkdir "$pdb_dir"
    
    # Move the pdb file to the newly created directory
    mv "$pdb_file" "$pdb_dir/"
    # Copy the pdb file to the newly created directory with the name "pose.pdb"
    cp "$pdb_dir/$pdb_file" "$pdb_dir/pose.pdb"
    
    # Debug message
    echo "Processed $pdb_file and moved to $pdb_dir"
done

# Debug message
echo "Completed processing all PDB files."

# Loop through each directory
for dir in */; do
    # Move into the directory
    cd "$dir"
    
    # Run sed command to remove lines containing 'HOH', 'CONECT', or 'ANISOU' from pose.pdb
    sed -i '/HOH\|CONECT\|ANISOU/d' pose.pdb
    # AWK: search for ligands, '{print > tolower($4)".pdb"}': print ligands to separate pdb-files
    awk '/UNK/ {print > tolower($4)".pdb"}' pose.pdb 

    acpype -i unk.pdb -n 0
    # Debug message
    echo "Cleaned pose & processed ligand topology in $dir"
    
    # Move back to the parent directory
    cd ..
done

# Get the current directory
current_directory=$(pwd)

# Loop through each directory in the current directory
for directory in $current_directory/*; do
    # Check if the item is a directory
    if [ -d "$directory" ]; then
        # Remove 'N2A_IFD_' from the directory name
        new_directory_name=$(basename "$directory" | sed 's/N2A_IFD_//')
        # Rename the directory
        
        # Find unk.acpype/unk_GMX.itp in the directory
        unk_gmx_file="$directory/unk.acpype/unk_GMX.itp"
        posre_file="$directory/unk.acpype/posre_unk.itp"

        # Check if the file exists
        if [ -f "$unk_gmx_file" ]; then
            # Create the ../Inputfiles directory if it doesn't exist
            inputfiles_directory="../../../N2A/Inputfiles/$new_directory_name"
            mkdir -p "$inputfiles_directory"
            
            # Copy the file to the ../Inputfiles directory
            cp "$unk_gmx_file" "$inputfiles_directory"
            cp "$posre_file" "$inputfiles_directory"
        fi
    fi
done

# Debug message
echo "Completed processing all directories."

