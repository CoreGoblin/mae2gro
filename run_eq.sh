#################################################################################
#!/bin/bash
# TESTING LINES --------------------------------------------------------------------------------------------
# Activates compilers, parallell processing, visualisation and gromacs to the current lunarc session
module add GCC/11.2.0  OpenMPI/4.1.1 VMD/1.9.4a57 GROMACS/2021.5-PLUMED-2.8.0
current_directory=$(pwd) 
# ------------------------------------------------------------------------------------------------------------
# Run energy minimization
for directory in $current_directory/*; do
    # Check if the item is a directory
    if [ -d "$directory" ]; then
        cd "$directory"   
        sbatch equilibration.sh -J N2Beq
        cd ..                       
    fi
done
echo "Equilibration running ... use squeue -u $USER to check status." 

