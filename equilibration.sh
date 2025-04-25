#!/bin/sh
#
# Job name
#SBATCH -J eq
#SBATCH -A LU2024-2-50
#SBATCH -p lu48
#SBATCH -N 1
#SBATCH -n 24
#SBATCH -t 10:00:00

# Use SBATCH equilibration.sh to run the script
module add GCC/11.2.0  OpenMPI/4.1.1 GROMACS/2021.5-PLUMED-2.8.0

######################### Fixed volume, 100 ps ############################
# -f: input parameter file, -c: input coordinate file, -p: topology file, -o: output file, -r: reference coordinate file
gmx grompp -f ../../Runfiles/nvt100.mdp -c em.gro -p topol.top -o nvt100.tpr -r em.gro
# -n: MPI processes -ntomp: threads -deffnm: output file name -s: input file  
mpirun -n 24 gmx_mpi mdrun -ntomp 1 -deffnm nvt100 -s nvt100.tpr 

######################### Fixed pressure, 500 ps ############################
gmx grompp -f ../../Runfiles/npt500.mdp -c nvt100.gro -p topol.top -o npt500.tpr -r em.gro
mpirun -n 24 gmx_mpi mdrun -ntomp 1 -deffnm npt500 -s npt500.tpr 
######################### Fixed pressure, 1000 ps ############################
gmx grompp -f ../../Runfiles/npt1000.mdp -c npt500.gro -p topol.top -o npt1000.tpr -r em.gro
mpirun -n 24 gmx_mpi mdrun -ntomp 1 -deffnm npt1000 -s npt1000.tpr
