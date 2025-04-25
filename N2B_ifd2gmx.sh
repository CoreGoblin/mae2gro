#!/bin/bash

#################################################################################
# Script Name: n2a_ifd2gmx.sh
# Description: This script automates the preparation of a new complex in GROMACS.
#              The script can be executed to perform the steps required for 
#              complex preparation. Run in the directory containing the PDB files. 
# Author: [Anton Sellerberg]
# Date: [09-08-24]
#################################################################################
# This script sets the shell option '-e' which causes the script to exit immediately if any command exits with a non-zero status.
set -e

# Loop through each pdb file in the script directory (IFD-outputs)
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

    cp ~/lun/nmda/N2A/complex_ref.pdb . 

    echo "Cleaned pose & loaded reference in $dir"

    # Move back to the parent directory
    cd ..
done

# INSTALLING CONDA ENVIRONMENT AND PACKAGES
# ----------------------------------------------------------------------------------------------
# The below line circumvents an issue with installing the conda packages and solvers for your local machine. 
# conda install -n base libarchive -c main --force-reinstall --solver classic
# conda install --solver=classic conda-forge::conda-libmamba-solver conda-forge::libmamba conda-forge::libmambapy conda-forge::libarchive
# ----------------------------------------------------------------------------------------------
# conda create -n md python=3.12.2 # Creates a conda environment and installs python 
# conda activate md # Activates the conda environment md
# conda install numpy scipy jupyter matplotlib pandas # Installs the necessary packages for the conda environment
# conda install -c conda-forge mdtraj # Installs the mdtraj package for the conda environment
# ----------------------------------------------------------------------------------------------

# Conflict avoidance 
module purge
# source deactivate 
# Activate environment
source activate md || { echo "Failed to activate Conda environment"; exit 1; }
which python # Check the python version obsessively 

# Loop through each directory
for dir in */; do
    cd "$dir"
    python ~/lun/nmda/Runfiles/mdtrajalign.py # Run the python script mdtrajalign.py in md environment
    cd ..
done 

# Debug message
echo "Completed processing all directories."

conda deactivate 

# Activates compilers, parallell processing, visualisation and gromacs to the current lunarc session
module add GCC/11.2.0  OpenMPI/4.1.1 VMD/1.9.4a57 GROMACS/2021.5-PLUMED-2.8.0

# Loop through each directory
for dir in */; do
    cd "$dir"
    # -ignh: ignore hydrogen atoms
    # -his: process histidine residues
    gmx pdb2gmx -f alignedprot.pdb -ignh -his -o syst.pdb << EOF
    6 
    1 
    1 
    1
    2
    0
    1
    1
    1
    1
    1
    0
    1
    1
EOF
    cd ..
done 

# Debug message
echo "Protein topologies generated, gromacs conversion completed."

# Build complex 
for dir in */; do
    cd "$dir"
    grep '^ATOM' syst.pdb > complex.pdb
    grep '^ATOM' staticligands.pdb >> complex.pdb
    grep '^ATOM' lig.pdb >> complex.pdb
    echo "$dir complex built."
    cd ..
done 

# Get the current directory
current_directory=$(pwd)

# Organization of directories and unpacking of input files
for directory in $current_directory/*; do
    # Check if the item is a directory
    if [ -d "$directory" ]; then
        # Remove 'N2A_IFD_' from the directory name
        new_directory_name=$(basename "$directory" | sed 's/N2A_IFD_//')

        # Rename the directory
        mv "$directory" "$current_directory/$new_directory_name"

        # Remove '_1' from the end of the directory name if it exists
        trim_directory_name=${new_directory_name%_1}
        inputfiles_directory="../../../N2A/Inputfiles/$trim_directory_name"

        cp "$inputfiles_directory"/* "$new_directory_name" 
        # Unpack input files in the cleanup directory 
        cp /home/babwan/lun/nmda/N2A/Inputfiles/"$trim_directory_name"/* "$new_directory_name"
        cp /home/babwan/lun/nmda/N2A/main_Inputfiles/* "$new_directory_name"
    fi
done


# Setting up the system for equilibration
for directory in $current_directory/*; do
    # Check if the item is a directory
    if [ -d "$directory" ]; then
        cd "$directory"             # Move into the directory
        cp complex.pdb system.pdb   # Backup duplicate of complex.pdb prior to equilibration
    
        # Define perioidic boundary conditions 
        gmx editconf -f system.pdb -bt octahedron -d 0.7 -o box.gro
        # Artificially solvate the system  
        gmx solvate -cp box.gro -o solvated.gro -p topol.top
        # Create run file for ions 
        gmx grompp -f ions.mdp -c solvated.gro -p topol.top -o ions.tpr -maxwarn 2 #RESOLVE WARNINGS
        # Neutralize the system
        printf "17\n" | gmx genion -s ions.tpr -o solvated_ions.gro -p topol.top -nname CL -neutral
        # Create index group for the ligand specific complex 
        printf "1|13|14|15\nname 26 Complex\nq\n" | gmx make_ndx -f solvated_ions.gro
        # Create run file for energy minimization
        gmx grompp -f em.mdp -c solvated_ions.gro -p topol.top -o em.tpr

        cd ..                       # Move back to the parent directory
    fi
done

# Debug message
echo "Protein ligand complexes ready for minimization."

# Run energy minimization
for directory in $current_directory/*; do
    # Check if the item is a directory
    if [ -d "$directory" ]; then
        cd "$directory"   

        # Minimization, 500 steps, takes a few minutes          
        gmx mdrun -deffnm em -v     
        # Package all files into prepfiles
        mkdir -p Prepfiles && find . -maxdepth 1 -type f -exec mv {} Prepfiles/ \;
        # Prepare equilibration script 
        cp ~/lun/nmda/Runfiles/equilibration.sh . 
        # Move index out of prepfiles 
        cp Prepfiles/index.ndx .

        cd ..                       
    fi
done

# Debug message
echo "Protein ligand complexes ready for equilibration."

#################################################################################
#!/bin/bash
# TESTING LINES --------------------------------------------------------------------------------------------
# Activates compilers, parallell processing, visualisation and gromacs to the current lunarc session
module add GCC/11.2.0  OpenMPI/4.1.1 VMD/1.9.4a57 GROMACS/2021.5-PLUMED-2.8.0
current_directory=$(pwd) 
# ------------------------------------------------------------------------------------------------------------

